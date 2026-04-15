import SwiftUI

struct PrayerView: View {
    @State private var viewModel = PrayerViewModel()
    @State private var savedStore = SavedPrayersStore.shared
    @State private var router = AppRouter.shared
    @State private var showDatePicker = false
    @State private var pendingDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                ParchmentBackground()

                if viewModel.isLoading {
                    PrayerLoadingView()
                } else if let prayer = viewModel.currentPrayer {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            PrayerHeaderCard(
                                prayer: prayer,
                                dateText: fullDateText(for: viewModel.selectedDate),
                                saintName: viewModel.currentSaintName,
                                isSaved: savedStore.contains(prayer),
                                onToggleSaved: {
                                    savedStore.toggle(prayer)
                                }
                            )

                            PrayerTextCard(prayer: prayer)

                            NavigationLink {
                                PrayerLibraryView()
                            } label: {
                                PrayerLibraryShortcutCard()
                            }
                            .buttonStyle(.plain)

                            PrayerSourceFooter(prayer: prayer)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 108)
                    }
                } else {
                    ErrorView(message: "No prayer could be loaded for this date.") {
                        Task {
                            await viewModel.load()
                        }
                    }
                }
            }
            .navigationTitle("Daily Prayer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        pendingDate = viewModel.selectedDate
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.inkBrown)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Browse prayers by date")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        PrayerLibraryView()
                    } label: {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.inkBrown)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Prayer library")
                }
            }
            .task {
                await viewModel.load()
            }
            .task(id: router.prayerDateRequestID) {
                guard let requestedDate = router.requestedPrayerDate else { return }
                await viewModel.selectDate(requestedDate)
                router.clearRequestedPrayerDate()
            }
        }
        .fullScreenCover(isPresented: $showDatePicker) {
            DatePickerOverlay(
                pendingDate: $pendingDate,
                confirmLabel: "Open Prayer",
                onClose: { showDatePicker = false },
                onConfirm: {
                    let selectedDate = pendingDate
                    showDatePicker = false
                    Task { await viewModel.selectDate(selectedDate) }
                }
            )
        }
    }

    private func fullDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

private struct PrayerHeaderCard: View {
    let prayer: DailyPrayer
    let dateText: String
    let saintName: String?
    let isSaved: Bool
    let onToggleSaved: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(dateText.uppercased())
                        .font(.saintCaption)
                        .foregroundStyle(Color.ancientGold)

                    Text(prayer.title)
                        .font(.saintTitle)
                        .foregroundStyle(Color.inkBrown)

                    Text(prayer.summary)
                        .font(.saintBody)
                        .foregroundStyle(Color.inkBrown.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onToggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSaved ? Color.ancientGold : Color.inkBrown.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(Color.parchment.opacity(0.9), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.ancientGold.opacity(0.45), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Remove prayer from saved" : "Save prayer")
            }

            HStack(spacing: 8) {
                PrayerMetaPill(label: prayer.category)
                PrayerMetaPill(label: prayer.occasion)
            }

            if let saintName, !saintName.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Linked Saint")
                        .font(.saintCaption)
                        .foregroundStyle(Color.ancientGold)

                    Text(saintName)
                        .font(.saintBody)
                        .foregroundStyle(Color.inkBrown)
                }
            }
        }
        .padding(20)
        .cardStyle()
    }
}

private struct PrayerTextCard: View {
    let prayer: DailyPrayer

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Prayer", systemImage: "hands.sparkles.fill")
                .font(.saintHeading)
                .foregroundStyle(Color.inkBrown)

            Divider()
                .overlay(Color.ancientGold.opacity(0.35))

            Text(prayer.text)
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .cardStyle()
    }
}

private struct PrayerSourceFooter: View {
    let prayer: DailyPrayer

    var body: some View {
        HStack(spacing: 6) {
            Text("Source:")
            Text(prayer.sourceTitle)
            if prayer.sourceLink != nil {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .semibold))
            }
        }
        .font(.saintCaption)
        .foregroundStyle(Color.inkBrown.opacity(0.55))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 2)
    }
}

private struct PrayerLibraryShortcutCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ancientGold.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.ancientGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Prayer Library")
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)

                Text("Browse the full collection by category.")
                    .font(.saintCaption)
                    .foregroundStyle(Color.inkBrown.opacity(0.72))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkBrown.opacity(0.35))
        }
        .padding(18)
        .cardStyle()
    }
}

private struct PrayerMetaPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.saintCaption)
            .foregroundStyle(Color.ancientGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.ancientGold.opacity(0.12), in: Capsule())
    }
}

private struct PrayerLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color.ancientGold)
                .scaleEffect(1.3)

            Text("Loading today's prayer...")
                .font(.saintCaption)
                .foregroundStyle(Color.inkBrown.opacity(0.7))
        }
    }
}
