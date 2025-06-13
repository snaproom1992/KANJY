import SwiftUI

struct PaymentSettings: View {
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    @AppStorage("bankName") private var bankName = ""
    @AppStorage("bankBranch") private var bankBranch = ""
    @AppStorage("accountType") private var accountType = ""
    @AppStorage("accountNumber") private var accountNumber = ""
    @AppStorage("accountHolder") private var accountHolder = ""
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
                TextField("銀行名", text: $bankName)
                    .textContentType(.organizationName)
                
                TextField("支店名", text: $bankBranch)
                    .textContentType(.organizationName)
                
                Picker("口座種別", selection: $accountType) {
                    Text("普通").tag("普通")
                    Text("当座").tag("当座")
                }
                .pickerStyle(.segmented)
                
                TextField("口座番号", text: $accountNumber)
                    .keyboardType(.numberPad)
                
                TextField("口座名義", text: $accountHolder)
                    .textContentType(.name)
                
                // プレビュー表示
                if !bankName.isEmpty || !bankBranch.isEmpty || !accountType.isEmpty || !accountNumber.isEmpty || !accountHolder.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text("\(bankName) \(bankBranch) \(accountType) \(accountNumber) 名義：\(accountHolder)")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                    .padding(.vertical, 8)
                }
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
        .onChange(of: [bankName, bankBranch, accountType, accountNumber, accountHolder]) {
            // 各項目の変更を監視して、bankInfoを更新
            let newBankInfo = "\(bankName) \(bankBranch) \(accountType) \(accountNumber) 名義：\(accountHolder)"
            bankInfo = newBankInfo.trimmingCharacters(in: .whitespaces)
        }
    }
}

#Preview {
    NavigationStack {
        PaymentSettings()
    }
} 