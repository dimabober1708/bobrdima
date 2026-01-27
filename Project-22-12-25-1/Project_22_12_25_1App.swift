import SwiftUI
import CoreData


// Для Мирона

@main
struct Project_22_12_25_1App: App {
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var errorHandler = ErrorHandler()
    
    @State private var showSplash = true
    @State private var showError = false
    
    @State private var remoteUrlString: String?
    @State private var urlFetchStatus: UrlFetchStatus = .pending
    @State private var navigationState: AppNavigationState = .initialScreen
    
    var body: some Scene {
        WindowGroup {
            
            ZStack {
                switch navigationState {
                case .initialScreen:
                    SplashScreenView()
                    
                case .primaryInterface:
                    MainTabView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(errorHandler)
                        .preferredColorScheme(themeManager.colorScheme)
                    
                case .browserContent(let urlString):
                    if let validUrl = URL(string: urlString) {
                        WebContentView(targetUrl: validUrl.absoluteString)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                            .ignoresSafeArea(.all, edges: .bottom)
                    } else {
                        Text("Invalid URL")
                    }
                    
                case .failureMessage(let errorMessage):
                    VStack(spacing: 20) {
                        Text("Error")
                            .font(.title)
                            .foregroundColor(.red)
                        Text(errorMessage)
                        Button("Retry") {
                            Task { await loadRemoteConfiguration() }
                        }
                    }
                    .padding()
                }
            }
            .task {
                await loadRemoteConfiguration()
            }
            .onChange(of: urlFetchStatus, initial: true) { oldValue, newValue in
                if case .completed = newValue, let url = remoteUrlString, !url.isEmpty {
                    Task {
                        await validateAndNavigateToUrl(targetUrl: url)
                    }
                }
            }

        }
    }
    
    private func loadRemoteConfiguration() async {
        await MainActor.run { navigationState = .initialScreen }
        
        let (url, state) = await RemoteUrlProvider.shared.fetchRemoteUrl()
        print("URL: \(url)")
        print("State: \(state)")
        
        await MainActor.run {
            self.remoteUrlString = url
            self.urlFetchStatus = state
        }
        
        if url == nil || url?.isEmpty == true {
            navigateToPrimaryInterface()
        }
    }
    
    private func navigateToPrimaryInterface() {
        withAnimation {
            navigationState = .primaryInterface
        }
    }
    
    private func validateAndNavigateToUrl(targetUrl: String) async {
        guard let url = URL(string: targetUrl) else {
            navigateToPrimaryInterface()
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "HEAD"
        urlRequest.timeoutInterval = 10
        
        do {
            let (_, httpResponse) = try await URLSession.shared.data(for: urlRequest)
            
            if let response = httpResponse as? HTTPURLResponse,
               (200...299).contains(response.statusCode) {
                await MainActor.run {
                    navigationState = .browserContent(targetUrl)
                }
            } else {
                navigateToPrimaryInterface()
            }
        } catch {
            navigateToPrimaryInterface()
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
