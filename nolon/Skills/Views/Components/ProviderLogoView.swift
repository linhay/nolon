import SwiftUI

struct ProviderLogoView: View {
    enum Style {
        case iconOnly
        case vertical
        case horizontal
    }
    
    let provider: Provider
    var style: Style = .iconOnly
    var iconSize: CGFloat? = nil
    
    var body: some View {
        switch style {
        case .iconOnly:
            iconView
        case .vertical:
            VStack(spacing: 4) {
                iconView
                nameView
            }
        case .horizontal:
            HStack(spacing: 8) {
                iconView
                nameView
            }
        }
    }
    
    @ViewBuilder
    var iconView: some View {
        if let logoName = lobeIconName {
            Image(logoName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .help(provider.displayName)
        } else {
            fallbackView
                .frame(width: iconSize, height: iconSize)
                .help(provider.displayName)
        }
    }
    
    var nameView: some View {
        Text(provider.displayName)
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(.primary)
    }
    
    var fallbackView: some View {
        let font: Font = {
            if let size = iconSize {
                return .system(size: size * 0.6, design: .rounded)
            } else {
                return .system(.title2, design: .rounded)
            }
        }()
        
        return Text(provider.pathURL.lastPathComponent.prefix(1).uppercased())
            .font(font)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
    }
    
    var lobeIconName: String? {
        if let id = provider.templateId,
           let template = ProviderTemplate(rawValue: id) {
            return template.logoFile
        }
        return nil
    }
}
