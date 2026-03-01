import SwiftUI

// MARK: - Animation Extensions (inspired by Task-Sync-Pro Flutter animations)

extension View {
    /// Smooth scale animation on appear
    func animateOnAppear(delay: Double = 0) -> some View {
        modifier(AppearAnimationModifier(delay: delay))
    }
    
    /// Bounce effect when tapped
    func bounceOnTap() -> some View {
        modifier(BounceModifier())
    }
    
    /// Shake animation for errors
    func shake(trigger: Bool) -> some View {
        modifier(ShakeModifier(animatableData: trigger ? 1 : 0))
    }
    
    /// Slide in from edge
    func slideIn(from edge: Edge, delay: Double = 0) -> some View {
        modifier(SlideInModifier(edge: edge, delay: delay))
    }
    
    /// Pulse animation
    func pulse(isActive: Bool) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
    
    /// Увеличение при наведении курсора или нажатии (как Dock на Mac). Управляется настройкой.
    func dockMagnificationEffect() -> some View {
        modifier(DockMagnificationModifier())
    }
}

// MARK: - Appear Animation

struct AppearAnimationModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

// MARK: - Dock-style Magnification (только hover, чтобы не перехватывать перетаскивание задач)

struct DockMagnificationModifier: ViewModifier {
    @AppStorage(Config.Storage.dockMagnificationKey) private var enabled = true
    @State private var isHovered = false
    
    private let scale: CGFloat = 1.08
    
    func body(content: Content) -> some View {
        content
            .scaleEffect((enabled && isHovered) ? scale : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Bounce Modifier

struct BounceModifier: ViewModifier {
    @State private var isPressed = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Shake Modifier

struct ShakeModifier: GeometryEffect {
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        let offset = sin(animatableData * .pi * 4) * 8
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

// MARK: - Slide In Modifier

struct SlideInModifier: ViewModifier {
    let edge: Edge
    let delay: Double
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(offset)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
    
    private var offset: CGSize {
        guard !isVisible else { return .zero }
        switch edge {
        case .top: return CGSize(width: 0, height: -50)
        case .bottom: return CGSize(width: 0, height: 50)
        case .leading: return CGSize(width: -50, height: 0)
        case .trailing: return CGSize(width: 50, height: 0)
        }
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                        scale = 1.1
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1
                    }
                }
            }
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 1.1).combined(with: .opacity)
        )
    }
    
    static var cardAppear: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        )
    }
    
    /// Анимация строки задачи: появление новой задачи и уход в «Выполнено»
    static var taskRowTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92)),
            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96))
        )
    }
}

// MARK: - Loading Skeleton

struct SkeletonView: View {
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.2),
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white, .clear],
                                startPoint: UnitPoint(x: shimmerOffset - 0.5, y: 0.5),
                                endPoint: UnitPoint(x: shimmerOffset + 0.5, y: 0.5)
                            )
                        )
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerOffset = 2
                    }
                }
        }
    }
}

// MARK: - Task Card Loading

struct TaskCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView()
                    .frame(height: 16)
                    .frame(maxWidth: 200)
                
                SkeletonView()
                    .frame(height: 12)
                    .frame(maxWidth: 120)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Haptic Feedback

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}

func triggerHaptic(_ type: HapticType) {
    #if os(iOS)
    switch type {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .success:
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    case .warning:
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    case .error:
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    case .selection:
        UISelectionFeedbackGenerator().selectionChanged()
    }
    #endif
}
