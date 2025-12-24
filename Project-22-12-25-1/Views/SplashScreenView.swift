import SwiftUI

struct SplashScreenView: View {
    @State private var showIcon = false
    @State private var showPath = false
    @State private var showTitle = false
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                ZStack {
                    // Crossroads icon
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 80, weight: .light))
                        .foregroundColor(AppColors.reflection)
                        .opacity(showIcon ? 1 : 0)
                        .scaleEffect(showIcon ? 1 : 0.5)
                    
                    // Glowing path
                    if showPath {
                        Path { path in
                            path.move(to: CGPoint(x: -30, y: 0))
                            path.addLine(to: CGPoint(x: 30, y: 0))
                        }
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.success.opacity(0.8), AppColors.success.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .shadow(color: AppColors.success.opacity(0.5), radius: 8)
                        .offset(y: -20)
                    }
                }
                .frame(height: 120)
                
                Text("Financial Decision\nLog Manager")
                    .font(.system(size: 32, weight: .medium, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showIcon = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.0)) {
                    showPath = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showTitle = true
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    isActive = false
                }
            }
        }
    }
}

#Preview {
    SplashScreenView(isActive: .constant(true))
}

