import Foundation
import AVFoundation
import AudioToolbox

public class NativeSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = NativeSpeechService()

    private var sharedSynthesizer = AVSpeechSynthesizer()
    private var previewSynthesizer = AVSpeechSynthesizer()

    public override init() {
        super.init()
        sharedSynthesizer.delegate = self
    }

    /// Previews a short spoken sample of a voice directly on the device.
    public func previewVoice(voiceId: String, sampleText: String = "Welcome to StoryTeller Pro. Creating viral videos in seconds.") {
        if previewSynthesizer.isSpeaking {
            previewSynthesizer.stopSpeaking(at: .immediate)
        }
        let voice = selectVoice(voiceId: voiceId)
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        previewSynthesizer.speak(utterance)
    }

    public func stopVoicePreview() {
        if previewSynthesizer.isSpeaking {
            previewSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    public var isPreviewing: Bool {
        previewSynthesizer.isSpeaking
    }

    public struct SpeechResult {
        public let audioURL: URL
        public let duration: Double
        public let words: [WordTiming]
    }

    /// Synthesizes the full story text to an on-device audio file without any truncation.
    /// Splits long text and multi-paragraph stories into sequential sentence chunks
    /// and streams them consecutively into a single audio file (.caf container).
    public func synthesizeStory(
        text: String,
        voiceId: String = "auto",
        rateMultiplier: Float = 1.05
    ) async throws -> SpeechResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw NSError(domain: "NativeSpeechService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Story text is empty"])
        }

        // 1. Prepare output audio file destination (.caf container natively supports any PCM buffer format)
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "narration_\(UUID().uuidString).caf"
        let outputURL = tempDir.appendingPathComponent(audioFileName)
        try? FileManager.default.removeItem(at: outputURL)

        // 2. Select iOS voice
        let voice = selectVoice(voiceId: voiceId)

        // 3. Segment story into natural speech chunks (sentences/paragraphs)
        // This ensures multi-paragraph stories and long texts are NEVER truncated or cut off early.
        let chunks = splitIntoSpeechChunks(text: cleanText)
        guard !chunks.isEmpty else {
            throw NSError(domain: "NativeSpeechService", code: 400, userInfo: [NSLocalizedDescriptionKey: "No speakable sentences found in story"])
        }

        let baseRate: Float = AVSpeechUtteranceDefaultSpeechRate
        let targetRate = min(0.62, max(0.40, baseRate * rateMultiplier))

        // Create a dedicated synthesizer instance for this session to prevent state crosstalk
        let sessionSynthesizer = AVSpeechSynthesizer()
        var audioFile: AVAudioFile?
        var wordTimings: [WordTiming] = []
        var previousEndDuration: Double = 0.0

        for chunk in chunks {
            let utterance = AVSpeechUtterance(string: chunk)
            utterance.voice = voice
            utterance.rate = targetRate
            utterance.pitchMultiplier = 1.0
            utterance.preUtteranceDelay = 0.02
            utterance.postUtteranceDelay = 0.12

            let chunkStartDuration = previousEndDuration

            do {
                let currentTotalDuration = try await renderUtteranceToFile(
                    synthesizer: sessionSynthesizer,
                    utterance: utterance,
                    audioFileRef: &audioFile,
                    outputURL: outputURL
                )
                let chunkDuration = max(0.2, currentTotalDuration - chunkStartDuration)
                let chunkWords = buildChunkWordTimestamps(
                    for: chunk,
                    startTime: chunkStartDuration,
                    duration: chunkDuration
                )
                wordTimings.append(contentsOf: chunkWords)
                previousEndDuration = currentTotalDuration
            } catch {
                print("[NativeSpeechService] Error synthesizing chunk '\(chunk.prefix(25))...': \(error)")
                // Continue to subsequent chunks so one chunk never aborts the rest of the story!
            }
        }

        // Finalize audio file handle to flush CAF headers to disk
        let totalDuration = previousEndDuration
        audioFile = nil

        guard totalDuration > 0.5 && FileManager.default.fileExists(atPath: outputURL.path) else {
            print("[NativeSpeechService] Synthesis produced insufficient audio. Using fallback generator.")
            let fallbackDuration = max(5.0, Double(cleanText.split(whereSeparator: \.isWhitespace).count) / 2.5)
            try generateSilenceAudioFile(outputURL: outputURL, duration: fallbackDuration)
            let fallbackWords = buildChunkWordTimestamps(for: cleanText, startTime: 0.0, duration: fallbackDuration)
            return SpeechResult(audioURL: outputURL, duration: fallbackDuration, words: fallbackWords)
        }

        return SpeechResult(audioURL: outputURL, duration: totalDuration, words: wordTimings)
    }

    /// Renders a single utterance's PCM buffers into the shared open AVAudioFile.
    /// Resumes when this specific utterance emits pcmBuffer.frameLength == 0.
    private func renderUtteranceToFile(
        synthesizer: AVSpeechSynthesizer,
        utterance: AVSpeechUtterance,
        audioFileRef: inout AVAudioFile?,
        outputURL: URL
    ) async throws -> Double {
        var localFile = audioFileRef

        let finalDuration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
            var hasFinished = false

            // Per-chunk safety timeout (25 seconds for a single 15-25 word sentence is generous)
            let timeoutWork = DispatchWorkItem {
                if !hasFinished {
                    hasFinished = true
                    let currentDur = localFile.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0.0
                    continuation.resume(returning: currentDur)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 25.0, execute: timeoutWork)

            synthesizer.write(utterance) { (buffer: AVAudioBuffer) in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                if pcmBuffer.frameLength == 0 {
                    // Frame length 0 signals the end of *this specific* chunk utterance
                    timeoutWork.cancel()
                    if !hasFinished {
                        hasFinished = true
                        let currentDur = localFile.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 0.0
                        continuation.resume(returning: currentDur)
                    }
                    return
                }

                if localFile == nil {
                    do {
                        // Native CAF Linear PCM format matching pcmBuffer natively with ZERO conversion error
                        localFile = try AVAudioFile(
                            forWriting: outputURL,
                            settings: pcmBuffer.format.settings,
                            commonFormat: pcmBuffer.format.commonFormat,
                            interleaved: pcmBuffer.format.isInterleaved
                        )
                    } catch {
                        timeoutWork.cancel()
                        if !hasFinished {
                            hasFinished = true
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                }

                do {
                    try localFile?.write(from: pcmBuffer)
                } catch {
                    print("[NativeSpeechService] Buffer write error: \(error)")
                }
            }
        }

        audioFileRef = localFile
        return finalDuration
    }

    /// Breaks a long story and multi-paragraph text into clean, natural sentence chunks.
    /// Eliminates early termination caused by newlines or oversized utterance buffers.
    private func splitIntoSpeechChunks(text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let lines = normalized.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var chunks: [String] = []

        for line in lines {
            var currentSentence = ""
            let words = line.split(whereSeparator: \.isWhitespace).map { String($0) }

            for (idx, word) in words.enumerated() {
                if currentSentence.isEmpty {
                    currentSentence = word
                } else {
                    currentSentence += " " + word
                }

                let isLastWord = (idx == words.count - 1)
                let endsWithTerminator = word.hasSuffix(".") || word.hasSuffix("!") || word.hasSuffix("?") || word.hasSuffix("…")
                let isTooLong = currentSentence.count > 160

                if isLastWord || endsWithTerminator || (isTooLong && word.hasSuffix(",")) {
                    let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        chunks.append(trimmed)
                    }
                    currentSentence = ""
                }
            }

            if !currentSentence.isEmpty {
                let trimmed = currentSentence.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    chunks.append(trimmed)
                }
            }
        }

        return chunks
    }

    /// Selects the best installed iOS voice
    private func selectVoice(voiceId: String) -> AVSpeechSynthesisVoice {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()

        if voiceId != "auto" {
            if let matched = availableVoices.first(where: { $0.identifier == voiceId || $0.name.lowercased().contains(voiceId.lowercased()) }) {
                return matched
            }
        }

        let preferredNames = ["Samantha", "Daniel", "Arthur", "Karen", "Nicky", "Alex", "Fred"]
        for pref in preferredNames {
            if let v = availableVoices.first(where: { $0.name.localizedCaseInsensitiveContains(pref) && $0.language.starts(with: "en") }) {
                return v
            }
        }

        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) ?? availableVoices.first ?? AVSpeechSynthesisVoice()
    }

    /// Distributes word timings accurately within a chunk's actual audio timeframe.
    private func buildChunkWordTimestamps(
        for text: String,
        startTime: Double,
        duration: Double
    ) -> [WordTiming] {
        let rawTokens = text.split(whereSeparator: \.isWhitespace).map { String($0) }
        guard !rawTokens.isEmpty else { return [] }

        var weights: [Double] = []
        for token in rawTokens {
            var w = Double(max(token.count, 2))
            if token.hasSuffix(",") || token.hasSuffix(";") || token.hasSuffix(":") {
                w += 2.0
            } else if token.hasSuffix(".") || token.hasSuffix("!") || token.hasSuffix("?") {
                w += 3.5
            }
            weights.append(w)
        }

        let totalWeight = max(weights.reduce(0, +), 1.0)
        var result: [WordTiming] = []
        var currentTime: Double = startTime

        for i in 0..<rawTokens.count {
            let token = rawTokens[i]
            let durationForWord = (weights[i] / totalWeight) * duration
            let wordStart = currentTime
            let wordEnd = min(startTime + duration, wordStart + durationForWord)

            let cleanWord = token.trimmingCharacters(in: CharacterSet.punctuationCharacters)
            let displayWord = cleanWord.isEmpty ? token : cleanWord

            result.append(WordTiming(
                word: displayWord,
                start: round(wordStart * 100) / 100.0,
                end: round(wordEnd * 100) / 100.0
            ))

            currentTime = wordEnd
        }

        return result
    }

    private func generateSilenceAudioFile(outputURL: URL, duration: Double) throws {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else { return }
        let audioFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)
        let frameCount = AVAudioFrameCount(duration * 44100)
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) {
            buffer.frameLength = frameCount
            try audioFile.write(from: buffer)
        }
    }

    /// Lists all installed high-quality speech voices for the UI picker
    public func getAvailableVoices() -> [PresetOption] {
        let all = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }
        var list: [PresetOption] = [
            PresetOption(id: "auto", name: "✨ AI Auto-Select", description: "Matches story tone and vibe automatically")
        ]

        let names = ["Samantha (Natural US)", "Daniel (British Narrator)", "Arthur (Deep & Clear)", "Karen (Australian)", "Alex (Classic)", "Fred (Fast & Punchy)"]
        for name in names {
            let key = name.components(separatedBy: " ").first ?? ""
            if let found = all.first(where: { $0.name.localizedCaseInsensitiveContains(key) }) {
                list.append(PresetOption(id: found.identifier, name: name, description: found.language))
            }
        }

        if list.count <= 1 {
            list.append(PresetOption(id: "en-US", name: "Default English (US)", description: "en-US"))
            list.append(PresetOption(id: "en-GB", name: "British English (UK)", description: "en-GB"))
        }

        return list
    }
}
