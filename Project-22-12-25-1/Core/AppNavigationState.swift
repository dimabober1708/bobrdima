import Foundation

enum AppNavigationState {
    case initialScreen
    case primaryInterface
    case browserContent(String)
    case failureMessage(String)
}
