import SwiftUI

// MARK: - Month Calendar Popup
// Extracted from StructuredMainView to reduce God View size.
// Self-contained monthly calendar overlay shown on the Today tab.

struct MonthCalendarPopup: View {
    let theme: JarvisTheme
    @Binding var selectedDate: Date
    @Binding var showMonthCalendar: Bool
    @ObservedObject var store: PlannerStore
    
    var body: some View {
        let cal = Calendar.current
        let month = cal.component(.month, from: selectedDate)
        let year = cal.component(.year, from: selectedDate)
        let firstOfMonth = cal.date(from: DateComponents(year: year, month: month, day: 1)) ?? selectedDate
        let daysInMonth = cal.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
        let firstWeekday = (cal.component(.weekday, from: firstOfMonth) + 5) % 7 // Mon=0
        let weekDays = Calendar.current.shortWeekdaySymbols.rotatedMondayFirst
        
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("\(selectedDate.formatted(.dateTime.month(.wide)))")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Text(selectedDate.formatted(.dateTime.year()))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(JarvisTheme.accent)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(JarvisTheme.accent)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { moveMonth(by: -1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { moveMonth(by: 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { withAnimation(.spring(response: 0.3)) { showMonthCalendar = false } }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(theme.cardBackground))
                }
                .buttonStyle(.plain)
            }
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days grid
            let totalCells = firstWeekday + daysInMonth
            let rows = (totalCells + 6) / 7
            
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let dayIndex = row * 7 + col - firstWeekday + 1
                        if dayIndex >= 1 && dayIndex <= daysInMonth {
                            let dayDate = cal.date(from: DateComponents(year: year, month: month, day: dayIndex)) ?? selectedDate
                            let isSelected = cal.isDate(dayDate, inSameDayAs: selectedDate)
                            let isToday = cal.isDateInToday(dayDate)
                            let taskCount = store.tasksForDay(dayDate).filter { !$0.isInbox && !$0.isCompleted }.count
                            
                            Button(action: {
                                selectedDate = dayDate
                                withAnimation(.spring(response: 0.3)) { showMonthCalendar = false }
                            }) {
                                VStack(spacing: 2) {
                                    Text("\(dayIndex)")
                                        .font(.system(size: 16, weight: isSelected || isToday ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : (isToday ? JarvisTheme.accent : theme.textPrimary))
                                        .frame(width: 36, height: 36)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? JarvisTheme.accent : Color.clear)
                                        )
                                    
                                    // Task dots
                                    HStack(spacing: 2) {
                                        ForEach(0..<Swift.min(taskCount, 3), id: \.self) { _ in
                                            Circle()
                                                .fill(isSelected ? JarvisTheme.accent : JarvisTheme.accent.opacity(0.6))
                                                .frame(width: 4, height: 4)
                                        }
                                    }
                                    .frame(height: 4)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 42)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(theme.background)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
        )
        .padding(.horizontal, 8)
    }
    
    private func moveMonth(by offset: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: offset, to: selectedDate) {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
}
