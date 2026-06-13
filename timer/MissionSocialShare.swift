#if os(iOS)
import SwiftUI
import UIKit

enum MissionSocialShare {
    @MainActor
    static func renderImage(snapshot: MissionShareSnapshot) -> UIImage? {
        let card = MissionShareCardView(snapshot: snapshot)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 1
        return renderer.uiImage
    }
}

struct MissionShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
