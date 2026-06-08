import Foundation
#if canImport(UIKit)
import UIKit
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
#endif
}
