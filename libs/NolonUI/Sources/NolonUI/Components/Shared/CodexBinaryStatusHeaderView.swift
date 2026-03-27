import SwiftUI
import NolonUIFoundation

public struct CodexBinaryStatusHeaderView: View {
    public let data: CodexBinaryStatusHeaderData

    public init(data: CodexBinaryStatusHeaderData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(data.hasUpdateAvailable ? DesignSystem.Colors.Status.warning : DesignSystem.Colors.Status.success)
                    .frame(width: 8, height: 8)
                Text(data.statusText)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Spacer(minLength: 0)
                Text(data.currentCLITitle)
                    .font(.callout)
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)
                Text(data.currentCLIVersion)
                    .font(.callout.monospaced())
                    .foregroundStyle(DesignSystem.Colors.Text.primary)
            }

            if data.isSyncingRemoteVersions || data.remoteVersionSyncFailed {
                HStack(spacing: 8) {
                    if data.isSyncingRemoteVersions {
                        ProgressView()
                            .controlSize(.small)
                        Text(data.syncingText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    } else if data.remoteVersionSyncFailed {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DesignSystem.Colors.Status.warning)
                        Text(data.failedText)
                            .font(.footnote)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
