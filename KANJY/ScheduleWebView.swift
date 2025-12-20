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
        let configuration = WKWebViewConfiguration()
        
        // WebViewの設定（iOS 14以降の推奨方法）
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // JavaScriptのコンソールログをSwiftのコンソールに出力
        let userContentController = WKUserContentController()
        
        // console.logをインターセプト
        let logScript = WKUserScript(
            source: """
            (function() {
                var originalLog = console.log;
                var originalError = console.error;
                var originalWarn = console.warn;
                
                console.log = function(...args) {
                    window.webkit.messageHandlers.consoleLog.postMessage(args.map(String).join(' '));
                    originalLog.apply(console, args);
                };
                
                console.error = function(...args) {
                    window.webkit.messageHandlers.consoleError.postMessage(args.map(String).join(' '));
                    originalError.apply(console, args);
                };
                
                console.warn = function(...args) {
                    window.webkit.messageHandlers.consoleWarn.postMessage(args.map(String).join(' '));
                    originalWarn.apply(console, args);
                };
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(logScript)
        
        // メッセージハンドラを追加
        userContentController.add(context.coordinator, name: "consoleLog")
        userContentController.add(context.coordinator, name: "consoleError")
        userContentController.add(context.coordinator, name: "consoleWarn")
        
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
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
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "consoleLog":
                print("🌐 [JS Console Log]: \(message.body)")
            case "consoleError":
                print("❌ [JS Console Error]: \(message.body)")
            case "consoleWarn":
                print("⚠️ [JS Console Warn]: \(message.body)")
            default:
                break
            }
        }
        
        // ナビゲーションポリシーを決定（ページ遷移を許可）
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // 同一ドメイン内のナビゲーションを許可
            if let url = navigationAction.request.url {
                print("🔄 [Navigation]: \(url.absoluteString)")
                
                // kanjy-web.netlify.app ドメイン内のナビゲーションを許可
                if url.host == "kanjy-web.netlify.app" || url.host == "localhost" {
                    print("✅ [Navigation]: 許可されました")
                    decisionHandler(.allow)
                } else {
                    // 外部リンクは許可しない（セキュリティのため）
                    print("⚠️ [Navigation]: 外部リンクのため拒否: \(url.host ?? "不明")")
                    decisionHandler(.cancel)
                }
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
            print("📡 [Navigation]: 読み込み開始")
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            
            // 現在のURLをログに出力
            if let currentURL = webView.url {
                print("✅ [Navigation]: 読み込み完了 - \(currentURL.absoluteString)")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            print("❌ [Navigation]: 読み込み失敗 - \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            print("❌ [Navigation]: 暫定的な読み込みに失敗 - \(error.localizedDescription)")
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