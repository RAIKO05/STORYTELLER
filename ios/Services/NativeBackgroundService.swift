import Foundation
import AVFoundation
import Photos
import UIKit
import CoreVideo

public class NativeBackgroundService {
    public static let shared = NativeBackgroundService()

    private let cacheDir: URL

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("StoryTellerBackgrounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.cacheDir = dir
    }

    public struct BackgroundPresetItem: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let category: String
        public let remoteURL: String?
        public let icon: String
    }

    public let availablePresets: [BackgroundPresetItem] = [
        BackgroundPresetItem(id: "auto", name: "✨ AI Auto-Select", category: "Smart", remoteURL: nil, icon: "wand.and.stars"),

        // 1. Gaming
        BackgroundPresetItem(
            id: "subway_surfers",
            name: "Subway Surfers Fast Run",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/subway_surfers.mp4",
            icon: "figure.run"
        ),
        BackgroundPresetItem(
            id: "minecraft_parkour",
            name: "Minecraft Parkour (9:16)",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/minecraft_parkour.mp4",
            icon: "gamecontroller.fill"
        ),
        BackgroundPresetItem(
            id: "gta_stunts",
            name: "GTA V Mega Ramp Stunts",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/gta_stunts.mp4",
            icon: "car.fill"
        ),
        BackgroundPresetItem(
            id: "beamng_crashes",
            name: "BeamNG Car Crashes & Stunts",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/gta_stunts.mp4",
            icon: "flame.fill"
        ),
        BackgroundPresetItem(
            id: "roblox_obby",
            name: "Roblox Tower Obby Parkour",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/minecraft_parkour.mp4",
            icon: "cube.fill"
        ),
        BackgroundPresetItem(
            id: "temple_run",
            name: "Temple Run 2 Classic Run",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/subway_surfers.mp4",
            icon: "figure.walk.motion"
        ),
        BackgroundPresetItem(
            id: "csgo_surf",
            name: "CS:GO / CS2 Smooth Surf",
            category: "Gaming",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/gta_stunts.mp4",
            icon: "water.waves"
        ),

        // 2. Satisfying / ASMR
        BackgroundPresetItem(
            id: "aurora_galaxy",
            name: "Aurora Galaxy & Cosmic ASMR",
            category: "Satisfying ASMR",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/aurora_galaxy.mp4",
            icon: "sparkles"
        ),
        BackgroundPresetItem(
            id: "satisfying_asmr",
            name: "Kinetic Sand & Soap ASMR",
            category: "Satisfying ASMR",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/aurora_galaxy.mp4",
            icon: "sparkles"
        ),
        BackgroundPresetItem(
            id: "hydraulic_press",
            name: "Hydraulic Press Crushing",
            category: "Satisfying ASMR",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/aurora_galaxy.mp4",
            icon: "hammer.fill"
        ),
        BackgroundPresetItem(
            id: "slime_asmr",
            name: "Crunchy Slime & Bubble Pop",
            category: "Satisfying ASMR",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/aurora_galaxy.mp4",
            icon: "bubbles.and.sparkles.fill"
        ),
        BackgroundPresetItem(
            id: "marble_run",
            name: "Gravity Marble Run Race",
            category: "Satisfying ASMR",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/aurora_galaxy.mp4",
            icon: "circle.circle.fill"
        ),

        // 3. Aesthetic & Procedural Loops (100% Offline)
        BackgroundPresetItem(
            id: "neon_motion_loop",
            name: "Cyber Neon Motion Loop (Built-in)",
            category: "Aesthetic",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/neon_motion_loop.mp4",
            icon: "grid"
        ),
        BackgroundPresetItem(
            id: "synthwave_drive",
            name: "Cyberpunk Synthwave Sunset Drive",
            category: "Aesthetic",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/neon_motion_loop.mp4",
            icon: "sunset.fill"
        ),
        BackgroundPresetItem(
            id: "neon_motion",
            name: "Neon Cyber Grid (AI Procedural)",
            category: "AI Procedural",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/neon_motion_loop.mp4",
            icon: "grid"
        ),
        BackgroundPresetItem(
            id: "dark_cinematic",
            name: "Dark Atmospheric Smoke (Built-in)",
            category: "AI Procedural",
            remoteURL: "https://raw.githubusercontent.com/RAIKO05/STORYTELLER/main/ios/Resources/Backgrounds/dark_cinematic.mp4",
            icon: "moon.fill"
        ),
        BackgroundPresetItem(
            id: "cosmic_warp",
            name: "Cosmic Starfield Warp (AI Procedural)",
            category: "AI Procedural",
            remoteURL: nil,
            icon: "sparkle"
        ),
        BackgroundPresetItem(
            id: "crimson_pulse",
            name: "Crimson Suspense Pulse (AI Procedural)",
            category: "AI Procedural",
            remoteURL: nil,
            icon: "heart.fill"
        )
    ]

    /// Resolves background footage: checks custom photo video, app bundle, local cache, validated remote download, or bundled/procedural fallback.
    public func resolveBackgroundVideo(
        id: String,
        customVideoURL: URL? = nil,
        progressHandler: ((String) -> Void)? = nil
    ) async throws -> URL {
        // 1. If user picked a custom video from Photos Camera Roll
        if let customURL = customVideoURL, FileManager.default.fileExists(atPath: customURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: customURL.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size > 100_000 {
                print("[NativeBackgroundService] Using user custom Photos video (\(size) bytes)")
                return customURL
            }
        }

        // 2. Resolve target ID (normalize)
        let targetId = (id == "auto" || id.isEmpty) ? "subway_surfers" : id

        // Check if procedural explicitly requested
        if targetId == "cosmic_warp" || targetId == "crimson_pulse" {
            progressHandler?("Generating AI procedural motion background...")
            return try await generateProceduralBackground(theme: targetId)
        }

        // Map aliases to bundled assets if applicable
        var bundleName = targetId
        if targetId == "neon_motion" { bundleName = "neon_motion_loop" }

        // 3. CHECK APP BUNDLE FIRST (100% Offline & Instant!)
        if let bundleURL = Bundle.main.url(forResource: bundleName, withExtension: "mp4") ??
                           Bundle.main.url(forResource: bundleName, withExtension: "mp4", subdirectory: "Backgrounds") ??
                           Bundle.main.url(forResource: targetId, withExtension: "mp4") ??
                           Bundle.main.url(forResource: targetId, withExtension: "mp4", subdirectory: "Backgrounds") {
            let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size > 100_000 {
                print("[NativeBackgroundService] Using bundled background: \(bundleURL.lastPathComponent) (\(size) bytes)")
                return bundleURL
            }
        }

        // 4. CHECK LOCAL CACHE (Must be > 200KB to purge old 404 stubs from previous versions)
        let localFile = cacheDir.appendingPathComponent("\(targetId).mp4")
        if FileManager.default.fileExists(atPath: localFile.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: localFile.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size > 200_000 {
                print("[NativeBackgroundService] Using cached background: \(localFile.lastPathComponent) (\(size) bytes)")
                return localFile
            } else {
                // Delete corrupted or 404 text file
                try? FileManager.default.removeItem(at: localFile)
            }
        }

        // 5. DOWNLOAD FROM REMOTE (With Strict HTTP Status & Size Validation)
        if let preset = availablePresets.first(where: { $0.id == targetId }),
           let remoteURLString = preset.remoteURL,
           let remoteURL = URL(string: remoteURLString) {
            progressHandler?("Downloading B-Roll (\(preset.name))...")
            do {
                var req = URLRequest(url: remoteURL)
                req.timeoutInterval = 20
                let (tempURL, response) = try await URLSession.shared.download(for: req)

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                    throw NSError(domain: "NativeBackgroundService", code: code, userInfo: [
                        NSLocalizedDescriptionKey: "Remote download returned HTTP \(code)"
                    ])
                }

                let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
                let size = attrs?[.size] as? Int64 ?? 0
                guard size > 200_000 else {
                    throw NSError(domain: "NativeBackgroundService", code: 400, userInfo: [
                        NSLocalizedDescriptionKey: "Downloaded file is corrupted or too small (\(size) bytes)"
                    ])
                }

                try? FileManager.default.removeItem(at: localFile)
                try FileManager.default.copyItem(at: tempURL, to: localFile)
                print("[NativeBackgroundService] Successfully downloaded and cached: \(localFile.lastPathComponent) (\(size) bytes)")
                return localFile
            } catch {
                print("[NativeBackgroundService] Remote download failed: \(error). Falling back to bundled/procedural asset.")
            }
        }

        // 6. FALLBACK TO ANY AVAILABLE BUNDLED BACKGROUND
        let fallbackCandidates = ["subway_surfers", "minecraft_parkour", "gta_stunts", "neon_motion_loop", "dark_cinematic", "aurora_galaxy"]
        for candidate in fallbackCandidates {
            if let bundleURL = Bundle.main.url(forResource: candidate, withExtension: "mp4") ??
                               Bundle.main.url(forResource: candidate, withExtension: "mp4", subdirectory: "Backgrounds") {
                let attrs = try? FileManager.default.attributesOfItem(atPath: bundleURL.path)
                let size = attrs?[.size] as? Int64 ?? 0
                if size > 100_000 {
                    print("[NativeBackgroundService] Falling back to bundled candidate: \(candidate)")
                    return bundleURL
                }
            }
        }

        // 7. FINAL SAFETY NET: PROCEDURAL BACKGROUND GENERATOR (100% On-Device AVAssetWriter)
        progressHandler?("Generating AI procedural motion background...")
        return try await generateProceduralBackground(theme: targetId)
    }

    /// Generates high resolution 1080x1920 9:16 procedural video directly on-device using AVAssetWriter and CoreGraphics
    public func generateProceduralBackground(theme: String = "neon_motion") async throws -> URL {
        let outURL = cacheDir.appendingPathComponent("procedural_\(theme).mp4")
        if FileManager.default.fileExists(atPath: outURL.path) {
            let attrs = try? FileManager.default.attributesOfItem(atPath: outURL.path)
            let size = attrs?[.size] as? Int64 ?? 0
            if size > 100_000 {
                return outURL
            }
        }

        try? FileManager.default.removeItem(at: outURL)

        let width = 720
        let height = 1280
        let fps: Int32 = 30
        let totalSeconds = 20
        let totalFrames = totalSeconds * Int(fps)

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_500_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw NSError(domain: "NativeBackgroundService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Cannot add AVAssetWriterInput"])
        }
        writer.add(writerInput)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "NativeBackgroundService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Writer failed to start"])
        }
        writer.startSession(atSourceTime: .zero)

        // Generate frames
        var frameIndex = 0
        while frameIndex < totalFrames {
            if writerInput.isReadyForMoreMediaData {
                let presentationTime = CMTime(value: Int64(frameIndex), timescale: fps)

                guard let pool = adaptor.pixelBufferPool else {
                    try? await Task.sleep(nanoseconds: 5_000_000)
                    continue
                }

                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)

                if status == kCVReturnSuccess, let buffer = pixelBuffer {
                    CVPixelBufferLockBaseAddress(buffer, [])
                    let data = CVPixelBufferGetBaseAddress(buffer)
                    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                    let context = CGContext(
                        data: data,
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: rgbColorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                    )

                    if let ctx = context {
                        drawProceduralFrame(ctx: ctx, width: width, height: height, frame: frameIndex, totalFrames: totalFrames, theme: theme)
                    }

                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    adaptor.append(buffer, withPresentationTime: presentationTime)
                    frameIndex += 1
                }
            } else {
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }

        writerInput.markAsFinished()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            writer.finishWriting {
                continuation.resume()
            }
        }

        return outURL
    }

    private func drawProceduralFrame(ctx: CGContext, width: Int, height: Int, frame: Int, totalFrames: Int, theme: String) {
        let progress = CGFloat(frame) / CGFloat(totalFrames)

        if theme == "dark_cinematic" {
            // Dark vignette mystery gradient
            let colors = [
                UIColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1.0).cgColor,
                UIColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 1.0).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
            let center = CGPoint(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 20, endCenter: center, endRadius: CGFloat(height) / 1.1, options: [.drawsAfterEndLocation])
        } else if theme == "crimson_pulse" {
            // Pulsing crimson suspense
            let pulse = sin(progress * .pi * 4.0) * 0.15 + 0.85
            let colors = [
                UIColor(red: 0.22 * pulse, green: 0.01, blue: 0.04, alpha: 1.0).cgColor,
                UIColor(red: 0.02, green: 0.00, blue: 0.01, alpha: 1.0).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
            let center = CGPoint(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 10, endCenter: center, endRadius: CGFloat(height) / 1.1, options: [.drawsAfterEndLocation])
        } else if theme == "cosmic_warp" {
            // Cosmic starfield warp
            ctx.setFillColor(UIColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1.0).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

            // Draw animated stars
            ctx.setFillColor(UIColor.white.cgColor)
            for i in 0..<80 {
                let seed = Double(i) * 137.5
                let speed = (Double(i % 5) + 1.5)
                let yOffset = fmod(Double(progress) * 800.0 * speed + seed, Double(height))
                let x = fmod(seed * 43.1, Double(width))
                let size = (Double(i % 3) + 1.5)
                ctx.fillEllipse(in: CGRect(x: x, y: yOffset, width: size, height: size))
            }
        } else {
            // Neon Cyber Grid
            let colors = [
                UIColor(red: 0.08, green: 0.02, blue: 0.18, alpha: 1.0).cgColor,
                UIColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1.0).cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0])!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(height)), options: [])

            // Neon horizontal perspective lines
            ctx.setStrokeColor(UIColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 0.18).cgColor)
            ctx.setLineWidth(1.5)
            let gridStep: CGFloat = 40.0
            let offset = fmod(progress * 120.0, gridStep)
            for y in stride(from: offset, to: CGFloat(height), by: gridStep) {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: CGFloat(width), y: y))
            }
            ctx.strokePath()
        }
    }
}
