import ManagedSettings
import ManagedSettingsUI
import UIKit

final class DisciplinedPetShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        configuration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        configuration()
    }

    private func configuration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemMaterial,
            backgroundColor: UIColor(red: 244 / 255, green: 228 / 255, blue: 191 / 255, alpha: 1),
            icon: currentCompanionIcon(),
            title: .init(
                text: String(localized: "shield.title", comment: "Title on the Screen Time shield."),
                color: UIColor(red: 90 / 255, green: 60 / 255, blue: 49 / 255, alpha: 1)
            ),
            subtitle: .init(
                text: String(localized: "shield.subtitle", comment: "Encouraging subtitle on the Screen Time shield."),
                color: UIColor(red: 90 / 255, green: 60 / 255, blue: 49 / 255, alpha: 0.76)
            ),
            primaryButtonLabel: .init(
                text: String(localized: "shield.return", comment: "Button that closes the shield and returns to focus."),
                color: UIColor.white
            ),
            primaryButtonBackgroundColor: UIColor(red: 201 / 255, green: 111 / 255, blue: 93 / 255, alpha: 1),
            secondaryButtonLabel: .init(
                text: String(localized: "shield.request", comment: "Button that opens the parent app to request access."),
                color: UIColor(red: 120 / 255, green: 148 / 255, blue: 163 / 255, alpha: 1)
            )
        )
    }

    private func currentCompanionIcon() -> UIImage? {
        let assetName = (try? currentCompanionAssetName())
            ?? ShieldCompanionPresentation.iconAssetName(for: nil)
        return UIImage(named: assetName)
    }

    private func currentCompanionAssetName() throws -> String {
        let store = try AppGroupStore()
        let persistedSpecies = try store.read(
            String.self,
            forKey: AppGroupKeys.shieldCompanionSpecies
        )
        return ShieldCompanionPresentation.iconAssetName(for: persistedSpecies)
    }
}
