import SwiftUI

struct ProviderLogoView: View {
    enum Style {
        case iconOnly
        case vertical
        case horizontal
    }
    
    let name: String
    let logoName: String?
    var style: Style = .iconOnly
    var iconSize: CGFloat? = nil
    
    init(provider: Provider, style: Style = .iconOnly, iconSize: CGFloat? = nil) {
        self.name = provider.displayName
        if let id = provider.templateId,
           let template = ProviderTemplate(rawValue: id) {
            self.logoName = template.logoFile
        } else {
            self.logoName = nil
        }
        self.style = style
        self.iconSize = iconSize
    }
    
    init(name: String, logoName: String?, style: Style = .iconOnly, iconSize: CGFloat? = nil) {
        self.name = name
        self.logoName = logoName
        self.style = style
        self.iconSize = iconSize
    }
    
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
    
    @Environment(\.colorScheme) var colorScheme
    
    @ViewBuilder
    var iconView: some View {
        if let logoName = logoName {
            if NSImage(named: logoName) != nil {
                // SwiftUI Image automatically handles Light/Dark appearances in XCAssets
                Image(logoName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .help(name)
            } else {
                // Fallback to remote Lobe Icons CDN
                let theme = colorScheme == .dark ? "dark" : "light"
                // Using colored priority in remote fallback if possible? 
                // Actually stick to the standard slug as it's more reliable via CDN
                let urlString = "https://unpkg.com/@lobehub/icons-static-png@latest/\(theme)/\(logoName).png"
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            fallbackView
                        case .empty:
                            ProgressView()
                                .controlSize(.small)
                        @unknown default:
                            fallbackView
                        }
                    }
                    .frame(width: iconSize, height: iconSize)
                    .help(name)
                } else {
                    fallbackView
                        .frame(width: iconSize, height: iconSize)
                        .help(name)
                }
            }
        } else {
            fallbackView
                .frame(width: iconSize, height: iconSize)
                .help(name)
        }
    }
    
    var nameView: some View {
        Text(name)
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
        
        return Text(name.prefix(1).uppercased())
            .font(font)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
    }
}
