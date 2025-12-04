import Foundation
import UIKit

// MARK: - Seedable Random Number Generator
/// A seedable random number generator for reproducible stimulus generation
/// Uses Linear Congruential Generator (LCG) algorithm for fast, reproducible randomness
struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    /// Initialize with a seed value
    init(seed: UInt64) {
        self.state = seed
    }
    
    /// Generate next random number using LCG algorithm
    mutating func next() -> UInt64 {
        // LCG parameters from Knuth's MMIX
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    
    /// Generate a random seed from current time (for new sequences)
    static func generateSeed() -> UInt64 {
        // Combine current time with a random component
        let time = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let random = UInt64.random(in: 0...UInt64.max)
        return time ^ random
    }
}

// MARK: - XorShift32 Random Number Generator
/// A 32-bit XorShift random number generator for MATLAB-compatible matrix generation
/// This implementation matches the MATLAB SeedGenerator.m for reproducible analysis
struct XorShift32 {
    private(set) var state: UInt32
    
    /// Initialize with a seed value
    /// - Parameter seed: Seed value (must be nonzero; uses fallback if zero)
    init(seed: UInt32) {
        // State must be nonzero, use fallback if zero
        self.state = seed == 0 ? 2463534242 : seed
    }
    
    /// Generate next random UInt32 value using XorShift algorithm
    /// Matches MATLAB implementation: x ^= x << 13; x ^= x >> 17; x ^= x << 5
    mutating func nextUInt32() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 17
        x ^= x << 5
        state = x
        return x
    }
    
    /// Generate next random boolean value
    /// Uses the top bit (0x8000_0000) to match MATLAB implementation
    mutating func nextBool() -> Bool {
        return (nextUInt32() & 0x8000_0000) != 0
    }
    
    /// Generate a random seed from current time (for new sequences)
    static func generateSeed() -> UInt32 {
        var seed = UInt32.random(in: UInt32.min...UInt32.max)
        if seed == 0 {
            seed = 2463534242  // Avoid zero
        }
        return seed
    }
}

// MARK: - Matrix Generation Utilities
/// Generate a black/white matrix from a seed using XorShift32
/// This produces the same matrix as the MATLAB SeedGenerator.m function
/// - Parameters:
///   - seed: Seed value (UInt32, will use fallback if zero)
///   - size: Matrix dimensions (n x n), default is 40
/// - Returns: A 2D array where 1 = black, 0 = white
func generateBlackWhiteMatrix(seed: UInt32, size: Int = 40) -> [[Int]] {
    var rng = XorShift32(seed: seed)
    var matrix = Array(repeating: Array(repeating: 0, count: size), count: size)
    
    for i in 0..<size {
        for j in 0..<size {
            matrix[i][j] = rng.nextBool() ? 1 : 0  // 1 = black, 0 = white
        }
    }
    
    return matrix
}

// MARK: - Quadrant Definition
enum Quadrant: String, CaseIterable {
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
    
    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }
    
    /// Get a random quadrant
    static func random() -> Quadrant {
        return Quadrant.allCases.randomElement()!
    }
}

// MARK: - Grid Size Options
enum GridSize: String, CaseIterable {
    case extraLarge = "64x48"
    
    var dimensions: (cols: Int, rows: Int) {
        return (64, 48)
    }
    
    var displayName: String {
        return rawValue
    }
    
    static let defaultSize: GridSize = .extraLarge
}

// MARK: - Trial Settings (User Configurable)
struct TrialSettings {
    
    // MARK: - Timing Settings
    var cueDuration: Double = 0.5            // How long the quadrant cue is shown (sec)
    var minGratingOnset: Double = 2.0        // Earliest time after trial starts when grating can appear (sec)
    var maxGratingOnset: Double = 6.0        // Latest time grating can appear (sec)
    var stimulusDuration: Double = 2.0       // How long the stimulus remains visible (sec)
    var rtWindowDelay: Double = 0.3          // Delay after grating appears before listening for response (sec)
    var rtWindowLength: Double = 2.0         // Duration subject has to respond once RT window starts (sec)
    
