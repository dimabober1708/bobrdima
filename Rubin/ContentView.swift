//
//  ContentView.swift
//  Rubin - Polarity Rush
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Settings

enum Difficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
    case insane = "Insane"
    
    var id: String { rawValue }
    
    var startingSpeedMultiplier: CGFloat {
        switch self {
        case .easy: return 0.7
        case .normal: return 1.0
        case .hard: return 1.3
        case .insane: return 1.8
        }
    }
    
    var damageMultiplier: CGFloat {
        switch self {
        case .easy: return 0.7
        case .normal: return 1.0
        case .hard: return 1.3
        case .insane: return 1.8
        }
    }
    
    var scoreMultiplier: CGFloat {
        switch self {
        case .easy: return 0.5
        case .normal: return 1.0
        case .hard: return 1.5
        case .insane: return 2.5
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .normal: return .blue
        case .hard: return .orange
        case .insane: return .red
        }
    }
}

class GameSettings: ObservableObject {
    @Published var difficulty: Difficulty = .normal
    @Published var showGrid: Bool = true
    @Published var hapticEnabled: Bool = true
    @Published var polarityButtonSize: CGFloat = 80
    @Published var playerTrail: Bool = true
    
    func resetToDefaults() {
        difficulty = .normal
        showGrid = true
        hapticEnabled = true
        polarityButtonSize = 80
        playerTrail = true
    }
}

// MARK: - Game Models

enum Polarity: CaseIterable {
    case positive
    case negative
    
    var color: Color {
        switch self {
        case .positive: return Color(red: 1.0, green: 0.3, blue: 0.4)
        case .negative: return Color(red: 0.3, green: 0.6, blue: 1.0)
        }
    }
    
    var symbol: String {
        switch self {
        case .positive: return "+"
        case .negative: return "−"
        }
    }
    
    var opposite: Polarity {
        self == .positive ? .negative : .positive
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var polarity: Polarity
    var size: CGFloat
    var isBonus: Bool = false
    
    mutating func update(playerPosition: CGPoint, playerPolarity: Polarity, bounds: CGSize, speedMultiplier: CGFloat) {
        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        
        if distance > 10 {
            let force: CGFloat = polarity == playerPolarity ? -800 : 600
            let strength = force / (distance * distance) * 60 * speedMultiplier
            
            velocity.dx += (dx / distance) * strength
            velocity.dy += (dy / distance) * strength
        }
        
        let maxSpeed: CGFloat = 400 * speedMultiplier
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > maxSpeed {
            velocity.dx = (velocity.dx / speed) * maxSpeed
            velocity.dy = (velocity.dy / speed) * maxSpeed
        }
        
        let friction = max(0.95, 0.98 - (speedMultiplier - 1.0) * 0.02)
        velocity.dx *= friction
        velocity.dy *= friction
        
        position.x += velocity.dx * 0.016 * speedMultiplier
        position.y += velocity.dy * 0.016 * speedMultiplier
        
        if position.x < size {
            position.x = size
            velocity.dx = abs(velocity.dx) * 0.8
        }
        if position.x > bounds.width - size {
            position.x = bounds.width - size
            velocity.dx = -abs(velocity.dx) * 0.8
        }
        if position.y < size {
            position.y = size
            velocity.dy = abs(velocity.dy) * 0.8
        }
        if position.y > bounds.height - size {
            position.y = bounds.height - size
            velocity.dy = -abs(velocity.dy) * 0.8
        }
    }
}

// MARK: - Game State

class GameState: ObservableObject {
    @Published var playerPosition: CGPoint = .zero
    @Published var playerPolarity: Polarity = .positive
    @Published var particles: [Particle] = []
    @Published var score: Int = 0
    @Published var health: Int = 100
    @Published var combo: Int = 1
    @Published var isGameOver: Bool = false
    @Published var isPlaying: Bool = false
    @Published var highScore: Int = 0
    @Published var screenShake: CGFloat = 0
    @Published var pulseEffect: CGFloat = 1.0
    
    var settings: GameSettings = GameSettings()
    
    var speedMultiplier: CGFloat {
        let baseMultiplier = settings.difficulty.startingSpeedMultiplier
        let scoreBonus = CGFloat(score) / 500.0
        return min(baseMultiplier + scoreBonus, 3.5)
    }
    
