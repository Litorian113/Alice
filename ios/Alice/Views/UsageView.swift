import SwiftUI
import Charts

struct UsageView: View {
    @State private var period: UsagePeriod = .sevenDays
    @State private var selectedInterval: String?
    private var selectedSample: UsageSample? { period.samples.first { $0.label == selectedInterval } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your usage")
                    .font(.plex(34, weight: .semibold, relativeTo: .largeTitle)).tracking(-1)
                    .padding(.top, 24)
                periodPicker
                tokenChart
                bobcoins
                Color.clear.frame(height: 8)
            }.padding(.horizontal, 24)
        }.scrollIndicators(.hidden)
    }

    private var periodPicker: some View {
        HStack(spacing: 5) {
            ForEach(UsagePeriod.allCases) { item in
                Button {
                    period = item
                    selectedInterval = nil
                } label: {
                    Text(item.rawValue).font(.plex(14, weight: .medium))
                        .foregroundStyle(period == item ? Color.alicePrimary : .aliceSecondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(period == item ? Color.aliceSurface : .clear, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("usage.\(item.rawValue.lowercased())")
                .accessibilityAddTraits(period == item ? .isSelected : [])
            }
        }
        .padding(5)
        .background(Color.aliceSurfaceRaised, in: RoundedRectangle(cornerRadius: 16))
    }

    private var selectedLabel: String {
        guard let s = selectedSample else { return period.caption }
        switch period {
        case .today: return "27 Sep · \(s.label):00"
        default: return "\(s.label) 2026"
        }
    }

    private var tokenChart: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: selectedSample == nil ? "Tokens used" : "Selected interval")
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text((selectedSample?.tokens ?? period.total).tokenLabel)
                            .font(.plex(43, weight: .semibold, relativeTo: .largeTitle)).tracking(-1.5).contentTransition(.numericText())
                        Text("tokens").font(.plex(13)).foregroundStyle(Color.aliceSecondary)
                    }
                    Text(selectedLabel)
                        .font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                }
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 19))
                    .foregroundStyle(Color.aliceAccent)
                    .padding(11).background(Color.aliceAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            Chart {
                ForEach(period.samples) { sample in
                    BarMark(x: .value("Interval", sample.label),
                            y: .value("Tokens", sample.input), width: .ratio(0.55))
                        .foregroundStyle(by: .value("Type", "Input"))
                        .cornerRadius(4)
                        .opacity(selectedInterval == nil || selectedInterval == sample.label ? 1 : 0.35)
                    BarMark(x: .value("Interval", sample.label),
                            y: .value("Tokens", sample.output), width: .ratio(0.55))
                        .foregroundStyle(by: .value("Type", "Output"))
                        .cornerRadius(4)
                        .opacity(selectedInterval == nil || selectedInterval == sample.label ? 1 : 0.35)
                    if selectedInterval == sample.label {
                        RuleMark(x: .value("Selected", sample.label))
                            .foregroundStyle(Color.alicePrimary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
            }
            .chartForegroundStyleScale(["Input": Color.aliceAccent, "Output": Color(hex: "B9A4EE")])
            .chartLegend(.hidden)
            .chartXScale(domain: period.samples.map(\.label))
            .chartXSelection(value: $selectedInterval)
            .chartXAxis {
                AxisMarks(values: period.samples.map(\.label)) { value in
                    AxisValueLabel(anchor: .top) {
                        if let label = value.as(String.self) {
                            Text(label).font(.plex(10)).foregroundStyle(Color.aliceSecondary)
                                .fixedSize()
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4])).foregroundStyle(Color.aliceBorder)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text("\(Int(amount / 1000))k").font(.plex(9)).foregroundStyle(Color.aliceMuted)
                        }
                    }
                }
            }
            .frame(height: 190)
            .accessibilityLabel("\(period.rawValue) token usage, \(period.total.tokenLabel) total")
            HStack(spacing: 8) {
                Circle().fill(Color.aliceAccent).frame(width: 7, height: 7)
                Text("Input").font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                Spacer()
                Text((selectedSample?.input ?? period.inputTotal).tokenLabel).font(.plex(14, weight: .medium))
                Rectangle().fill(Color.aliceBorder).frame(width: 1, height: 24).padding(.horizontal, 10)
                Circle().fill(Color(hex: "B9A4EE")).frame(width: 7, height: 7)
                Text("Output").font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                Spacer()
                Text((selectedSample?.output ?? period.outputTotal).tokenLabel).font(.plex(14, weight: .medium))
            }
        }
        .padding(22).aliceSurface()
    }

    private var bobcoins: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Label("Bobcoins", systemImage: "circle.hexagongrid")
                    .font(.plex(17, weight: .semibold))
                Spacer()
                Text("SPENDING LIMIT").font(.plex(8, weight: .medium)).tracking(1)
                    .foregroundStyle(.white.opacity(0.6))
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(UsageData.bobcoinsUsed)").font(.plex(31, weight: .semibold)).tracking(-0.8)
                Text("/ \(UsageData.bobcoinLimit) used").font(.plex(13)).foregroundStyle(.white.opacity(0.65))
                Spacer()
                Text("\(UsageData.bobcoinsRemaining) left").font(.plex(12, weight: .medium)).foregroundStyle(Color(hex: "C7D7FF"))
            }
            GeometryReader { geometry in
                Capsule().fill(.white.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color(hex: "83A9FF"))
                            .frame(width: geometry.size.width * UsageData.bobcoinFraction)
                    }
            }.frame(height: 6)
            Text("ibm-hackathon-lablab")
                .font(.plex(11)).foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(Color.aliceInk, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}
