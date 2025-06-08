import SwiftUI

struct PaymentSettings: View {
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    @AppStorage("paymentMessage") private var paymentMessage = "お支払いよろしくお願いします。"
    @AppStorage("paymentDueMessage") private var paymentDueMessage = "お支払い期限: 7日以内"
    
    var body: some View {
        Form {
            Section(header: Text("PayPay情報")) {
                TextField("PayPay ID", text: $payPayID)
                Text("PayPayアプリのプロフィールからIDを確認できます")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("銀行振込情報")) {
                TextField("銀行振込情報", text: $bankInfo, axis: .vertical)
                    .lineLimit(5...)
                Text("例: 〇〇銀行 △△支店 普通 1234567 名義：山田太郎")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Section(header: Text("メッセージ設定")) {
                TextField("案内メッセージ", text: $paymentMessage, axis: .vertical)
                    .lineLimit(3...)
                
                TextField("支払い期限", text: $paymentDueMessage)
            }
            
            Section(header: Text("情報"), footer: Text("ここで設定した情報は支払い案内画像に使用されます。プライバシーに配慮し、個人情報の入力には十分ご注意ください。")) {
                Text("支払い情報は端末内に保存され、支払い案内の作成時のみ使用されます。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("支払い情報設定")
    }
}

#Preview {
    NavigationStack {
        PaymentSettings()
    }
} 