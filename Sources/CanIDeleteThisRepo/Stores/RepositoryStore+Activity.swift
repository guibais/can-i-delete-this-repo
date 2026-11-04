import Foundation

extension RepositoryStore {
    @discardableResult
    func beginActivity(_ title: String, symbol: String, total: Int = 0, goal: Int64? = nil) -> Activity.ID {
        let activity = Activity(title: title, symbol: symbol, total: total, goal: goal, freed: goal.map { _ in 0 })
        activities.append(activity)
        return activity.id
    }

    func updateActivity(_ id: Activity.ID, detail: String? = nil, completed: Int? = nil, total: Int? = nil) {
        mutateActivity(id) { activity in
            activity.detail = detail ?? activity.detail
            activity.completed = completed ?? activity.completed
            activity.total = total ?? activity.total
        }
    }

    func addFreed(_ bytes: Int64, to id: Activity.ID) {
        guard bytes > 0 else { return }
        savings.add(bytes)
        mutateActivity(id) { $0.freed = ($0.freed ?? 0) + bytes }
    }

    func finishActivity(_ id: Activity.ID, _ outcome: Toast) {
        mutateActivity(id) { activity in
            activity.outcome = outcome
            activity.completed = activity.total
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(outcome.isError ? 6 : 2.8))
            self?.dismissActivity(id)
        }
    }

    func dismissActivity(_ id: Activity.ID) {
        activities.removeAll { $0.id == id }
    }

    func activity(_ id: Activity.ID) -> Activity? {
        activities.first { $0.id == id }
    }

    func runDetached<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    private func mutateActivity(_ id: Activity.ID, _ change: (inout Activity) -> Void) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        change(&activities[index])
    }
}
