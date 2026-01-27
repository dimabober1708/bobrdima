import SwiftUI
import CoreData

struct MoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    
    var body: some View {
        NavigationView {
            List {
                Section("Tools") {
                    NavigationLink(destination: DecisionPreparationHelperView()) {
                        Label("Preparation Helper", systemImage: "lightbulb.fill")
                    }
                    
                    NavigationLink(destination: ReflectionGalleryView()) {
                        Label("Reflection Gallery", systemImage: "book.fill")
                    }
                    
                    NavigationLink(destination: CategoriesManagerView()) {
                        Label("Categories", systemImage: "folder.fill")
                    }
                    
                    NavigationLink(destination: ExportReviewView()) {
                        Label("Export & Review", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("Settings") {
                    NavigationLink(destination: SettingsView()) {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    MoreView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(ErrorHandler())
}

