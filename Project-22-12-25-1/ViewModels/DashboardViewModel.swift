import Foundation
import CoreData

class DashboardViewModel: ObservableObject {
    @Published var searchText: String = ""
    
    func filterDecisions(_ decisions: [FinancialDecision], searchText: String) -> [FinancialDecision] {
        guard !searchText.isEmpty else { return decisions }
        
        let lowercasedSearch = searchText.lowercased()
        return decisions.filter { decision in
            let title = (decision.title ?? "").lowercased()
            let note = (decision.note ?? "").lowercased()
            let chosenOption = (decision.chosenOption ?? "").lowercased()
            let categoryName = (decision.category?.name ?? "").lowercased()
            
            return title.contains(lowercasedSearch) ||
                   note.contains(lowercasedSearch) ||
                   chosenOption.contains(lowercasedSearch) ||
                   categoryName.contains(lowercasedSearch)
        }
    }
}

