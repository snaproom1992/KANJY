import SwiftUI
import WebKit

struct ScheduleWebView: View {
    let event: ScheduleEvent
    @ObservedObject var viewModel: ScheduleManagementViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var webUrl: String = ""
    @State private var currentUrl: URL? = nil // 現在表示中のURL
    @State private var shouldGoBack = false // WebViewの戻るフラグ
    
    private var webUrlOptional: URL? {
        // currentUrlが設定されていればそれを使用、なければ初期URLを使用
        if let url = currentUrl {
            return url
        }
        let urlString = webUrl.isEmpty ? viewModel.getWebUrl(for: event) : webUrl
        return URL(string: urlString)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let url = webUrlOptional {
                    WebView(
                        url: url,
                        isLoading: $isLoading,
                        currentUrl: $currentUrl,
                        shouldGoBack: $shouldGoBack,
                        onGoBack: {
                            dismiss()
                        },
                        onGoBackProcessed: {
                            // フラグをリセット
                            shouldGoBack = false
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("URLを読み込み中...")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondary)
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
                            .foregroundColor(DesignSystem.Colors.secondary)
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
                        // WebViewの履歴がある場合は、WebViewを戻す
                        // ない場合は、親ビューを閉じる
                        shouldGoBack = true
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
    @Binding var currentUrl: URL? // 現在のURLを親に通知するためのBinding
    @Binding var shouldGoBack: Bool // 戻るボタンが押された時のフラグ
    var onGoBack: (() -> Void)? // 戻るボタンが押された時のコールバック
    var onGoBackProcessed: (() -> Void)? // 戻る処理が完了した時のコールバック（フラグリセット用）
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // WebViewの設定（iOS 14以降の推奨方法）
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        // JavaScript主導のナビゲーションを許可
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // メディア再生設定
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
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
        userContentController.add(context.coordinator, name: "navigateToUrl") // ページ遷移用
        
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView // WebViewの参照をCoordinatorに設定
        
        // ユーザーエージェントを設定（モバイル表示のため）
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        
        // バックフォワードナビゲーションを有効化
        webView.allowsBackForwardNavigationGestures = true
        
        // リンクプレビュー機能を有効化
        webView.allowsLinkPreview = false // プレビューを無効にして即座に遷移
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 初回読み込みのみ実行（WebViewがまだ何も読み込んでいない場合）
        // その後のナビゲーションは全てdecidePolicyForで処理される
        // updateUIViewでの強制再読み込みはJavaScript経由のナビゲーションを妨げるため行わない
        if uiView.url == nil {
            var request = URLRequest(url: url)
            // キャッシュポリシーを設定（ローカルキャッシュのみ無視）
            request.cachePolicy = .reloadIgnoringLocalCacheData
            print("🔄 [WebView]: 初回読み込みを実行します")
            print("   - URL: \(url.absoluteString)")
            print("   - キャッシュポリシー: reloadIgnoringLocalCacheData")
            uiView.load(request)
        }
        
        // 戻るボタンが押された場合
        if shouldGoBack {
            context.coordinator.goBack()
            // フラグをリセット（親ビューで行う）
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView
        weak var webView: WKWebView? // WebViewの参照を保持
        var isGoingBack = false // 戻る処理中フラグ（重複実行を防ぐ）
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func goBack() {
            // 既に処理中の場合は何もしない
            guard !isGoingBack else {
                print("📱 [Swift]: 既に戻る処理中です")
                return
            }
            
            isGoingBack = true
            
            if let webView = webView, webView.canGoBack {
                print("📱 [Swift]: WebViewの履歴を使用して戻ります")
                webView.goBack()
                // ナビゲーションが完了したらフラグをリセット
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isGoingBack = false
                    self.parent.onGoBackProcessed?()
                }
            } else {
                print("📱 [Swift]: WebViewの履歴がないため、親ビューを閉じます")
                isGoingBack = false
                parent.onGoBackProcessed?()
                parent.onGoBack?()
            }
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "consoleLog":
                print("🌐 [JS Console Log]: \(message.body)")
            case "consoleError":
                print("❌ [JS Console Error]: \(message.body)")
            case "consoleWarn":
                print("⚠️ [JS Console Warn]: \(message.body)")
            case "navigateToUrl":
                // JavaScriptからのページ遷移リクエスト
                if let urlString = message.body as? String,
                   let url = URL(string: urlString) {
                    print("🚀 [Swift]: JavaScriptからのページ遷移リクエスト: \(urlString)")
                    // JavaScriptを評価してwindow.location.hrefを設定（履歴が正しく管理される）
                    if let webView = message.webView {
                        print("✅ [Swift]: JavaScriptでwindow.location.hrefを設定します")
                        let escapedUrl = urlString.replacingOccurrences(of: "'", with: "\\'")
                        let script = "window.location.href = '\(escapedUrl)';"
                        webView.evaluateJavaScript(script) { result, error in
                            if let error = error {
                                print("❌ [Swift]: JavaScript実行エラー: \(error)")
                                // フォールバック: 直接load()を使用
                                let request = URLRequest(url: url)
                                webView.load(request)
                            } else {
                                print("✅ [Swift]: JavaScript実行成功")
                            }
                            
                            // 親ビューに現在のURLを通知
                            DispatchQueue.main.async {
                                self.parent.currentUrl = url
                            }
                        }
                    }
                } else {
                    print("❌ [Swift]: 無効なURL: \(message.body)")
                }
            default:
                break
            }
        }
        
        // ナビゲーションポリシーを決定（ページ遷移を許可）
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                print("🔄 [Navigation]: \(url.absoluteString)")
                
                // 許可するドメインのリスト
                let allowedHosts = [
                    "kanjy-web.netlify.app",
                    "kanjy.vercel.app",
                    "kanjy-dzxo9jpk7-snaprooms-projects.vercel.app",
                    "localhost",
                    "127.0.0.1"
                ]
                
                // ドメインチェック
                if let host = url.host, allowedHosts.contains(host) {
                    print("✅ [Navigation]: 許可 - \(host)")
                    // 全て許可（キャッシュ処理はJavaScript側で行う）
                    DispatchQueue.main.async {
                        self.parent.currentUrl = url
                    }
                    decisionHandler(.allow)
                } else {
                    print("⚠️ [Navigation]: 外部リンク拒否")
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
                
                // ナビゲーション完了後、currentUrlを実際のWebViewのURLに更新
                // これにより、updateUIViewでの不要な再読み込みを防ぐ
                if let webViewUrl = webView.url {
                    print("✅ [Navigation]: 読み込み完了 - \(webViewUrl.absoluteString)")
                    self.parent.currentUrl = webViewUrl
                    print("🔄 [Navigation]: currentUrlを更新: \(webViewUrl.absoluteString)")
                }
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
            
            // エラーコード -999 は「キャンセル」を意味し、通常は別のナビゲーションが開始された時に発生
            // これは正常な動作なので、特別な処理は不要
            let nsError = error as NSError
            if nsError.code == NSURLErrorCancelled {
                print("ℹ️ [Navigation]: ナビゲーションがキャンセルされました（別のページに遷移中）")
            } else {
                print("❌ [Navigation]: 暫定的な読み込みに失敗 - \(error.localizedDescription)")
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