import SwiftUI
import CoreData

struct DecisionDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    let decision: FinancialDecision
    
    @State private var showEdit = false
    @State private var showOutcomeUpdate = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(decision.title ?? "Untitled Decision")
                        .font(.system(size: 32, weight: .semibold))
                    
                    HStack {
                        Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        if let category = decision.category {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(category.name ?? "")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Chosen Option
                if let chosenOption = decision.chosenOption, !chosenOption.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Chosen Option")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(chosenOption)
                            .font(.system(size: 20, weight: .medium))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.success.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Options Considered
                if let options = decision.options, !options.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Options Considered")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            HStack {
                                Circle()
                                    .fill(option == decision.chosenOption ? AppColors.success : Color(.systemGray4))
                                    .frame(width: 8, height: 8)
                                
                                Text(option)
                                    .font(.system(size: 17, weight: .regular))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Pros & Cons
                if let pros = decision.pros, !pros.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pros")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.success)
                        
                        Text(pros)
                            .font(.system(size: 17, weight: .regular))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.success.opacity(0.05))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                if let cons = decision.cons, !cons.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cons")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.learning)
                        
                        Text(cons)
                            .font(.system(size: 17, weight: .regular))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.learning.opacity(0.05))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Expected Outcome
                if let expectedOutcome = decision.expectedOutcome, !expectedOutcome.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected Outcome")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(expectedOutcome)
                            .font(.system(size: 17, weight: .regular))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Actual Outcome
                if let actualOutcome = decision.actualOutcome, !actualOutcome.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Actual Outcome")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(AppColors.reflection)
                        
                        Text(actualOutcome)
                            .font(.system(size: 17, weight: .regular))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.reflection.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Success Rating
                if decision.successRating > 0 {
                    let rating = decision.successRating
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Success Rating")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            ForEach(1...10, id: \.self) { index in
                                Circle()
                                    .fill(index <= Int(rating) ? AppColors.success : Color(.systemGray4))
                                    .frame(width: 24, height: 24)
                            }
                            
                            Spacer()
                            
                            Text("\(Int(rating))/10")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(AppColors.success)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Emotional State
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emotional State")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Calm")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Anxious")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.success, AppColors.learning],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(decision.emotionalState) / 10.0, height: 8)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 20)
                
                // Notes
                if let note = decision.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(note)
                            .font(.system(size: 17, weight: .regular))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 20)
                }
                
                // Actions
                VStack(spacing: 12) {
                    if decision.successRating == 0 {
                        Button(action: { showOutcomeUpdate = true }) {
                            Text("Update Outcome")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(AppColors.success)
                                .cornerRadius(16)
                        }
                    }
                    
                    Button(action: { showEdit = true }) {
                        Text("Edit Decision")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    
                    Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                        Text("Delete Decision")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEdit) {
            DecisionFormView(decision: decision)
        }
        .sheet(isPresented: $showOutcomeUpdate) {
            QuickOutcomeUpdateView(decision: decision)
        }
        .alert("Delete Decision", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteDecision()
            }
        } message: {
            Text("Are you sure you want to delete \"\(decision.title ?? "this decision")\"? This action cannot be undone.")
        }
        .errorAlert(errorHandler: errorHandler)
    }
    
    private func deleteDecision() {
        viewContext.delete(decision)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorHandler.handle(.deleteFailed(error.localizedDescription))
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let decision = FinancialDecision(context: context)
    decision.id = UUID()
    decision.title = "Sample Decision"
    decision.date = Date()
    decision.chosenOption = "Option A"
    decision.options = ["Option A", "Option B"]
    decision.emotionalState = 5
    
    return NavigationView {
        DecisionDetailView(decision: decision)
    }
    .environment(\.managedObjectContext, context)
}