    // MARK: - Visual Settings
    var gridSizePercent: Double = 100.0      // Grid size as percentage of screen (100% = full screen)
    var gridSize: GridSize = .extraLarge         // Grid dimensions preset
    var stimulusHz: Int = 20                 // Stimulus refresh rate (Hz) - how fast the grid flickers
    
    // MARK: - Reward Settings
    var probAutomaticStimReward: Double = 0.2  // Probability of automatic reward without correct response (0-1)
    var probFALickReward: Double = 0.0  // Probability of rewarding a false alarm lick (0-1)
    var rewardLicksWindowLength: Double = 0.4  // Duration to ignore licks after rewards (seconds)
    
    // MARK: - Grating Contrast Settings
    var gratingContrasts: String = "0 0.1 0.2 0.3 0.4 0.5 0.75 1.0"  // Space-separated grating contrast levels (0-1)
    
    // MARK: - Testing Mode Settings
    var testingMode: Bool = true  // When true, stimulus is red for testing. When false, stimulus is white.
    
    // MARK: - Convenience Methods
    
    /// Calculate the mean of the exponential distribution for grating onset times
    /// This matches the MATLAB implementation: assumes 95% of CDF is within [min, max]
    var exponentialDistributionMean: Double {
        let range = maxGratingOnset - minGratingOnset
        guard range > 0 else { return 0 }
        // mean = range / (-log(1 - 0.95)) = range / (-log(0.05))
        // This ensures 95% of samples fall within the range
        return range / (-log(0.05))
    }
    
    /// Random onset time using exponential distribution (earlier times more likely)
    /// Matches MATLAB implementation: uses exponential distribution with 95% CDF in [min, max]
    /// 
    /// Distribution properties:
    /// - Earlier times are more likely than later times
    /// - 95% of samples fall within [minGratingOnset, maxGratingOnset]
    /// - ~2.5% of samples will be clamped to maxGratingOnset
    var randomOnsetTime: Double {
        let mean = exponentialDistributionMean
        
        // Generate exponential random variable: -log(U) * mean
        // where U is uniform random [0, 1)
        // Use epsilon to avoid log(0) edge case
        let u = max(Double.random(in: 0.0..<1.0), 1e-10)
        let exponentialValue = -log(u) * mean
        
        // Add minimum offset and clamp to maximum
        var onsetTime = exponentialValue + minGratingOnset
        
        // Clamp to maximum (this should happen ~2.5% of the time)
        if onsetTime > maxGratingOnset {
            onsetTime = maxGratingOnset
        }
        
        return onsetTime
    }
    
