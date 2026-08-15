import Foundation

enum StreakManager {
    @discardableResult
    static func recordOpenToday() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastOpen = SharedDefaults.lastOpenDate else {
            SharedDefaults.streakCount = 1
            SharedDefaults.lastOpenDate = today
            return 1
        }

        let lastOpenDay = calendar.startOfDay(for: lastOpen)
        let daysSince = calendar.dateComponents([.day], from: lastOpenDay, to: today).day ?? 0

        switch daysSince {
        case 0:
            break
        case 1:
            SharedDefaults.streakCount += 1
            SharedDefaults.lastOpenDate = today
        default:
            SharedDefaults.streakCount = 1
            SharedDefaults.lastOpenDate = today
        }

        return SharedDefaults.streakCount
    }
}
