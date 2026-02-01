import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = PrePlanViewModel()
    @State private var selectedRole: Role? = nil
    @State private var showingHelpGuide = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("使い方") {
                    Button {
                        showingHelpGuide = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("使い方ガイド")
                        }
                    }
                    
                    if hasCompletedOnboarding {
                        Button {
                            showingOnboarding = true
                        } label: {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(DesignSystem.Colors.primary)
                                Text("チュートリアルを再表示")
                            }
                        }
                    }
                }
                
                Section("集金設定") {
                    NavigationLink(destination: PaymentSettings()) {
                        HStack {
                            Image(systemName: "creditcard")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("集金情報設定")
                        }
                    }
                }
                
                Section("役職設定") {
                    NavigationLink(destination: RoleSettingsView(viewModel: viewModel, selectedRole: $selectedRole)) {
                        HStack {
                            Image(systemName: "person.3")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("役職と倍率設定")
                        }
                    }
                }
                
                Section("開発") {
                    NavigationLink(destination: StyleGuideView()) {
                        HStack {
                            Image(systemName: "paintpalette")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("スタイルガイド")
                        }
                    }
                }
                
                Section("法的情報") {
                    NavigationLink(destination: MarkdownDocumentView(filename: "TERMS_OF_SERVICE", title: "利用規約")) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("利用規約")
                        }
                    }
                    
                    NavigationLink(destination: MarkdownDocumentView(filename: "PRIVACY_POLICY", title: "プライバシーポリシー")) {
                        HStack {
                            Image(systemName: "hand.raised")
                                .foregroundColor(DesignSystem.Colors.primary)
                            Text("プライバシーポリシー")
                        }
                    }
                }
                
                Section("アプリについて") {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(DesignSystem.Colors.secondary)
                    }
                    
                    Text("幹事さんのための割り勘アプリ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showingHelpGuide) {
                HelpGuideView()
            }
            .fullScreenCover(isPresented: $showingOnboarding) {
                OnboardingGuideView(isPresented: $showingOnboarding) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

