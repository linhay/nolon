import XCTest
import NolonResourceKit
@testable import nolon

final class ResourceCatalogGridViewDeleteMessageTests: XCTestCase {
    func testBuildDeleteResultMessage_Success_BuildsEnglishMessageWithoutRuntimeFormatting() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 3,
            successCount: 3,
            removedGlobalCache: true,
            failures: []
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "Skills",
            localized: { key, fallback in
                switch key {
                case "resource.delete.result.success":
                    return "%1$@ \"%2$@\" deleted. Removed from %3$ld provider(s)."
                default:
                    return fallback
                }
            },
            preferredLanguages: { ["en"] }
        )

        XCTAssertEqual(message, "Skills \"gemini\" deleted. Removed from 3 provider(s).")
    }

    func testBuildDeleteResultMessage_Success_BuildsChineseMessageFromPreferredLanguage() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 2,
            successCount: 2,
            removedGlobalCache: false,
            failures: []
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "技能",
            localized: { key, fallback in
                switch key {
                case "resource.delete.result.success":
                    return "已删除%1$@“%2$@”。已从 %3$ld 个 Provider 中移除。"
                default:
                    return fallback
                }
            },
            preferredLanguages: { ["zh-Hans"] }
        )

        XCTAssertEqual(message, "已删除技能“gemini”。已从 2 个 Provider 中移除。")
    }

    func testBuildDeleteResultMessage_PartialFailure_ContainsFailureDetails() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 3,
            successCount: 1,
            removedGlobalCache: false,
            failures: [
                .init(targetName: "Provider A", reason: "permission denied"),
                .init(targetName: "Global Cache", reason: "in use")
            ]
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "Skills",
            localized: { key, fallback in
                switch key {
                case "resource.delete.result.partial":
                    return "%1$@ \"%2$@\" deleted with partial failures.\nSuccess: %3$ld/%4$ld\n%5$@"
                default:
                    return fallback
                }
            },
            preferredLanguages: { ["en"] }
        )

        XCTAssertTrue(message.contains("Skills \"gemini\" deleted with partial failures."))
        XCTAssertTrue(message.contains("Success: 1/3"))
        XCTAssertTrue(message.contains("Provider A: permission denied"))
        XCTAssertTrue(message.contains("Global Cache: in use"))
    }

    func testBuildDeleteResultMessage_PartialFailure_BuildsChineseMessageFromPreferredLanguage() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 3,
            successCount: 1,
            removedGlobalCache: false,
            failures: [
                .init(targetName: "Provider A", reason: "permission denied"),
                .init(targetName: "Global Cache", reason: "in use")
            ]
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "技能",
            localized: { key, fallback in
                switch key {
                case "resource.delete.result.partial":
                    return "已删除%1$@“%2$@”，但部分目标失败。\n成功：%3$ld/%4$ld\n%5$@"
                default:
                    return fallback
                }
            },
            preferredLanguages: { ["zh-Hans"] }
        )

        XCTAssertEqual(
            message,
            "已删除技能“gemini”，但部分目标失败。\n成功：1/3\nProvider A: permission denied\nGlobal Cache: in use"
        )
    }

    func testBuildDeleteResultMessage_EmptyLocalizedTemplate_FallsBackToDefaultSuccessMessage() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 1,
            successCount: 1,
            removedGlobalCache: false,
            failures: []
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "Skills",
            localized: { _, _ in "" },
            preferredLanguages: { ["en"] }
        )

        XCTAssertEqual(message, "Skills \"gemini\" deleted. Removed from 1 provider(s).")
    }

    func testBuildDeleteResultMessage_EmptyLocalizedTemplate_FallsBackToDefaultPartialMessage() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 2,
            successCount: 1,
            removedGlobalCache: false,
            failures: [
                .init(targetName: "Provider A", reason: "permission denied")
            ]
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "Skills",
            localized: { _, _ in "" },
            preferredLanguages: { ["en"] }
        )

        XCTAssertTrue(message.contains("Skills \"gemini\" deleted with partial failures."))
        XCTAssertTrue(message.contains("Success: 1/2"))
        XCTAssertTrue(message.contains("Provider A: permission denied"))
    }

    func testBuildDeleteResultMessage_MalformedLocalizedTemplate_FallsBackToDefaultSuccessMessage() {
        let result = ResourceDeleteExecutionResult(
            resourceSlug: "gemini",
            resourceType: .skill,
            attemptedCount: 2,
            successCount: 2,
            removedGlobalCache: false,
            failures: []
        )

        let message = ResourceCatalogGridViewModel.buildDeleteResultMessage(
            resourceSlug: "gemini",
            result: result,
            typeName: "Skills",
            localized: { _, _ in
                "deleted"
            },
            preferredLanguages: { ["en"] }
        )

        XCTAssertEqual(message, "Skills \"gemini\" deleted. Removed from 2 provider(s).")
    }
}
