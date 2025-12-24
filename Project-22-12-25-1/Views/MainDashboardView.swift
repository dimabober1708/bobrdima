import SwiftUI
import CoreData

struct MainDashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
        animation: .default
    ) private var decisions: FetchedResults<FinancialDecision>
    
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showAddDecision = false
    
    private var totalDecisions: Int {
        decisions.count
    }
    
    private var successRate: Double {
        let ratedDecisions = decisions.filter { $0.successRating > 0 }
        guard !ratedDecisions.isEmpty else { return 0 }
        let ratings = ratedDecisions.map { Double($0.successRating) }
        return ratings.reduce(0, +) / Double(ratings.count) / 10.0
    }
    
    private var recentDecisions: [FinancialDecision] {
        let allDecisions = Array(decisions)
        let filtered = viewModel.filterDecisions(allDecisions, searchText: viewModel.searchText)
        return Array(filtered.prefix(5))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Statistics Section
                        VStack(spacing: 16) {
                            Text("\(totalDecisions)")
                                .font(.system(size: 64, weight: .medium, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("financial decisions logged")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 32)
                        
                        // Success Rate Ring
                        SuccessRateRing(rate: successRate)
                            .frame(height: 200)
                        
                        // Recent Decisions
                        if !recentDecisions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Decisions")
                                    .font(.system(size: 22, weight: .semibold))
                                    .padding(.horizontal, 20)
                                
                                ForEach(recentDecisions) { decision in
                                    NavigationLink(destination: DecisionDetailView(decision: decision)) {
                                        DecisionCard(decision: decision)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
                            EmptyStateView()
                        }
                    }
                    .padding(.bottom, 100)
                }
                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddDecision = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(AppColors.success)
                                .clipShape(Circle())
                                .shadow(color: AppColors.success.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Dashboard")
            .searchable(text: $viewModel.searchText, prompt: "Search decisions...")
            .sheet(isPresented: $showAddDecision) {
                DecisionFormView(decision: nil)
            }
        }
    }
}

struct SuccessRateRing: View {
    let rate: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 16)
            
            Circle()
                .trim(from: 0, to: rate)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.success, AppColors.learning],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.0, dampingFraction: 0.8), value: rate)
            
            VStack(spacing: 4) {
                Text("\(Int(rate * 100))%")
                    .font(.system(size: 36, weight: .semibold))
                Text("Success Rate")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct DecisionCard: View {
    let decision: FinancialDecision
    
    private var outcomeEmoji: String {
        let rating = decision.successRating
        guard rating > 0 else { return "📊" }
        switch rating {
        case 8...10: return "✅"
        case 5...7: return "⚡️"
        default: return "📉"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Text(outcomeEmoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(decision.title ?? "Untitled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if decision.successRating > 0 {
                Text("\(decision.successRating)/10")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.success)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No decisions yet")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Start tracking your financial decisions to learn and grow")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

#Preview {
    MainDashboardView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

