import SwiftUI
import WebKit

struct ScheduleWebView: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var webUrl: String = ""
    
    private var webUrlOptional: URL? {
        let urlString = webUrl.isEmpty ? viewModel.getWebUrl(for: event) : webUrl
        return URL(string: urlString)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let url = webUrlOptional {
                    WebView(
                        url: url,
                        isLoading: $isLoading
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("URLを読み込み中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        
                        Text("読み込み中...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                }
            }
            .onAppear {
                if webUrl.isEmpty {
                    webUrl = viewModel.getWebUrl(for: event)
                }
            }
            .navigationTitle("スケジュール調整")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // URLを共有
                        let activityVC = UIActivityViewController(
                            activityItems: [webUrl],
                            applicationActivities: nil
                        )
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first {
                            window.rootViewController?.present(activityVC, animated: true)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        // WebViewの設定（iOS 14以降の推奨方法）
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // ユーザーエージェントを設定（モバイル表示のため）
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

#Preview {
    let sampleEvent = ScheduleEvent(
        id: UUID(),
        title: "サンプルイベント",
        description: "テスト用のイベントです",
        candidateDates: [Date()],
        responses: [],
        createdBy: "テストユーザー",
        createdAt: Date()
    )
    
    let viewModel = ScheduleManagementViewModel()
    
    return ScheduleWebView(event: sampleEvent, viewModel: viewModel)
} 