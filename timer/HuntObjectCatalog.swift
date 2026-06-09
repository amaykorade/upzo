import Foundation

struct HuntObjectVisionLabel: Equatable {
    let identifier: String
    /// When set, this label must meet this threshold instead of the mission default.
    let minConfidenceOverride: Float?
}

struct HuntObject: Identifiable, Equatable {
    let id: String
    let displayName: String
    let systemImage: String
    let visionLabels: [HuntObjectVisionLabel]
}

enum HuntObjectCatalog {
    static let all: [HuntObject] = [
        HuntObject(
            id: "coffee_mug",
            displayName: "Coffee mug",
            systemImage: "cup.and.saucer.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "coffee_mug", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "mug", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "cup", minConfidenceOverride: 0.30),
                HuntObjectVisionLabel(identifier: "coffee_cup", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "water_bottle",
            displayName: "Water bottle",
            systemImage: "waterbottle.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "water_bottle", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "bottle", minConfidenceOverride: 0.50),
            ]
        ),
        HuntObject(
            id: "toothbrush",
            displayName: "Toothbrush",
            systemImage: "mouth.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "toothbrush", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "hair_dryer",
            displayName: "Hair dryer",
            systemImage: "wind",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "hair_dryer", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "microwave",
            displayName: "Microwave",
            systemImage: "microwave.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "microwave", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "refrigerator",
            displayName: "Refrigerator",
            systemImage: "refrigerator.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "refrigerator", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "icebox", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "clock",
            displayName: "Clock",
            systemImage: "clock.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "analog_clock", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "wall_clock", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "digital_clock", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "book",
            displayName: "Book",
            systemImage: "book.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "book", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "book_jacket", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "notebook", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "library", minConfidenceOverride: 0.25),
            ]
        ),
        HuntObject(
            id: "television",
            displayName: "Television",
            systemImage: "tv.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "television", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "tv_monitor", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "laptop",
            displayName: "Laptop",
            systemImage: "laptopcomputer",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "laptop", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "laptop_computer", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "notebook_computer", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "computer", minConfidenceOverride: 0.28),
            ]
        ),
        HuntObject(
            id: "keyboard",
            displayName: "Keyboard",
            systemImage: "keyboard.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "keyboard", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "computer_keyboard", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "mouse",
            displayName: "Computer mouse",
            systemImage: "computermouse.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "computer_mouse", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "mouse", minConfidenceOverride: 0.55),
            ]
        ),
        HuntObject(
            id: "banana",
            displayName: "Banana",
            systemImage: "leaf.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "banana", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "plantain", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "fruit", minConfidenceOverride: 0.24),
            ]
        ),
        HuntObject(
            id: "orange",
            displayName: "Orange",
            systemImage: "circle.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "orange", minConfidenceOverride: 0.12),
                HuntObjectVisionLabel(identifier: "citrus_fruit", minConfidenceOverride: 0.14),
                HuntObjectVisionLabel(identifier: "navel_orange", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "fruit", minConfidenceOverride: 0.22),
            ]
        ),
        HuntObject(
            id: "chair",
            displayName: "Chair",
            systemImage: "chair.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "chair", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "folding_chair", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "armchair", minConfidenceOverride: nil),
                HuntObjectVisionLabel(identifier: "rocking_chair", minConfidenceOverride: nil),
            ]
        ),
        HuntObject(
            id: "pillow",
            displayName: "Pillow",
            systemImage: "bed.double.fill",
            visionLabels: [
                HuntObjectVisionLabel(identifier: "pillow", minConfidenceOverride: nil),
            ]
        ),
    ]

    static func randomTarget() -> HuntObject {
        all.randomElement() ?? all[0]
    }

    static func object(withId id: String) -> HuntObject? {
        all.first { $0.id == id }
    }
}
