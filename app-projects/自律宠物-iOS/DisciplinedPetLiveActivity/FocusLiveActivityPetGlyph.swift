import SwiftUI
import UIKit

struct FocusLiveActivityPetGlyph: View {
    let pet: FocusLiveActivityPet
    var phase: FocusLiveActivityPhase = .focusing
    var frameSize: CGFloat = 26

    var body: some View {
        glyph
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: frameSize, height: frameSize)
            .clipShape(.rect(cornerRadius: frameSize * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }

    private var glyph: Image {
        let primaryName = pet.liveActivityBadgeAssetName(for: phase)
        if let image = UIImage(named: primaryName) {
            return Image(uiImage: image)
        }

        // A second branded, opaque resource is intentionally used instead of a
        // generic symbol. It remains recognizable as Milo or Max if a primary
        // rendition cannot be loaded by WidgetKit.
        if let fallback = UIImage(named: pet.liveActivityFallbackAssetName) {
            return Image(uiImage: fallback)
        }

        // The dedicated fallback is part of this extension's catalog. If it is
        // unexpectedly unavailable, leave the slot empty rather than substituting
        // an emoji or a generic system glyph that could be mistaken for state.
        return Image(decorative: pet.liveActivityFallbackAssetName)
    }
}

extension FocusLiveActivityPet {
    var accentColor: Color {
        switch self {
        case .cat: Color(red: 132 / 255, green: 149 / 255, blue: 110 / 255)
        case .dog: Color(red: 120 / 255, green: 148 / 255, blue: 163 / 255)
        }
    }
}

extension Color {
    static let focumiPaper = Color(red: 244 / 255, green: 228 / 255, blue: 191 / 255)
    static let focumiInk = Color(red: 90 / 255, green: 60 / 255, blue: 49 / 255)
    static let focumiCoral = Color(red: 201 / 255, green: 111 / 255, blue: 93 / 255)
}
