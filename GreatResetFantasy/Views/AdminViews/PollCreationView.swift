// import Inject
import SwiftUI
import Supabase

struct PollCreationView: View {
//    @ObserveInjection var inject

    @Environment(\.dismiss) private var dismiss
    @Environment(SupabaseSessionManager.self) private var supabaseSession

    @State private var question: String = ""
    @State private var options: [String] = Array(repeating: "", count: 3)
    @State private var saving = false
    @State private var errorMessage: String?

    private var pollService: PollService { PollService(client: supabaseSession.client) }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                Section("Question") {
                    TextField("Poll question", text: $question)
                }

                Section("Options") {
                    ForEach(options.indices, id: \.self) { index in
                        TextField("Option \(index + 1)", text: $options[index])
                    }
                    .onDelete { indexSet in
                        guard options.count > 2 else { return }
                        options.remove(atOffsets: indexSet)
                    }

                    Button {
                        options.append("")
                    } label: {
                        Label("Add option", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("New Poll")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await savePoll() }
                    }
                    .disabled(saving)
                }
            }
        }
//        .enableInjection()
    }

    private func savePoll() async {
        let cleanedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOptions = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedQuestion.isEmpty, !cleanedOptions.isEmpty else { return }
        guard let ownerId = supabaseSession.user?.id else { return }

        saving = true
        errorMessage = nil
        defer { saving = false }
        do {
            _ = try await pollService.createPoll(
                question: cleanedQuestion,
                optionTexts: cleanedOptions,
                ownerId: ownerId
            )
            dismiss()
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}

#Preview {
    PollCreationView()
        .environment(SupabaseSessionManager())
}
