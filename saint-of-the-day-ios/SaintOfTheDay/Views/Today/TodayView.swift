import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()

    var body: some View {
        PageFlipContainer(viewModel: viewModel)
            .task { await viewModel.loadToday() }
            .onAppear { NotificationService.shared.clearBadge() }
    }
}
