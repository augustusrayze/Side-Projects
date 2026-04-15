import SwiftUI

struct SavedView: View {
    @State private var savedSaintsStore = SavedSaintsStore.shared
    @State private var savedPrayersStore = SavedPrayersStore.shared
    @State private var router = AppRouter.shared
    @State private var sortOrder: SavedSortOrder = .newest

    var body: some View {
        NavigationStack {
            ZStack {
                Color.parchment.ignoresSafeArea()

                if savedSaintsStore.savedSaints.isEmpty && savedPrayersStore.savedPrayers.isEmpty {
                    emptyState
                } else {
                    List {
                        if !sortedPrayers.isEmpty {
                            Section("Saved Prayers") {
                                ForEach(sortedPrayers) { prayer in
                                    NavigationLink {
                                        PrayerDetailView(prayer: prayer)
                                    } label: {
                                        SavedPrayerRow(prayer: prayer)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            savedPrayersStore.remove(prayer)
                                        } label: {
                                            Label("Remove", systemImage: "bookmark.slash")
                                        }
                                    }
                                }
                            }
                        }

                        if !sortedSaints.isEmpty {
                            Section("Saved Saints") {
                                ForEach(sortedSaints) { saint in
                                    NavigationLink {
                                        SavedSaintPage(saint: saint)
                                    } label: {
                                        SavedSaintRow(saint: saint)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions {
                                        Button(role: .destructive) {
                                            savedSaintsStore.remove(saint)
                                        } label: {
                                            Label("Remove", systemImage: "bookmark.slash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if !savedSaintsStore.savedSaints.isEmpty || !savedPrayersStore.savedPrayers.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort", selection: $sortOrder) {
                                ForEach(SavedSortOrder.allCases) { order in
                                    Text(order.title).tag(order)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(Color.inkBrown)
                        }
                        .accessibilityLabel("Sort saved items")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.ancientGold)

            Text("No Saved Items Yet")
                .font(.saintHeading)
                .foregroundStyle(Color.inkBrown)

            Text("Save a saint or a prayer and it will appear here.")
                .font(.saintBody)
                .foregroundStyle(Color.inkBrown.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                Button {
                    router.selectedTab = .saints
                } label: {
                    Text("Go to Saints")
                        .font(.saintBody)
                        .foregroundStyle(Color.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ancientGold)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Button {
                    router.openPrayer()
                } label: {
                    Text("Go to Prayer")
                        .font(.saintBody)
                        .foregroundStyle(Color.inkBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.ancientGold.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.ancientGold.opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(28)
        .cardStyle()
        .padding(.horizontal, 20)
    }

    private var sortedSaints: [Saint] {
        switch sortOrder {
        case .newest:
            return savedSaintsStore.savedSaints
        case .feastDay:
            return savedSaintsStore.savedSaints.sorted {
                if $0.feastMonth == $1.feastMonth {
                    return $0.feastDayOfMonth < $1.feastDayOfMonth
                }
                return $0.feastMonth < $1.feastMonth
            }
        case .alphabetical:
            return savedSaintsStore.savedSaints.sorted {
                $0.canonicalName.localizedCaseInsensitiveCompare($1.canonicalName) == .orderedAscending
            }
        }
    }

    private var sortedPrayers: [DailyPrayer] {
        switch sortOrder {
        case .newest, .feastDay:
            return savedPrayersStore.savedPrayers
        case .alphabetical:
            return savedPrayersStore.savedPrayers.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
}

private struct SavedSaintPage: View {
    let saint: Saint
    @State private var navigationPath = NavigationPath()

    var body: some View {
        SaintScreenView(
            saint: saint,
            error: nil,
            isLoading: false,
            dateLabel: saint.feastDay,
            navigationPath: $navigationPath,
            allowsRefresh: false,
            onRefresh: {}
        )
    }
}

private struct SavedSaintRow: View {
    let saint: Saint

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: saint.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    Image("PlaceholderSaint")
                        .resizable()
                        .scaledToFill()
                @unknown default:
                    Color.vellumShadow
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.ancientGold.opacity(0.35), lineWidth: 0.75)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(saint.canonicalName)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text("Feast Day: \(saint.feastDay)")
                    .font(.saintCaption)
                    .foregroundStyle(Color.ancientGold)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkBrown.opacity(0.3))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct SavedPrayerRow: View {
    let prayer: DailyPrayer

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ancientGold.opacity(0.14))
                    .frame(width: 56, height: 56)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.ancientGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(prayer.title)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                Text("\(prayer.category) • \(prayer.occasion)")
                    .font(.saintCaption)
                    .foregroundStyle(Color.ancientGold)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkBrown.opacity(0.3))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private enum SavedSortOrder: String, CaseIterable, Identifiable {
    case newest
    case feastDay
    case alphabetical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest:
            return "Newest Saved"
        case .feastDay:
            return "Feast Day"
        case .alphabetical:
            return "Alphabetical"
        }
    }
}
