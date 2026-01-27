import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    @StateObject private var themeManager = ThemeManager()
    
    @AppStorage("currencyDisplay") private var currencyDisplay: String = "USD"
    @AppStorage("reminderEnabled") private var reminderEnabled: Bool = false
    @State private var showDataResetAlert = false
    @State private var showBackupOptions = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                }
                
                Section("Preferences") {
                    Picker("Currency", selection: $currencyDisplay) {
                        Text("USD").tag("USD")
                        Text("EUR").tag("EUR")
                        Text("GBP").tag("GBP")
                        Text("None").tag("None")
                    }
                    
                    Toggle("Weekly Reflection Reminder", isOn: $reminderEnabled)
                }
                
                Section("Data Management") {
                    Button(action: { showBackupOptions = true }) {
                        HStack {
                            Text("Backup & Restore")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                    
                    Button(role: .destructive, action: { showDataResetAlert = true }) {
                        Text("Reset All Data")
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("App Store")
                        Spacer()
                        Text("Ready for Review")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Reset All Data", isPresented: $showDataResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("This will permanently delete all your decisions and categories. This action cannot be undone.")
            }
            .sheet(isPresented: $showBackupOptions) {
                BackupRestoreView()
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .errorAlert(errorHandler: errorHandler)
    }
    
    private func resetAllData() {
        let fetchRequest1: NSFetchRequest<NSFetchRequestResult> = FinancialDecision.fetchRequest()
        let deleteRequest1 = NSBatchDeleteRequest(fetchRequest: fetchRequest1)
        
        let fetchRequest2: NSFetchRequest<NSFetchRequestResult> = Category.fetchRequest()
        let deleteRequest2 = NSBatchDeleteRequest(fetchRequest: fetchRequest2)
        
        do {
            try viewContext.execute(deleteRequest1)
            try viewContext.execute(deleteRequest2)
            try viewContext.save()
        } catch {
            errorHandler.handle(.deleteFailed(error.localizedDescription))
        }
    }
}

struct BackupRestoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    @State private var showDocumentPicker = false
    @State private var showShareSheet = false
    @State private var backupURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(AppColors.reflection)
                    
                    Text("Backup & Restore")
                        .font(.system(size: 28, weight: .semibold))
                    
                    Text("Backup your data to Files app or restore from a backup")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    Button(action: createBackup) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Create Backup")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.success)
                        .cornerRadius(16)
                    }
                    
                    Button(action: { showDocumentPicker = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Restore from Backup")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = backupURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .errorAlert(errorHandler: errorHandler)
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        restoreFromBackup(url: url)
                    }
                case .failure(let error):
                    print("Failed to import: \(error)")
                }
            }
        }
    }
    
    private func createBackup() {
        let exporter = DataExporter(context: viewContext)
        if let url = exporter.exportToJSON() {
            backupURL = url
            showShareSheet = true
        }
    }
    
    private func restoreFromBackup(url: URL) {
        let importer = DataImporter(context: viewContext)
        if importer.importFromJSON(url: url) {
            dismiss()
        } else {
            errorHandler.handle(.importFailed("Failed to import backup file"))
        }
    }
}

class DataExporter {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func exportToJSON() -> URL? {
        let fetchRequest1: NSFetchRequest<FinancialDecision> = FinancialDecision.fetchRequest()
        let fetchRequest2: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let decisions = try context.fetch(fetchRequest1)
            let categories = try context.fetch(fetchRequest2)
            
            let decisionsData: [[String: Any]] = decisions.map { decision in
                var dict: [String: Any] = [:]
                dict["id"] = decision.id?.uuidString ?? ""
                dict["title"] = decision.title ?? ""
                dict["date"] = decision.date?.ISO8601Format() ?? ""
                dict["categoryId"] = decision.category?.id?.uuidString ?? ""
                dict["options"] = decision.options ?? []
                dict["chosenOption"] = decision.chosenOption ?? ""
                dict["pros"] = decision.pros ?? ""
                dict["cons"] = decision.cons ?? ""
                dict["expectedOutcome"] = decision.expectedOutcome ?? ""
                dict["actualOutcome"] = decision.actualOutcome ?? ""
                dict["successRating"] = decision.successRating > 0 ? Int(decision.successRating) : 0
                dict["emotionalState"] = Int(decision.emotionalState)
                dict["note"] = decision.note ?? ""
                return dict
            }
            
            let categoriesData: [[String: Any]] = categories.map { category in
                var dict: [String: Any] = [:]
                dict["id"] = category.id?.uuidString ?? ""
                dict["name"] = category.name ?? ""
                dict["iconName"] = category.iconName ?? ""
                dict["accentColor"] = category.accentColor ?? ""
                return dict
            }
            
            let exportData: [String: Any] = [
                "decisions": decisionsData,
                "categories": categoriesData,
                "exportDate": Date().ISO8601Format()
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("DecisionsBackup_\(Date().timeIntervalSince1970).json")
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to export: \(error)")
            return nil
        }
    }
}

class DataImporter {
    let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func importFromJSON(url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            guard let json = json,
                  let categoriesData = json["categories"] as? [[String: Any]],
                  let decisionsData = json["decisions"] as? [[String: Any]] else {
                return false
            }
            
            // Import categories
            var categoryMap: [String: Category] = [:]
            for catData in categoriesData {
                let category = Category(context: context)
                if let idString = catData["id"] as? String, let id = UUID(uuidString: idString) {
                    category.id = id
                } else {
                    category.id = UUID()
                }
                category.name = catData["name"] as? String
                category.iconName = catData["iconName"] as? String
                category.accentColor = catData["accentColor"] as? String
                if let idString = catData["id"] as? String {
                    categoryMap[idString] = category
                }
            }
            
            // Import decisions
            for decData in decisionsData {
                let decision = FinancialDecision(context: context)
                if let idString = decData["id"] as? String, let id = UUID(uuidString: idString) {
                    decision.id = id
                } else {
                    decision.id = UUID()
                }
                decision.title = decData["title"] as? String
                if let dateString = decData["date"] as? String {
                    let formatter = ISO8601DateFormatter()
                    decision.date = formatter.date(from: dateString)
                }
                if let categoryId = decData["categoryId"] as? String {
                    decision.category = categoryMap[categoryId]
                }
                decision.options = decData["options"] as? [String]
                decision.chosenOption = decData["chosenOption"] as? String
                decision.pros = decData["pros"] as? String
                decision.cons = decData["cons"] as? String
                decision.expectedOutcome = decData["expectedOutcome"] as? String
                decision.actualOutcome = decData["actualOutcome"] as? String
                decision.successRating = Int16(decData["successRating"] as? Int ?? 0)
                decision.emotionalState = Int16(decData["emotionalState"] as? Int ?? 5)
                decision.note = decData["note"] as? String
            }
            
            try context.save()
            return true
        } catch {
            print("Failed to import: \(error)")
            return false
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

