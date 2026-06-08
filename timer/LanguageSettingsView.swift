import SwiftUI

struct LanguageSettingsView: View {
    @State private var selectedLanguage = "en"

    private let languages: [(id: String, name: String)] = [
        ("en", "English"),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(languages, id: \.id) { language in
                    Button {
                        selectedLanguage = language.id
                    } label: {
                        HStack {
                            Text(language.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLanguage == language.id {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            } footer: {
                Text("More languages will be added in a future update.")
            }
        }
        .navigationTitle("Language")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
    }
}
