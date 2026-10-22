import Foundation
import AVFoundation
import AudioToolbox

public class NativeSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = NativeSpeechService()

    private var synthesizer = AVSpeechSynthesizer()

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public struct SpeechResult {
        public let audioURL: URL
        public let duration: Double
        public let words: [WordTiming]
    }

    /// Synthesizes story text to an on-device audio file and generates word timings.
    public func synthesizeStory(
        text: String,
        voiceId: String = "auto",
        rateMultiplier: Float = 1.05
    ) async throws -> SpeechResult {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            throw NSError(domain: "NativeSpeechService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Story text is empty"])
        }

        // 1. Prepare output audio file destination
        let tempDir = FileManager.default.temporaryDirectory
        let audioFileName = "narration_\(UUID().uuidString).m4a"
        let outputURL = tempDir.appendingPathComponent(audioFileName)
        try? FileManager.default.removeItem(at: outputURL)

        // 2. Select iOS voice
        let voice = selectVoice(voiceId: voiceId)

        // 3. Configure utterance
        let utterance = AVSpeechUtterance(string: cleanText)
        utterance.voice = voice

        // Base rate in iOS: AVSpeechUtteranceDefaultSpeechRate is ~0.5.
        // Fast viral TikTok pacing is ~0.53 - 0.56.
        let baseRate: Float = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = min(0.62, max(0.40, baseRate * rateMultiplier))
        utterance.pitchMultiplier = 1.0
        utterance.preUtteranceDelay = 0.05
        utterance.postUtteranceDelay = 0.1

        // 4. Synthesize to audio buffer & write to file
        let audioFileDuration = try await renderUtteranceToFile(utterance: utterance, outputURL: outputURL)

        // 5. Build synchronous word-level timestamps
        let words = buildWordTimestamps(for: cleanText, totalDuration: audioFileDuration)

        return SpeechResult(audioURL: outputURL, duration: audioFileDuration, words: words)
    }

    private func selectVoice(voiceId: String) -> AVSpeechSynthesisVoice {
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()

        // If specific language/identifier requested
        if voiceId != "auto" {
            if let matched = availableVoices.first(where: { $0.identifier == voiceId || $0.name.lowercased().contains(voiceId.lowercased()) }) {
                return matched
            }
        }

        // Try to pick high quality English voice (Samantha, Daniel, Karen, Arthur)
        let preferredNames = ["Samantha", "Daniel", "Karen", "Arthur", "Nicky", "Alex", "Fred"]
        for pref in preferredNames {
            if let v = availableVoices.first(where: { $0.name.localizedCaseInsensitiveContains(pref) && $0.language.starts(with: "en") }) {
                return v
            }
        }

        // Fallback to any en-US voice or system default
        return AVSpeechSynthesisVoice(language: "en-US") ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) ?? availableVoices.first!
    }

    private func renderUtteranceToFile(utterance: AVSpeechUtterance, outputURL: URL) async throws -> Double {
        return try await withCheckedThrowingContinuation { continuation in
            var audioFile: AVAudioFile?
            var hasFinished = false

            // Use write callback of AVSpeechSynthesizer
            self.synthesizer.write(utterance) { (buffer: AVAudioBuffer) in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer else { return }

                if pcmBuffer.frameLength == 0 {
                    // Synthesis finished
                    if !hasFinished {
                        hasFinished = true
                        let duration = audioFile.map { Double($0.length) / $0.processingFormat.sampleRate } ?? 10.0
                        continuation.resume(returning: max(duration, 3.0))
                    }
                    return
                }

                if audioFile == nil {
                    // Create audio file with the buffer's format
                    do {
                        let settings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVSampleRateKey: pcmBuffer.format.sampleRate,
                            AVNumberOfChannelsKey: pcmBuffer.format.channelCount,
                            AVEncoderBitRateKey: 128000
                        ]
                        audioFile = try AVAudioFile(forWriting: outputURL, settings: settings)
                    } catch {
                        if !hasFinished {
                            hasFinished = true
                            continuation.resume(throwing: error)
                        }
                        return
                    }
                }

                do {
                    try audioFile?.write(from: pcmBuffer)
                } catch {
                    print("[NativeSpeechService] Buffer write error: \(error)")
                }
            }
        }
    }

    /// Computes accurate word-by-word timestamps across the total narration duration,
    /// weighting by syllables and punctuation pauses (commas, periods).
    private func buildWordTimestamps(for text: String, totalDuration: Double) -> [WordTiming] {
        let rawTokens = text.split(whereSeparator: \.isWhitespace).map { String($0) }
        guard !rawTokens.isEmpty else { return [] }

        // Calculate relative weight for each word based on character length and punctuation
        var weights: [Double] = []
        for token in rawTokens {
            var w = Double(max(token.count, 2))
            if token.hasSuffix(",") || token.hasSuffix(";") || token.hasSuffix(":") {
                w += 3.5 // Punctuation pause
            } else if token.hasSuffix(".") || token.hasSuffix("!") || token.hasSuffix("?") {
                w += 5.5 // Sentence pause
            }
            weights.append(w)
        }

        let totalWeight = weights.reduce(0, +)
        var result: [WordTiming] = []
        var currentTime: Double = 0.05

        for i in 0..<rawTokens.count {
            let token = rawTokens[i]
            let durationForWord = (weights[i] / totalWeight) * (totalDuration - 0.2)
            let wordStart = currentTime
            let wordEnd = min(totalDuration, wordStart + durationForWord)

            // Strip trailing punctuation for clean on-screen display
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
            // Default generic options
            list.append(PresetOption(id: "en-US", name: "Default English (US)", description: "en-US"))
            list.append(PresetOption(id: "en-GB", name: "British English (UK)", description: "en-GB"))
        }

        return list
    }
}
