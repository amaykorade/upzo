import Foundation
#if canImport(UIKit)
import UIKit
import Vision
#endif

enum MissionVerifiers {
    // MARK: - Text & voice

    static func textMatches(input: String, expectedPhrase: String) -> Bool {
        normalize(input) == normalize(expectedPhrase)
    }

    static func voiceTranscriptMatches(_ transcript: String, expectedPhrase: String) -> Bool {
        normalize(transcript).contains(normalize(expectedPhrase))
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    // MARK: - Math

    struct MathChallenge: Equatable {
        let prompt: String
        let answer: Int
    }

    static func generateMathChallenge(level: MissionVerificationLevel) -> MathChallenge {
        switch level {
        case .normal:
            let a = Int.random(in: 3...18)
            let b = Int.random(in: 3...18)
            return MathChallenge(prompt: "\(a) + \(b) = ?", answer: a + b)
        case .strict:
            let a = Int.random(in: 6...14)
            let b = Int.random(in: 6...14)
            return MathChallenge(prompt: "\(a) × \(b) = ?", answer: a * b)
        }
    }

    static func mathAnswerMatches(input: String, expected: Int) -> Bool {
        guard let value = Int(input.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return value == expected
    }

    // MARK: - Photo

#if canImport(UIKit)
    static func photoPassesSkyCheck(_ image: UIImage, minimumTopBrightness: Int) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = min(cgImage.width, 120)
        let height = min(cgImage.height, 120)
        guard width > 0, height > 0 else { return false }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        let topRowEnd = width * 4
        var brightnessSum = 0
        for i in stride(from: 0, to: topRowEnd, by: 4) {
            let r = Int(pixels[i])
            let g = Int(pixels[i + 1])
            let b = Int(pixels[i + 2])
            brightnessSum += (r + g + b) / 3
        }
        let averageTopBrightness = brightnessSum / width
        return averageTopBrightness > minimumTopBrightness
    }

    // MARK: - Object hunt

    static let objectHuntTopClassificationCount = 40

    static func photoContainsHuntObject(
        _ image: UIImage,
        target: HuntObject,
        minConfidence: Float
    ) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )
        do {
            try handler.perform([request])
            guard let results = request.results else { return false }
            let observations = results
                .prefix(objectHuntTopClassificationCount)
                .map { (identifier: $0.identifier, confidence: $0.confidence) }
            return huntObjectMatches(observations: observations, target: target, minConfidence: minConfidence)
        } catch {
            return false
        }
    }

    static func huntObjectMatches(
        observations: [(identifier: String, confidence: Float)],
        target: HuntObject,
        minConfidence: Float
    ) -> Bool {
        let normalizedLabels = target.visionLabels.map { label in
            (
                identifier: normalizeVisionIdentifier(label.identifier),
                minConfidenceOverride: label.minConfidenceOverride
            )
        }

        for observation in observations {
            let observedID = normalizeVisionIdentifier(observation.identifier)
            for label in normalizedLabels where visionIdentifiersMatch(observedID, catalogID: label.identifier) {
                let requiredConfidence = label.minConfidenceOverride ?? minConfidence
                if observation.confidence >= requiredConfidence {
                    return true
                }
            }
        }
        return false
    }

    static func normalizeVisionIdentifier(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    private static func visionIdentifiersMatch(_ observedID: String, catalogID: String) -> Bool {
        observedID == catalogID
            || observedID.hasSuffix("_\(catalogID)")
            || observedID.hasPrefix("\(catalogID)_")
    }

    static func normalizedUpOrientation(_ image: UIImage) -> UIImage {
        image.normalizedUpOrientation()
    }
#endif
}

#if canImport(UIKit)
import UIKit

extension UIImage {
    /// Draws the image upright so Vision sees the same framing as the user captured.
    func normalizedUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
