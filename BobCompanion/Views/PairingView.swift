import SwiftUI

struct PairingView: View {
    @EnvironmentObject var store: SessionStore
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo / wordmark
            VStack(spacing: 12) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(.bcAccent)

                Text("Bob Companion")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundColor(.bcPrimary)

                Text("Scan the QR code shown by Bob\nto begin your session.")
                    .font(.system(size: 16))
                    .foregroundColor(.bcSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            // Actions
            VStack(spacing: 12) {
                Button {
                    isScanning = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Scan QR Code")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.bcAccent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }

                // DEV ONLY: skip pairing for mock testing
                Button {
                    store.simulatePaired()
                } label: {
                    Text("Skip — use mock session")
                        .font(.system(size: 14))
                        .foregroundColor(.bcMuted)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
    }
}

#Preview {
    PairingView()
        .environmentObject(SessionStore())
        .background(Color.bcBackground)
        .preferredColorScheme(.dark)
}
