//
//  ParticleAnimation.swift
//  TextParticle
//
//  Created by Minsang Choi on 7/24/24.
//

import SwiftUI

struct ParticleTextAnimation: View {
    
    let content: ParticleContent
    let isFirstFrame: Bool
    var particleCount = 800
        
    @State private var particles: [Particle] = []
    @State private var dragPosition: CGPoint?
    @State private var dragVelocity: CGSize?
    @State private var size: CGSize = .zero
    @State private var showBackground: Bool = false
    
    
    let timer = Timer.publish(every: 1/120, on: .main, in: .common).autoconnect()
        
    var body: some View {
        
        Canvas { context, size in
            
            context.blendMode = .normal
            
            for particle in particles {
                // Compute particle size: particles closer (lower z) appear larger.
                let maxParticleSize: Double = 4.0
                let minParticleSize: Double = 1.0
                let particleSize = maxParticleSize - (maxParticleSize - minParticleSize) * particle.z

                // Compute particle opacity: particles closer (lower z) are more opaque.
                let maxOpacity: Double = 0.9
                let minOpacity: Double = 0.2
                let particleOpacity = maxOpacity - (maxOpacity - minOpacity) * particle.z

                let path = Path(ellipseIn: CGRect(x: particle.x, y: particle.y, width: particleSize, height: particleSize))
                context.fill(path, with: .color(particle.color.opacity(particleOpacity)))
            }
        }
        
        .onReceive(timer) { _ in
            updateParticles()
        }
        .onChange(of: content) {
            toggleBackground()
            createParticles()
        }
        .onAppear {
            createParticles()
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragPosition = value.location
                    dragVelocity = value.velocity
                    triggerHapticFeedback()
                }
            
                .onEnded { value in
                    dragPosition = nil
                    dragVelocity = nil
                    updateParticles()
                }
            
        )
        
        .overlay {
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        size = geometry.size
                        createParticles()
                    }
            }
        }
        .background {
            if showBackground {
                Group {
                    switch content {
                    case .text(let string):
                        Text(string)
                            .font(.system(size: 80, design: .rounded))
                            .bold()
                            .foregroundStyle(.white)
                            .frame(width: 800)
                    case .sfSymbol(let string):
                        Image(systemName: string) .foregroundStyle(.white).font(.system(size: 200))
                    case .view(let anyView):
                        anyView
                    }
                }
                .opacity(0.2)
            }
        }
    }
    
    func toggleBackground() {
        showBackground = false
        Task {
            try await Task.sleep(for: .seconds(isFirstFrame ? 6 : 1))
            withAnimation(.smooth.delay(1)) {
                showBackground = true
            }
        }
    }
    private func createParticles() {
        var renderer = ImageRenderer(content: AnyView(Text("Hello World")))
        switch content {
        case .text(let string):
            renderer = ImageRenderer(content: AnyView(Text(string)
                .font(.system(size: 80, design: .rounded))
                .bold()
                .foregroundStyle(.white)
                .frame(width: 800)))
        case .sfSymbol(let string):
            renderer = ImageRenderer(content: AnyView(Image(systemName: string) .foregroundStyle(.white).font(.system(size: 200))))
        case .view(let view):
            renderer = ImageRenderer(content: view)
        }
        
        renderer.scale = 1.0
        
        guard let image = renderer.uiImage else { return }
        guard let cgImage = image.cgImage else { return }
        
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        
        guard let pixelData = cgImage.dataProvider?.data, let data = CFDataGetBytePtr(pixelData) else { return }
        
        let offsetX = (size.width - CGFloat(width)) / 2
        let offsetY = (size.height - CGFloat(height)) / 2
        
        // Generate new target positions for each particle
        var newTargets: [(Double, Double, Double, Color)] = []
        for _ in 0..<particleCount {
            var px, py: Int
            repeat {
                px = Int.random(in: 0..<width)
                py = Int.random(in: 0..<height)
            } while data[((width * py) + px) * 4 + 3] < 128
            let pixelIndex = ((width * py) + px) * 4
            let r = Double(data[pixelIndex]) / 255.0
            let g = Double(data[pixelIndex + 1]) / 255.0
            let b = Double(data[pixelIndex + 2]) / 255.0
            let brightness = (r + g + b) / 3.0
            let rawDepth = 1 - brightness
            let multiplier: Double
            switch content {
            case .text, .sfSymbol:
                multiplier = 1.5
            default:
                multiplier = 1.0
            }
            let depth = min(1.0, rawDepth * multiplier)
            let pixelColor = Color(red: r, green: g, blue: b)
            newTargets.append((Double(px) + Double(offsetX), Double(py) + Double(offsetY), depth, pixelColor))
        }
        
        if particles.isEmpty {
            // If no particles exist, create new ones with random starting positions.
            particles = newTargets.map { target in
                Particle(
                    x: Double.random(in: -size.width...size.width * 2),
                    y: Double.random(in: 0...size.height * 2),
                    baseX: target.0,
                    baseY: target.1,
                    density: Double.random(in: 5...20),
                    z: target.2,
                    color: target.3
                )
            }
            toggleBackground()
        } else {
            // Otherwise, update the base positions for existing particles so they transition smoothly
            for i in particles.indices {
                let target = newTargets[i % newTargets.count]
                particles[i].baseX = target.0
                particles[i].baseY = target.1
                particles[i].z = target.2
                particles[i].color = target.3
            }
        }
    }
    
    
    
    private func updateParticles() {
        for i in particles.indices {
            withAnimation(.smooth) {
                particles[i].update(dragPosition: dragPosition,
                                    dragVelocity: dragVelocity,
                                    isFirstFrame: isFirstFrame)
            }
        }
    }
}



func triggerHapticFeedback() {
    let impact = UIImpactFeedbackGenerator(style: .light)
    impact.impactOccurred()
}