    /// Parse grating contrasts string into array of Double values
    var parsedGratingContrasts: [Double] {
        return gratingContrasts
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 0.0 && $0 <= 1.0 }  // Only keep valid values in range [0, 1]
    }
    
    /// UserDefaults keys for persistence
    struct Keys {
        static let cueDuration = "TrialSettings.cueDuration"
        static let minGratingOnset = "TrialSettings.minGratingOnset"
        static let maxGratingOnset = "TrialSettings.maxGratingOnset"
        static let stimulusDuration = "TrialSettings.stimulusDuration"
        static let rtWindowDelay = "TrialSettings.rtWindowDelay"
        static let rtWindowLength = "TrialSettings.rtWindowLength"
        static let gridSizePercent = "TrialSettings.gridSizePercent"
        static let gridSize = "TrialSettings.gridSize"
        static let probAutomaticStimReward = "TrialSettings.probAutomaticStimReward"
        static let probFALickReward = "TrialSettings.probFALickReward"
        static let rewardLicksWindowLength = "TrialSettings.rewardLicksWindowLength"
        static let stimulusHz = "TrialSettings.stimulusHz"
        static let gratingContrasts = "TrialSettings.gratingContrasts"
        static let testingMode = "TrialSettings.testingMode"
    }
    
    // MARK: - Persistence
    
    /// Save settings to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(cueDuration, forKey: Keys.cueDuration)
        defaults.set(minGratingOnset, forKey: Keys.minGratingOnset)
        defaults.set(maxGratingOnset, forKey: Keys.maxGratingOnset)
        defaults.set(stimulusDuration, forKey: Keys.stimulusDuration)
        defaults.set(rtWindowDelay, forKey: Keys.rtWindowDelay)
        defaults.set(rtWindowLength, forKey: Keys.rtWindowLength)
        defaults.set(gridSizePercent, forKey: Keys.gridSizePercent)
        defaults.set(gridSize.rawValue, forKey: Keys.gridSize)
        defaults.set(probAutomaticStimReward, forKey: Keys.probAutomaticStimReward)
        defaults.set(probFALickReward, forKey: Keys.probFALickReward)
        defaults.set(rewardLicksWindowLength, forKey: Keys.rewardLicksWindowLength)
        defaults.set(stimulusHz, forKey: Keys.stimulusHz)
        defaults.set(gratingContrasts, forKey: Keys.gratingContrasts)
        defaults.set(testingMode, forKey: Keys.testingMode)
    }
    
    /// Load settings from UserDefaults
    static func load() -> TrialSettings {
        let defaults = UserDefaults.standard
        var settings = TrialSettings()
        
        if defaults.object(forKey: Keys.cueDuration) != nil {
            settings.cueDuration = defaults.double(forKey: Keys.cueDuration)
        }
        if defaults.object(forKey: Keys.minGratingOnset) != nil {
            settings.minGratingOnset = defaults.double(forKey: Keys.minGratingOnset)
        }
        if defaults.object(forKey: Keys.maxGratingOnset) != nil {
            settings.maxGratingOnset = defaults.double(forKey: Keys.maxGratingOnset)
        }
        if defaults.object(forKey: Keys.stimulusDuration) != nil {
            settings.stimulusDuration = defaults.double(forKey: Keys.stimulusDuration)
        }
        if defaults.object(forKey: Keys.rtWindowDelay) != nil {
            settings.rtWindowDelay = defaults.double(forKey: Keys.rtWindowDelay)
        }
        if defaults.object(forKey: Keys.rtWindowLength) != nil {
            settings.rtWindowLength = defaults.double(forKey: Keys.rtWindowLength)
        }
        if defaults.object(forKey: Keys.gridSizePercent) != nil {
            settings.gridSizePercent = defaults.double(forKey: Keys.gridSizePercent)
        }
        if let gridSizeString = defaults.string(forKey: Keys.gridSize),
           let gridSize = GridSize(rawValue: gridSizeString) {
            settings.gridSize = gridSize
        }
        if defaults.object(forKey: Keys.probAutomaticStimReward) != nil {
            settings.probAutomaticStimReward = defaults.double(forKey: Keys.probAutomaticStimReward)
        }
        if defaults.object(forKey: Keys.probFALickReward) != nil {
            settings.probFALickReward = defaults.double(forKey: Keys.probFALickReward)
        }
        if defaults.object(forKey: Keys.rewardLicksWindowLength) != nil {
            settings.rewardLicksWindowLength = defaults.double(forKey: Keys.rewardLicksWindowLength)
        }
        if defaults.object(forKey: Keys.stimulusHz) != nil {
            settings.stimulusHz = defaults.integer(forKey: Keys.stimulusHz)
        }
        if let gratingContrastsString = defaults.string(forKey: Keys.gratingContrasts) {
            settings.gratingContrasts = gratingContrastsString
        }
        if defaults.object(forKey: Keys.testingMode) != nil {
            settings.testingMode = defaults.bool(forKey: Keys.testingMode)
        }
        
        return settings
    }
    
    /// Apply grid size to StimulusParams
    func applyGridSize() {
        let dimensions = gridSize.dimensions
        StimulusParams.cols = dimensions.cols
        StimulusParams.rows = dimensions.rows
    }
    
    /// Apply stimulus Hz setting to StimulusParams
    func applyStimulusHz() {
        StimulusParams.targetStimHz = stimulusHz
    }
}

