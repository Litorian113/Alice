import SwiftUI

struct TaskCompletedView: View {
    @EnvironmentObject var store: SessionStore
    let message: String

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Text("✓")
                    .font(.system(size: 64))
                    .foregroundColor(.bcRiskLow)

                Text("BOB FINISHED")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.bcRiskLow)

                Text(message)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.bcPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button {
                store.simulatePaired()
            } label: {
                Text("Back to session")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.bcSecondary)
            }
            .padding(.bottom, 52)
        }
    }
}

#Preview {
    TaskCompletedView(message: "Authentication refactor complete.\n48 / 48 tests passing.")
        .environmentObject(SessionStore())
        .background(Color.bcBackground)
        .preferredColorScheme(.dark)
}
