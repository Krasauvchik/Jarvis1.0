#if !os(watchOS)
import SwiftUI

/// Анимированный эквалайзер звуковых волн — показывает уровень аудиосигнала в реальном времени.
/// Пользователь видит, слышит ли его микрофон.
struct AudioWaveformView: View {
    let levels: [CGFloat]
    let barCount: Int
    let activeColor: Color
    let isActive: Bool
    
    init(
        levels: [CGFloat],
        barCount: Int = 20,
        activeColor: Color = .orange,
        isActive: Bool = true
    ) {
        self.levels = levels
        self.barCount = barCount
        self.activeColor = activeColor
        self.isActive = isActive
    }
    
    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveBar(
                    level: barLevel(for: index),
                    activeColor: activeColor,
                    isActive: isActive,
                    index: index
                )
            }
        }
    }
    
    private func barLevel(for index: Int) -> CGFloat {
        guard index < levels.count else { return 0.05 }
        let level = levels[index]
        // Minimum height so bars are always visible
        return max(level, 0.05)
    }
}

/// Одна полоска эквалайзера с анимацией
private struct WaveBar: View {
    let level: CGFloat
    let activeColor: Color
    let isActive: Bool
    let index: Int
    
    @State private var animatedLevel: CGFloat = 0.05
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(barColor)
            .frame(width: 3, height: max(3, animatedLevel * 32))
            .onChange(of: level) { _, newValue in
                withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.6)) {
                    animatedLevel = newValue
                }
            }
            .onAppear {
                if isActive {
                    // Start with a subtle idle animation
                    withAnimation(
                        .easeInOut(duration: Double.random(in: 0.4...0.8))
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05)
                    ) {
                        animatedLevel = 0.1
                    }
                }
            }
    }
    
    private var barColor: Color {
        if !isActive { return activeColor.opacity(0.3) }
        // Color intensity based on level
        let intensity = max(0.4, min(1.0, Double(level) * 2 + 0.4))
        return activeColor.opacity(intensity)
    }
}

/// Компактная версия для вставки в input bar
struct CompactWaveformView: View {
    let levels: [CGFloat]
    let isActive: Bool
    let transcript: String
    let onStop: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: colorScheme)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Waveform
            AudioWaveformView(
                levels: levels,
                barCount: 16,
                activeColor: JarvisTheme.accentOrange,
                isActive: isActive
            )
            .frame(height: 32)
            
            // Live transcript
            if !transcript.isEmpty {
                Text(transcript)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.head)
            } else {
                Text(L10n.speakNow)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
                    .italic()
            }
            
            Spacer()
            
            // Stop button
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(JarvisTheme.accentOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                .fill(theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: JarvisTheme.Dimensions.cornerRadius)
                        .stroke(JarvisTheme.accentOrange.opacity(0.5), lineWidth: 2)
                )
        )
    }
}

#if DEBUG
#Preview("Audio Waveform") {
    VStack(spacing: 20) {
        AudioWaveformView(
            levels: (0..<20).map { _ in CGFloat.random(in: 0...1) },
            activeColor: .orange,
            isActive: true
        )
        .frame(height: 40)
        .padding()
        
        CompactWaveformView(
            levels: (0..<20).map { _ in CGFloat.random(in: 0...0.8) },
            isActive: true,
            transcript: "Привет, создай задачу...",
            onStop: {}
        )
        .padding()
    }
}
#endif
#endif
