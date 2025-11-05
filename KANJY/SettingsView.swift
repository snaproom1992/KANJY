import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @State private var selectedRole: Role? = nil
    
    var body: some View {
        NavigationStack {
            List {
                Section("集金設定") {
                    NavigationLink(destination: PaymentSettings()) {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(.blue)
                            Text("集金情報設定")
                        }
                    }
                }
                
                Section("役職設定") {
                    NavigationLink(destination: RoleSettingsView(viewModel: viewModel, selectedRole: $selectedRole)) {
                        HStack {
                            Image(systemName: "person.3")
                                .foregroundColor(.blue)
                            Text("役職と倍率設定")
                        }
                    }
                }
                
                Section("アプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Text("幹事さんのための割り勘アプリ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}

#Preview {
    SettingsView()
}

