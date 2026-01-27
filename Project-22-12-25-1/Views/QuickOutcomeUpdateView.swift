import SwiftUI
import CoreData

struct QuickOutcomeUpdateView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    let decision: FinancialDecision
    
    @State private var successRating: Double = 5.0
    @State private var actualOutcome: String = ""
    @State private var showCelebration = false
    @State private var showReflection = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Text("How did it go?")
                        .font(.system(size: 28, weight: .semibold))
                    
                    Text("Rate the success of this decision")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Success Rating
                VStack(spacing: 24) {
                    Text("\(Int(successRating))/10")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(ratingColor)
                    
                    Slider(value: $successRating, in: 1...10, step: 1)
                        .tint(ratingColor)
                        .padding(.horizontal, 40)
                    
                    HStack {
                        Text("Poor")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Excellent")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Visual Rating
                HStack(spacing: 8) {
                    ForEach(1...10, id: \.self) { index in
                        Circle()
                            .fill(index <= Int(successRating) ? ratingColor : Color(.systemGray4))
                            .frame(width: 20, height: 20)
                            .animation(.spring(response: 0.3), value: successRating)
                    }
                }
                
                // Outcome Notes
                VStack(alignment: .leading, spacing: 8) {
                    Text("What happened?")
                        .font(.system(size: 18, weight: .semibold))
                    
                    TextField("Describe the actual outcome", text: $actualOutcome, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: saveOutcome) {
                    Text("Save Outcome")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ratingColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Update Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if showCelebration {
                    CelebrationView()
                        .transition(.scale.combined(with: .opacity))
                }
                
                if showReflection {
                    ReflectionView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
    
    private var ratingColor: Color {
        switch Int(successRating) {
        case 8...10: return AppColors.success
        case 5...7: return AppColors.learning
        default: return AppColors.reflection
        }
    }
    
    private func saveOutcome() {
        decision.actualOutcome = actualOutcome.isEmpty ? nil : actualOutcome
        decision.successRating = Int16(successRating)
        
        do {
            try viewContext.save()
            
            if successRating >= 8 {
                withAnimation {
                    showCelebration = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            } else {
                withAnimation {
                    showReflection = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    dismiss()
                }
            }
        } catch {
            errorHandler.handle(.saveFailed(error.localizedDescription))
        }
    }
}

struct CelebrationView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.success)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Text("Great Decision!")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct ReflectionView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.learning)
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                Text("Learning Opportunity")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let decision = FinancialDecision(context: context)
    decision.id = UUID()
    decision.title = "Sample Decision"
    decision.date = Date()
    
    return QuickOutcomeUpdateView(decision: decision)
        .environment(\.managedObjectContext, context)
}

