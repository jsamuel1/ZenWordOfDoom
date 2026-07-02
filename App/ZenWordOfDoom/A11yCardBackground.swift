import SwiftUI

/// Card/backdrop material that respects Reduce Transparency (audit 6.1).
///
/// Normally renders `.ultraThinMaterial`. When the user has Reduce
/// Transparency enabled, materials can render as near-opaque anyway on
/// device, but VoiceOver/contrast tooling and some simulator configurations
/// still show the translucent blend-through — so this swaps to a flat,
/// opaque fill instead of relying on the system's own dampening.
private struct A11yCardBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fillStyle)
        )
    }

    private var fillStyle: AnyShapeStyle {
        reduceTransparency
            ? AnyShapeStyle(Color(.systemBackground).opacity(0.92))
            : AnyShapeStyle(.ultraThinMaterial)
    }
}

extension View {
    /// Card/backdrop that renders `.ultraThinMaterial` normally and an opaque
    /// fill under Reduce Transparency (audit 6.1). Shape via cornerRadius;
    /// pass `.infinity` for a capsule — `RoundedRectangle` clamps the radius
    /// to half the shorter side, so it renders identically to `Capsule()`.
    func a11yCardBackground(cornerRadius: CGFloat) -> some View {
        modifier(A11yCardBackgroundModifier(cornerRadius: cornerRadius))
    }
}
