import SwiftUI

struct TopView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                NavigationLink(destination: Text("事前集金プラン作成画面")) {
                    Text("事前集金プランを作る")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                NavigationLink(destination: Text("事後集金プラン作成画面")) {
                    Text("事後集金プランを作る")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("幹事アプリ")
        }
    }
}

#Preview {
    TopView()
}