//
//  Particle.swift
//  TextParticle
//
//  Created by Minsang Choi on 7/24/24.
//

import SwiftUI

// MARK: - ParticleContent
/// An enum to differentiate between text and SF Symbols for a particle.
enum ParticleContent: Equatable {
    static func == (lhs: ParticleContent, rhs: ParticleContent) -> Bool {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)):
            // Compare associated String values for the .text case
            return a == b
        case (.sfSymbol(let a), .sfSymbol(let b)):
            // Compare associated String values for the .sfSymbol case
            return a == b
        case (.view(_), .view(_)):
            // For views, equality cannot be determined reliably, so return false
            return true
        default:
            // Different cases are not equal
            return false
        }
    }
    
    case text(String)
    case sfSymbol(String)
    case view(AnyView)
    
    var higherDensity: Bool {
        switch self {
        case .text(let _):
            return true
        case .view(let _):
            return false
        default:
            return false
        }
    }
}

struct Particle {
    
    var x: Double
    var y: Double
    var baseX: Double
    var baseY: Double
    let density: Double
    var z: Double
    var color: Color
    var isStopped = false
    var velocityX: Double = 0.0
    var velocityY: Double = 0.0
    
    mutating func update(dragPosition: CGPoint?, dragVelocity: CGSize?, isFirstFrame: Bool) {
        // Spring-damper simulation constants for natural motion
        let springConstant: Double = 0.002
        let damping: Double = isFirstFrame ? 0.55 : 0.7
        
        // Calculate the displacement from the base position
        let dx = baseX - x
        let dy = baseY - y
        
        // Compute acceleration proportional to the displacement and density
        let ax = dx * springConstant * density
        let ay = dy * springConstant * density
        
        // Update velocity with acceleration and apply damping to simulate friction
        velocityX = (velocityX + ax) * damping
        velocityY = (velocityY + ay) * damping
        
        // Update position based on the new velocity
        x += velocityX
        y += velocityY
        
        // If a drag gesture is active, adjust velocity for interactive response
        if let dragPosition = dragPosition {
            let dragDx = x - Double(dragPosition.x)
            let dragDy = y - Double(dragPosition.y)
            
            var velocityF = 0.0
            if let dragVelocity = dragVelocity {
                velocityF = max(abs(dragVelocity.width), abs(dragVelocity.height))
            }
            
            let dragDistance = sqrt(dragDx * dragDx + dragDy * dragDy)
            let dragForce = (200 - min(dragDistance, 200)) / 200 + velocityF * 0.00005
            
            // Slightly adjust the velocity based on the drag force
            velocityX += dragDx * dragForce * 0.005
            velocityY += dragDy * dragForce * 0.005
        }
        
        // Add a constant, subtle noise to maintain slight movement even when nearly static
        let noiseLevel = 0.1
        velocityX += Double.random(in: -noiseLevel...noiseLevel)
        velocityY += Double.random(in: -noiseLevel...noiseLevel)
    }
}
