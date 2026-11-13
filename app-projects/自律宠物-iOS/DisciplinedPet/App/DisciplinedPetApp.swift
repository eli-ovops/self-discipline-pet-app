import Foundation
import SwiftUI

@main
struct DisciplinedPetApp: App {
    var body: some Scene {
        WindowGroup {
            FocumiProductionRoot()
        }
    }
}

private struct FocumiProductionRoot: View {
    @State private var model = FriendMVPModel()
    @AppStorage(FocumiInterfaceLanguage.storageKey)
    private var interfaceLanguageRawValue = FocumiInterfaceLanguage.system.rawValue

    var body: some View {
        FriendMVPView(model: model)
            .environment(
                \.locale,
                FocumiInterfaceLanguage.resolvedLocale(selection: interfaceLanguageRawValue)
            )
    }
}
