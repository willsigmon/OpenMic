import SwiftUI

struct WatchConversationView: View {
    @ObservedObject var viewModel: WatchConversationViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if viewModel.messages.isEmpty {
                            Text("Tap Dictate, ask anything.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.isLoading {
                    ProgressView("Thinking…")
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                TextField("Ask OpenMic", text: $viewModel.draft)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.sendDraft()
                    }

                HStack(spacing: 8) {
                    Button {
                        viewModel.dictateAndSend()
                    } label: {
                        Label("Dictate", systemImage: "mic.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)

                    Button {
                        viewModel.sendDraft()
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.isLoading
                            || viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("OpenMic")
            .padding(.horizontal, 2)
        }
    }
}

private struct MessageBubble: View {
    let message: WatchChatMessage

    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var bubbleColor: Color {
        message.role == .user ? .blue : Color.gray.opacity(0.2)
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(message.text)
                .font(.caption2)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bubbleColor)
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: message.role == .user ? .trailing : .leading
                )
        }
    }
}
