import SwiftUI
import CoreData

struct DecisionFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    let decision: FinancialDecision?
    
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: Category?
    @State private var options: [String] = ["", ""]
    @State private var chosenOption: String = ""
    @State private var pros: String = ""
    @State private var cons: String = ""
    @State private var expectedOutcome: String = ""
    @State private var emotionalState: Double = 5.0
    @State private var note: String = ""
    @State private var validationError: String?
    @State private var showValidationError = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    init(decision: FinancialDecision?) {
        self.decision = decision
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Decision Details") {
                    TextField("Decision Title", text: $title)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("None").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name ?? "Unknown").tag(category as Category?)
                        }
                    }
                }
                
                Section("Options Considered") {
                    ForEach(0..<options.count, id: \.self) { index in
                        TextField("Option \(index + 1)", text: Binding(
                            get: { options[safe: index] ?? "" },
                            set: { if index < options.count { options[index] = $0 } }
                        ))
                    }
                    
                    if options.count < DataValidator.maxOptionsCount {
                        Button(action: {
                            options.append("")
                        }) {
                            Label("Add Option", systemImage: "plus.circle")
                        }
                    } else {
                        Text("Maximum \(DataValidator.maxOptionsCount) options allowed")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Chosen Option") {
                    Picker("Chosen Option", selection: $chosenOption) {
                        Text("Not selected").tag("")
                        ForEach(options.filter { !$0.isEmpty }, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                }
                
                Section("Analysis") {
                    TextField("Pros", text: $pros, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Cons", text: $cons, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Expected Outcome", text: $expectedOutcome, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("Emotional State") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Calm")
                            Spacer()
                            Text("Anxious")
                        }
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        
                        Slider(value: $emotionalState, in: 1...10, step: 1)
                        
                        Text("Level: \(Int(emotionalState))")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(decision == nil ? "New Decision" : "Edit Decision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveDecision()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = validationError {
                    Text(error)
                }
            }
        }
        .errorAlert(errorHandler: errorHandler)
        .onAppear {
            if let decision = decision {
                loadDecision(decision)
            }
        }
    }
    
    private func loadDecision(_ decision: FinancialDecision) {
        title = decision.title ?? ""
        date = decision.date ?? Date()
        selectedCategory = decision.category
        options = decision.options ?? [""]
        chosenOption = decision.chosenOption ?? ""
        pros = decision.pros ?? ""
        cons = decision.cons ?? ""
        expectedOutcome = decision.expectedOutcome ?? ""
        emotionalState = Double(decision.emotionalState)
        note = decision.note ?? ""
    }
    
    private func saveDecision() {
        // Validate title
        let titleValidation = DataValidator.validateTitle(title)
        guard titleValidation.isValid else {
            validationError = titleValidation.errorMessage
            showValidationError = true
            return
        }
        
        // Validate date
        let dateValidation = DataValidator.validateDate(date)
        guard dateValidation.isValid else {
            validationError = dateValidation.errorMessage
            showValidationError = true
            return
        }
        
        // Validate options
        let optionsValidation = DataValidator.validateOptions(options)
        guard optionsValidation.isValid else {
            validationError = optionsValidation.errorMessage
            showValidationError = true
            return
        }
        
        // Validate note
        if !note.isEmpty {
            let noteValidation = DataValidator.validateNote(note)
            guard noteValidation.isValid else {
                validationError = noteValidation.errorMessage
                showValidationError = true
                return
            }
        }
        
        let decisionToSave: FinancialDecision
        
        if let existingDecision = decision {
            decisionToSave = existingDecision
        } else {
            decisionToSave = FinancialDecision(context: viewContext)
            decisionToSave.id = UUID()
        }
        
        decisionToSave.title = title
        decisionToSave.date = date
        decisionToSave.category = selectedCategory
        decisionToSave.options = options.filter { !$0.isEmpty }
        decisionToSave.chosenOption = chosenOption
        decisionToSave.pros = pros.isEmpty ? nil : pros
        decisionToSave.cons = cons.isEmpty ? nil : cons
        decisionToSave.expectedOutcome = expectedOutcome.isEmpty ? nil : expectedOutcome
        decisionToSave.emotionalState = Int16(emotionalState)
        decisionToSave.note = note.isEmpty ? nil : note
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorHandler.handle(.saveFailed(error.localizedDescription))
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    DecisionFormView(decision: nil)
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(ErrorHandler())
}

