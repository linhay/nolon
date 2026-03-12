//
//  ContentView.swift
//  nolon
//
//  Created by linhey on 1/20/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
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
    }
}

#Preview {
    ContentView()
}
