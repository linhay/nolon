import SwiftUI
import NolonUIFoundation

public struct SettingsSheetScaffoldView<Content: View>: View {
    let title: String
    let items: [SettingsSidebarItemData]
    @Binding var selectedID: String
    let onClose: () -> Void
    let content: () -> Content

    public init(
        title: String = NSLocalizedString("settings.title", value: "Settings", comment: "Settings sheet title"),
        items: [SettingsSidebarItemData],
        selectedID: Binding<String>,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.items = items
        self._selectedID = selectedID
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(title: title) {
                onClose()
            }

            SheetDivider()

            HStack(spacing: 0) {
                settingsSidebar

                Divider()
                    .opacity(0.1)

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            content()
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 32)
                    }
                }
                .background(DesignSystem.Colors.Background.surface)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
    }

    private var settingsSidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                GenericSelectionControl(
                    value: item.id,
                    selection: $selectedID
                ) { isSelected in
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                        .foregroundStyle(isSelected ? DesignSystem.Colors.Text.primary : DesignSystem.Colors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.Metrics.cornerRadiusS)
                                .fill(isSelected ? DesignSystem.Colors.primary.opacity(0.08) : Color.clear)
                        )
                }
                .dsLinkButton()
            }
            Spacer()
        }
        .padding(.top, 40)
        .padding(.horizontal, 12)
        .frame(width: 180)
        .background(DesignSystem.Colors.Component.controlFillSubtle.opacity(0.6))
    }
}
