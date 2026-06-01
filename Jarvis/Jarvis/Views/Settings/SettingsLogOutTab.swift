import SwiftUI

// MARK: - Log Out Tab

struct SettingsLogOutTab: View {
    let theme: JarvisTheme
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(JarvisTheme.accentOrange.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 36))
                    .foregroundColor(JarvisTheme.accentOrange)
            }
            
            Text(L10n.settingsLogOutTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.textPrimary)
            
            Text(L10n.settingsLogOutDesc)
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: { }) {
                Text(L10n.settingsLogOutAction)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(JarvisTheme.accentOrange)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