    var gameSize: CGSize = .zero
    var timer: Timer?
    var spawnTimer: Timer?
    var lastCollectTime: Date = Date()
    
    func startGame(size: CGSize) {
        gameSize = size
        playerPosition = CGPoint(x: size.width / 2, y: size.height / 2)
        playerPolarity = .positive
        particles = []
        score = 0
        health = 100
        combo = 1
        isGameOver = false
        isPlaying = true
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        
        scheduleNextSpawn()
        
        for _ in 0..<5 {
            spawnParticle()
        }
    }
    
    func stopGame() {
        timer?.invalidate()
        spawnTimer?.invalidate()
        timer = nil
        spawnTimer = nil
        isPlaying = false
        if score > highScore {
            highScore = score
        }
    }
    
    func scheduleNextSpawn() {
        guard isPlaying else { return }
        
        let interval = max(0.4, 1.2 / Double(speedMultiplier))
        
        spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.spawnParticle()
            self?.scheduleNextSpawn()
        }
    }
    
    func togglePolarity() {
        playerPolarity = playerPolarity.opposite
        
        if settings.hapticEnabled {
            triggerLightHaptic()
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            pulseEffect = 1.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                self.pulseEffect = 1.0
            }
        }
    }
    
    func spawnParticle() {
        guard isPlaying, gameSize.width > 100, gameSize.height > 100 else { return }
        
        let edge = Int.random(in: 0..<4)
        var position: CGPoint
        var velocity: CGVector
        
        switch edge {
        case 0:
            position = CGPoint(x: CGFloat.random(in: 50...(gameSize.width - 50)), y: -30)
            velocity = CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: 30...80))
        case 1:
            position = CGPoint(x: CGFloat.random(in: 50...(gameSize.width - 50)), y: gameSize.height + 30)
            velocity = CGVector(dx: CGFloat.random(in: -50...50), dy: CGFloat.random(in: -80...(-30)))
        case 2:
            position = CGPoint(x: -30, y: CGFloat.random(in: 50...(gameSize.height - 50)))
            velocity = CGVector(dx: CGFloat.random(in: 30...80), dy: CGFloat.random(in: -50...50))
        default:
            position = CGPoint(x: gameSize.width + 30, y: CGFloat.random(in: 50...(gameSize.height - 50)))
            velocity = CGVector(dx: CGFloat.random(in: -80...(-30)), dy: CGFloat.random(in: -50...50))
        }
        
        let isBonus = Int.random(in: 0..<10) == 0
        let particle = Particle(
            position: position,
            velocity: velocity,
            polarity: Polarity.allCases.randomElement()!,
            size: isBonus ? 25 : CGFloat.random(in: 15...22),
            isBonus: isBonus
        )
        
        particles.append(particle)
        
        if particles.count > 25 {
            particles.removeFirst()
        }
    }
    
    func update() {
        guard isPlaying && !isGameOver else { return }
        
        for i in particles.indices {
            particles[i].update(playerPosition: playerPosition, playerPolarity: playerPolarity, bounds: gameSize, speedMultiplier: speedMultiplier)
        }
        
        checkCollisions()
        
        if screenShake > 0 {
            screenShake *= 0.9
        }
        
        if Date().timeIntervalSince(lastCollectTime) > 2.0 && combo > 1 {
            combo = 1
        }
    }
    
    func checkCollisions() {
        var particlesToRemove: Set<UUID> = []
        let playerRadius: CGFloat = 30
        
        for particle in particles {
            let dx = playerPosition.x - particle.position.x
            let dy = playerPosition.y - particle.position.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < playerRadius + particle.size {
                particlesToRemove.insert(particle.id)
                
                if particle.polarity != playerPolarity {
                    let basePoints = particle.isBonus ? 50 : 10
                    let points = Int(CGFloat(basePoints * combo) * settings.difficulty.scoreMultiplier)
                    score += points
                    combo = min(combo + 1, 10)
                    lastCollectTime = Date()
                    
                    if particle.isBonus {
                        health = min(health + 20, 100)
                    }
                } else {
                    let baseDamage = particle.isBonus ? 30 : 15
                    let damage = Int(CGFloat(baseDamage) * settings.difficulty.damageMultiplier)
                    health -= damage
                    combo = 1
                    screenShake = 10
                    
                    if settings.hapticEnabled {
                        triggerHeavyHaptic()
                    }
                    
                    if health <= 0 {
                        health = 0
                        isGameOver = true
                        stopGame()
                    }
                }
            }
        }
        
        particles.removeAll { particlesToRemove.contains($0.id) }
    }
    
    func triggerHeavyHaptic() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
    
    func triggerLightHaptic() {
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    func movePlayer(to position: CGPoint) {
        let margin: CGFloat = 35
        playerPosition = CGPoint(
            x: min(max(position.x, margin), gameSize.width - margin),
            y: min(max(position.y, margin), gameSize.height - margin)
        )
    }
}

