import SwiftUI
import UIKit

/// Colours are sampled from the exported Figma screenshots. Replace with exact hex values from Figma if they differ.
enum Theme {
    static let background = Color(red: 0.992, green: 0.978, blue: 0.953)
    static let card = Color(red: 1.0, green: 0.992, blue: 0.972)
    static let cardStroke = Color(red: 0.929, green: 0.890, blue: 0.808)
    static let maroon = Color(red: 0.478, green: 0.153, blue: 0.188)
    static let sand = Color(red: 0.929, green: 0.867, blue: 0.718)
    static let sandSoft = Color(red: 0.969, green: 0.929, blue: 0.839)
    static let sandDeep = Color(red: 0.878, green: 0.776, blue: 0.545)
    static let gold = Color(red: 0.788, green: 0.639, blue: 0.341)
    static let ink = Color(red: 0.165, green: 0.106, blue: 0.098)
    static let muted = Color(red: 0.447, green: 0.357, blue: 0.318)
    static let success = Color(red: 0.200, green: 0.502, blue: 0.298)
    static let successSoft = Color(red: 0.882, green: 0.941, blue: 0.867)
    static let warning = Color(red: 0.757, green: 0.455, blue: 0.106)
    static let warningSoft = Color(red: 0.988, green: 0.929, blue: 0.827)
    static let danger = Color(red: 0.718, green: 0.176, blue: 0.176)
    static let dangerSoft = Color(red: 0.980, green: 0.886, blue: 0.878)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
    static let screenPadding: CGFloat = 20
}

extension Font {
    /// Serif (New York) for the brand / onboarding titles, as in the Figma.
    static let brandTitle = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let screenTitle = Font.system(.title, design: .default, weight: .bold)
}

// MARK: Button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonLabel(configuration: configuration)
    }
}

private struct PrimaryButtonLabel: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.maroon.opacity(isEnabled ? 1 : 0.35),
                        in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.maroon)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.sand, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).stroke(Theme.gold.opacity(0.6), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: Surfaces

extension View {
    func cardStyle(fill: Color = Theme.card, radius: CGFloat = Theme.cardRadius) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
            .shadow(color: Theme.maroon.opacity(0.04), radius: 6, y: 2)
    }

    /// Cream background, inline title area, custom back chevron (swipe-back still works).
    func swarScreen() -> some View {
        self
            .background(Theme.background.ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { BackButton() } }
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left").font(.body.weight(.semibold)).foregroundStyle(Theme.maroon)
        }
        .accessibilityLabel("Back")
    }
}

// Keeps the interactive swipe-back gesture when the system back button is hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: Small reusable pieces

struct ScreenHeader: View {
    let title: String
    var subtitle: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.screenTitle).foregroundStyle(Theme.maroon)
            if let subtitle { Text(subtitle).font(.footnote).foregroundStyle(Theme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct IconTile: View {
    let symbol: String
    var size: CGFloat = 40
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(Theme.maroon)
            .frame(width: size, height: size)
            .background(Theme.sand, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct CircleIcon: View {
    let symbol: String
    var filled = false
    var size: CGFloat = 30
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(filled ? Color.white : Theme.maroon)
            .frame(width: size, height: size)
            .background(Circle().fill(filled ? Theme.maroon : Color.clear))
            .overlay(Circle().stroke(Theme.maroon.opacity(filled ? 0 : 0.7), lineWidth: 1))
    }
}

struct StatusPill: View {
    let feedback: PitchFeedback
    var body: some View {
        Label(feedback.title, systemImage: feedback.symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(bg, in: Capsule())
            .contentTransition(.symbolEffect(.replace))
            .animation(.snappy, value: feedback.title)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(feedback.title)
    }
    private var fg: Color {
        switch feedback.tone {
        case .neutral: return Theme.muted
        case .good: return Theme.success
        case .caution: return Theme.warning
        case .off: return Theme.danger
        }
    }
    private var bg: Color {
        switch feedback.tone {
        case .neutral: return Theme.sandSoft
        case .good: return Theme.successSoft
        case .caution: return Theme.warningSoft
        case .off: return Theme.dangerSoft
        }
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 44
    var body: some View {
        Group {
            if UIImage(named: "avatar") != nil {
                Image("avatar").resizable().scaledToFill()
            } else {
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.maroon)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.sand)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.gold.opacity(0.7), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Uses an exported Figma illustration if present in Assets, otherwise a soft placeholder.
struct IllustrationImage: View {
    let name: String
    var body: some View {
        if UIImage(named: name) != nil {
            Image(name).resizable().scaledToFill()
        } else {
            LinearGradient(colors: [Theme.sandSoft, Theme.background], startPoint: .top, endPoint: .bottom)
                .overlay(Image(systemName: "music.quarternote.3").font(.system(size: 64)).foregroundStyle(Theme.gold.opacity(0.45)))
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
