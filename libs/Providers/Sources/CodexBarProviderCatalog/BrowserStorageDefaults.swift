import Foundation

public enum ProviderBrowserStorageDefaults {
    public static let factoryChromiumBrowsers: [Browser] = [
        .chrome,
        .chromeBeta,
        .chromeCanary,
        .arc,
        .arcBeta,
        .arcCanary,
        .dia,
        .chatgptAtlas,
        .chromium,
        .helium,
    ]

    public static let factorySafariOriginHosts: [String] = [
        "app.factory.ai",
        "auth.factory.ai",
    ]

    public static let factorySafariOriginHostCandidates: [String] = [
        "app.factory.ai",
        "auth.factory.ai",
        "factory.ai",
    ]

    public static let minimaxChromiumBrowsers: [Browser] = [
        .chrome,
        .chromeBeta,
        .chromeCanary,
        .edge,
        .edgeBeta,
        .edgeCanary,
        .brave,
        .braveBeta,
        .braveNightly,
        .vivaldi,
        .arc,
        .arcBeta,
        .arcCanary,
        .dia,
        .chatgptAtlas,
        .chromium,
        .helium,
    ]

    public static let minimaxWebOrigins: [String] = [
        "https://platform.minimax.io",
        "https://www.minimax.io",
        "https://minimax.io",
        "https://platform.minimaxi.com",
        "https://www.minimaxi.com",
        "https://minimaxi.com",
    ]

    public static let minimaxIndexedDBTargetPrefixes: [String] = [
        "https_platform.minimax.io_",
        "https_www.minimax.io_",
        "https_minimax.io_",
        "https_platform.minimaxi.com_",
        "https_minimaxi.com_",
        "https_www.minimaxi.com_",
    ]
}

