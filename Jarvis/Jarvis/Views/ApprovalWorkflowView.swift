import SwiftUI

// MARK: - Approval Workflow Section

/// Embeddable approval workflow section for task detail / edit views.
/// Shows approval status, existing steps, and allows adding new steps / approving / rejecting.
struct ApprovalWorkflowSection: View {
    @Binding var task: PlannerTask
    @State private var showAddStep = false
    @State private var newReviewerName = ""
    @State private var newReviewerHandle = ""
    
    private var theme: JarvisTheme {
        JarvisTheme.current(for: ThemeManager.shared.currentTheme.colorScheme ?? .light)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label(L10n.approvalRequestApproval, systemImage: "person.badge.shield.checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                statusBadge(task.approvalStatus)
            }
            
            // Existing steps
            if !task.approvalSteps.isEmpty {
                VStack(spacing: 8) {
                    ForEach(Array(task.approvalSteps.enumerated()), id: \.element.id) { idx, step in
                        approvalStepRow(step: step, index: idx)
                    }
                }
            }
            
            // Quick actions
            if task.approvalStatus == .none {
                Button(action: {
                    task.approvalStatus = .pending
                }) {
                    Label(L10n.approvalRequestApproval, systemImage: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(JarvisTheme.accentBlue))
                }
                .buttonStyle(.plain)
            }
            
            // Add approver
            Button(action: { showAddStep = true }) {
                Label(L10n.approvalAddStep, systemImage: "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(JarvisTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
        .alert(L10n.approvalAddStep, isPresented: $showAddStep) {
            TextField(L10n.approvalReviewer, text: $newReviewerName)
            TextField("@handle", text: $newReviewerHandle)
            Button(L10n.cancel, role: .cancel) {
                newReviewerName = ""
                newReviewerHandle = ""
            }
            Button(L10n.save) {
                let step = ApprovalStep(
                    reviewerName: newReviewerName.trimmingCharacters(in: .whitespaces),
                    reviewerHandle: newReviewerHandle.isEmpty ? nil : newReviewerHandle.trimmingCharacters(in: .whitespaces)
                )
                task.approvalSteps.append(step)
                if task.approvalStatus == .none {
                    task.approvalStatus = .pending
                }
                newReviewerName = ""
                newReviewerHandle = ""
            }
        }
    }
    
    // MARK: - Step Row
    
    private func approvalStepRow(step: ApprovalStep, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: step.status.icon)
                .font(.system(size: 18))
                .foregroundColor(step.status.color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(step.reviewerName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    if let handle = step.reviewerHandle {
                        Text(handle)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                }
                Text(step.status.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(step.status.color)
                if !step.comment.isEmpty {
                    Text(step.comment)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .italic()
                }
                if let decidedDate = step.decidedAt {
                    Text(decidedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textTertiary)
                }
            }
            
            Spacer()
            
            if step.status == .pending {
                HStack(spacing: 8) {
                    Button(action: { approveStep(at: index) }) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { rejectStep(at: index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(step.status.color.opacity(0.08))
        )
    }
    
    // MARK: - Actions
    
    private func approveStep(at index: Int) {
        guard index < task.approvalSteps.count else { return }
        task.approvalSteps[index].status = .approved
        task.approvalSteps[index].decidedAt = Date()
        recalculateOverallStatus()
    }
    
    private func rejectStep(at index: Int) {
        guard index < task.approvalSteps.count else { return }
        task.approvalSteps[index].status = .rejected
        task.approvalSteps[index].decidedAt = Date()
        recalculateOverallStatus()
    }
    
    /// Recalculate overall approval status from individual steps.
    private func recalculateOverallStatus() {
        let statuses = task.approvalSteps.map(\.status)
        if statuses.allSatisfy({ $0 == .approved }) {
            task.approvalStatus = .approved
        } else if statuses.contains(.rejected) {
            task.approvalStatus = .rejected
        } else if statuses.contains(.revisionNeeded) {
            task.approvalStatus = .revisionNeeded
        } else {
            task.approvalStatus = .pending
        }
    }
    
    // MARK: - Status Badge
    
    private func statusBadge(_ status: ApprovalStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 12))
            Text(status.displayName)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(status.color.opacity(0.15))
        )
    }
}
