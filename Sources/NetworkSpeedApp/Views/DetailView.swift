import AppKit
import SwiftUI

struct DetailView: View {
    @Binding private var refreshInterval: Double
    @ObservedObject private var loginItemManager: LoginItemManager
    private let onQuit: () -> Void

    init(model: NetworkSpeedModel) {
        _refreshInterval = Binding(
            get: { model.refreshInterval },
            set: { model.refreshInterval = $0 }
        )
        loginItemManager = model.loginItemManager
        onQuit = {
            model.stop()
            NSApplication.shared.terminate(nil)
        }
    }

    var body: some View {
        Picker("刷新频率", selection: $refreshInterval) {
            ForEach(NetworkSpeedModel.allowedIntervals, id: \.self) { interval in
                Text(interval == 0.5 ? "0.5 秒" : "\(Int(interval)) 秒").tag(interval)
            }
        }

        Toggle("登录时启动", isOn: Binding(
            get: { loginItemManager.isEnabled },
            set: { loginItemManager.setEnabled($0) }
        ))

        if let error = loginItemManager.errorMessage {
            Button(error) {}
                .disabled(true)
        }

        Divider()

        Link("GitHub 仓库", destination: URL(string: "https://github.com/YPJCoding/NetworkSpeedApp")!)

        Button("退出", action: onQuit)
            .keyboardShortcut("q")
    }
}
