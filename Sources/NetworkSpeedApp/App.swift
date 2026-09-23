import SwiftUI

@main
@MainActor
struct NetworkSpeedApplication: App {
    @State private var model = NetworkSpeedModel()

    var body: some Scene {
        MenuBarExtra {
            DetailView(model: model)
                .onAppear {
                    model.loginItemManager.refresh()
                    model.start()
                }
        } label: {
            MenuBarLabel(model: model)
                .task { model.start() }
        }
        .menuBarExtraStyle(.menu)
    }
}
