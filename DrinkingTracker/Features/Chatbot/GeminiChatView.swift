import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp = Date()

    enum Role { case user, assistant }
}

struct GeminiChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isLoading = false
    @State private var chatStarted = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                            }
                            if isLoading {
                                HStack {
                                    ProgressView().padding(8)
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Input bar
                HStack(spacing: 8) {
                    TextField("Ask about your current state...", text: $input, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .onSubmit { send() }

                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
                .padding()
            }
            .navigationTitle("Chat with Gemini")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            guard !chatStarted else { return }
            chatStarted = true
            let context = "BAC: \(String(format: "%.3f", appState.currentBAC))%, Stage: \(appState.currentStage.label)"
            GeminiService.shared.startChat(context: context)

            // Welcome message
            messages.append(ChatMessage(
                role: .assistant,
                text: "Hi! I'm your harm-reduction assistant. Your current BAC is \(String(format: "%.3f", appState.currentBAC))% (\(appState.currentStage.label)). How can I help you?"
            ))
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        input = ""

        messages.append(ChatMessage(role: .user, text: text))
        isLoading = true

        Task {
            let response = (try? await GeminiService.shared.sendChatMessage(text)) ?? "Sorry, I couldn't respond."
            messages.append(ChatMessage(role: .assistant, text: response))
            isLoading = false
        }
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.text)
                .padding(12)
                .background(message.role == .user ? Color.blue : Color(.secondarySystemBackground))
                .foregroundStyle(message.role == .user ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
