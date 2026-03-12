import SwiftUI
import NolonResourceKit

struct SkillAboutSection: View {
    let description: String
    let metadataRows: [SkillDetailMetadataRow]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About".uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                .tracking(0.8)
            
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !metadataRows.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(metadataRows) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.label.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                                .tracking(0.6)

                            Text(row.value)
                                .font(.system(size: 11))
                                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
    }
}
