import SwiftUI

/// Debug utility to render AppIconView to a PNG in the app's Documents directory.
///
/// HOW TO USE:
/// 1. Add AppIconExporterTrigger() anywhere temporarily (e.g. in RootView's .onAppear)
/// 2. Run the app once in Simulator
/// 3. Find AppIcon.png in the app container's Documents directory
/// 4. Drag it into SaintOfTheDay/Assets.xcassets/AppIcon.appiconset/ in Finder
/// 5. Remove AppIconExporterTrigger() from your code
#if DEBUG
struct AppIconExporterTrigger: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { AppIconExporter.export() }
    }
}

enum AppIconExporter {
    @MainActor
    static func export() {
        let iconView = AppIconView().frame(width: 1024, height: 1024)
        let renderer = ImageRenderer(content: iconView)
        renderer.scale = 1.0  // 1.0 = exactly 1024×1024 px

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            print("[AppIconExporter] ⚠️ Failed to render icon")
            return
        }

        // Write to the app's Documents directory.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = documents.appendingPathComponent("AppIcon.png")

        do {
            try pngData.write(to: dest, options: .atomic)
            print("[AppIconExporter] ✅ AppIcon.png written to \(dest.path)")
        } catch {
            print("[AppIconExporter] ⚠️ Write failed: \(error)")
        }
    }
}
#endif
