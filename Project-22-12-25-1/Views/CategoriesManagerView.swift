import SwiftUI
import CoreData

struct CategoriesManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    @State private var showAddCategory = false
    @State private var categoryToDelete: Category?
    @State private var showDeleteConfirmation = false
    @State private var _categoriesToDelete: [Category] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categories) { category in
                    NavigationLink(destination: CategoryDetailView(category: category)) {
                        CategoryRow(category: category)
                    }
                }
                .onDelete(perform: deleteCategories)
            }
            .navigationTitle("Categories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddCategoryView()
            }
            .alert("Delete Category", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                    _categoriesToDelete = []
                }
                Button("Delete", role: .destructive) {
                    if !_categoriesToDelete.isEmpty {
                        // Delete multiple categories
                        withAnimation {
                            _categoriesToDelete.forEach { category in
                                deleteCategory(category)
                            }
                        }
                        _categoriesToDelete = []
                    } else if let category = categoryToDelete {
                        // Delete single category
                        deleteCategory(category)
                    }
                }
            } message: {
                if !_categoriesToDelete.isEmpty {
                    Text("Are you sure you want to delete \(_categoriesToDelete.count) categories? This will remove the categories from all associated decisions.")
                } else if let category = categoryToDelete {
                    Text("Are you sure you want to delete \"\(category.name ?? "this category")\"? This will remove the category from all associated decisions.")
                }
            }
        }
        .errorAlert(errorHandler: errorHandler)
    }
    
    private func deleteCategories(offsets: IndexSet) {
        let categoriesToDelete = offsets.map { categories[$0] }
        
        if categoriesToDelete.count == 1, let category = categoriesToDelete.first {
            categoryToDelete = category
            showDeleteConfirmation = true
        } else {
            // Multiple categories - show confirmation
            categoryToDelete = categoriesToDelete.first
            showDeleteConfirmation = true
            // Store all categories to delete after confirmation
            _categoriesToDelete = categoriesToDelete
        }
    }
    
    private func deleteCategory(_ category: Category) {
        withAnimation {
            viewContext.delete(category)
            
            do {
                try viewContext.save()
            } catch {
                errorHandler.handle(.deleteFailed(error.localizedDescription))
            }
        }
        categoryToDelete = nil
    }
}

struct CategoryRow: View {
    let category: Category
    
    @FetchRequest private var decisions: FetchedResults<FinancialDecision>
    
    init(category: Category) {
        self.category = category
        _decisions = FetchRequest(
            entity: FinancialDecision.entity(),
            sortDescriptors: [],
            predicate: NSPredicate(format: "category == %@", category)
        )
    }
    
    private var ratedDecisions: [FinancialDecision] {
        decisions.filter { $0.successRating > 0 }
    }
    
    private var averageSuccessRate: Double {
        let ratings = ratedDecisions.map { Double($0.successRating) }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count) / 10.0
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(colorFromString(category.accentColor ?? "4A90E2").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category.iconName ?? "folder")
                    .foregroundColor(colorFromString(category.accentColor ?? "4A90E2"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "Unknown")
                    .font(.system(size: 17, weight: .semibold))
                
                HStack {
                    Text("\(decisions.count) decisions")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                    
                    if !ratedDecisions.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(Int(averageSuccessRate * 100))% success")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func colorFromString(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

struct CategoryDetailView: View {
    let category: Category
    
    @FetchRequest private var decisions: FetchedResults<FinancialDecision>
    
    init(category: Category) {
        self.category = category
        _decisions = FetchRequest(
            entity: FinancialDecision.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
            predicate: NSPredicate(format: "category == %@", category)
        )
    }
    
    private var averageSuccessRate: Double {
        let ratedDecisions = decisions.filter { $0.successRating > 0 }
        guard !ratedDecisions.isEmpty else { return 0 }
        let ratings = ratedDecisions.map { Double($0.successRating) }
        return ratings.reduce(0, +) / Double(ratings.count) / 10.0
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(colorFromString(category.accentColor ?? "4A90E2").opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: category.iconName ?? "folder")
                                .font(.system(size: 40))
                                .foregroundColor(colorFromString(category.accentColor ?? "4A90E2"))
                        }
                        
                        Text(category.name ?? "Unknown")
                            .font(.system(size: 24, weight: .semibold))
                        
                        Text("\(decisions.count) decisions")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        if !decisions.filter({ $0.successRating > 0 }).isEmpty {
                            Text("\(Int(averageSuccessRate * 100))% average success")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(AppColors.success)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
            }
            
            Section("Decisions") {
                if decisions.isEmpty {
                    Text("No decisions in this category yet")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(decisions) { decision in
                        NavigationLink(destination: DecisionDetailView(decision: decision)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(decision.title ?? "Untitled")
                                    .font(.system(size: 17, weight: .semibold))
                                
                                Text(decision.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                if decision.successRating > 0 {
                                    Text("\(Int(decision.successRating))/10")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.success)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func colorFromString(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

struct AddCategoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    @State private var name: String = ""
    @State private var iconName: String = "folder"
    @State private var accentColor: String = "4A90E2"
    @State private var validationError: String?
    @State private var showValidationError = false
    
    private let availableIcons = ["folder", "creditcard", "house", "car", "gift", "chart.bar", "dollarsign.circle", "bag", "cart", "tag"]
    private let availableColors = ["4CAF50", "FFB300", "4A90E2", "9C27B0", "F44336", "00BCD4", "FF9800", "795548"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                }
                
                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button(action: { iconName = icon }) {
                                    ZStack {
                                        Circle()
                                            .fill(icon == iconName ? colorFromString(accentColor).opacity(0.2) : Color(.systemGray6))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: icon)
                                            .foregroundColor(icon == iconName ? colorFromString(accentColor) : .secondary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Section("Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableColors, id: \.self) { color in
                                Button(action: { accentColor = color }) {
                                    ZStack {
                                        Circle()
                                            .fill(colorFromString(color))
                                            .frame(width: 44, height: 44)
                                        
                                        if color == accentColor {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 18, weight: .semibold))
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
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
    }
    
    private func saveCategory() {
        let validation = DataValidator.validateCategoryName(name)
        guard validation.isValid else {
            validationError = validation.errorMessage
            showValidationError = true
            return
        }
        
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = name
        category.iconName = iconName
        category.accentColor = accentColor
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorHandler.handle(.saveFailed(error.localizedDescription))
        }
    }
    
    private func colorFromString(_ hex: String) -> Color {
        Color(hex: hex)
    }
}

#Preview {
    CategoriesManagerView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(ErrorHandler())
}

