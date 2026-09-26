import Foundation

// MARK: - Decision Card (matches relay JSON protocol)

struct DecisionCard: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let context: String
    let risk: RiskLevel
    let options: [DecisionOption]
    let allowFreeText: Bool
    let expiresAt: Date?
    // Optional extension for command approvals; older relay cards can omit it.
    let command: String?

    init(id: String, title: String, context: String, risk: RiskLevel,
         options: [DecisionOption], allowFreeText: Bool, expiresAt: Date?, command: String? = nil) {
        self.id = id
        self.title = title
        self.context = context
        self.risk = risk
        self.options = options
        self.allowFreeText = allowFreeText
        self.expiresAt = expiresAt
        self.command = command
    }

    enum RiskLevel: String, Codable {
        case low
        case medium
        case high
    }
}

enum ApprovalChoice: String {
    case once = "approve_once"
    case task = "approve_for_task"
    case reject = "reject"
}

struct DecisionOption: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let detail: String
    let recommended: Bool

    var approvalChoice: ApprovalChoice? { ApprovalChoice(rawValue: id) }

    init(id: String, label: String, detail: String, recommended: Bool = false) {
        self.id = id
        self.label = label
        self.detail = detail
        self.recommended = recommended
    }
}

// MARK: - Decision Response (sent back to relay)

struct DecisionResponse: Codable {
    let type: String
    let id: String
    let optionId: String
    let text: String?

    init(id: String, optionId: String, text: String? = nil) {
        self.type = "decision_response"
        self.id = id
        self.optionId = optionId
        self.text = text
    }
}

// MARK: - Notification / Status

struct StatusNotification: Identifiable, Codable {
    let id: String
    let message: String
    let level: NotificationLevel

    enum NotificationLevel: String, Codable {
        case info
        case success
        case error
    }
}

// MARK: - Activity Item

struct ActivityItem: Identifiable {
    let id: UUID
    let timestamp: Date
    let description: String
    let kind: Kind

    enum Kind {
        case bobAction
        case userDecision
        case notification
    }

    init(description: String, kind: Kind, timestamp: Date = .now) {
        self.id = UUID()
        self.timestamp = timestamp
        self.description = description
        self.kind = kind
    }
}
