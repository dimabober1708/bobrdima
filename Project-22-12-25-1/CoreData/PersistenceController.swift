import CoreData
import Foundation

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    @Published var loadError: AppError?
    @Published var hasLoadError = false
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FinancialDecisionModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                let appError = AppError.coreDataLoadFailed(error.localizedDescription)
                DispatchQueue.main.async {
                    self?.loadError = appError
                    self?.hasLoadError = true
                }
                // Log error but don't crash
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() throws {
        let context = container.viewContext
        if context.hasChanges {
            try context.save()
        }
    }
    
    func saveWithErrorHandler(_ errorHandler: ErrorHandler) {
        do {
            try save()
        } catch {
            errorHandler.handle(.saveFailed(error.localizedDescription))
        }
    }
}

