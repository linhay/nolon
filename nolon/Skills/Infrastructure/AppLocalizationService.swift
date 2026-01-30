import Foundation
import ObjectiveC.runtime

enum AppLocalizationService {
    static func setLanguageOverride(_ languageCode: String?) {
        Bundle.nolon_setLanguageOverride(languageCode)
    }
}

// MARK: - Bundle override (runtime)

private enum NolonBundleLanguageOverride {
    static var didSwizzle = false
    static var bundleKey: UInt8 = 0
}

private extension Bundle {
    static func nolon_setLanguageOverride(_ languageCode: String?) {
        nolon_swizzleLocalizationIfNeeded()

        guard
            let languageCode,
            let languageBundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: languageBundlePath)
        else {
            objc_setAssociatedObject(Bundle.main, &NolonBundleLanguageOverride.bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        objc_setAssociatedObject(Bundle.main, &NolonBundleLanguageOverride.bundleKey, languageBundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    static func nolon_swizzleLocalizationIfNeeded() {
        guard !NolonBundleLanguageOverride.didSwizzle else { return }
        NolonBundleLanguageOverride.didSwizzle = true

        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.nolon_localizedString(forKey:value:table:))

        guard
            let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
            let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func nolon_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let overrideBundle = objc_getAssociatedObject(self, &NolonBundleLanguageOverride.bundleKey) as? Bundle {
            return overrideBundle.nolon_localizedString(forKey: key, value: value, table: tableName)
        }

        return nolon_localizedString(forKey: key, value: value, table: tableName)
    }
}

