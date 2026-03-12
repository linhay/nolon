import SwiftUI

// MARK: - Animation System

extension DesignSystem {
    struct Animations {
        // MARK: Durations
        static let instant: Double = 0.1
        static let fast: Double = 0.2
        static let normal: Double = 0.3
        static let slow: Double = 0.5

        // MARK: Standard Animations
        static let quick = Animation.easeInOut(duration: fast)
        static let standard = Animation.easeInOut(duration: normal)
        static let smooth = Animation.easeInOut(duration: slow)

        // MARK: Spring Animations
        static let springQuick = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let springStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)
        static let springBouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    }

    struct Transitions {
        static let fade = AnyTransition.opacity
        static let scale = AnyTransition.scale(scale: 0.95).combined(with: .opacity)
        static let slide = AnyTransition.move(edge: .trailing).combined(with: .opacity)
    }
}
