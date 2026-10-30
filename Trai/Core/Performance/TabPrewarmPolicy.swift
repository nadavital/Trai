import Foundation

/// Schedules background tab prewarming so first tab switches can avoid cold view setup.
struct TabPrewarmPolicy: Sendable {
    let initialDelayMilliseconds: Int
    let interTabDelayMilliseconds: Int

    init(initialDelayMilliseconds: Int, interTabDelayMilliseconds: Int) {
        self.initialDelayMilliseconds = max(0, initialDelayMilliseconds)
        self.interTabDelayMilliseconds = max(0, interTabDelayMilliseconds)
    }

    func preloadOrder(
        for selectedTab: AppTab,
        loadedTabs: Set<AppTab>
    ) -> [AppTab] {
        let prioritized: [AppTab]
        switch selectedTab {
        case .dashboard:
            prioritized = [.workouts, .trai]
        case .trai:
            prioritized = [.dashboard, .workouts]
        case .workouts:
            prioritized = [.dashboard, .trai]
        case .profile:
            prioritized = [.dashboard, .workouts, .trai]
        }

        return prioritized.filter { !loadedTabs.contains($0) }
    }
}
