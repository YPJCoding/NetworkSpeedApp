import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var model: NetworkSpeedModel

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.twoLine(
            upload: model.uploadText,
            download: model.downloadText
        ))
        .renderingMode(.template)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("上传 \(model.uploadText)，下载 \(model.downloadText)")
    }
}