// MARK: - Views

struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [particle.polarity.color.opacity(0.6), particle.polarity.color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: particle.size * 1.5
                    )
                )
                .frame(width: particle.size * 3, height: particle.size * 3)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [particle.polarity.color, particle.polarity.color.opacity(0.7)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: particle.size
                    )
                )
                .frame(width: particle.size * 2, height: particle.size * 2)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: particle.isBonus ? 3 : 1)
                )
            
            Text(particle.polarity.symbol)
                .font(.system(size: particle.size * 0.8, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            if particle.isBonus {
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: particle.size * 2.5, height: particle.size * 2.5)
            }
        }
        .position(particle.position)
    }
}

struct PlayerView: View {
    let position: CGPoint
    let polarity: Polarity
    let pulseEffect: CGFloat
    var showTrail: Bool = true
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [polarity.color.opacity(0.4), polarity.color.opacity(0)],
                        center: .center,
                        startRadius: 20,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
            
            if showTrail {
                ForEach(0..<6, id: \.self) { i in
                    Capsule()
                        .fill(polarity.color.opacity(0.3))
                        .frame(width: 4, height: 50)
                        .offset(y: -40)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                .rotationEffect(.degrees(Date().timeIntervalSinceReferenceDate * 30))
            }
            
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [polarity.color, polarity.color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 70, height: 70)
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, polarity.color],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 35
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: polarity.color, radius: 15)
            
            Text(polarity.symbol)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
        .scaleEffect(pulseEffect)
        .position(position)
        .animation(.easeInOut(duration: 0.1), value: polarity)
    }
}

struct HealthBar: View {
    let health: Int
    
    var healthColor: Color {
        if health > 60 { return .green }
        if health > 30 { return .orange }
        return .red
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HEALTH")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 120, height: 12)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [healthColor, healthColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: CGFloat(health) / 100 * 120, height: 12)
                    .animation(.spring(response: 0.3), value: health)
            }
        }
    }
}

struct GameHUD: View {
    let score: Int
    let combo: Int
    let health: Int
    let polarity: Polarity
    let speedMultiplier: CGFloat
    var buttonSize: CGFloat = 80
    let onTogglePolarity: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(score)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    if combo > 1 {
                        Text("×\(combo) COMBO")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    SpeedIndicator(multiplier: speedMultiplier)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 12) {
                    Button(action: onExit) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                            Text("EXIT")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                    }
                    
                    HealthBar(health: health)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            
            Spacer()
            
            Button(action: onTogglePolarity) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [polarity.color, polarity.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(color: polarity.color.opacity(0.5), radius: 10)
                    
                    VStack(spacing: 2) {
                        Text(polarity.symbol)
                            .font(.system(size: buttonSize * 0.45, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("TAP")
                            .font(.system(size: buttonSize * 0.125, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(.bottom, 40)
        }
    }
}

struct SpeedIndicator: View {
    let multiplier: CGFloat
    
    var speedColor: Color {
        if multiplier < 1.5 { return .green }
        if multiplier < 2.0 { return .yellow }
        if multiplier < 2.5 { return .orange }
        return .red
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundColor(speedColor)
            
            Text(String(format: "×%.1f", multiplier))
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(speedColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(speedColor.opacity(0.2))
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.3), value: multiplier)
    }
}

struct GameOverView: View {
    let score: Int
    let highScore: Int
    let maxSpeed: CGFloat
    let onRestart: () -> Void
    let onMainMenu: () -> Void
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("GAME OVER")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    Text("SCORE")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(score)")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Max Speed: ×\(String(format: "%.1f", maxSpeed))")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                    
                    if score >= highScore && score > 0 {
                        Text("🏆 NEW HIGH SCORE!")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    } else {
                        Text("Best: \(highScore)")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                VStack(spacing: 16) {
                    Button(action: onRestart) {
                        Text("PLAY AGAIN")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(30)
                            .shadow(color: .white.opacity(0.3), radius: 10)
                    }
                    
                    Button(action: onMainMenu) {
                        Text("MAIN MENU")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(25)
                    }
                }
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}

struct StartMenuView: View {
    let highScore: Int
    let difficulty: Difficulty
    let onStart: () -> Void
    let onSettings: () -> Void
    
    @State private var showContent = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(
                        i % 2 == 0 ?
                        Color(red: 1.0, green: 0.3, blue: 0.4).opacity(0.1) :
                        Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.1)
                    )
                    .frame(width: CGFloat.random(in: 100...200))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: CGFloat.random(in: -300...300)
                    )
                    .blur(radius: 30)
            }
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .opacity(showContent ? 1 : 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                Spacer()
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 200, height: 200)
                            .scaleEffect(pulseAnimation ? 1.1 : 0.9)
                        
