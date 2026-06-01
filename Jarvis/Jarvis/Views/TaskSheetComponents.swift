import SwiftUI
import UniformTypeIdentifiers

// MARK: - Shared Task Sheet Components
// Extracted from TaskSheets.swift to eliminate duplication between AddTaskSheet and EditTaskSheet.
// Both sheets had identical attachment handling, file import, and attachment UI code.

// MARK: - Attachment Manager (shared logic)

class AttachmentManager {
    static func handleFileImport(result: Result<URL, Error>, attachments: inout [TaskAttachment]) {
        switch result {
        case .failure(let error):
            Logger.shared.error("File import failed: \(error.localizedDescription)")
        case .success(let url):
            addAttachment(from: url, attachments: &attachments)
        }
    }
    
    static func addAttachment(from url: URL, attachments: inout [TaskAttachment]) {
        let fileManager = FileManager.default
        let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let baseURL = docsURL else { return }
        
        let attachmentsDir = baseURL.appendingPathComponent("TaskAttachments", isDirectory: true)
        if !fileManager.fileExists(atPath: attachmentsDir.path) {
            try? fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        }
        
        let destinationURL = attachmentsDir.appendingPathComponent("\(UUID().uuidString)_\(url.lastPathComponent)")
        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: url, to: destinationURL)
            } else {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try? fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: url, to: destinationURL)
            }
        } catch {
            Logger.shared.error("Failed to copy attachment: \(error.localizedDescription)")
        }
        
        let resourceValues = try? destinationURL.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey])
        let isImage = resourceValues?.contentType?.conforms(to: .image) ?? false
        let type: TaskAttachment.AttachmentType = isImage ? .image : .file
        let size = resourceValues?.fileSize.map { Int64($0) }
        
        let attachment = TaskAttachment(
            type: type,
            fileName: url.lastPathComponent,
            filePath: destinationURL.path,
            fileSize: size
        )
        attachments.append(attachment)
    }
}

// MARK: - Attachments Section View (shared UI)

struct AttachmentsSection: View {
    let theme: JarvisTheme
    @Binding var attachments: [TaskAttachment]
    @Binding var showFileImporter: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.attachmentsTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Spacer()
                Button {
                    showFileImporter = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(JarvisTheme.accent)
                }
                .buttonStyle(.plain)
                .bounceOnTap()
            }
            
            if attachments.isEmpty {
                Text(L10n.noAttachments)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textTertiary)
            } else {
                ForEach(attachments, id: \.id) { attachment in
                    HStack(spacing: 8) {
                        Image(systemName: attachment.type == .image ? "photo" : "doc")
                            .font(.system(size: 14))
                            .foregroundColor(JarvisTheme.accent)
                        Text(attachment.fileName)
                            .font(.system(size: 13))
                            .foregroundColor(theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button {
                            attachments.removeAll { $0.id == attachment.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(theme.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
        .padding(.horizontal, 16)
    }
}
