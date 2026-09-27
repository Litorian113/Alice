import SwiftUI

struct AliceCustomizerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("alicePalette") private var paletteID = AlicePalette.violet.rawValue
    @AppStorage("aliceUsesGradient") private var usesGradient = true

    private var palette: AlicePalette { AlicePalette(rawValue: paletteID) ?? .violet }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    AliceMascot(grounded: true)
                        .frame(width: 180, height: 215)
                        .padding(.top, 12)
                        .accessibilityLabel("Alice preview, \(palette.name), \(usesGradient ? "gradient" : "solid")")

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Color").font(.plex(17, weight: .semibold))
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 14) {
                            ForEach(AlicePalette.allCases) { item in
                                Button { paletteID = item.rawValue } label: {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: usesGradient ? [item.colors.start, item.colors.end] : [item.colors.accent, item.colors.accent],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 46, height: 46)
                                            .overlay {
                                                if palette == item {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 17, weight: .bold))
                                                        .foregroundStyle(Color(hex: "182544"))
                                                        .padding(5).background(.white, in: Circle())
                                                }
                                            }
                                        Text(item.name).font(.plex(12, weight: .medium))
                                            .foregroundStyle(Color.alicePrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(palette == item ? Color.aliceSurfaceRaised : .clear, in: RoundedRectangle(cornerRadius: 16))
                                    .contentShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.name)
                                .accessibilityAddTraits(palette == item ? .isSelected : [])
                                .accessibilityIdentifier("customizer.\(item.rawValue)")
                            }
                        }
                        Text("Finish").font(.plex(17, weight: .semibold)).padding(.top, 6)
                        HStack(spacing: 5) {
                            ForEach([true, false], id: \.self) { gradient in
                                Button { usesGradient = gradient } label: {
                                    Text(gradient ? "Gradient" : "Solid")
                                        .font(.plex(14, weight: .medium))
                                        .foregroundStyle(usesGradient == gradient ? Color.alicePrimary : .aliceSecondary)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(usesGradient == gradient ? Color.aliceSurface : .clear, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(usesGradient == gradient ? .isSelected : [])
                            }
                        }
                        .padding(5)
                        .background(Color.aliceSurfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("customizer.finish")
                    }
                    .padding(20).aliceSurface()

                    VStack(spacing: 14) {
                        Text("Your colors, everywhere Alice appears.")
                            .font(.plex(12)).foregroundStyle(Color.aliceSecondary)
                            .multilineTextAlignment(.center)
                        Button("Reset to original") {
                            paletteID = AlicePalette.violet.rawValue
                            usesGradient = true
                        }
                        .buttonStyle(.plain)
                        .font(.plex(13, weight: .medium))
                        .foregroundStyle(Color.aliceAccent)
                        .frame(minHeight: 44)
                        .opacity(palette == .violet && usesGradient ? 0.45 : 1)
                        .disabled(palette == .violet && usesGradient)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.aliceBackground)
            .foregroundStyle(Color.alicePrimary)
            .navigationTitle("Your Alice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.font(.plex(15, weight: .medium))
                }
            }
        }
        .tint(.aliceAccent)
    }
}
