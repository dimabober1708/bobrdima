import SwiftUI
import CoreData
import PDFKit

struct ExportReviewView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var errorHandler: ErrorHandler
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: false)],
        animation: .default
    ) private var decisions: FetchedResults<FinancialDecision>
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var isExporting = false
    
    private var availableYears: [Int] {
        let years = Set(decisions.compactMap { decision -> Int? in
            guard let date = decision.date else { return nil }
            return Calendar.current.component(.year, from: date)
        })
        return Array(years).sorted(by: >)
    }
    
    private var yearDecisions: [FinancialDecision] {
        Array(decisions.filter { decision in
            guard let date = decision.date else { return false }
            return Calendar.current.component(.year, from: date) == selectedYear
        })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(AppColors.reflection)
                    
                    Text("Export & Review")
                        .font(.system(size: 28, weight: .semibold))
                    
                    Text("Export your decisions for review and reflection")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select Year")
                        .font(.system(size: 20, weight: .semibold))
                        .padding(.horizontal, 20)
                    
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 20)
                }
                
                if yearDecisions.isEmpty {
                    EmptyExportStateView()
                } else {
                    ExportButton(
                        title: "Export Year as PDF",
                        icon: "doc.text",
                        color: AppColors.success,
                        isLoading: isExporting
                    ) {
                        exportYearAsPDF()
                    }
                    .disabled(isExporting)
                    .padding(.horizontal, 20)
                }
                
                Spacer()
            }
            .navigationTitle("Export")
            .overlay {
                if isExporting {
                    ExportingOverlay()
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
        .errorAlert(errorHandler: errorHandler)
    }
    
    private func exportYearAsPDF() {
        guard !yearDecisions.isEmpty else {
            errorHandler.handle(.exportFailed("No decisions found for selected year"))
            return
        }
        
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let pdfCreator = PDFCreator(decisions: yearDecisions, year: selectedYear)
            if let url = pdfCreator.createPDF() {
                DispatchQueue.main.async {
                    self.pdfURL = url
                    self.isExporting = false
                    self.showShareSheet = true
                }
            } else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.errorHandler.handle(.exportFailed("Failed to create PDF"))
                }
            }
        }
    }
}

struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(20)
            .background(isLoading ? color.opacity(0.7) : color)
            .cornerRadius(16)
        }
        .disabled(isLoading)
    }
}

struct ExportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text("Creating PDF...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(Color(.systemGray6))
            .cornerRadius(20)
        }
    }
}

struct EmptyExportStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            Text("No decisions to export")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Create some decisions first to export them")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class PDFCreator {
    let decisions: [FinancialDecision]
    let year: Int
    
    init(decisions: [FinancialDecision], year: Int) {
        self.decisions = decisions
        self.year = year
    }
    
    func createPDF() -> URL? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Financial Decision Log Manager",
            kCGPDFContextAuthor: "User",
            kCGPDFContextTitle: "My Financial Decisions \(year)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 72
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor.label
            ]
            let title = "My Financial Decisions \(year)"
            title.draw(at: CGPoint(x: 72, y: yPosition), withAttributes: titleAttributes)
            yPosition += 50
            
            // Decisions
            for decision in decisions.sorted(by: { ($0.date ?? Date()) < ($1.date ?? Date()) }) {
                if yPosition > pageHeight - 200 {
                    context.beginPage()
                    yPosition = 72
                }
                
                let decisionText = formatDecision(decision)
                let textRect = CGRect(x: 72, y: yPosition, width: pageWidth - 144, height: 150)
                decisionText.draw(in: textRect, withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.label
                ])
                
                yPosition += 160
            }
        }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Decisions_\(year).pdf")
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to create PDF: \(error)")
            return nil
        }
    }
    
    private func formatDecision(_ decision: FinancialDecision) -> String {
        var text = ""
        text += "\(decision.title ?? "Untitled")\n"
        if let date = decision.date {
            text += "Date: \(date.formatted(date: .abbreviated, time: .omitted))\n"
        }
        if let chosenOption = decision.chosenOption {
            text += "Chosen: \(chosenOption)\n"
        }
        if decision.successRating > 0 {
            text += "Success Rating: \(decision.successRating)/10\n"
        }
        if let outcome = decision.actualOutcome {
            text += "Outcome: \(outcome)\n"
        }
        text += "\n"
        return text
    }
}

#Preview {
    ExportReviewView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environmentObject(ErrorHandler())
}

