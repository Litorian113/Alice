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
    let kind: CardKind
    let explanations: [CommandExplanation]
    let reply: String?
    let acceptsVoice: Bool

    init(id: String, title: String, context: String, risk: RiskLevel,
         options: [DecisionOption], allowFreeText: Bool, expiresAt: Date?, command: String? = nil,
         kind: CardKind? = nil, explanations: [CommandExplanation] = [],
         reply: String? = nil, acceptsVoice: Bool = false) {
        self.id = id
        self.title = title
        self.context = context
        self.risk = risk
        self.options = options
        self.allowFreeText = allowFreeText
        self.expiresAt = expiresAt
        self.command = command
        self.kind = kind ?? (command == nil ? .choice : .approval)
        self.explanations = explanations
        self.reply = reply
        self.acceptsVoice = acceptsVoice
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, context, risk, options, allowFreeText, expiresAt, command, kind, explanations, reply, acceptsVoice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id),
                  title: try c.decode(String.self, forKey: .title),
                  context: try c.decodeIfPresent(String.self, forKey: .context) ?? "",
                  risk: try c.decode(RiskLevel.self, forKey: .risk),
                  options: try c.decode([DecisionOption].self, forKey: .options),
                  allowFreeText: try c.decodeIfPresent(Bool.self, forKey: .allowFreeText) ?? false,
                  expiresAt: try c.decodeIfPresent(Date.self, forKey: .expiresAt),
                  command: try c.decodeIfPresent(String.self, forKey: .command),
                  kind: try c.decodeIfPresent(CardKind.self, forKey: .kind),
                  explanations: try c.decodeIfPresent([CommandExplanation].self, forKey: .explanations) ?? [],
                  reply: try c.decodeIfPresent(String.self, forKey: .reply),
                  acceptsVoice: try c.decodeIfPresent(Bool.self, forKey: .acceptsVoice) ?? false)
    }

    enum RiskLevel: String, Codable {
        case low
        case medium
        case high
    }
}

enum CardKind: String, Codable {
    case choice, approval, unknown
    init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

struct CommandExplanation: Codable, Equatable {
    let part: String
    let meaning: String
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

    private enum CodingKeys: String, CodingKey { case id, label, detail, recommended }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try c.decode(String.self, forKey: .id), label: try c.decode(String.self, forKey: .label),
                  detail: try c.decodeIfPresent(String.self, forKey: .detail) ?? "",
                  recommended: try c.decodeIfPresent(Bool.self, forKey: .recommended) ?? false)
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
