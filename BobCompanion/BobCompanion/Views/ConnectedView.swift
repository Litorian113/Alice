import SwiftUI

struct ConnectedView: View {
    @EnvironmentObject var store: SessionStore
    let status: BobStatus

    @State private var elapsed: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.bcRiskLow)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.bcRiskLow)
                }
                Spacer()
                Button {
                    store.disconnect()
                } label: {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.bcMuted)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 32)

            Spacer()

            // Main status — calm, minimal
            VStack(spacing: 8) {
                Text("Bob is working")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.bcPrimary)

                Text(status.currentActivity)
                    .font(.system(size: 17))
                    .foregroundColor(.bcSecondary)

                Text(elapsed)
                    .font(.system(size: 13))
                    .foregroundColor(.bcMuted)
                    .padding(.top, 4)
            }
            .onReceive(timer) { _ in
                elapsed = formatElapsed(since: status.startedAt)
            }
            .onAppear {
                elapsed = formatElapsed(since: status.startedAt)
            }

            Spacer()

            // Activity log
            if !store.activityLog.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Activity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.bcMuted)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(store.activityLog.suffix(5).reversed()) { item in
                                ActivityRow(item: item)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
                .padding(.bottom, 20)
            }

            // Send instruction button
            Button {
                // TODO: show instruction sheet
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                    Text("Send instruction")
                }
                .font(.system(size: 15))
                .foregroundColor(.bcSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.bcSurface)
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)

            // DEV: simulate a decision arriving
            Button {
                store.simulateDecisionArrived(MockData.lowRiskDecision)
            } label: {
                Text("Simulate decision (mock)")
                    .font(.system(size: 12))
                    .foregroundColor(.bcMuted)
            }
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    private func formatElapsed(since date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "Started \(minutes) min ago" }
        let hours = minutes / 60
        return "Started \(hours)h \(minutes % 60)m ago"
    }
}

struct ActivityRow: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(iconColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(item.description)
                .font(.system(size: 13))
                .foregroundColor(.bcSecondary)

            Spacer()

            Text(timeString(item.timestamp))
                .font(.system(size: 11))
                .foregroundColor(.bcMuted)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        switch item.kind {
        case .bobAction: return .bcMuted
        case .userDecision: return .bcAccent
        case .notification: return .bcRiskLow
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

#Preview {
    ConnectedView(status: MockData.workingStatus)
        .environmentObject({
            let s = SessionStore()
            s.activityLog = MockData.sampleActivity
            return s
        }())
        .background(Color.bcBackground)
        .preferredColorScheme(.dark)
}
