import SwiftUI

@main
struct DaybookApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Daybook")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.ground)
        }
    }
}
