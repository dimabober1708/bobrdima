import SwiftUI
import CoreData

struct DecisionPreparationHelperView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
        animation: .default
    ) private var allDecisions: FetchedResults<FinancialDecision>
    
    @State private var selectedCategory: Category?
    @State private var showReferenceDecisions = false
    @State private var referenceDecisions: [FinancialDecision] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(AppColors.learning)
                    
                    Text("Decision Preparation Helper")
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)
                    
                    Text("Review similar past decisions to make better choices")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select a Category")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            CategorySelectionCard(
                                category: nil,
                                isSelected: selectedCategory == nil
                            ) {
                                selectedCategory = nil
                                updateReferenceDecisions()
                            }
                            
                            ForEach(categories) { category in
                                CategorySelectionCard(
                                    category: category,
                                    isSelected: selectedCategory?.id == category.id
                                ) {
                                    selectedCategory = category
                                    updateReferenceDecisions()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                if showReferenceDecisions && !referenceDecisions.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reference Decisions")
                            .font(.system(size: 20, weight: .semibold))
                            .padding(.horizontal, 20)
                        
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(referenceDecisions.prefix(10).enumerated()), id: \.element.id) { index, decision in
                                    NavigationLink(destination: DecisionDetailView(decision: decision)) {
                                        ReferenceDecisionCard(decision: decision)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                } else if showReferenceDecisions {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.secondary)
                        
                        Text("No decisions in this category yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                }
                
                Spacer()
            }
            .navigationTitle("Preparation Helper")
        }
    }
    
    private func updateReferenceDecisions() {
        if let category = selectedCategory {
            referenceDecisions = Array(allDecisions.filter { $0.category == category })
        } else {
            referenceDecisions = Array(allDecisions)
        }
        showReferenceDecisions = true
    }
}

struct CategorySelectionCard: View {
    let category: Category?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected ?
                            (category != nil ? colorFromString(category!.accentColor ?? "4A90E2") : AppColors.reflection).opacity(0.2) :
                            Color(.systemGray6)
                        )
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: category?.iconName ?? "folder")
                        .foregroundColor(
                            isSelected ?
                            (category != nil ? colorFromString(category!.accentColor ?? "4A90E2") : AppColors.reflection) :
                            .secondary
                        )
                        .font(.system(size: 24))
                }
                
                Text(category?.name ?? "All")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.primary)
            }
            .padding(16)
            .frame(width: 120)
            .background(isSelected ? Color(.systemBackground) : Color(.systemGray6))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppColors.reflection : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private func colorFromString(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

struct ReferenceDecisionCard: View {
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
            
            VStack(alignment: .leading, spacing: 8) {
                Text(decision.title ?? "Untitled")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let chosenOption = decision.chosenOption, !chosenOption.isEmpty {
                    Text("Chose: \(chosenOption)")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack {
                    Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    if decision.successRating > 0 {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(Int(decision.successRating))/10")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppColors.success)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}


#Preview {
    DecisionPreparationHelperView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

