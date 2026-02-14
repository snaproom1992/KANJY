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
                .onAppear {
                    setupKeyboardDismissOnTap()
                }
        }
    }
    
    /// キーボードの外をタップしたらキーボードを閉じる（アプリ全体に適用）
    private func setupKeyboardDismissOnTap() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing(_:)))
        tapGesture.cancelsTouchesInView = false // ボタンなど他のタップは正常に動作させる
        window.addGestureRecognizer(tapGesture)
    }
}
