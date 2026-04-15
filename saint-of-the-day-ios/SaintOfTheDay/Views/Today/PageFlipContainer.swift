import SwiftUI
import UIKit

struct PageFlipContainer: View {
    @Bindable var viewModel: TodayViewModel

    // Drives the entire animation 0.0 → 1.0 each flip
    @State private var flipProgress: Double = 0.0
    @State private var isAnimating: Bool = false
    @State private var showMenu: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var pendingDate = Date()

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
                .opacity(yesterdayLayerOpacity)

            // MARK: Today (top layer, flips away)
            todayLayer
                .rotation3DEffect(
                    .degrees(todayRotation),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    anchorZ: 0,
                    perspective: 0.4
                )
                .opacity(todayLayerOpacity)
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
                    isLoading: viewModel.isYesterdayLoading
                ) {
                    performFlip()
                }

                Spacer()

                MenuButton {
                    showMenu = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.parchment.ignoresSafeArea())
        .gesture(swipeGesture)
        .sheet(isPresented: $showMenu) {
            MenuSheet(saint: currentSaint)
        }
        .fullScreenCover(isPresented: $showDatePicker) {
            DatePickerOverlay(
                pendingDate: $pendingDate,
                confirmLabel: "Open Saint",
                onClose: { showDatePicker = false },
                onConfirm: {
                    let selectedDate = pendingDate
                    showDatePicker = false
                    Task { await viewModel.selectDate(selectedDate) }
                }
            )
        }
    }

    // MARK: - Current Saint (for Share)

    private var currentSaint: Saint? {
        viewModel.isShowingYesterday ? viewModel.yesterdaySaint : viewModel.todaySaint
    }

    // MARK: - Page Layers

    @ViewBuilder
    private var todayLayer: some View {
        SaintScreenView(
            saint: viewModel.todaySaint,
            error: viewModel.todayError,
            isLoading: viewModel.isTodayLoading,
            dateLabel: viewModel.todayDateLabel,
            navigationPath: $todayPath,
            onRefresh: { await viewModel.refreshCurrentDate() },
            leadingToolbar: AnyView(calendarButton)
        )
    }

    @ViewBuilder
    private var yesterdayLayer: some View {
        SaintScreenView(
            saint: viewModel.yesterdaySaint,
            error: viewModel.yesterdayError,
            isLoading: viewModel.isYesterdayLoading,
            dateLabel: viewModel.previousDateLabel,
            navigationPath: $yesterdayPath,
            onRefresh: { await viewModel.refreshPreviousDate() },
            leadingToolbar: AnyView(calendarButton)
        )
    }

    // MARK: - Animation Math

    private var isFlipInProgress: Bool {
        isAnimating || flipProgress > 0
    }

    private var todayLayerOpacity: Double {
        if isFlipInProgress {
            return viewModel.isShowingYesterday ? (flipProgress >= 0.5 ? 1 : 0) : (flipProgress < 0.5 ? 1 : 0)
        }
        return viewModel.isShowingYesterday ? 0 : 1
    }

    private var yesterdayLayerOpacity: Double {
        if isFlipInProgress {
            return viewModel.isShowingYesterday ? (flipProgress < 0.5 ? 1 : 0) : (flipProgress >= 0.5 ? 1 : 0)
        }
        return viewModel.isShowingYesterday ? 1 : 0
    }

    private var todayRotation: Double {
        guard isFlipInProgress else { return 0 }
        if viewModel.isShowingYesterday {
            let half = max((flipProgress - 0.5) * 2.0, 0.0)
            return -90.0 * (1.0 - half)
        } else {
            let half = min(flipProgress * 2.0, 1.0)
            return -90.0 * half
        }
    }

    private var yesterdayRotation: Double {
        guard isFlipInProgress else { return 0 }
        if viewModel.isShowingYesterday {
            let half = min(flipProgress * 2.0, 1.0)
            return 90.0 * half
        } else {
            let half = max((flipProgress - 0.5) * 2.0, 0.0)
            return 90.0 * (1.0 - half)
        }
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
                    ? value.translation.width / width      // right drag → back to today
                    : -value.translation.width / width     // left drag → reveal yesterday
                let clamped = max(0, min(0.85, raw))
                flipProgress = clamped

                // Kick off lazy load early when user starts dragging toward yesterday
                if !viewModel.isShowingYesterday && clamped > 0.05 {
                    Task { await viewModel.loadPreviousDateIfNeeded() }
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

        if !viewModel.isShowingYesterday,
           viewModel.yesterdaySaint == nil,
           viewModel.yesterdayError == nil {
            Task {
                await viewModel.loadPreviousDateIfNeeded()
                startFlip(duration: 0.65)
            }
        } else {
            startFlip(duration: 0.65)
        }
    }

    private func startFlip(duration: Double) {
        guard !isAnimating else { return }
        isAnimating = true

        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: max(duration - 0.05, 0.1))) {
            flipProgress = 1.0
        }

        // Haptic at midpoint
        Task {
            try? await Task.sleep(for: .seconds(duration / 2))
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        finishFlip(after: duration)
    }

    private func completeFlip(duration: Double) {
        guard !isAnimating else { return }
        isAnimating = true
        withAnimation(.timingCurve(0.4, 0.0, 0.2, 1.0, duration: duration)) {
            flipProgress = 1.0
        }
        finishFlip(after: duration)
    }

    private func finishFlip(after duration: Double) {
        Task {
            try? await Task.sleep(for: .seconds(duration + 0.05))
            viewModel.isShowingYesterday.toggle()
            flipProgress = 0.0
            isAnimating = false
            dragHapticFired = false
        }
    }

    private var calendarButton: some View {
        Button {
            pendingDate = viewModel.selectedDate
            showDatePicker = true
        } label: {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.inkBrown)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse saints by date")
    }
}