// MARK: - Centralized Configuration Parameters
struct StimulusParams {
    
    // MARK: - Grid Configuration - adjustable
    static var cols = 64  // Default grid size
    static var rows = 48  // Default grid size
    
    // MARK: - Display Properties
    static let nominalPPI = 264.0  // iPad Pro 11" nominal PPI
    static let displayHz = 120     // Will be detected at runtime, but default to 120Hz
    static var targetStimHz = 30   // Target stimulus update frequency - adjustable
    
    // MARK: - Viewing Distance
    static let defaultViewingDistanceCm = 20.0  // Adjusted for 16 cols grid
    
    // MARK: - Colors (sRGB values)
    static let whiteColor = UIColor(red: 230/255.0, green: 230/255.0, blue: 230/255.0, alpha: 1.0)
    static let grayColor = UIColor(red: 128/255.0, green: 128/255.0, blue: 128/255.0, alpha: 1.0)
    static let blackColor = UIColor(red: 25/255.0, green: 25/255.0, blue: 25/255.0, alpha: 1.0)
    
    /// Stimulus color - red for testing mode, white for normal operation
    static var stimulusColor: UIColor {
        let settings = TrialSettings.load()
        return settings.testingMode ? UIColor.red : whiteColor
    }
    
    static let fixationColor = UIColor.white  // White fixation dot to avoid confusion
    
    // MARK: - Coherence Levels (Legacy - now always use 1.0 for red stimulus)
    static let coherenceLevels: [Double] = [0.15, 0.25, 0.4, 0.6, 0.8, 1.0]
    static let catchCoherence: Double = 0.0  // Catch trials
    
    // MARK: - Trial Timings (seconds) - adjustable (Legacy - now use TrialSettings)
    static var fixationDuration: Double = 1.0
    static var coherentWindowDuration: Double = 3.0
    static var interTrialInterval: Double = 2.0
    static var minOnsetTime: Double = 4.0  // Minimum onset time in seconds
    static var maxOnsetTime: Double = 12.0  // Maximum onset time in seconds
    
    // MARK: - Fixation Dot - adjustable
    static var fixationDotRadius: CGFloat = 3.0
    
    
    // MARK: - Computed Properties
    
    /// Updates per frame at target stimulus frequency
    static func updatesPerFrame(displayHz: Int) -> Int {
        return max(1, Int(round(Double(displayHz) / Double(targetStimHz))))
    }
    
    /// All coherence levels including catches
    static var allCoherenceLevels: [Double] {
        return coherenceLevels + [catchCoherence]
    }
    
    /// Gabor patch center positions based on quadrant
    /// 3 columns: 2 squares wide, 7 squares height, 2 squares between columns
    static func gaborCenters(quadrant: Quadrant) -> [(x: Int, y: Int)] {
        let centerX = cols / 2
        let centerY = rows / 2
        
        // Offset from center to position stimulus in quadrant
        // Each quadrant center is at 1/4 and 3/4 of the grid dimensions
        let quadrantOffsetX: Int
        let quadrantOffsetY: Int
        
        switch quadrant {
        case .topLeft:
            quadrantOffsetX = -cols / 4
            quadrantOffsetY = -rows / 4
        case .topRight:
            quadrantOffsetX = cols / 4
            quadrantOffsetY = -rows / 4
        case .bottomLeft:
            quadrantOffsetX = -cols / 4
            quadrantOffsetY = rows / 4
        case .bottomRight:
            quadrantOffsetX = cols / 4
            quadrantOffsetY = rows / 4
        }
        
        // Position the three columns around the quadrant center
        let quadrantCenterX = centerX + quadrantOffsetX
        let quadrantCenterY = centerY + quadrantOffsetY
        
        return [
            (x: quadrantCenterX - 4, y: quadrantCenterY),  // Left column center
            (x: quadrantCenterX, y: quadrantCenterY),      // Center column center  
            (x: quadrantCenterX + 4, y: quadrantCenterY)   // Right column center
        ]
    }
    
