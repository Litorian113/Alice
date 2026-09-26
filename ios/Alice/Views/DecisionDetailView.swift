import SwiftUI

struct DecisionDetailView: View {
    let card: DecisionCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Eyebrow(text: "Behind the request")
                    Spacer()
                    Button("Done") { dismiss() }.font(.plex(14, weight: .medium))
                }
                Text(card.title).font(.plex(27, weight: .semibold))
                if let command = card.command {
                    CommandSnippet(command: command)
                }
                Text(card.context).font(.plex(15)).foregroundStyle(Color.aliceSecondary)
                if !card.explanations.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(card.explanations.enumerated()), id: \.offset) { _, item in
                            explanation(item.part, item.meaning)
                        }
                    }
                    .padding(20).aliceSurface()
                }
                if card.kind == .approval { VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Your call")
                    explanation("Approve once", "Allow this execution. Ask again next time.")
                    explanation("Approve for task", "Allow this command again during the current task. The permission ends with the task.")
                    explanation("Reject", "Don't allow this command. Bob needs a different approach.")
                } }
            }
            .padding(24).padding(.top, 12)
        }
        .background(Color.aliceBackground)
        .foregroundStyle(Color.alicePrimary)
    }

    private func explanation(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.plex(14, weight: .medium))
            Text(detail).font(.plex(13)).foregroundStyle(Color.aliceSecondary)
        }
    }
}
