import SwiftUI

struct PrayerLibraryView: View {
    @State private var savedStore = SavedPrayersStore.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"

    private let prayerService = PrayerService.shared

    var body: some View {
        List {
            if !filteredPrayers.isEmpty {
                categoryPickerSection

                ForEach(filteredPrayers) { prayer in
                    NavigationLink {
                        PrayerDetailView(prayer: prayer)
                    } label: {
                        PrayerLibraryRow(
                            prayer: prayer,
                            isSaved: savedStore.contains(prayer),
                            onToggleSaved: {
                                savedStore.toggle(prayer)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing) {
                        Button {
                            savedStore.toggle(prayer)
                        } label: {
                            Label(savedStore.contains(prayer) ? "Remove" : "Save", systemImage: savedStore.contains(prayer) ? "bookmark.slash" : "bookmark")
                        }
                        .tint(savedStore.contains(prayer) ? .red : Color.ancientGold)
                    }
                }
            } else {
                categoryPickerSection

                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(Color.ancientGold)

                    Text("No prayers matched that search.")
                        .font(.saintHeading)
                        .foregroundStyle(Color.inkBrown)

                    Text("Try a broader title or switch categories.")
                        .font(.saintBody)
                        .foregroundStyle(Color.inkBrown.opacity(0.72))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle("Prayer Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search prayers")
        .onAppear {
            if selectedCategory == "All" || allCategories.contains(selectedCategory) {
                return
            }
            selectedCategory = "All"
        }
    }

    private var filteredPrayers: [DailyPrayer] {
        prayerService.library.filter { prayer in
            let matchesCategory = selectedCategory == "All" || prayer.category == selectedCategory
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    prayer.title.localizedCaseInsensitiveContains(searchText) ||
                    prayer.summary.localizedCaseInsensitiveContains(searchText) ||
                    prayer.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
            return matchesCategory && matchesSearch
        }
    }

    private var allCategories: [String] {
        ["All"] + prayerService.categories
    }

    private var categoryPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(allCategories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.saintCaption)
                            .foregroundStyle(selectedCategory == category ? Color.parchment : Color.inkBrown)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.ancientGold : Color.ancientGold.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .listRowBackground(Color.clear)
    }
}

struct PrayerDetailView: View {
    let prayer: DailyPrayer
    @State private var savedStore = SavedPrayersStore.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(prayer.title)
                                .font(.saintTitle)
                                .foregroundStyle(Color.inkBrown)

                            Text(prayer.summary)
                                .font(.saintBody)
                                .foregroundStyle(Color.inkBrown.opacity(0.8))
                        }

                        Spacer(minLength: 0)

                        Button {
                            savedStore.toggle(prayer)
                        } label: {
                            Image(systemName: savedStore.contains(prayer) ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(savedStore.contains(prayer) ? Color.ancientGold : Color.inkBrown.opacity(0.75))
                                .frame(width: 36, height: 36)
                                .background(Color.parchment.opacity(0.9), in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.ancientGold.opacity(0.45), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        PrayerDetailPill(label: prayer.category)
                        PrayerDetailPill(label: prayer.occasion)
                    }
                }
                .padding(20)
                .cardStyle()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Prayer")
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

                PrayerLibrarySourceFooter(prayer: prayer)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(Color.parchment.ignoresSafeArea())
        .navigationTitle("Prayer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrayerLibraryRow: View {
    let prayer: DailyPrayer
    let isSaved: Bool
    let onToggleSaved: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.ancientGold.opacity(0.14))
                    .frame(width: 44, height: 44)

                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.ancientGold)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(prayer.title)
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown)
                    .lineLimit(2)

                Text(prayer.summary)
                    .font(.saintCaption)
                    .foregroundStyle(Color.inkBrown.opacity(0.75))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    PrayerDetailPill(label: prayer.category)
                    PrayerDetailPill(label: prayer.occasion)
                }
            }

            Spacer(minLength: 0)

            Button(action: onToggleSaved) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSaved ? Color.ancientGold : Color.inkBrown.opacity(0.65))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSaved ? "Remove prayer from saved" : "Save prayer")
        }
        .padding(16)
        .cardStyle()
    }
}

private struct PrayerDetailPill: View {
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

private struct PrayerLibrarySourceFooter: View {
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
