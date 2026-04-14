import SwiftUI

struct SaintScreenView: View {
    let saint: Saint?
    let error: String?
    let isLoading: Bool
    let dateLabel: String
    @Binding var navigationPath: NavigationPath
    let allowsRefresh: Bool
    let onRefresh: () async -> Void
    let leadingToolbar: AnyView?
    let emptyView: AnyView

    init(
        saint: Saint?,
        error: String?,
        isLoading: Bool,
        dateLabel: String,
        navigationPath: Binding<NavigationPath>,
        allowsRefresh: Bool = true,
        onRefresh: @escaping () async -> Void,
        leadingToolbar: AnyView? = nil,
        emptyView: AnyView = AnyView(Color.parchment.ignoresSafeArea())
    ) {
        self.saint = saint
        self.error = error
        self.isLoading = isLoading
        self.dateLabel = dateLabel
        self._navigationPath = navigationPath
        self.allowsRefresh = allowsRefresh
        self.onRefresh = onRefresh
        self.leadingToolbar = leadingToolbar
        self.emptyView = emptyView
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .navigationTitle("Saint of the Day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.parchment, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    if let leadingToolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            leadingToolbar
                        }
                    }
                }
                .navigationDestination(for: Saint.self) { saint in
                    SaintDetailView(saint: saint)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()
            if isLoading {
                SaintPageSkeleton()
            } else if let error {
                ErrorView(message: error) {
                    Task {
                        await onRefresh()
                    }
                }
            } else if let saint {
                SaintPageView(
                    saint: saint,
                    dateLabel: dateLabel,
                    navigationPath: $navigationPath,
                    onRefresh: allowsRefresh ? onRefresh : {}
                )
            } else {
                emptyView
            }
        }
    }
}
