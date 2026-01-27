import SwiftUI
import Foundation

enum AppError: LocalizedError {
    case coreDataLoadFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case exportFailed(String)
    case importFailed(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .coreDataLoadFailed(let message):
            return "Failed to load data: \(message)"
        case .saveFailed(let message):
            return "Failed to save: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete: \(message)"
        case .exportFailed(let message):
            return "Failed to export: \(message)"
        case .importFailed(let message):
            return "Failed to import: \(message)"
        case .validationFailed(let message):
            return "Validation error: \(message)"
        }
    }
}

class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showError = false
    
    func handle(_ error: AppError) {
        currentError = error
        showError = true
    }
    
    func handle(_ error: Error) {
        if let appError = error as? AppError {
            handle(appError)
        } else {
            handle(.saveFailed(error.localizedDescription))
        }
    }
}

struct ErrorAlert: ViewModifier {
    @ObservedObject var errorHandler: ErrorHandler
    
    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: $errorHandler.showError) {
                Button("OK", role: .cancel) {
                    errorHandler.currentError = nil
                }
            } message: {
                if let error = errorHandler.currentError {
                    Text(error.errorDescription ?? "An unknown error occurred")
                }
            }
    }
}

extension View {
    func errorAlert(errorHandler: ErrorHandler) -> some View {
        modifier(ErrorAlert(errorHandler: errorHandler))
    }
}

