//
//  ContentView.swift
//  nolon
//
//  Created by linhey on 1/20/26.
//

import SwiftUI
import NolonUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var debugMarkerToastCenter = DebugMarkerToastCenter.shared
    
    var body: some View {
        Group {
            if UITestSupport.isRunningUnitTests {
                Color.clear
            } else if hasCompletedOnboarding || UITestSupport.shouldSkipOnboarding {
                MainSplitView()
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .textSelection(.enabled)
        .overlay(alignment: .bottom) {
            if debugMarkerToastCenter.isVisible {
                NolonUI.ToastView(
                    config: .init(
                        text: debugMarkerToastCenter.message,
                        systemImage: "checkmark",
                        style: .success
                    )
                )
                .padding(.bottom, 20)
            }
        }
        .animation(.easeOut(duration: 0.2), value: debugMarkerToastCenter.isVisible)
    }
}

#Preview {
    ContentView()
}
