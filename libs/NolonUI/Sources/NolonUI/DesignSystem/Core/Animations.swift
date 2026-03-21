import SwiftUI

extension DesignSystem {
    public struct Animations {
        public static let instant: Double = 0.1
        public static let fast: Double = 0.2
        public static let normal: Double = 0.3
        public static let slow: Double = 0.5

        public static let quick = Animation.easeInOut(duration: fast)
        public static let standard = Animation.easeInOut(duration: normal)
        public static let smooth = Animation.easeInOut(duration: slow)

        public static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.7)
        public static let springStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)
        public static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    }

    @MainActor
    public struct Transitions {
        public static let fade = AnyTransition.opacity
        public static let scale = AnyTransition.scale(scale: 0.95).combined(with: .opacity)
        public static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity)
    }
}
