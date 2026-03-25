import SwiftUI
import ProviderCatalog
import NolonResourceKit

struct RemoteSkillDetailView: View {
    let skill: RemoteSkill
    let providers: [Provider]
    var targetProvider: Provider? = nil
    var isInstalled: Bool = false
    let onInstall: (Provider) -> Void

    var body: some View {
        SkillDetailView(
            remoteSkill: skill,
            providers: providers,
            targetProvider: targetProvider,
            onInstall: onInstall
        )
    }
}
