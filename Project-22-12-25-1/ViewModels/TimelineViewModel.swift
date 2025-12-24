import Foundation
import CoreData

class TimelineViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: Category?
    @Published var selectedYear: Int?
    
    func filterDecisions(_ decisions: [FinancialDecision], searchText: String, category: Category?, year: Int?) -> [FinancialDecision] {
        var filtered = Array(decisions)
        
        // Filter by category
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by year
        if let year = year {
            filtered = filtered.filter {
                guard let date = $0.date else { return false }
                return Calendar.current.component(.year, from: date) == year
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            filtered = filtered.filter { decision in
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
        
        return filtered
    }
}

