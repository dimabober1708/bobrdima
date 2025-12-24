import Foundation

struct DataValidator {
    static let maxTitleLength = 200
    static let maxNoteLength = 2000
    static let maxOptionLength = 200
    static let maxOptionsCount = 10
    static let minOptionsCount = 2
    
    static func validateTitle(_ title: String) -> ValidationResult {
        if title.isEmpty {
            return .failure("Title cannot be empty")
        }
        if title.count > maxTitleLength {
            return .failure("Title must be \(maxTitleLength) characters or less")
        }
        return .success
    }
    
    static func validateNote(_ note: String) -> ValidationResult {
        if note.count > maxNoteLength {
            return .failure("Note must be \(maxNoteLength) characters or less")
        }
        return .success
    }
    
    static func validateOptions(_ options: [String]) -> ValidationResult {
        let validOptions = options.filter { !$0.isEmpty }
        
        if validOptions.count < minOptionsCount {
            return .failure("At least \(minOptionsCount) options are required")
        }
        
        if validOptions.count > maxOptionsCount {
            return .failure("Maximum \(maxOptionsCount) options allowed")
        }
        
        for option in validOptions {
            if option.count > maxOptionLength {
                return .failure("Each option must be \(maxOptionLength) characters or less")
            }
        }
        
        return .success
    }
    
    static func validateDate(_ date: Date) -> ValidationResult {
        let calendar = Calendar.current
        let today = Date()
        
        // Allow dates up to 1 year in the future (for planning)
        if let futureDate = calendar.date(byAdding: .year, value: 1, to: today),
           date > futureDate {
            return .failure("Date cannot be more than 1 year in the future")
        }
        
        // Allow dates up to 10 years in the past
        if let pastDate = calendar.date(byAdding: .year, value: -10, to: today),
           date < pastDate {
            return .failure("Date cannot be more than 10 years in the past")
        }
        
        return .success
    }
    
    static func validateCategoryName(_ name: String) -> ValidationResult {
        if name.isEmpty {
            return .failure("Category name cannot be empty")
        }
        if name.count > 50 {
            return .failure("Category name must be 50 characters or less")
        }
        return .success
    }
}

enum ValidationResult {
    case success
    case failure(String)
    
    var isValid: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var errorMessage: String? {
        if case .failure(let message) = self {
            return message
        }
        return nil
    }
}