    // MARK: - Gabor Parameters
    // Rectangular patches: 2 squares wide x 7 squares height
    static let gaborWidth = 1.0         // Half-width of rectangular patch (1 = 2 squares wide)
    static let gaborHeight = 3.5        // Half-height of rectangular patch (3.5 = 7 squares height)
    static var gaborFrequency = 0.8     // Spatial frequency (cycles per tile)
    static let gaborSigmaX = 0.5        // Gaussian envelope standard deviation in X direction (tighter for 2-wide columns)
    static let gaborSigmaY = 2.0        // Gaussian envelope standard deviation in Y direction (for 7-tall columns)
    static let gaborOrientation = 0.0   // Orientation in radians (0 = vertical)
    
    // Legacy parameter for backward compatibility
    static let gaborRadius = 3.5        // Use gaborHeight for circular calculations
    
    // MARK: - UserDefaults Keys
    static let viewingDistanceCmKey = "ViewingDistanceCm"
}

// MARK: - Trial States
enum TrialState: String, CaseIterable {
    case idle = "idle"
    case cue = "cue"
    case fixation = "fixation"
    case noise = "noise"
    case coherent = "coherent"
    case interTrial = "inter_trial"
    
    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .cue: return "Cue"
        case .fixation: return "Fixation"
        case .noise: return "Noise"
        case .coherent: return "Coherent"
        case .interTrial: return "Inter-Trial"
        }
    }
}

// MARK: - Trial Configuration
struct TrialConfig {
    let coherence: Double
    let gratingContrast: Double  // Percentage of Gabor patch squares that are red (0-1)
    let onsetTime: Double  // Random onset time within [minOnset, maxOnset]
    let trialIndex: Int
    let settings: TrialSettings  // Trial settings used for this trial
    var quadrant: Quadrant  // Which quadrant the stimulus will appear in (set randomly at cue time)
    
    init(coherence: Double, gratingContrast: Double = 1.0, trialIndex: Int, settings: TrialSettings = TrialSettings(), quadrant: Quadrant? = nil) {
        self.coherence = coherence
        self.gratingContrast = gratingContrast
        self.trialIndex = trialIndex
        self.settings = settings
        self.onsetTime = settings.randomOnsetTime
        // Don't set quadrant here - it will be randomly selected when the cue appears
        // For now, use a placeholder (will be replaced at cue time)
        self.quadrant = quadrant ?? .topLeft  // Placeholder, will be randomized at cue time
    }
    
    /// Response window start time (onset + RT delay)
    var responseWindowStart: Double {
        return onsetTime + settings.rtWindowDelay
    }
    
    /// Response window end time
    var responseWindowEnd: Double {
        return responseWindowStart + settings.rtWindowLength
    }
    
    /// Whether this trial should receive automatic reward
    var shouldReceiveAutomaticReward: Bool {
        return Double.random(in: 0...1) < settings.probAutomaticStimReward
    }
}

// MARK: - Frame Types
enum FrameType {
    case noise(seed: UInt64)
    case coherent(coherence: Double, gratingContrast: Double, seed: UInt64)  // coherence level, grating contrast, and seed
    case fixation
}

