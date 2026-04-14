import SwiftUI

struct MenuSheet: View {
    let saint: Saint?
    @AppStorage("appColorScheme") private var storedScheme: String = "system"
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetent: PresentationDetent = .fraction(0.72)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Text("Sacred Resources")
                        .font(.saintHeading)
                        .foregroundStyle(Color.inkBrown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 16)

                    MenuGoldDivider()

                    VStack(spacing: 0) {
                        NavigationLink {
                            PrayerLibraryView()
                        } label: {
                            MenuRow(
                                icon: "book.closed.fill",
                                label: "Prayer Library",
                                color: Color.frescoRed
                            )
                        }
                        .buttonStyle(.plain)

                        MenuGoldDivider().padding(.leading, 64)

                        NavigationLink {
                            DailyReadingsView()
                        } label: {
                            MenuRow(
                                icon: "text.book.closed",
                                label: "Mass Readings",
                                color: Color.ancientGold
                            )
                        }
                        .buttonStyle(.plain)

                        MenuGoldDivider().padding(.leading, 64)

                        NavigationLink {
                            LiturgicalCalendarView()
                        } label: {
                            MenuRow(
                                icon: "calendar.badge.clock",
                                label: "Liturgical Calendar",
                                color: Color.inkBrown
                            )
                        }
                        .buttonStyle(.plain)

                        MenuGoldDivider().padding(.leading, 64)

                        NavigationLink {
                            GuidedRosaryMeditationsView()
                        } label: {
                            MenuRow(
                                icon: "sparkles",
                                label: "Guided Rosary Meditations",
                                color: Color.frescoRed
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    MenuGoldDivider()

                    if let saint, let shareImage = renderedShareCard(for: saint) {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview(saint.canonicalName, image: shareImage)
                        ) {
                            MenuRow(
                                icon: "square.and.arrow.up",
                                label: "Share Today's Saint",
                                color: Color.inkBrown,
                                showChevron: false
                            )
                        }
                        .buttonStyle(.plain)

                        MenuGoldDivider()
                    } else if saint != nil {
                        ShareLink(item: shareText(for: saint!)) {
                            MenuRow(
                                icon: "square.and.arrow.up",
                                label: "Share Today's Saint",
                                color: Color.inkBrown,
                                showChevron: false
                            )
                        }
                        .buttonStyle(.plain)

                        MenuGoldDivider()
                    }

                    settingsSection

                    Spacer(minLength: 40)
                }
            }
            .background(Color.parchment.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.inkBrown.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.parchment)
    }

    @MainActor
    private func renderedShareCard(for saint: Saint) -> Image? {
        let card = SaintShareCard(saint: saint).frame(width: 390, height: 520)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    private func shareText(for saint: Saint) -> String {
        var text = "Saint of the Day: \(saint.canonicalName)\n"
        text += "Feast Day: \(saint.feastDay)\n"
        if let period = saint.timePeriod { text += "\(period)\n" }
        text += "\n\(saint.shortBio)"
        return text
    }
}

// MARK: - Supporting Views

extension MenuSheet {
    private var settingsSection: some View {
        HStack(spacing: 14) {
            NavigationLink {
                SettingsView()
            } label: {
                SettingsCircleButton(icon: "gearshape.fill", tint: Color.inkBrown)
            }
            .buttonStyle(.plain)

            Picker("Appearance", selection: $storedScheme) {
                Text("Light").tag("light")
                Text("System").tag("system")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .tint(Color.ancientGold)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }
}

private struct MenuRow: View {
    let icon: String
    let label: String
    let color: Color
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(color)
            }

            Text(label)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkBrown.opacity(0.3))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct SettingsCircleButton: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.ancientGold.opacity(0.22), lineWidth: 0.75)
                )

            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(tint)
        }
    }
}

private struct MenuGoldDivider: View {
    var body: some View {
        Divider()
            .overlay(Color.ancientGold.opacity(0.25))
    }
}
