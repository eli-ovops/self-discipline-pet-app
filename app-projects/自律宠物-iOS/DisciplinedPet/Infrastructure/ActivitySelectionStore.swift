import FamilyControls
import Foundation

@MainActor
struct ActivitySelectionStore {
    private let store: AppGroupStore?

    init() {
        store = try? AppGroupStore()
    }

    func load() -> FamilyActivitySelection {
        guard let store else { return FamilyActivitySelection() }
        return (try? store.read(FamilyActivitySelection.self, forKey: AppGroupKeys.activitySelection))
            ?? FamilyActivitySelection()
    }

    func save(_ selection: FamilyActivitySelection) throws {
        guard let store else { throw AppGroupStoreError.suiteUnavailable }
        try store.write(selection, forKey: AppGroupKeys.activitySelection)
    }
}
