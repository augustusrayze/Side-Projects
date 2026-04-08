import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            Color.parchment.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon / decorative cross
                ZStack {
                    Circle()
                        .fill(Color.ancientGold.opacity(0.15))
                        .frame(width: 140, height: 140)
                    Circle()
                        .stroke(Color.ancientGold.opacity(0.4), lineWidth: 2)
                        .frame(width: 140, height: 140)
                    Image(systemName: "cross.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.ancientGold)
                }

                VStack(spacing: 12) {
                    Text("Meet a New Saint")
                        .font(.saintTitle)
                        .foregroundStyle(Color.inkBrown)
                    Text("Every Day")
                        .font(.system(size: 32, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(Color.ancientGold)
                }

                Text("Discover the lives, miracles, and writings of the Catholic saints — one each morning.")
                    .font(.saintBody)
                    .foregroundStyle(Color.inkBrown.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        isRequesting = true
                        Task {
                            _ = await NotificationService.shared.requestPermissionIfNeeded()
                            await NotificationService.shared.scheduleDailyNotification()
                            isRequesting = false
                            hasSeenOnboarding = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isRequesting {
                                ProgressView().tint(Color.parchment)
                            } else {
                                Image(systemName: "bell.fill")
                            }
                            Text("Allow Notifications")
                                .font(.saintBody)
                        }
                        .foregroundStyle(Color.parchment)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.ancientGold)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isRequesting)
                    .padding(.horizontal, 24)

                    Button {
                        hasSeenOnboarding = true
                    } label: {
                        Text("Maybe Later")
                            .font(.saintCaption)
                            .foregroundStyle(Color.inkBrown.opacity(0.5))
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }
}
