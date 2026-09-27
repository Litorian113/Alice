import SwiftUI
import Charts

struct UsageView: View {
    @State private var period: UsagePeriod = .threeDays
    @State private var selectedIndex: Int?
    private var selectedSample: UsageSample? { period.samples.first { $0.id == selectedIndex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your usage")
                    .font(.plex(34, weight: .semibold, relativeTo: .largeTitle)).tracking(-1)
                    .padding(.top, 24)
                periodPicker
                tokenChart
                bobcoins
                HStack(spacing: 16) {
                    AliceMascot(faceOnly: true, animated: false).frame(width: 53, height: 48)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("An Alice that's so you.").font(.plex(17, weight: .semibold))
                        Text("Colors, outfits, a little personality.\nCompanion customization is coming later.")
                            .font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(19)
                .background(Color.aliceVioletSurface, in: RoundedRectangle(cornerRadius: 22))
                Color.clear.frame(height: 8)
            }.padding(.horizontal, 24)
        }.scrollIndicators(.hidden)
    }

    private var periodPicker: some View {
        HStack(spacing: 5) {
            ForEach(UsagePeriod.allCases) { item in
                Button {
                    period = item
                    selectedIndex = nil
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
                    Text(selectedSample.map { period == .today ? "27 Sep · \($0.label):00" : "\($0.label) 2026" } ?? period.caption)
                        .font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                }
                Spacer()
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 19))
                    .foregroundStyle(Color.aliceAccent)
                    .padding(11).background(Color.aliceAccent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            Chart {
                ForEach(period.samples) { sample in
                    AreaMark(x: .value("Interval", sample.id), y: .value("Tokens", sample.input), stacking: .unstacked)
                        .foregroundStyle(by: .value("Type", "Input"))
                        .interpolationMethod(.monotone).opacity(0.1)
                    AreaMark(x: .value("Interval", sample.id), y: .value("Tokens", sample.output), stacking: .unstacked)
                        .foregroundStyle(by: .value("Type", "Output"))
                        .interpolationMethod(.monotone).opacity(0.1)
                    LineMark(x: .value("Interval", sample.id), y: .value("Tokens", sample.input))
                        .foregroundStyle(by: .value("Type", "Input"))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .symbol(Circle()).symbolSize(selectedIndex == sample.id ? 65 : 28)
                    LineMark(x: .value("Interval", sample.id), y: .value("Tokens", sample.output))
                        .foregroundStyle(by: .value("Type", "Output"))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .symbol(Circle()).symbolSize(selectedIndex == sample.id ? 65 : 28)
                    if selectedIndex == sample.id {
                        RuleMark(x: .value("Selected", sample.id))
                            .foregroundStyle(Color.alicePrimary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                }
            }
            .chartForegroundStyleScale(["Input": Color.aliceAccent, "Output": Color(hex: "B9A4EE")])
            .chartLegend(.hidden)
            .chartXScale(domain: -0.15...Double(period.samples.count - 1) + 0.15)
            .chartXSelection(value: $selectedIndex)
            .chartXAxis {
                AxisMarks(values: period.samples.map(\.id)) { value in
                    AxisValueLabel(anchor: .top) {
                        if let index = value.as(Int.self), period.samples.indices.contains(index) {
                            Text(period.samples[index].label).font(.plex(10)).foregroundStyle(Color.aliceSecondary)
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