// MARK: - Trial Result
struct TrialResult {
    let config: TrialConfig
    let startTime: Date
    let endTime: Date
    let coherentOnsetFrame: Int
    let totalFrames: Int
    let response: String?
    let reactionTime: Double?
    let responseTime: Double?  // Time of response relative to trial start
    let wasInResponseWindow: Bool  // Whether response occurred within the valid window
    let receivedAutomaticReward: Bool  // Whether automatic reward was given
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    /// Whether the response was valid (within response window)
    var isValidResponse: Bool {
        guard let responseTime = responseTime else { return false }
        return responseTime >= config.responseWindowStart && responseTime <= config.responseWindowEnd
    }
    
    /// Response latency relative to response window start
    var responseLatency: Double? {
        guard let responseTime = responseTime else { return nil }
        return responseTime - config.responseWindowStart
    }
}

// MARK: - Timing Statistics
struct TimingStats {
    let meanFrameTime: Double
    let medianFrameTime: Double
    let p95FrameTime: Double
    let expectedFrameTime: Double
    let averageJitter: Double
    let sampleCount: Int
    
    var meanFrameRate: Double {
        return 1.0 / meanFrameTime
    }
    
    var medianFrameRate: Double {
        return 1.0 / medianFrameTime
    }
    
    /// Human-readable description
    var description: String {
        return """
        Timing Stats (\(sampleCount) samples):
        Mean: \(String(format: "%.1f", meanFrameRate)) Hz (\(String(format: "%.3f", meanFrameTime * 1000)) ms)
        Median: \(String(format: "%.1f", medianFrameRate)) Hz (\(String(format: "%.3f", medianFrameTime * 1000)) ms)
        P95: \(String(format: "%.3f", p95FrameTime * 1000)) ms
        Expected: \(String(format: "%.3f", expectedFrameTime * 1000)) ms
        Avg Jitter: \(String(format: "%.3f", averageJitter * 1000)) ms
        """
    }
}

// MARK: - Session Info (Experiment, User, Subject)
struct SessionInfo {
    var experimentName: String = ""
    var playerName: String = ""  // Subject name
    var username: String = ""
    
    /// UserDefaults keys for persistence
    struct Keys {
        static let experimentName = "SessionInfo.experimentName"
        static let playerName = "SessionInfo.playerName"
        static let username = "SessionInfo.username"
    }
    
    /// Generate session ID in format "Experiment_User_Subject"
    var sessionId: String {
        let exp = experimentName.isEmpty ? "Experiment" : experimentName
        let user = username.isEmpty ? "User" : username
        let subject = playerName.isEmpty ? "Subject" : playerName
        return "\(exp)_\(user)_\(subject)"
    }
    
    /// Save to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(experimentName, forKey: Keys.experimentName)
        defaults.set(playerName, forKey: Keys.playerName)
        defaults.set(username, forKey: Keys.username)
    }
    
    /// Load from UserDefaults
    static func load() -> SessionInfo {
        let defaults = UserDefaults.standard
        var info = SessionInfo()
        
        if let experimentName = defaults.string(forKey: Keys.experimentName) {
            info.experimentName = experimentName
        }
        if let playerName = defaults.string(forKey: Keys.playerName) {
            info.playerName = playerName
        }
        if let username = defaults.string(forKey: Keys.username) {
            info.username = username
        }
        
        return info
    }
}

// MARK: - Protocols
protocol StimulusControllerDelegate: AnyObject {
    func stimulusController(_ controller: StimulusController, didChangeState state: TrialState)
    func stimulusController(_ controller: StimulusController, didStartTrial trial: TrialConfig)
    func stimulusController(_ controller: StimulusController, didCompleteTrials results: [TrialResult])
    func stimulusController(_ controller: StimulusController, requestsFrameUpdate frameType: FrameType)
}

protocol DisplayTickerDelegate: AnyObject {
    func displayTicker(_ ticker: DisplayTicker, shouldUpdateFrame frameCount: Int)
    func displayTicker(_ ticker: DisplayTicker, didDetectRefreshRate hz: Int)
}
