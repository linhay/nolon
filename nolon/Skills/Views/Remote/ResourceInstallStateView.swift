import SwiftUI
import NolonUI

struct ResourceInstallStateView: View {
    let isInstalled: Bool
    let isInstalling: Bool
    let errorMessage: String?
    let onInstall: () -> Void
    let onRetry: () -> Void

    var body: some View {
        NolonUI.ResourceInstallStateView(
            isInstalled: isInstalled,
            isInstalling: isInstalling,
            errorMessage: errorMessage,
            onInstall: onInstall,
            onRetry: onRetry
        )
    }
}
