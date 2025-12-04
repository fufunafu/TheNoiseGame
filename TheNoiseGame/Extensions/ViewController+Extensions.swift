import Foundation
import UIKit

extension ViewController: StimulusControllerDelegate {
    
    func stimulusController(_ controller: StimulusController, didChangeState state: TrialState) {
        DispatchQueue.main.async {
            // Start flickering when moving from idle to any active state
            if state != .idle {
                self.flickerGridView?.startFlickering()
            }
            // Stop flickering when moving back to idle
            if state == .idle {
                self.flickerGridView?.stopFlickering()
                self.flickerGridView?.showStaticCheckerboard()
            }
            
            // Update coherence display
            if state == .coherent {
                let coherence = controller.currentCoherence
                self.updateCoherenceDisplay(coherence: coherence)
                
                // Store the quadrant when entering coherent phase to prevent mid-stimulus changes
                if let trial = controller.currentTrial {
                    self.currentCoherentQuadrant = trial.quadrant
                    // Update the quadrant once when entering coherent phase
                    self.flickerGridView?.updateQuadrant(trial.quadrant)
                    print("🔒 Locking quadrant to \(trial.quadrant.displayName) for coherent stimulus duration")
                }
            } else {
                self.hideCoherenceDisplay()
                
                // Clear stored quadrant when leaving coherent phase
                if state != .coherent {
                    self.currentCoherentQuadrant = nil
                }
            }
            
            // Handle quadrant arrow cue visibility
            if state == .cue {
                // IMPORTANT: Ensure we're showing noise during cue phase, not coherent stimulus
                // The cue should only show the indicator rectangle, not the actual stimulus pattern
                // Use a default seed for cue phase (won't be logged as frame event)
                self.flickerGridView?.showNoise(seed: SeededRandomGenerator.generateSeed())
                
                // Show cue when entering cue state
                // The quadrant should be set by now in currentTrial
                if let trial = controller.currentTrial {
                    print("📍 didChangeState(.cue): Showing cue for quadrant: \(trial.quadrant.displayName)")
                    self.showQuadrantArrow(quadrant: trial.quadrant)
                } else {
                    print("⚠️ WARNING: Entering cue state but currentTrial is nil")
                }
            } else {
                // Hide quadrant arrow cue when leaving cue state
                self.hideQuadrantArrow()
            }
            
            // Check for automatic reward when transitioning to interTrial (MISS case)
            if state == .interTrial && controller.wasAutomaticRewardGiven {
                // Show heart feedback for automatic reward on MISS
                self.showPositiveFeedback()
                self.playGoodSound()
            }
            
            self.updateUIState()
        }
    }
    
    func stimulusController(_ controller: StimulusController, didStartTrial trial: TrialConfig) {
        DispatchQueue.main.async {
            // Ensure flickering is started when trials begin
            self.flickerGridView?.startFlickering()
            
            // IMPORTANT: Do NOT update the quadrant here - it will be updated when entering .coherent state
            // Updating it here causes artifacts where the stimulus pattern appears during the cue phase
            // The cue phase should only show the arrow indicator, not the actual stimulus pattern
            print("🎯 Trial started: Quadrant will be \(trial.quadrant.displayName) (will be set at coherent phase)")
            
            // Verify the controller's currentTrial matches (for debugging)
            if let controllerTrial = controller.currentTrial {
                if controllerTrial.trialIndex != trial.trialIndex || controllerTrial.quadrant != trial.quadrant {
                    print("⚠️ WARNING: Mismatch! Controller trial index: \(controllerTrial.trialIndex), quadrant: \(controllerTrial.quadrant.displayName)")
                } else {
                    print("✓ Trial quadrant verified: \(trial.quadrant.displayName)")
                }
            }
            
            // Hide psychometric plot if visible (new trials starting)
            self.closePsychometricPlot()
            
            self.updateUIState()
        }
    }
    
    func stimulusController(_ controller: StimulusController, didCompleteTrials results: [TrialResult]) {
        DispatchQueue.main.async {
            // Stop flickering when trials complete
            self.flickerGridView?.stopFlickering()
            self.flickerGridView?.showStaticCheckerboard()
            self.updateUIState()
            
            // Show psychometric curve
            self.showPsychometricCurve(results: results)
            
            self.showAlert(title: "Trials Complete", message: "Completed \(results.count) trials. Data is ready for export.")
        }
    }
    
    func stimulusController(_ controller: StimulusController, requestsFrameUpdate frameType: FrameType) {
        // With the new FlickerGridView, we just control the pattern type
        // The flickering happens continuously in the background
        
        switch frameType {
        case .noise(let seed):
            flickerGridView?.showNoise(seed: seed)
            
        case .coherent(let coherence, let gratingContrast, let seed):
            // Use the stored quadrant (set when entering coherent phase) to prevent mid-stimulus changes
            // This ensures the quadrant stays consistent throughout the entire coherent stimulus duration
            // The quadrant was already set when entering coherent phase, so we don't need to update it every frame
            if currentCoherentQuadrant == nil {
                // Fallback: if no stored quadrant, use current trial (shouldn't happen normally)
                // This means the state change didn't set it properly
                if let trial = controller.currentTrial {
                    currentCoherentQuadrant = trial.quadrant
                    flickerGridView?.updateQuadrant(trial.quadrant)
                    print("⚠️ Fallback: Using currentTrial quadrant \(trial.quadrant.displayName) (should have been set on state change)")
                }
            }
            // Quadrant is locked and maintained by FlickerGridView - just show the coherent stimulus with pre-generated seed
            flickerGridView?.showCoherent(coherence: coherence, gratingContrast: gratingContrast, seed: seed)
            
        case .fixation:
            // Keep showing noise during fixation (no seed needed for static display)
            flickerGridView?.showStaticCheckerboard()
        }
    }
}
