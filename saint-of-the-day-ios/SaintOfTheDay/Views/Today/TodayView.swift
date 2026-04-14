import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()
    @State private var router = AppRouter.shared

    var body: some View {
        PageFlipContainer(viewModel: viewModel)
            .task { await viewModel.loadCurrentDate() }
            .task(id: router.saintDateRequestID) {
                guard let requestedDate = router.requestedSaintDate else { return }
                await viewModel.selectDate(requestedDate)
                router.clearRequestedSaintDate()
            }
            .onAppear { NotificationService.shared.clearBadge() }
    }
}
