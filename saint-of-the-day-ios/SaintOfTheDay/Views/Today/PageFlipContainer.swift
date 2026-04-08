import SwiftUI
import UIKit

struct PageFlipContainer: View {
    @Bindable var viewModel: TodayViewModel

    // Drives the entire animation 0.0 → 1.0 each flip
    @State private var flipProgress: Double = 0.0
    @State private var isAnimating: Bool = false
    @State private var showMenu: Bool = false

    // Swipe gesture state
    @State private var dragHapticFired: Bool = false

    // Independent navigation paths for each page
    @State private var todayPath = NavigationPath()
    @State private var yesterdayPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // MARK: Bottom button row
            HStack {
                FlipButton(
                    isShowingYesterday: viewModel.isShowingYesterday,
                    isLoading: viewModel.isYesterdayLoading && viewModel.isShowingYesterday
                ) {
                    performFlip()
                }

                Spacer()

                MenuButton {
                    showMenu = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(Color.parchment.ignoresSafeArea())
        .gesture(swipeGesture)
        .sheet(isPresented: $showMenu) {
            MenuSheet(saint: currentSaint)
        }
    }

    // MARK: - Current Saint (for Share)

    private var currentSaint: Saint? {
        viewModel.isShowingYesterday ? viewModel.yesterdaySaint : viewModel.todaySaint
    }

    // MARK: - Page Layers

    @ViewBuilder
    private var todayLayer: some View {
        NavigationStack(path: $todayPath) {
            ZStack {
                Color.parchment.ignoresSafeArea()
                if viewModel.isTodayLoading {
                    SaintPageSkeleton()
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
                    SaintPageSkeleton()
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

    private var todayRotation: Double {
        let half = min(flipProgress * 2.0, 1.0)
        return viewModel.isShowingYesterday
            ? -90.0 * half
            : -90.0 * (1.0 - half)
    }

    private var yesterdayRotation: Double {
        let half = max((flipProgress - 0.5) * 2.0, 0.0)
        return viewModel.isShowingYesterday
            ? 90.0 * (1.0 - half)
            : 90.0 * half
    }

    private var midpointShadow: Double {
        sin(flipProgress * .pi) * 0.35
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                guard !isAnimating else { return }
                let width = UIScreen.main.bounds.width
                let raw = viewModel.isShowingYesterday
                    ? value.translation.x / width      // right drag → back to today
                    : -value.translation.x / width     // left drag → reveal yesterday
                let clamped = max(0, min(0.85, raw))
                flipProgress = clamped

                // Kick off lazy load early when user starts dragging toward yesterday
                if !viewModel.isShowingYesterday && clamped > 0.05 {
                    Task { await viewModel.loadYesterdayIfNeeded() }
                }

                // Haptic at midpoint crossing
                if clamped >= 0.5 && !dragHapticFired {
                    dragHapticFired = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } else if clamped < 0.5 {
                    dragHapticFired = false
                }
            }
            .onEnded { _ in
                guard !isAnimating else { return }
                if flipProgress >= 0.3 {
                    completeFlip(duration: 0.35)
                } else {
                    withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                        flipProgress = 0.0
                    }
                    dragHapticFired = false
                }
            }
    }

    // MARK: - Flip Actions

    private func performFlip() {
        guard !isAnimating else { return }

        if !viewModel.isShowingYesterday {
            Task { await viewModel.loadYesterdayIfNeeded() }
        }

        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: 0.6)) {
            flipProgress = 1.0
        }

        // Haptic at midpoint
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        completeFlip(duration: 0.65)
    }

    private func completeFlip(duration: Double) {
        isAnimating = true
        if duration < 0.6 {
            // Came from swipe — animate remainder
            withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: duration)) {
                flipProgress = 1.0
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(duration + 0.05))
            viewModel.isShowingYesterday.toggle()
            flipProgress = 0.0
            isAnimating = false
            dragHapticFired = false
        }
    }
}
