import SwiftUI
import CoreData


// Для Мирона

@main
struct Project_22_12_25_1App: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var errorHandler = ErrorHandler()
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if persistenceController.hasLoadError {
                CoreDataErrorView(error: persistenceController.loadError)
            } else if showSplash {
                SplashScreenView(isActive: $showSplash)
            } else {
                MainTabView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(errorHandler)
                    .preferredColorScheme(themeManager.colorScheme)
            }
        }
    }
}

struct CoreDataErrorView: View {
    let error: AppError?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.orange)
            
            Text("Data Loading Error")
                .font(.system(size: 24, weight: .semibold))
            
            Text(error?.errorDescription ?? "Failed to load application data")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Please restart the app. If the problem persists, contact support.")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MainDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            
            DecisionTimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            
            SuccessInsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis.circle.fill")
                }
        }
        .accentColor(AppColors.reflection)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
