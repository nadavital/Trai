import Foundation

struct LiveWorkoutRestTimer: Equatable {
    private(set) var endDate: Date?
    private(set) var exerciseName: String?

    var isActive: Bool {
        endDate != nil
    }

    mutating func start(seconds: Int, exerciseName: String, now: Date = .now) {
        guard seconds > 0 else {
            stop()
            return
        }
        self.exerciseName = exerciseName
        endDate = now.addingTimeInterval(TimeInterval(seconds))
    }

    mutating func add(seconds: Int) {
        guard let endDate, seconds > 0 else { return }
        self.endDate = endDate.addingTimeInterval(TimeInterval(seconds))
    }

    mutating func stop() {
        endDate = nil
        exerciseName = nil
    }

    func remainingSeconds(at date: Date = .now) -> Int {
        guard let endDate else { return 0 }
        return max(0, Int(ceil(endDate.timeIntervalSince(date))))
    }
}
