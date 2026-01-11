import SwiftUI

struct HelpGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("基本操作") {
                    GuideItem(
                        icon: "plus.circle.fill",
                        title: "飲み会を作成",
                        description: "ホーム画面の「新規作成」ボタンから飲み会を作成できます"
                    )
                    
                    GuideItem(
                        icon: "person.2.fill",
                        title: "参加者を追加",
                        description: "飲み会詳細画面で参加者を追加し、役職を設定できます"
                    )
                    
                    GuideItem(
                        icon: "yensign.circle.fill",
                        title: "金額を設定",
                        description: "合計金額または内訳を設定して、自動で割り勘計算されます"
                    )
                }
                
                Section("スケジュール調整") {
                    GuideItem(
                        icon: "calendar.badge.plus",
                        title: "スケジュール調整を作成",
                        description: "飲み会詳細画面の「スケジュール調整」セクションから作成できます"
                    )
                    
                    GuideItem(
                        icon: "link",
                        title: "URLを共有",
                        description: "作成したスケジュール調整のURLを参加者に共有できます"
                    )
                }
                
                Section("集金管理") {
                    GuideItem(
                        icon: "creditcard.fill",
                        title: "支払い案内を生成",
                        description: "飲み会詳細画面の「支払い案内」ボタンから案内画像を生成できます"
                    )
                    
                    GuideItem(
                        icon: "checkmark.circle.fill",
                        title: "集金状況を管理",
                        description: "参加者リストで集金済みにチェックを入れて管理できます"
                    )
                }
            }
            .navigationTitle("使い方ガイド")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GuideItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HelpGuideView()
}

