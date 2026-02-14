import SwiftUI

struct PaymentSettings: View {
    @AppStorage("payPayID") private var payPayID = ""
    @AppStorage("bankInfo") private var bankInfo = ""
    @AppStorage("bankName") private var bankName = ""
    @AppStorage("bankBranch") private var bankBranch = ""
    @AppStorage("accountType") private var accountType = ""
    @AppStorage("accountNumber") private var accountNumber = ""
    @AppStorage("accountHolder") private var accountHolder = ""
    
    var body: some View {
        Form {
            Section(header: Text("PayPay情報")) {
                TextField("PayPay ID", text: $payPayID)
                    .submitLabel(.done)
                Text("PayPayアプリのプロフィールからIDを確認できます")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.gray6)
            }
            
            Section(header: Text("銀行振込情報")) {
                TextField("銀行名", text: $bankName)
                    .textContentType(.organizationName)
                    .submitLabel(.done)
                
                TextField("支店名", text: $bankBranch)
                    .textContentType(.organizationName)
                    .submitLabel(.done)
                
                Picker("口座種別", selection: $accountType) {
                    Text("普通").tag("普通")
                    Text("当座").tag("当座")
                }
                .pickerStyle(.segmented)
                
                TextField("口座番号", text: $accountNumber)
                    .keyboardType(.numberPad)
                
                TextField("口座名義", text: $accountHolder)
                    .textContentType(.name)
                    .submitLabel(.done)
                
                // プレビュー表示
                if !bankName.isEmpty || !bankBranch.isEmpty || !accountType.isEmpty || !accountNumber.isEmpty || !accountHolder.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("プレビュー")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.gray6)
                        
                        Text("\(bankName) \(bankBranch) \(accountType) \(accountNumber) 名義：\(accountHolder)")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                            )
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section(header: Text("情報"), footer: Text("ここで設定した情報は集金案内画像に使用されます。プライバシーに配慮し、個人情報の入力には十分ご注意ください。")) {
                Text("集金情報は端末内に保存され、集金案内の作成時のみ使用されます。")
                    .font(.footnote)
                    .foregroundColor(DesignSystem.Colors.secondary)
            }
        }
        .navigationTitle("集金情報設定")
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