import FeedbackSDK
import SwiftUI
import UniformTypeIdentifiers

struct AttachmentPickerButton: View {
    let title: String
    let onAttachments: ([AttachmentInput]) -> Void

    @State private var isPresentingPicker = false

    var body: some View {
        Button(title) {
            isPresentingPicker = true
        }
        .fileImporter(
            isPresented: $isPresentingPicker,
            allowedContentTypes: [.png, .jpeg, .heic, .webP],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                let attachments = urls.compactMap { url -> AttachmentInput? in
                    guard url.startAccessingSecurityScopedResource() else { return nil }
                    defer { url.stopAccessingSecurityScopedResource() }

                    guard let data = try? Data(contentsOf: url) else { return nil }
                    let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType
                        ?? "application/octet-stream"

                    return AttachmentInput(
                        filename: url.lastPathComponent,
                        data: data,
                        contentType: contentType
                    )
                }

                if !attachments.isEmpty {
                    onAttachments(attachments)
                }
            case .failure:
                break
            }
        }
    }
}

struct SelectedAttachmentsList: View {
    let attachments: [AttachmentInput]
    let onRemove: (Int) -> Void

    var body: some View {
        if attachments.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                    HStack {
                        Text(attachment.filename)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button("Remove") {
                            onRemove(index)
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
}
