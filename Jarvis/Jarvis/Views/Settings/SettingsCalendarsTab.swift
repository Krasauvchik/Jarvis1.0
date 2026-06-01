import SwiftUI

// MARK: - Calendars Tab

struct SettingsCalendarsTab: View {
    let theme: JarvisTheme
    @StateObject private var calendarSync = CalendarSyncService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.settingsCalendarAccess)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                
                VStack(spacing: 0) {
                    Button(action: {
                        Task {
                            let granted = await calendarSync.requestAccess()
                            if granted {
                                EventKitService.shared.checkAuthorization()
                                EventKitService.shared.loadCalendars()
                                EventKitService.shared.syncEventsToStore()
                            }
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentBlue)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsSystemCalendar)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(calendarSync.isAuthorizedForCalendar ? L10n.settingsConnected : L10n.settingsTapToConnect)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            if calendarSync.isAuthorizedForCalendar {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(JarvisTheme.accentGreen)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    
                    Divider().foregroundColor(theme.divider).padding(.leading, 48)
                    
                    Toggle(isOn: Binding(
                        get: { calendarSync.syncToCalendarEnabled },
                        set: { calendarSync.setSyncToCalendarEnabled($0) }
                    )) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(JarvisTheme.accentTeal)
                                .frame(width: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.settingsTwoWaySync)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(theme.textPrimary)
                                Text(L10n.settingsTwoWaySyncDesc)
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackground)
                )
            }
        }
    }
}
