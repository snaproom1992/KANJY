import SwiftUI

struct OnboardingGuideView: View {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)? = nil
    @State private var currentPage = 0
    
    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "🍻",
            title: "飲み会管理を簡単に",
            description: "飲み会の計画から集金まで、全てを1つのアプリで管理できます"
        ),
        OnboardingPage(
            icon: "👥",
            title: "参加者と金額を管理",
            description: "参加者を追加して、役職に応じた自動割り勘計算ができます"
        ),
        OnboardingPage(
            icon: "📅",
            title: "スケジュール調整",
            description: "候補日程を設定して、参加者と日程調整ができます"
        ),
        OnboardingPage(
            icon: "💰",
            title: "集金管理",
            description: "支払い案内を生成して、集金状況を簡単に管理できます"
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // スキップボタン
                HStack {
                    Spacer()
                    Button("スキップ") {
                        isPresented = false
                        onComplete?()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                // ページコンテンツ
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // ナビゲーションボタン
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("戻る") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button("次へ") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("始める") {
                            isPresented = false
                            onComplete?()
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.headline)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text(page.icon)
                .font(.system(size: 100))
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding(40)
    }
}

#Preview {
    OnboardingGuideView(isPresented: .constant(true))
}

