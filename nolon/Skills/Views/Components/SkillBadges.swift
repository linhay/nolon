import SwiftUI

struct SkillVersionBadge: View {
    let version: String

    var body: some View {
        Text("v\(version)")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
            .foregroundStyle(.primary)
    }
}

struct SkillInstalledBadge: View {
    var body: some View {
        Text("Installed")
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green)
            .cornerRadius(4)
    }
}

struct SkillOrphanedBadge: View {
    var body: some View {
        Text(NSLocalizedString("skill.orphaned", value: "Needs Migration", comment: "Orphaned skill badge"))
            .font(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .cornerRadius(4)
    }
}

#Preview {
    HStack {
        SkillVersionBadge(version: "1.0.0")
        SkillInstalledBadge()
    }
    .padding()
}
