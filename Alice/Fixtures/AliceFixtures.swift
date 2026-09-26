import Foundation

// MARK: - Mock data for all app states — no backend needed

enum AliceFixtures {

    // MARK: - Decision Cards

    static var commandApproval: DecisionCard { DecisionCard(
        id: UUID().uuidString,
        title: "Run the auth tests",
        context: "Checks that sign-in still works after Bob's changes. Stops at the first failing test.",
        risk: .low,
        options: [
            DecisionOption(id: ApprovalChoice.once.rawValue, label: "Approve once", detail: "Just this time"),
            DecisionOption(id: ApprovalChoice.reject.rawValue, label: "Reject", detail: "Don't run it"),
            DecisionOption(id: ApprovalChoice.task.rawValue, label: "Approve for task", detail: "Allow this command for this task")
        ],
        allowFreeText: false,
        expiresAt: nil,
        command: "npm test -- --runInBand --bail auth"
    ) }

    static var lowRiskDecision: DecisionCard { DecisionCard(
        id: "d_01",
        title: "3 tests are failing",
        context: "Auth module refactored. 3 of 48 tests fail on outdated mocks.",
        risk: .low,
        options: [
            DecisionOption(id: "a", label: "Fix tests", detail: "Update mocks, then rerun", recommended: true),
            DecisionOption(id: "b", label: "Revert refactor", detail: "Back to last green commit"),
            DecisionOption(id: "c", label: "Pause", detail: "Wait until I'm back")
        ],
        allowFreeText: true,
        expiresAt: nil
    ) }

    static let mediumRiskDecision = DecisionCard(
        id: "d_02",
        title: "Two valid API designs found",
        context: "REST and GraphQL both work here. Choice affects client compatibility.",
        risk: .medium,
        options: [
            DecisionOption(id: "a", label: "REST endpoint", detail: "Simpler, already in use", recommended: true),
            DecisionOption(id: "b", label: "GraphQL", detail: "More flexible, new dependency")
        ],
        allowFreeText: true,
        expiresAt: Date().addingTimeInterval(180)
    )

    static let highRiskDecision = DecisionCard(
        id: "d_03",
        title: "Database migration required",
        context: "Migration will remove deprecated user_legacy table. 0 active references found.",
        risk: .high,
        options: [
            DecisionOption(id: "a", label: "Run migration", detail: "Drop table, update schema"),
            DecisionOption(id: "b", label: "Skip for now", detail: "Continue without migration", recommended: true),
            DecisionOption(id: "c", label: "Pause", detail: "Review manually first")
        ],
        allowFreeText: false,
        expiresAt: Date().addingTimeInterval(300)
    )

    // MARK: - Activity Log

    static let sampleActivity: [ActivityItem] = [
        ActivityItem(description: "Session started", kind: .notification, timestamp: Date().addingTimeInterval(-380)),
        ActivityItem(description: "Started refactor", kind: .bobAction, timestamp: Date().addingTimeInterval(-360)),
        ActivityItem(description: "Updated auth service", kind: .bobAction, timestamp: Date().addingTimeInterval(-240)),
        ActivityItem(description: "Updated token handler", kind: .bobAction, timestamp: Date().addingTimeInterval(-120)),
        ActivityItem(description: "Running tests", kind: .bobAction, timestamp: Date().addingTimeInterval(-30))
    ]
}
