import Testing
@testable import ProviderUsage

@Suite("Codex Usage Descriptor")
struct CodexUsageDescriptorTests {
    @Test("Formats status reset descriptions into localized labels")
    func formatStatusResetDescription() {
        #expect(CodexUsageDescriptor.formatStatusResetDescription("in 4h 51m") == "Resets in 4h 51m")
        #expect(CodexUsageDescriptor.formatStatusResetDescription("at 11:00 AM") == "Resets 11:00 AM")
        #expect(CodexUsageDescriptor.formatStatusResetDescription("soon") == "Resets soon")
    }
}
