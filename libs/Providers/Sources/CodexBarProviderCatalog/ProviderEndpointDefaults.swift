import Foundation

public enum ProviderServiceEndpoints {
    public enum Factory {
        public static let appBaseURL = URL(string: "https://app.factory.ai")!
        public static let authBaseURL = URL(string: "https://auth.factory.ai")!
        public static let apiBaseURL = URL(string: "https://api.factory.ai")!

        public static let originHeaderValue = "https://app.factory.ai"
        public static let refererHeaderValue = "https://app.factory.ai/"

        public static let cookieDomains: [String] = [
            "factory.ai",
            "app.factory.ai",
            "auth.factory.ai",
        ]

        public static let workosAuthenticateURL = URL(string: "https://api.workos.com/user_management/authenticate")!
        public static let workosClientIDs: [String] = [
            "client_01HXRMBQ9BJ3E7QSTQ9X2PHVB7",
            "client_01HNM792M5G5G1A2THWPXKFMXB",
        ]
    }

    public enum Claude {
        public static let hostBaseURLString = "https://claude.ai"
        public static let apiBaseURLString = "https://claude.ai/api"
    }

    public enum MiniMax {
        public static let baseURLStringGlobal = "https://platform.minimax.io"
        public static let baseURLStringChinaMainland = "https://platform.minimaxi.com"

        public static let codingPlanPath = "user-center/payment/coding-plan"
        public static let codingPlanQuery = "cycle_type=3"
        public static let remainsPath = "v1/api/openplatform/coding_plan/remains"
    }
}

