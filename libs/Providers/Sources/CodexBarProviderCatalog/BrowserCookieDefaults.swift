import Foundation
import SweetCookieKit

public typealias Browser = SweetCookieKit.Browser
public typealias BrowserCookieImportOrder = [Browser]

public enum ProviderBrowserCookieDefaults {
    public static var defaultImportOrder: BrowserCookieImportOrder? {
        #if os(macOS)
        Browser.defaultImportOrder
        #else
        nil
        #endif
    }

    public static var augmentImportOrder: BrowserCookieImportOrder? {
        #if os(macOS)
        // Custom browser order that includes Chrome Beta and other variants
        // to support users running beta/canary versions.
        return [
            .safari,
            .chrome,
            .chromeBeta,
            .chromeCanary,
            .edge,
            .edgeBeta,
            .brave,
            .arc,
            .dia,
            .arcBeta,
            .firefox,
        ]
        #else
        return nil
        #endif
    }
}
