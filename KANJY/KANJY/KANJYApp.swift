//
//  KANJYApp.swift
//  KANJY
//
//  Created by 辻雄大 on 2025/04/29.
//

import SwiftUI

@main
struct KANJYApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    // アプリ起動時に匿名ログインを行う
                    do {
                        try await SupabaseManager.shared.signInAnonymously()
                    } catch {
                        print("❌ 匿名ログイン失敗: \(error)")
                    }
                }
        }
    }
}
