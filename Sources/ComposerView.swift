import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ComposerView: View {
    @Binding var text: String
    @Binding var draftAttachments: [URL]
    let isSending: Bool
    let onSubmit: () -> Void
    @State private var isImportingAttachment = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !draftAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draftAttachments, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                if let nsImage = NSImage(contentsOf: url) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
                                } else {
                                    RoundedRectangle(cornerRadius: AppTheme.radius)
                                        .fill(AppTheme.surfaceSecondary)
                                        .frame(width: 56, height: 56)
                                        .overlay(Text(url.pathExtension.uppercased()).font(.caption))
                                }
                                
                                Button {
                                    draftAttachments.removeAll { $0 == url }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .black)
                                        .background(Circle().fill(.white))
                                }
                                .buttonStyle(.plain)
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 64)
            }
            
            ZStack(alignment: .topLeading) {
                GrowingTextView(text: $text, onSubmit: onSubmit)
                    .frame(minHeight: 74, maxHeight: 116)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Message AI Chat...")
                        .font(AppTheme.uiFont(16, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 12)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 12) {
                Button {
                    isImportingAttachment = true
                } label: {
                    ComposerAccessoryButton(icon: "paperclip")
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onSubmit) {
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(AppTheme.uiFont(16, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.navy700, AppTheme.blue500],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draftAttachments.isEmpty) || isSending)
            }
        }
        .padding(16)
        .background(AppTheme.surfacePrimary)
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                .strokeBorder(AppTheme.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 3)
        .fileImporter(
            isPresented: $isImportingAttachment,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: true
        ) { result in
            if let urls = try? result.get() {
                for url in urls {
                    let accessed = url.startAccessingSecurityScopedResource()
                    if accessed {
                        draftAttachments.append(url)
                    }
                }
            }
        }
    }
}

struct ComposerAccessoryButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(AppTheme.uiFont(15, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 42, height: 42)
            .background(AppTheme.surfaceSecondary)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius, style: .continuous))
    }
}

struct GrowingTextView: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = SubmitAwareTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.font = AppTheme.uiNSFont(16, weight: .regular)
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.submitHandler = onSubmit
        textView.textContainerInset = NSSize(width: 10, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 60)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.string = text

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitAwareTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = AppTheme.uiNSFont(16, weight: .regular)
        textView.textColor = NSColor(AppTheme.textPrimary)
        textView.insertionPointColor = NSColor(AppTheme.textPrimary)
        textView.submitHandler = onSubmit
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        let onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

final class SubmitAwareTextView: NSTextView {
    var submitHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && !event.modifierFlags.contains(.shift) {
            submitHandler?()
        } else {
            super.keyDown(with: event)
        }
    }
}
