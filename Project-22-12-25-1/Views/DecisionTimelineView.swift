import SwiftUI
import CoreData

struct DecisionTimelineView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
        animation: .default
    ) private var decisions: FetchedResults<FinancialDecision>
    
    @StateObject private var viewModel = TimelineViewModel()
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    private var filteredDecisions: [FinancialDecision] {
        viewModel.filterDecisions(
            Array(decisions),
            searchText: viewModel.searchText,
            category: viewModel.selectedCategory,
            year: viewModel.selectedYear
        )
    }
    
    private var availableYears: [Int] {
        let years = Set(decisions.compactMap { decision -> Int? in
            guard let date = decision.date else { return nil }
            return Calendar.current.component(.year, from: date)
        })
        return Array(years).sorted(by: >)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(title: "All Categories", isSelected: viewModel.selectedCategory == nil) {
                            viewModel.selectedCategory = nil
                        }
                        
                        ForEach(categories) { category in
                            FilterChip(
                                title: category.name ?? "Unknown",
                                isSelected: viewModel.selectedCategory?.id == category.id
                            ) {
                                viewModel.selectedCategory = category
                            }
                        }
                        
                        Divider()
                            .frame(height: 30)
                        
                        FilterChip(title: "All Years", isSelected: viewModel.selectedYear == nil) {
                            viewModel.selectedYear = nil
                        }
                        
                        ForEach(availableYears, id: \.self) { year in
                            FilterChip(
                                title: "\(year)",
                                isSelected: viewModel.selectedYear == year
                            ) {
                                viewModel.selectedYear = year
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // Timeline
                if filteredDecisions.isEmpty {
                    EmptyTimelineView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredDecisions.enumerated()), id: \.element.id) { index, decision in
                                TimelineItem(decision: decision, isFirst: index == 0)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Timeline")
            .searchable(text: $viewModel.searchText, prompt: "Search decisions...")
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppColors.reflection : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct TimelineItem: View {
    let decision: FinancialDecision
    let isFirst: Bool
    
    private var successColor: Color {
        let rating = decision.successRating
        guard rating > 0 else {
            return Color(.systemGray4)
        }
        
        let normalized = Double(rating) / 10.0
        if normalized >= 0.8 {
            return AppColors.success
        } else if normalized >= 0.5 {
            return AppColors.learning
        } else {
            return Color(.systemRed)
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline line
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(height: 20)
                }
                
                Circle()
                    .fill(successColor)
                    .frame(width: 12, height: 12)
                    .shadow(color: successColor.opacity(0.5), radius: 4)
                
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            // Content
            NavigationLink(destination: DecisionDetailView(decision: decision)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    Text(decision.title ?? "Untitled")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if decision.successRating > 0 {
                        HStack {
                            Text("\(Int(decision.successRating))/10")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(successColor)
                            
                            if let category = decision.category {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(category.name ?? "")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No decisions found")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Try adjusting your filters or create a new decision")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

#Preview {
    DecisionTimelineView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(ErrorHandler())
}

