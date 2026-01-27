import SwiftUI
import CoreData
#if canImport(Charts)
import Charts
#endif

struct SuccessInsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FinancialDecision.date, ascending: true)],
        animation: .default
    ) private var decisions: FetchedResults<FinancialDecision>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.name, ascending: true)],
        animation: .default
    ) private var categories: FetchedResults<Category>
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Overall Stats
                    OverallStatsCard(decisions: Array(decisions))
                    
                    // Success by Category
                    if hasRatedDecisions {
                        SuccessByCategoryChart(decisions: Array(decisions), categories: Array(categories))
                    }
                    
                    // Insights
                    InsightsCard(decisions: Array(decisions))
                    
                    // Patterns
                    PatternsCard(decisions: Array(decisions))
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Insights")
        }
    }
    
    private var hasRatedDecisions: Bool {
        decisions.contains { $0.successRating > 0 }
    }
}

struct OverallStatsCard: View {
    let decisions: [FinancialDecision]
    
    private var totalDecisions: Int {
        decisions.count
    }
    
    private var ratedDecisions: [FinancialDecision] {
        decisions.filter { $0.successRating > 0 }
    }
    
    private var averageSuccess: Double {
        let ratings = ratedDecisions.map { Double($0.successRating) }
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0, +) / Double(ratings.count) / 10.0
    }
    
    private var bestMonth: String {
        let monthRatings = Dictionary(grouping: ratedDecisions) { decision -> String in
            guard let date = decision.date else { return "" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
        
        let averages = monthRatings.mapValues { decisions in
            let ratings = decisions.map { Double($0.successRating) }
            return ratings.isEmpty ? 0.0 : ratings.reduce(0, +) / Double(ratings.count)
        }
        
        return averages.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Overall Statistics")
                .font(.system(size: 22, weight: .semibold))
            
            HStack(spacing: 24) {
                StatBox(title: "Total", value: "\(totalDecisions)")
                StatBox(title: "Rated", value: "\(ratedDecisions.count)")
                StatBox(title: "Avg Success", value: "\(Int(averageSuccess * 100))%")
            }
            
            if !bestMonth.isEmpty && bestMonth != "N/A" {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(AppColors.learning)
                    Text("Best Month: \(bestMonth)")
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SuccessRateChart: View {
    let decisions: [FinancialDecision]
    
    private var monthlyData: [(month: String, rate: Double, date: Date)] {
        let ratedDecisions = decisions.filter { $0.successRating > 0 && $0.date != nil }
        
        guard !ratedDecisions.isEmpty else { return [] }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        
        let grouped = Dictionary(grouping: ratedDecisions) { decision -> String in
            guard let date = decision.date else { return "" }
            return formatter.string(from: date)
        }
        
        return grouped.compactMap { month, decisions in
            guard !month.isEmpty, let firstDate = decisions.first?.date else { return nil }
            let ratings = decisions.map { Double($0.successRating) }
            guard !ratings.isEmpty else { return nil }
            let avg = ratings.reduce(0, +) / Double(ratings.count) / 10.0
            return (month: month, rate: avg, date: firstDate)
        }.sorted { $0.date < $1.date }
    }
    
    private var chartData: [(month: String, rate: Double)] {
        let data = monthlyData.map { (month: $0.month, rate: $0.rate) }
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Success Rate Over Time")
                .font(.system(size: 22, weight: .semibold))
            
            if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("Add more rated decisions to see trends")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            } else {
                ZStack {
                    if #available(iOS 16.0, *) {
                        #if canImport(Charts)
                        Chart {
                            ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                                LineMark(
                                    x: .value("Month", data.month),
                                    y: .value("Rate", data.rate)
                                )
                                .foregroundStyle(AppColors.success)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Month", data.month),
                                    y: .value("Rate", data.rate)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.success.opacity(0.3), AppColors.success.opacity(0.0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .frame(height: 200)
                        #else
                        SimpleChartView(data: chartData)
                        #endif
                    } else {
                        SimpleChartView(data: chartData)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct SuccessByCategoryChart: View {
    let decisions: [FinancialDecision]
    let categories: [Category]
    
    private var categoryData: [(category: String, rate: Double)] {
        categories.compactMap { category in
            let categoryDecisions = decisions.filter { $0.category == category && $0.successRating > 0 }
            guard !categoryDecisions.isEmpty else { return nil }
            
            let ratings = categoryDecisions.map { Double($0.successRating) }
            let avg = ratings.reduce(0, +) / Double(ratings.count) / 10.0
            return (category: category.name ?? "Unknown", rate: avg)
        }.sorted { $0.rate > $1.rate }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Success by Category")
                .font(.system(size: 22, weight: .semibold))
            
            if #available(iOS 16.0, *) {
                #if canImport(Charts)
                Chart {
                    ForEach(categoryData, id: \.category) { data in
                        BarMark(
                            x: .value("Category", data.category),
                            y: .value("Rate", data.rate)
                        )
                        .foregroundStyle(AppColors.reflection)
                    }
                }
                .frame(height: 200)
                #else
                CategoryChartView(data: categoryData)
                #endif
            } else {
                CategoryChartView(data: categoryData)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct InsightsCard: View {
    let decisions: [FinancialDecision]
    
    private var mostImprovedCategory: String {
        // Simplified - would need more complex logic for real improvement tracking
        let categoryCounts = Dictionary(grouping: decisions.filter { $0.successRating > 0 }) { decision -> String in
            decision.category?.name ?? "Uncategorized"
        }
        let categoryAverages = categoryCounts.mapValues { decisions in
            let ratings = decisions.map { Double($0.successRating) }
            return ratings.isEmpty ? 0.0 : ratings.reduce(0, +) / Double(ratings.count)
        }
        return categoryAverages.max(by: { $0.value < $1.value })?.key ?? "N/A"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.system(size: 22, weight: .semibold))
            
            if mostImprovedCategory != "N/A" {
                InsightRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Best Performing Category",
                    value: mostImprovedCategory,
                    color: AppColors.success
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
            }
        }
    }
}

struct PatternsCard: View {
    let decisions: [FinancialDecision]
    
    private var emotionSuccessCorrelation: String {
        let ratedDecisions = decisions.filter { $0.successRating > 0 }
        guard !ratedDecisions.isEmpty else { return "N/A" }
        
        let highEmotion = ratedDecisions.filter { $0.emotionalState >= 7 }
        let lowEmotion = ratedDecisions.filter { $0.emotionalState <= 4 }
        
        let highEmotionAvg = highEmotion.map { Double($0.successRating) }.reduce(0, +) / Double(highEmotion.count)
        let lowEmotionAvg = lowEmotion.map { Double($0.successRating) }.reduce(0, +) / Double(lowEmotion.count)
        
        if highEmotionAvg < lowEmotionAvg {
            return "High emotion decisions tend to have lower success rates"
        } else {
            return "Emotional state doesn't significantly impact success"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Patterns")
                .font(.system(size: 22, weight: .semibold))
            
            if emotionSuccessCorrelation != "N/A" {
                Text(emotionSuccessCorrelation)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
    }
}

struct SimpleChartView: View {
    let data: [(month: String, rate: Double)]
    
    private var maxRate: Double {
        let max = data.map { $0.rate }.max() ?? 1.0
        return max > 0 ? max : 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No data to display")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.month)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 85, alignment: .leading)
                            
                            Spacer()
                            
                            Text("\(Int(item.rate * 100))%")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppColors.success)
                                .frame(width: 50, alignment: .trailing)
                        }
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 10)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.success)
                                    .frame(
                                        width: max(10, geometry.size.width * CGFloat(item.rate / maxRate)),
                                        height: 10
                                    )
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(height: 200)
    }
}

struct CategoryChartView: View {
    let data: [(category: String, rate: Double)]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(data, id: \.category) { item in
                HStack {
                    Text(item.category)
                        .font(.system(size: 14, weight: .regular))
                    Spacer()
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 20)
                                .cornerRadius(10)
                            
                            Rectangle()
                                .fill(AppColors.reflection)
                                .frame(width: geometry.size.width * CGFloat(item.rate), height: 20)
                                .cornerRadius(10)
                        }
                    }
                    .frame(height: 20)
                    
                    Text("\(Int(item.rate * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.reflection)
                        .frame(width: 50, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    SuccessInsightsView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

