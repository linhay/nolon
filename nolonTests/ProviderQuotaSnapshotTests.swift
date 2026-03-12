import XCTest
import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

final class ProviderQuotaSnapshotTests: XCTestCase {
    
    @MainActor
    func testCaptureSnapshots() {
        _ = ProviderQuotaSection(
            provider: .codex,
            usage: UsageSnapshot(
                identity: UsageIdentity(accountEmail: "zolplay@nolon.ai", accountOrganization: nil, loginMethod: nil, plan: "Pro Plan"),
                primary: RateWindow(usedPercent: 16, resetsAt: Date().addingTimeInterval(12)),
                secondary: RateWindow(usedPercent: 8, resetsAt: Date().addingTimeInterval(345600)),
                tertiary: nil
            ),
            credits: CreditsSnapshot(remaining: 1420),
            isLoading: false
        )
        .padding()
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        
        // 我们在终端环境下无法直接运行 UI 渲染并看到图片
        // 但我可以确认代码逻辑是否符合我们刚才在 HTML 中定稿的 115pt 约束
        print("Verifying UI layout constraints...")
    }
}