                        HStack(spacing: 20) {
                            Text("+")
                                .font(.system(size: 60, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.4))
                            
                            Text("−")
                                .font(.system(size: 60, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 1.0))
                        }
                    }
                    
                    Text("POLARITY")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("RUSH")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(12)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                
                Spacer()
                
                VStack(spacing: 16) {
                    HStack(spacing: 30) {
                        InstructionItem(
                            symbol: "+",
                            color: Color(red: 1.0, green: 0.3, blue: 0.4),
                            text: "Positive"
                        )
                        
                        InstructionItem(
                            symbol: "−",
                            color: Color(red: 0.3, green: 0.6, blue: 1.0),
                            text: "Negative"
                        )
                    }
                    
                    Text("Collect opposite polarity\nAvoid same polarity")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Button(action: onStart) {
                        Text("START GAME")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 50)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.6, green: 0.3, blue: 1.0),
                                        Color(red: 0.4, green: 0.2, blue: 0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(30)
                            .shadow(color: Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.5), radius: 15)
                    }
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 12))
                        Text(difficulty.rawValue)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(difficulty.color)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(difficulty.color.opacity(0.2))
                    .cornerRadius(20)
                }
                .opacity(showContent ? 1 : 0)
                
                if highScore > 0 {
                    Text("High Score: \(highScore)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer()
                    .frame(height: 50)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }
}

struct InstructionItem: View {
    let symbol: String
    let color: Color
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(symbol)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(color)
            }
            
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct GameView: View {
    @StateObject private var gameState = GameState()
    @ObservedObject var settings: GameSettings
    let onExitToMenu: (Int) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.15),
                        Color(red: 0.05, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if settings.showGrid {
                    GridBackground()
                }
                
                ForEach(gameState.particles) { particle in
                    ParticleView(particle: particle)
                }
                
                PlayerView(
                    position: gameState.playerPosition,
                    polarity: gameState.playerPolarity,
                    pulseEffect: gameState.pulseEffect,
                    showTrail: settings.playerTrail
                )
                
                GameHUD(
                    score: gameState.score,
                    combo: gameState.combo,
                    health: gameState.health,
                    polarity: gameState.playerPolarity,
                    speedMultiplier: gameState.speedMultiplier,
                    buttonSize: settings.polarityButtonSize,
                    onTogglePolarity: { gameState.togglePolarity() },
                    onExit: {
                        gameState.stopGame()
                        onExitToMenu(gameState.highScore)
                    }
                )
            }
            .offset(
                x: CGFloat.random(in: -gameState.screenShake...gameState.screenShake),
                y: CGFloat.random(in: -gameState.screenShake...gameState.screenShake)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        gameState.movePlayer(to: value.location)
                    }
            )
            .onAppear {
                gameState.settings = settings
                gameState.startGame(size: geometry.size)
            }
            .onDisappear {
                gameState.stopGame()
            }
            .overlay {
                if gameState.isGameOver {
                    GameOverView(
                        score: gameState.score,
                        highScore: gameState.highScore,
                        maxSpeed: gameState.speedMultiplier,
                        onRestart: {
                            gameState.startGame(size: geometry.size)
                        },
                        onMainMenu: {
                            gameState.stopGame()
                            onExitToMenu(gameState.highScore)
                        }
                    )
                }
            }
        }
    }
}

