import SwiftUI

struct MarkdownDocumentView: View {
    let filename: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            if let content = loadMarkdown() {
                VStack(alignment: .leading, spacing: 16) {
                    Text(content)
                        .font(.body)
                        .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("ドキュメントを読み込めませんでした")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func loadMarkdown() -> String? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return content
    }
}

#Preview {
    NavigationStack {
        MarkdownDocumentView(
            filename: "TERMS_OF_SERVICE",
            title: "利用規約"
        )
    }
}
