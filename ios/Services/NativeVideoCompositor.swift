import Foundation
import AVFoundation
import CoreGraphics
import QuartzCore
import UIKit
import Photos
import CoreText

public class NativeVideoCompositor {
    public static let shared = NativeVideoCompositor()

    private init() {}

    public struct CompositionOptions {
        public var title: String
        public var backgroundVideoURL: URL
        public var narrationAudioURL: URL
        public var audioDuration: Double
        public var wordTimestamps: [WordTiming]
        public var subtitleStyle: String // "karaoke", "single", "auto"
        public var highlightColorHex: String // e.g. "&H00FFFF&" or "#FFEE00"
        public var progressCallback: ((Double, String) -> Void)?
    }

    /// Composes a 1080x1920 9:16 TikTok video on-device with synced karaoke captions.
    public func composeVideo(options: CompositionOptions) async throws -> URL {
        options.progressCallback?(0.05, "Preparing media composition...")

        let targetSize = CGSize(width: 1080, height: 1920)
        let totalDuration = CMTime(seconds: options.audioDuration, preferredTimescale: 600)

        // 0. Safety Checks on Input Files
        guard FileManager.default.fileExists(atPath: options.backgroundVideoURL.path) else {
            throw NSError(domain: "NativeVideoCompositor", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Background video file not found on disk (\(options.backgroundVideoURL.lastPathComponent))"
            ])
        }
        let bgFileSize = (try? FileManager.default.attributesOfItem(atPath: options.backgroundVideoURL.path)[.size] as? Int64) ?? 0
        guard bgFileSize > 10_000 else {
            throw NSError(domain: "NativeVideoCompositor", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "Background video file is corrupt or empty (\(bgFileSize) bytes)"
            ])
        }

        let bgAsset = AVURLAsset(url: options.backgroundVideoURL)
        let audioAsset = AVURLAsset(url: options.narrationAudioURL)

        let bgVideoTrack: AVAssetTrack
        do {
            guard let track = try await bgAsset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "NativeVideoCompositor", code: 404, userInfo: [
                    NSLocalizedDescriptionKey: "Background video has no video track (\(options.backgroundVideoURL.lastPathComponent))"
                ])
            }
            bgVideoTrack = track
        } catch {
            throw NSError(domain: "NativeVideoCompositor", code: 500, userInfo: [
                NSLocalizedDescriptionKey: "Cannot open background video track: \(error.localizedDescription)"
            ])
        }

        // 1. Create Mutable Composition
        let composition = AVMutableComposition()

        guard let compVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "NativeVideoCompositor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create video composition track"])
        }

        // 2. Insert narration audio first to obtain exact uncompressed timeline duration
        var effectiveDuration = totalDuration
        if let narrationTrack = try? await audioAsset.loadTracks(withMediaType: .audio).first {
            let rawAudioDuration = (try? await audioAsset.load(.duration)) ?? CMTime.zero
            if rawAudioDuration.isNumeric && rawAudioDuration.seconds > 0.1 {
                if let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    try? compAudioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: rawAudioDuration), of: narrationTrack, at: .zero)
                    effectiveDuration = max(totalDuration, rawAudioDuration)
                }
            }
        }

        // 3. Insert and loop background video across the full effective audio duration
        let rawBgDuration = (try? await bgAsset.load(.duration)) ?? CMTime(seconds: 10, preferredTimescale: 600)
        let bgDuration = (rawBgDuration.isNumeric && rawBgDuration.seconds > 0.5) ? rawBgDuration : CMTime(seconds: 10, preferredTimescale: 600)

        var currentTime = CMTime.zero
        while currentTime < effectiveDuration {
            let remaining = effectiveDuration - currentTime
            let slice = (remaining < bgDuration) ? remaining : bgDuration
            if slice.seconds <= 0.01 { break }
            try compVideoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: slice), of: bgVideoTrack, at: currentTime)
            currentTime = currentTime + slice
        }

        options.progressCallback?(0.20, "Scaling B-roll to 9:16 vertical 1080p...")

        guard effectiveDuration.isNumeric && effectiveDuration.seconds > 0.5 else {
            throw NSError(domain: "NativeVideoCompositor", code: 400, userInfo: [NSLocalizedDescriptionKey: "Composition timeline is empty or duration is invalid"])
        }

        // 4. Video Composition & Layer Instructions (Center-crop & Scale to 1080x1920)
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = targetSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: effectiveDuration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideoTrack)

        // Asynchronously load naturalSize and preferredTransform
        let naturalSize = (try? await bgVideoTrack.load(.naturalSize)) ?? CGSize(width: 720, height: 1280)
        let preferredTransform = (try? await bgVideoTrack.load(.preferredTransform)) ?? .identity
        let transformedSize = naturalSize.applying(preferredTransform)
        let srcWidth = max(abs(transformedSize.width), 10.0)
        let srcHeight = max(abs(transformedSize.height), 10.0)

        let scale = max(targetSize.width / srcWidth, targetSize.height / srcHeight)
        let scaledW = srcWidth * scale
        let scaledH = srcHeight * scale
        let tx = (targetSize.width - scaledW) / 2.0
        let ty = (targetSize.height - scaledH) / 2.0

        var finalTransform = preferredTransform
        finalTransform = finalTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        finalTransform = finalTransform.concatenating(CGAffineTransform(translationX: tx, y: ty))
        layerInstruction.setTransform(finalTransform, at: .zero)

        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        options.progressCallback?(0.35, "Generating dynamic viral karaoke subtitles...")

        // 5. Build Subtitle Overlay Layers
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: targetSize)
        parentLayer.isGeometryFlipped = true

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: targetSize)
        parentLayer.addSublayer(videoLayer)

        let subtitleOverlayLayer = CALayer()
        subtitleOverlayLayer.frame = CGRect(origin: .zero, size: targetSize)
        parentLayer.addSublayer(subtitleOverlayLayer)

        // Build caption chunks (3-4 words per phrase or single bouncy words)
        buildKaraokeCaptionLayers(
            into: subtitleOverlayLayer,
            words: options.wordTimestamps,
            style: options.subtitleStyle,
            highlightHex: options.highlightColorHex,
            canvasSize: targetSize
        )

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        options.progressCallback?(0.50, "Rendering with Apple VideoToolbox hardware encoder...")

        // 6. Export Session (Use AVAssetExportPresetHighestQuality for portrait 9:16 compatibility)
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputFileName = "StoryTeller_\(UUID().uuidString).mp4"
        let outputURL = docsDir.appendingPathComponent(outputFileName)
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "NativeVideoCompositor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.timeRange = CMTimeRange(start: .zero, duration: effectiveDuration)
        exportSession.shouldOptimizeForNetworkUse = true

        // Progress polling task
        let progressTask = Task {
            while exportSession.status == .exporting || exportSession.status == .waiting {
                let p = Double(exportSession.progress)
                let pct = 0.50 + (p * 0.45)
                options.progressCallback?(pct, "Encoding 1080x1920 video: \(Int(p * 100))%...")
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        await exportSession.export()
        progressTask.cancel()

        // If primary export with animationTool failed, try fallback clean composition
        if exportSession.status != .completed {
            let primaryError = exportSession.error
            print("[NativeVideoCompositor] Primary export with animationTool failed: \(String(describing: primaryError)). Attempting fallback composition...")

            let cleanVideoComp = AVMutableVideoComposition()
            cleanVideoComp.renderSize = targetSize
            cleanVideoComp.frameDuration = CMTime(value: 1, timescale: 30)
            cleanVideoComp.instructions = [instruction]

            try? FileManager.default.removeItem(at: outputURL)
            if let fallbackSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) {
                fallbackSession.outputURL = outputURL
                fallbackSession.outputFileType = .mp4
                fallbackSession.videoComposition = cleanVideoComp
                fallbackSession.timeRange = CMTimeRange(start: .zero, duration: effectiveDuration)
                fallbackSession.shouldOptimizeForNetworkUse = true
                await fallbackSession.export()

                if fallbackSession.status == .completed && FileManager.default.fileExists(atPath: outputURL.path) {
                    print("[NativeVideoCompositor] Fallback video composition successfully exported!")
                    options.progressCallback?(0.96, "Saving directly to iPhone Camera Roll...")
                    await saveToPhotoLibrary(fileURL: outputURL)
                    options.progressCallback?(1.0, "Complete!")
                    return outputURL
                }
            }

            if let error = primaryError {
                let nsError = error as NSError
                var details = error.localizedDescription
                if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                    details += " (\(underlying.domain) \(underlying.code): \(underlying.localizedDescription))"
                }
                throw NSError(domain: "NativeVideoCompositor", code: nsError.code, userInfo: [
                    NSLocalizedDescriptionKey: details
                ])
            }
        }

        guard exportSession.status == .completed, FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "NativeVideoCompositor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Export incomplete or output missing"])
        }

        options.progressCallback?(0.96, "Saving directly to iPhone Camera Roll...")

        // 7. Auto-save to Camera Roll
        await saveToPhotoLibrary(fileURL: outputURL)

        options.progressCallback?(1.0, "Complete!")
        return outputURL
    }

    // MARK: - Subtitle Overlay Generation
    private func buildKaraokeCaptionLayers(
        into container: CALayer,
        words: [WordTiming],
        style: String,
        highlightHex: String,
        canvasSize: CGSize
    ) {
        guard !words.isEmpty else { return }

        let highlightColor = parseColor(hex: highlightHex)
        let isSingleWord = (style == "single")

        if isSingleWord {
            // High-velocity MrBeast style: 1-2 words per flash with punchy bounce
            for w in words {
                let textLayer = createSingleCaptionLayer(
                    text: w.word.uppercased(),
                    startTime: w.start,
                    endTime: w.end,
                    textColor: highlightColor,
                    canvasSize: canvasSize
                )
                container.addSublayer(textLayer)
            }
        } else {
            // CapCut Viral Karaoke: Group into 3-word chunks
            var chunks: [[WordTiming]] = []
            var currentChunk: [WordTiming] = []

            for w in words {
                currentChunk.append(w)
                if currentChunk.count >= 3 || w.word.hasSuffix(".") || w.word.hasSuffix("!") || w.word.hasSuffix("?") {
                    chunks.append(currentChunk)
                    currentChunk = []
                }
            }
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
            }

            for (idx, chunk) in chunks.enumerated() {
                guard let first = chunk.first, let last = chunk.last else { continue }
                let phrase = chunk.map { $0.word }.joined(separator: " ")
                let chunkStart = first.start
                let nextStart = (idx + 1 < chunks.count) ? (chunks[idx + 1].first?.start ?? last.end) : last.end
                let chunkEnd = min(max(last.end, chunkStart + 0.3), nextStart)

                let textLayer = createChunkCaptionLayer(
                    text: phrase.uppercased(),
                    startTime: chunkStart,
                    endTime: chunkEnd,
                    highlightColor: highlightColor,
                    canvasSize: canvasSize
                )
                container.addSublayer(textLayer)
            }
        }
    }

    private func createChunkCaptionLayer(
        text: String,
        startTime: Double,
        endTime: Double,
        highlightColor: UIColor,
        canvasSize: CGSize
    ) -> CALayer {
        let container = CALayer()
        let width: CGFloat = canvasSize.width - 120
        let height: CGFloat = 160
        // Centered vertically in the lower half (TikTok sweet spot)
        let x: CGFloat = 60
        let y: CGFloat = (canvasSize.height / 2.0) - 80

        container.frame = CGRect(x: x, y: y, width: width, height: height)
        container.opacity = 0.0

        // Background pill badge for ultra-readability
        let bgPill = CALayer()
        bgPill.frame = CGRect(x: 0, y: 15, width: width, height: height - 30)
        bgPill.backgroundColor = UIColor.black.withAlphaComponent(0.48).cgColor
        bgPill.cornerRadius = 24
        container.addSublayer(bgPill)

        let textLayer = CATextLayer()
        textLayer.frame = CGRect(x: 10, y: 32, width: width - 20, height: height - 50)
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("AvenirNext-Heavy" as CFString, 52, nil)
        textLayer.fontSize = 52
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = highlightColor.cgColor
        textLayer.isWrapped = true
        textLayer.contentsScale = 2.0
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 0.95
        textLayer.shadowRadius = 8
        textLayer.shadowOffset = CGSize(width: 0, height: 4)

        container.addSublayer(textLayer)

        let duration = max(endTime - startTime, 0.4)

        // Opacity keyframes
        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [0.0, 1.0, 1.0, 0.0]
        opacityAnim.keyTimes = [0.0, 0.03, 0.97, 1.0]
        opacityAnim.duration = duration
        opacityAnim.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        opacityAnim.fillMode = .both
        opacityAnim.isRemovedOnCompletion = false

        // Bouncy scale keyframes (viral CapCut pop)
        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnim.values = [0.88, 1.12, 1.0]
        scaleAnim.keyTimes = [0.0, 0.35, 1.0]
        scaleAnim.duration = min(duration, 0.3)
        scaleAnim.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        scaleAnim.fillMode = .both
        scaleAnim.isRemovedOnCompletion = false

        container.add(opacityAnim, forKey: "opacity")
        container.add(scaleAnim, forKey: "scale")

        return container
    }

    private func createSingleCaptionLayer(
        text: String,
        startTime: Double,
        endTime: Double,
        textColor: UIColor,
        canvasSize: CGSize
    ) -> CALayer {
        let container = CALayer()
        let width: CGFloat = canvasSize.width - 160
        let height: CGFloat = 140
        let x: CGFloat = 80
        let y: CGFloat = (canvasSize.height / 2.0) - 70

        container.frame = CGRect(x: x, y: y, width: width, height: height)
        container.opacity = 0.0

        let textLayer = CATextLayer()
        textLayer.frame = CGRect(x: 0, y: 15, width: width, height: height)
        textLayer.string = text
        textLayer.font = CTFontCreateWithName("AvenirNext-Heavy" as CFString, 74, nil)
        textLayer.fontSize = 74
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = textColor.cgColor
        textLayer.contentsScale = 2.0
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 1.0
        textLayer.shadowRadius = 10
        textLayer.shadowOffset = CGSize(width: 0, height: 4)

        container.addSublayer(textLayer)

        let duration = max(endTime - startTime, 0.25)

        let opacityAnim = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnim.values = [0.0, 1.0, 1.0, 0.0]
        opacityAnim.keyTimes = [0.0, 0.02, 0.98, 1.0]
        opacityAnim.duration = duration
        opacityAnim.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        opacityAnim.fillMode = .both
        opacityAnim.isRemovedOnCompletion = false

        let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
        scaleAnim.values = [0.75, 1.22, 1.0]
        scaleAnim.keyTimes = [0.0, 0.35, 1.0]
        scaleAnim.duration = min(duration, 0.22)
        scaleAnim.beginTime = AVCoreAnimationBeginTimeAtZero + startTime
        scaleAnim.fillMode = .both
        scaleAnim.isRemovedOnCompletion = false

        container.add(opacityAnim, forKey: "opacity")
        container.add(scaleAnim, forKey: "scale")

        return container
    }

    private func parseColor(hex: String) -> UIColor {
        if hex.contains("&H00FFFF&") || hex.lowercased().contains("yellow") {
            return UIColor(red: 1.0, green: 0.92, blue: 0.0, alpha: 1.0) // TikTok Yellow
        } else if hex.contains("&H00FF00&") || hex.lowercased().contains("green") {
            return UIColor(red: 0.0, green: 1.0, blue: 0.35, alpha: 1.0) // Neon Lime
        } else if hex.contains("&HFFFF00&") || hex.lowercased().contains("cyan") {
            return UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0) // Electric Cyan
        } else if hex.contains("&H0000FF&") || hex.lowercased().contains("red") {
            return UIColor(red: 1.0, green: 0.22, blue: 0.35, alpha: 1.0) // Hot Coral Red
        }
        return UIColor.white
    }

    private func saveToPhotoLibrary(fileURL: URL) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            print("[NativeVideoCompositor] Photo library authorization denied")
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            }
            print("[NativeVideoCompositor] Successfully saved to Camera Roll!")
        } catch {
            print("[NativeVideoCompositor] Error saving to Camera Roll: \(error)")
        }
    }
}
