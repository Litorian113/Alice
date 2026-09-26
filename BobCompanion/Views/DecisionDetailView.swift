import SwiftUI

struct DecisionDetailView: View {
    let card: DecisionCard
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Eyebrow(text: "A little more context")
                    Spacer()
                    Button("Done") { dismiss() }.font(.plex(14, weight: .medium))
                }
                Text(card.title).font(.plex(27, weight: .semibold))
                Text(card.context).font(.plex(16)).foregroundStyle(Color.bcSecondary)
                if card.id == "d_01" {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Demo test run")
                        detailRow("Refactor", "Authentication module updated", "checkmark.circle", .bcSuccess)
                        detailRow("Passing", "45 of 48 tests", "checkmark.circle", .bcSuccess)
                        detailRow("Failing", "3 tests still use outdated mocks", "exclamationmark.circle", .bcRiskMedium)
                    }
                    .padding(18).companionSurface()
                }
                if let option = card.options.first(where: \.recommended) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Bob recommends")
                        Text(option.label).font(.plex(19, weight: .semibold))
                        Text(option.detail).font(.plex(15)).foregroundStyle(Color.bcSecondary)
                    }
                }
                Label(card.risk.label, systemImage: "shield.lefthalf.filled")
                    .font(.plex(13, weight: .medium)).foregroundStyle(card.risk.color)
                Text("This is a local demo. Your choice plays out in the app; no code or files are changed.")
                    .font(.plex(12)).foregroundStyle(Color.bcSecondary)
            }
            .padding(26).padding(.top, 12)
        }
        .background(Color.bcBackground)
        .foregroundStyle(Color.bcPrimary)
    }

    private func detailRow(_ title: String, _ detail: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.plex(13, weight: .medium))
                Text(detail).font(.plex(12)).foregroundStyle(Color.bcSecondary)
            }
        }
    }
}
