import SwiftUI
import CoreData

struct ReflectionGalleryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
        animation: .default
    ) private var decisions: FetchedResults<FinancialDecision>
    
    private var reflectionDecisions: [FinancialDecision] {
        // Decisions with notes or low success ratings (learning opportunities)
        decisions.filter { decision in
            (decision.note != nil && !decision.note!.isEmpty) ||
            (decision.successRating > 0 && decision.successRating < 6)
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if reflectionDecisions.isEmpty {
                    EmptyReflectionView()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(reflectionDecisions) { decision in
                                NavigationLink(destination: DecisionDetailView(decision: decision)) {
                                    ReflectionCard(decision: decision)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(20)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Reflection Gallery")
        }
    }
}

struct EmptyReflectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No reflections yet")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Add notes to decisions or rate them to see them here")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

struct ReflectionCard: View {
    let decision: FinancialDecision
    
    private var cardColor: Color {
        let rating = decision.successRating
        if rating > 0 && rating < 6 {
            return AppColors.learning.opacity(0.1)
        }
        return AppColors.reflection.opacity(0.1)
    }
    
    private var icon: String {
        let rating = decision.successRating
        if rating > 0 && rating < 6 {
            return "lightbulb.fill"
        }
        return "book.fill"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(AppColors.learning)
                    .font(.system(size: 24))
                
                Spacer()
                
                if decision.successRating > 0 {
                    Text("\(Int(decision.successRating))/10")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(decision.title ?? "Untitled")
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let note = decision.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            Spacer()
            
            Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(height: 180)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardColor)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

#Preview {
    ReflectionGalleryView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

