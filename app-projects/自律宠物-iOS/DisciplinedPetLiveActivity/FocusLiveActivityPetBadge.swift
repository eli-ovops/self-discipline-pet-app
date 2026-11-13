import SwiftUI

struct FocusLiveActivityPetBadge: View {
    let pet: FocusLiveActivityPet
    let phase: FocusLiveActivityPhase
    let size: CGFloat

    var body: some View {
        FocusLiveActivityPetGlyph(
            pet: pet,
            phase: phase,
            frameSize: size
        )
        .background(Color.focumiPaper, in: RoundedRectangle(cornerRadius: size * 0.28))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28)
                .strokeBorder(pet.accentColor.opacity(0.72), lineWidth: 1)
        }
    }
}
