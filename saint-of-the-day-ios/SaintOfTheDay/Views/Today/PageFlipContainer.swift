import SwiftUI

struct PageFlipContainer: View {
    @Bindable var viewModel: TodayViewModel

    // Drives the entire animation 0.0 → 1.0 each flip
    @State private var flipProgress: Double = 0.0
    @State private var isAnimating: Bool = false

    // Independent navigation paths for each page
    @State private var todayPath = NavigationPath()
    @State private var yesterdayPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // MARK: Yesterday (bottom layer)
            yesterdayLayer
                .rotation3DEffect(
                    .degrees(yesterdayRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    anchorZ: 0,
                    perspective: 0.4
                )
                .opacity(flipProgress >= 0.5 ? 1 : 0)

            // MARK: Today (top layer, flips away)
            todayLayer
                .rotation3DEffect(
                    .degrees(todayRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    anchorZ: 0,
                    perspective: 0.4
                )
                .opacity(flipProgress < 0.5 ? 1 : 0)
                .shadow(
                    color: .black.opacity(midpointShadow),
                    radius: midpointShadow * 20,
                    x: -6, y: 0
                )
                .allowsHitTesting(!viewModel.isShowingYesterday && !isAnimating)

            // MARK: Glass flip button
            FlipButton(
                isShowingYesterday: viewModel.isShowingYesterday,
                isLoading: viewModel.isYesterdayLoading && viewModel.isShowingYesterday
            ) {
                performFlip()
            }
            .padding(.leading, 20)
            .padding(.bottom, 36)
        }
        .background(Color.parchment.ignoresSafeArea())
    }

    // MARK: - Page Layers

    @ViewBuilder
    private var todayLayer: some View {
        NavigationStack(path: $todayPath) {
            ZStack {
                Color.parchment.ignoresSafeArea()
                if viewModel.isTodayLoading {
                    LoadingView()
                } else if let error = viewModel.todayError {
                    ErrorView(message: error) {
                        Task { await viewModel.refreshToday() }
                    }
                } else if let saint = viewModel.todaySaint {
                    SaintPageView(
                        saint: saint,
                        dateLabel: "Today",
                        navigationPath: $todayPath,
                        onRefresh: { await viewModel.refreshToday() }
                    )
                }
            }
            .navigationTitle("Saint of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: Saint.self) { saint in
                SaintDetailView(saint: saint)
            }
        }
    }

    @ViewBuilder
    private var yesterdayLayer: some View {
        NavigationStack(path: $yesterdayPath) {
            ZStack {
                Color.parchment.ignoresSafeArea()
                if viewModel.isYesterdayLoading {
                    LoadingView()
                } else if let error = viewModel.yesterdayError {
                    ErrorView(message: error) {
                        Task { await viewModel.retryYesterday() }
                    }
                } else if let saint = viewModel.yesterdaySaint {
                    SaintPageView(
                        saint: saint,
                        dateLabel: "Yesterday",
                        navigationPath: $yesterdayPath,
                        onRefresh: { await viewModel.retryYesterday() }
                    )
                } else {
                    // Idle — blank parchment until first flip
                    Color.parchment.ignoresSafeArea()
                }
            }
            .navigationTitle("Saint of the Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.parchment, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .navigationDestination(for: Saint.self) { saint in
                SaintDetailView(saint: saint)
            }
        }
    }

    // MARK: - Animation Math

    // Today: rotates 0° → -90° while progress goes 0 → 0.5 (flipping to yesterday)
    //        rotates -90° → 0° while progress goes 0 → 0.5 (flipping back to today)
    private var todayRotation: Double {
        let half = min(flipProgress * 2.0, 1.0)
        return viewModel.isShowingYesterday
            ? -90.0 * half
            : -90.0 * (1.0 - half)
    }

    // Yesterday: rotates 90° → 0° while progress goes 0.5 → 1 (arriving)
    //            rotates 0° → 90° while progress goes 0 → 0.5 (departing)
    private var yesterdayRotation: Double {
        let half = max((flipProgress - 0.5) * 2.0, 0.0)
        return viewModel.isShowingYesterday
            ? 90.0 * (1.0 - half)
            : 90.0 * half
    }

    // Shadow peaks at midpoint (sin curve: 0 → 1 → 0)
    private var midpointShadow: Double {
        sin(flipProgress * .pi) * 0.35
    }

    // MARK: - Flip Action

    private func performFlip() {
        guard !isAnimating else { return }
        isAnimating = true

        // Kick off lazy load immediately so it arrives during or shortly after the animation
        if !viewModel.isShowingYesterday {
            Task { await viewModel.loadYesterdayIfNeeded() }
        }

        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.6)) {
            flipProgress = 1.0
        }

        // After animation: toggle state and reset progress (no animation on reset)
        Task {
            try? await Task.sleep(for: .seconds(0.65))
            viewModel.isShowingYesterday.toggle()
            flipProgress = 0.0
            isAnimating = false
        }
    }
}
