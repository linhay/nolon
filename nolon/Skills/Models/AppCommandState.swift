import SwiftUI

@Observable
final class AppCommandState {
    static let shared = AppCommandState()
    
    var showingSettings = false
    
    private init() {}
}