struct GridBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            
            for x in stride(from: 0, to: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 1)
            }
            
            for y in stride(from: 0, to: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.white.opacity(0.03)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var settings: GameSettings
    @Binding var highScore: Int
    let onBack: () -> Void
    
    @State private var showResetAlert = false
    @State private var showResetScoreAlert = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                ScrollView {
                    VStack(spacing: 24) {
                        SettingsSection(title: "DIFFICULTY") {
                            VStack(spacing: 12) {
                                ForEach(Difficulty.allCases) { difficulty in
                                    DifficultyButton(
                                        difficulty: difficulty,
                                        isSelected: settings.difficulty == difficulty,
                                        action: { settings.difficulty = difficulty }
                                    )
                                }
                            }
                        }
                        
                        SettingsSection(title: "GAMEPLAY") {
                            VStack(spacing: 16) {
                                SettingsToggle(
                                    title: "Background Grid",
                                    subtitle: "Decorative grid pattern",
                                    icon: "grid",
                                    isOn: $settings.showGrid
                                )
                                
                                SettingsToggle(
                                    title: "Haptic Feedback",
                                    subtitle: "Vibration on damage",
                                    icon: "iphone.radiowaves.left.and.right",
                                    isOn: $settings.hapticEnabled
                                )
                                
                                SettingsToggle(
                                    title: "Player Trail",
                                    subtitle: "Magnetic field effect",
                                    icon: "sparkles",
                                    isOn: $settings.playerTrail
                                )
                            }
                        }
                        
                        SettingsSection(title: "CONTROLS") {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "circle.circle")
                                            .font(.system(size: 18))
                                            .foregroundColor(.purple)
                                            .frame(width: 30)
                                        
                                        Text("Button Size")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(settings.polarityButtonSize))")
                                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Slider(value: $settings.polarityButtonSize, in: 60...120, step: 10)
                                        .tint(.purple)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                            }
                        }
                        
                        SettingsSection(title: "DATA") {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "trophy.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.yellow)
                                        .frame(width: 30)
                                    
                                    Text("High Score")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(highScore)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.yellow)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(12)
                                
                                Button(action: { showResetScoreAlert = true }) {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.system(size: 18))
                                            .foregroundColor(.orange)
                                            .frame(width: 30)
                                        
                                        Text("Reset High Score")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                                
                                Button(action: { showResetAlert = true }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 18))
                                            .foregroundColor(.red)
                                            .frame(width: 30)
                                        
                                        Text("Reset All Settings")
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        
                                        Spacer()
                                    }
                                    .padding(16)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text("POLARITY RUSH")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Version 1.0")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .alert("Reset Settings?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("All settings will be reset to defaults.")
        }
        .alert("Reset High Score?", isPresented: $showResetScoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                highScore = 0
            }
        } message: {
            Text("Your high score will be reset to zero.")
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .padding(.leading, 4)
            
            content
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.purple)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(.purple)
                .labelsHidden()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct DifficultyButton: View {
    let difficulty: Difficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.rawValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    
                    HStack(spacing: 12) {
                        Label("×\(String(format: "%.1f", difficulty.scoreMultiplier))", systemImage: "star.fill")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.yellow.opacity(0.8))
                        
                        Label("×\(String(format: "%.1f", difficulty.damageMultiplier))", systemImage: "heart.fill")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                        
                        Label("×\(String(format: "%.1f", difficulty.startingSpeedMultiplier))", systemImage: "bolt.fill")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.8))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(difficulty.color)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? difficulty.color.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? difficulty.color : Color.clear, lineWidth: 2)
                    )
            )
        }
    }
}

// MARK: - Main View

enum Screen {
    case menu
    case game
    case settings
}

struct ContentView: View {
    @State private var currentScreen: Screen = .menu
    @State private var highScore = 0
    @StateObject private var settings = GameSettings()
    
    var body: some View {
        ZStack {
            switch currentScreen {
            case .menu:
                StartMenuView(
                    highScore: highScore,
                    difficulty: settings.difficulty,
                    onStart: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .game
                        }
                    },
                    onSettings: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .settings
                        }
                    }
                )
                .transition(.opacity)
                
            case .game:
                GameView(
                    settings: settings,
                    onExitToMenu: { newHighScore in
                        highScore = max(highScore, newHighScore)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .menu
                        }
                    }
                )
                .transition(.opacity)
                
            case .settings:
                SettingsView(
                    settings: settings,
                    highScore: $highScore,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentScreen = .menu
                        }
                    }
                )
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ContentView()
}
