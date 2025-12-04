import Foundation
import UIKit

// MARK: - Display Ticker (VSync-locked timing)
class DisplayTicker {
    
    // MARK: - Properties
    weak var delegate: DisplayTickerDelegate?
    
    private var displayLink: CADisplayLink?
    private var isRunning = false
    private var frameCount = 0
    private var stimulusFrameCount = 0
    
    // Display properties
    private var detectedRefreshRate: Int = 60
    private var updatesPerFrame: Int = 2  // Default for 60Hz -> 30Hz
    
    // Timing validation
    private var lastUpdateTime: CFTimeInterval = 0
    private var frameTimes: [CFTimeInterval] = []
    private let maxFrameTimesSamples = 120  // 2 seconds at 60Hz
    
    // MARK: - Public Interface
    
    /// Current detected refresh rate
    var refreshRate: Int {
        return detectedRefreshRate
    }
    
    /// Number of display updates per stimulus frame
    var stimulusUpdatesPerFrame: Int {
        return updatesPerFrame
    }
    
    /// Actual stimulus frame rate
    var actualStimulusRate: Double {
        return Double(detectedRefreshRate) / Double(updatesPerFrame)
    }
    
    /// Whether the ticker is currently running
    var isActive: Bool {
        return isRunning
    }
    
    /// Total number of stimulus frames generated
    var totalStimulusFrames: Int {
        return stimulusFrameCount
    }
    
    // MARK: - Control Methods
    
    /// Start the display ticker
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        frameCount = 0
        stimulusFrameCount = 0
        lastUpdateTime = 0
        frameTimes.removeAll()
        
        // Create and configure display link
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        
        // Try to get the actual refresh rate from the main screen
        if #available(iOS 10.3, *) {
            detectedRefreshRate = Int(UIScreen.main.maximumFramesPerSecond)
        } else {
            detectedRefreshRate = 60  // Fallback
        }
        
        // Calculate updates per frame for target stimulus Hz
        updatesPerFrame = max(1, Int(round(Double(detectedRefreshRate) / Double(StimulusParams.targetStimHz))))
        
        // Configure display link for optimal performance
        // Don't set preferredFramesPerSecond - let it run at native display rate
        // This ensures we never miss frames and can downsample consistently
        
        // Add to run loop with tracking mode for consistent timing even during scrolling/gestures
        displayLink?.add(to: .main, forMode: .common)
        
        // Notify delegate of detected refresh rate
        delegate?.displayTicker(self, didDetectRefreshRate: detectedRefreshRate)
        
        print("DisplayTicker started: \(detectedRefreshRate)Hz display, updating every \(updatesPerFrame) frames for ~\(actualStimulusRate)Hz stimulus")
    }
    
    /// Stop the display ticker
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        
        print("DisplayTicker stopped: Generated \(stimulusFrameCount) stimulus frames")
    }
    
    /// Reset frame counters
    func reset() {
        frameCount = 0
        stimulusFrameCount = 0
        lastUpdateTime = 0
        frameTimes.removeAll()
    }
    
    // MARK: - Display Link Callback
    
    @objc private func displayLinkFired(_ displayLink: CADisplayLink) {
        guard isRunning else { return }
        
        frameCount += 1
        
        // Record frame timing for validation
        recordFrameTiming(displayLink.timestamp)
        
        // Check if we should update the stimulus using modulo for consistent frame pacing
        // This ensures regular updates even if occasional frames are slightly delayed
        if frameCount % updatesPerFrame == 0 {
            stimulusFrameCount += 1
            
            // Call delegate on the same thread (main thread) to maintain timing
            // Don't dispatch async - keep it synchronous for precise timing
            delegate?.displayTicker(self, shouldUpdateFrame: stimulusFrameCount)
        }
    }
    
    // MARK: - Timing Validation
    
    private func recordFrameTiming(_ timestamp: CFTimeInterval) {
        if lastUpdateTime > 0 {
            let frameTime = timestamp - lastUpdateTime
            frameTimes.append(frameTime)
            
            // Keep only recent samples
            if frameTimes.count > maxFrameTimesSamples {
                frameTimes.removeFirst()
            }
        }
        lastUpdateTime = timestamp
    }
    
    /// Get timing statistics for validation
    func getTimingStats() -> TimingStats? {
        guard frameTimes.count > 10 else { return nil }
        
        let sortedTimes = frameTimes.sorted()
        let count = sortedTimes.count
        
        let mean = sortedTimes.reduce(0, +) / Double(count)
        let median = sortedTimes[count / 2]
        let p95 = sortedTimes[Int(Double(count) * 0.95)]
        
        let expectedFrameTime = 1.0 / Double(detectedRefreshRate)
        let jitter = sortedTimes.map { abs($0 - expectedFrameTime) }.reduce(0, +) / Double(count)
        
        return TimingStats(
            meanFrameTime: mean,
            medianFrameTime: median,
            p95FrameTime: p95,
            expectedFrameTime: expectedFrameTime,
            averageJitter: jitter,
            sampleCount: count
        )
    }
    
    /// Check if timing is within acceptable bounds
    func isTimingAccurate(tolerance: Double = 0.001) -> Bool {
        guard let stats = getTimingStats() else { return false }
        return stats.averageJitter < tolerance
    }
    
    deinit {
        stop()
    }
}

