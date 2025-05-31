import SwiftUI

struct RoleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PrePlanViewModel
    @Binding var selectedRole: Role?
    @State private var showingAddRole = false
    @State private var newRoleName = ""
    @State private var newRoleMultiplier = 1.0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingRole: Role? = nil
    @State private var editingMultiplier: Double = 1.0
    @State private var editingName: String = ""
    
    // 役職の説明を取得する関数
    private func getRoleDescription(_ role: Role) -> String {
        switch role {
        case .director:
            return "部門の責任者。支払いの倍率が最も高くなります。"
        case .manager:
            return "チームの管理者。標準より高めの支払い倍率となります。"
        case .staff:
            return "一般社員。標準的な支払い倍率となります。"
        case .newbie:
            return "新入社員。支払い倍率を抑えめに設定しています。"
        }
    }
    
    var body: some View {
        List {
            Section("標準の役職") {
                ForEach(Role.allCases) { role in
                    Button(action: {
                        editingRole = role
                        editingMultiplier = role.defaultMultiplier
                        editingName = role.name
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.name)
                                    .font(.headline)
                                Text("支払い倍率: ×\(String(format: "%.1f", role.defaultMultiplier))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            
            if !viewModel.customRoles.isEmpty {
                Section("カスタム役職") {
                    ForEach(viewModel.customRoles) { role in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(role.name)
                                    .font(.headline)
                                Text("支払い倍率: ×\(String(format: "%.1f", role.multiplier))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                viewModel.deleteCustomRole(id: role.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    showingAddRole = true
                }) {
                    Label("カスタム役職を追加", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("役職設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完了") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingAddRole) {
            NavigationStack {
                Form {
                    Section {
                        TextField("役職名", text: $newRoleName)
                        
                        HStack {
                            Text("支払い倍率")
                            Spacer()
                            TextField("", value: $newRoleMultiplier, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
                .navigationTitle("カスタム役職の追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            showingAddRole = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("追加") {
                            if validateNewRole() {
                                viewModel.addCustomRole(name: newRoleName, multiplier: newRoleMultiplier)
                                newRoleName = ""
                                newRoleMultiplier = 1.0
                                showingAddRole = false
                            }
                        }
                        .disabled(newRoleName.isEmpty)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editingRole) { role in
            NavigationStack {
                Form {
                    Section {
                        TextField("役職名", text: $editingName)
                        
                        HStack {
                            Text("支払い倍率")
                            Spacer()
                            TextField("", value: $editingMultiplier, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                    }
                }
                .navigationTitle("\(role.name)の設定")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            editingRole = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if validateMultiplier(editingMultiplier) && !editingName.isEmpty {
                                role.setMultiplier(editingMultiplier)
                                role.setName(editingName)
                                editingRole = nil
                            } else if editingName.isEmpty {
                                alertMessage = "役職名を入力してください"
                                showingAlert = true
                            }
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("エラー", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func validateNewRole() -> Bool {
        if newRoleName.isEmpty {
            alertMessage = "役職名を入力してください"
            showingAlert = true
            return false
        }
        
        return validateMultiplier(newRoleMultiplier)
    }
    
    private func validateMultiplier(_ multiplier: Double) -> Bool {
        if multiplier <= 0 {
            alertMessage = "支払い倍率は0より大きい値を入力してください"
            showingAlert = true
            return false
        }
        
        if multiplier > 5.0 {
            alertMessage = "支払い倍率は5.0以下の値を入力してください"
            showingAlert = true
            return false
        }
        
        return true
    }
} 
