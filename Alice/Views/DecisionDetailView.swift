import SwiftUI

struct DecisionDetailView: View {
    let card: DecisionCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Eyebrow(text: "Behind the command")
                    Spacer()
                    Button("Done") { dismiss() }.font(.plex(14, weight: .medium))
                }
                Text(card.title).font(.plex(27, weight: .semibold))
                if let command = card.command {
                    CommandSnippet(command: command)
                }
                Text(card.context).font(.plex(15)).foregroundStyle(Color.aliceSecondary)
                if card.command == AliceFixtures.commandApproval.command {
                    VStack(alignment: .leading, spacing: 16) {
                        explanation("npm test", "Starts the project's test runner.")
                        explanation("--runInBand", "Runs the tests one at a time.")
                        explanation("--bail", "Stops when the first test fails.")
                        explanation("auth", "Selects the authentication tests.")
                    }
                    .padding(20).aliceSurface()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "Your call")
                    explanation("Approve once", "Allow this execution. Ask again next time.")
                    explanation("Approve for task", "Allow this command again during the current task. The permission ends with the task.")
                    explanation("Reject", "Don't allow this command. Bob needs a different approach.")
                }
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
