import Supabase
import Foundation

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: SupabaseConfig.url)!,
            supabaseKey: SupabaseConfig.anonKey
        )
    }
    
    // 匿名ログインを実行する
    // 匿名ログインを実行する
    func signInAnonymously() async throws {
        // すでにセッションがある場合は何もしない（IDが変わるのを防ぐ）
        if let _ = client.auth.currentSession {
            print("✅ 既存のセッションを使用: \(currentUserId ?? "unknown")")
            return
        }
        
        _ = try await client.auth.signInAnonymously()
        print("✅ 匿名ログイン成功: \(client.auth.currentUser?.id.uuidString ?? "unknown")")
    }
    
    // 現在のユーザーIDを取得する
    var currentUserId: String? {
        client.auth.currentUser?.id.uuidString.lowercased()
    }
} 