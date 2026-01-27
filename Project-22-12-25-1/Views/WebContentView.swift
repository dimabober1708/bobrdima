import SwiftUI
import WebKit

struct WebContentView: UIViewRepresentable {
    let targetUrl: String

    func makeUIView(context: Context) -> WKWebView {
        // Configure WebView for cookie persistence
        let configuration = WKWebViewConfiguration()
        
        // Use default data store to persist cookies and session data
        configuration.websiteDataStore = .default()
        
        // Enable cookie storage and JavaScript
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Set cookie acceptance policy
        configuration.processPool = WKProcessPool()
        
        // Create WebView with configuration
        let browserView = WKWebView(frame: .zero, configuration: configuration)
        browserView.navigationDelegate = context.coordinator
        browserView.allowsBackForwardNavigationGestures = true
        
        // Remove white background and fix layout
        browserView.backgroundColor = .black
        browserView.isOpaque = true
        browserView.scrollView.backgroundColor = .black
        
        // Fix content inset to respect safe area (status bar) but fill screen
        browserView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Remove bounce effect that can cause white space
        browserView.scrollView.bounces = false
        browserView.scrollView.alwaysBounceVertical = false
        browserView.scrollView.alwaysBounceHorizontal = false
        
        // Ensure WebView fills the entire view immediately
        browserView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        return browserView
    }

    func updateUIView(_ browserView: WKWebView, context: Context) {
        // Update frame to fill screen
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            browserView.frame = window.bounds
        }
        
        guard
            let encodedUrl = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let validUrl = URL(string: encodedUrl)
        else { return }

        if browserView.url != validUrl {
            let urlRequest = URLRequest(url: validUrl)
            browserView.load(urlRequest)
        }
    }

    func makeCoordinator() -> WebNavigationHandler {
        WebNavigationHandler()
    }

    final class WebNavigationHandler: NSObject, WKNavigationDelegate {
        func webView(_ browserView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("Navigation started: \(browserView.url?.absoluteString ?? "")")
        }

        func webView(_ browserView: WKWebView, didFinish navigation: WKNavigation!) {
            print("Navigation completed")
            // Ensure WebView fills the screen after load and remove any white space
            DispatchQueue.main.async {
                browserView.scrollView.contentInset = .zero
                browserView.scrollView.scrollIndicatorInsets = .zero
                // Force layout update to remove white space
                browserView.setNeedsLayout()
                browserView.layoutIfNeeded()
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation to preserve cookies and session
            decisionHandler(.allow)
        }

        func webView(_ browserView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed: \(error.localizedDescription)")
        }
    }
}
