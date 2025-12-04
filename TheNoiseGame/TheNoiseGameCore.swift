import Foundation
import UIKit

// MARK: - Checkerboard Renderer (Pattern Generation)
class CheckerboardRenderer {
    
    // MARK: - Properties
    private var rows: Int
    private var cols: Int
    private var currentGrid: [[Bool]]
    private var gaborMask: [[Double]]  // Store Gabor values (0.0 to 1.0)
    private var isCoherentFrame = false  // Track if current frame is coherent
    private var activeGaborTiles: Set<String> = []  // Tiles that should show red (format: "row,col")
    private var currentQuadrant: Quadrant = .topLeft  // Track current quadrant for stimulus positioning
    
    // Statistics tracking
    private var frameCount = 0
    private var lastBalanceCheck: (whites: Int, blacks: Int) = (0, 0)
    
    // Seedable RNG tracking
    private(set) var lastUsedSeed: UInt64 = 0  // Track the seed used for current frame
    
    // MARK: - Initialization
    init(rows: Int = StimulusParams.rows, cols: Int = StimulusParams.cols, quadrant: Quadrant = .topLeft) {
        self.rows = rows
        self.cols = cols
        self.currentQuadrant = quadrant
        self.currentGrid = Array(repeating: Array(repeating: false, count: cols), count: rows)
        self.gaborMask = CheckerboardRenderer.generateGaborMask(rows: rows, cols: cols, quadrant: quadrant)
    }
    
    // MARK: - Grid Size Updates
    
    /// Update grid dimensions and regenerate internal structures
    func updateGridSize(newRows: Int, newCols: Int) {
        // Only update if dimensions actually changed
        guard newRows != rows || newCols != cols else { return }
        
        let oldRows = rows
        let oldCols = cols
        
        // Update stored dimensions
        self.rows = newRows
        self.cols = newCols
        
        // Recreate the grid array with new dimensions
        currentGrid = Array(repeating: Array(repeating: false, count: newCols), count: newRows)
        
        // Regenerate Gabor mask with new dimensions and current quadrant
        gaborMask = CheckerboardRenderer.generateGaborMask(rows: newRows, cols: newCols, quadrant: currentQuadrant)
        
        print("CheckerboardRenderer: Updated grid size from \(oldCols)×\(oldRows) to \(newCols)×\(newRows)")
    }
    
    /// Update quadrant for stimulus positioning
    func updateQuadrant(_ quadrant: Quadrant) {
        guard quadrant != currentQuadrant else { return }
        
        currentQuadrant = quadrant
        // Regenerate Gabor mask with new quadrant
        gaborMask = CheckerboardRenderer.generateGaborMask(rows: rows, cols: cols, quadrant: quadrant)
        
        print("CheckerboardRenderer: Updated quadrant to \(quadrant.displayName)")
    }
    
    
    // MARK: - Grid Access
    
    /// Get current grid state
    func getCurrentGrid() -> [[Bool]] {
        return currentGrid
    }
    
    /// Get tile color for position
    func getTileColor(row: Int, col: Int) -> UIColor {
        guard row >= 0 && row < rows && col >= 0 && col < cols else {
            return StimulusParams.grayColor
        }
        
        // Apply Gabor modulation only during coherent frames
        if isCoherentFrame {
            let gaborValue = gaborMask[row][col]
            if gaborValue > 0.01 {  // Check if in Gabor patch area
                // Check if this specific tile should be stimulus color based on grating contrast
                let tileKey = "\(row),\(col)"
                if activeGaborTiles.contains(tileKey) {
                    return StimulusParams.stimulusColor  // Stimulus color (red for testing, white for normal)
                }
                // Otherwise, fall through to show background pattern
            }
        }
        
        // Get base color from grid (background pattern)
        let baseColor = currentGrid[row][col] ? StimulusParams.whiteColor : StimulusParams.blackColor
        return baseColor
    }
    
    /// Get Gabor mask
    func getGaborMask() -> [[Double]] {
        return gaborMask
    }
    
    // MARK: - Checksum Calculation (for MATLAB compatibility)
    
    /// Calculate checksum for current frame (sum of all tile values)
    /// Values: 0 = black, 1 = white, 2 = red (stimulus)
    /// Returns: -1 for blank/static frames, otherwise sum of all tile values
    func calculateChecksum() -> Int {
        var sum = 0
        var hasContent = false
        
        for row in 0..<rows {
            for col in 0..<cols {
                let color = getTileColor(row: row, col: col)
                var value: Int
                if color == StimulusParams.blackColor {
                    value = 0
                } else if color == StimulusParams.whiteColor {
                    value = 1
                } else {
                    // Stimulus color (red)
                    value = 2
                }
                sum += value
                hasContent = true
            }
        }
        
        // Return -1 for blank frames (no content), otherwise sum
        return hasContent ? sum : -1
    }
    
    /// Get frame state as 2D array of integers (0=black, 1=white, 2=red)
    func getFrameState() -> [[Int]] {
        var state: [[Int]] = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let color = getTileColor(row: row, col: col)
                if color == StimulusParams.blackColor {
                    state[row][col] = 0
                } else if color == StimulusParams.whiteColor {
                    state[row][col] = 1
                } else {
                    // Stimulus color (red)
                    state[row][col] = 2
                }
            }
        }
        return state
    }
    
    // MARK: - Frame Generation
    
    /// Generate a pure noise frame with exact mean luminance balance
    /// - Parameter seed: Optional seed for reproducible randomness. If nil, generates a new seed.
    /// - Returns: The seed used for this frame (for logging/reproduction)
    @discardableResult
    func makeNoiseFrame(seed: UInt64? = nil) -> UInt64 {
        frameCount += 1
        isCoherentFrame = false  // Mark as noise frame
        
        // Use provided seed or generate new one
        let usedSeed = seed ?? SeededRandomGenerator.generateSeed()
        lastUsedSeed = usedSeed
        var rng = SeededRandomGenerator(seed: usedSeed)
        
        // Step 1: Assign random values to all tiles using seeded RNG
        for row in 0..<rows {
            for col in 0..<cols {
                currentGrid[row][col] = Bool.random(using: &rng)
            }
        }
        
        // Step 2: Enforce exact balance (also needs seeded RNG for flipping)
        enforceExactBalance(using: &rng)
        
        // Validate balance
        validateBalance()
        
        return usedSeed
    }
    
    /// Generate a coherent frame with specified coherence level and grating contrast
    /// - Parameters:
    ///   - coherence: Coherence level (0.0 to 1.0)
    ///   - gratingContrast: Percentage of Gabor tiles that should be red (0.0 to 1.0)
    ///   - seed: Optional seed for reproducible randomness. If nil, generates a new seed.
    /// - Returns: The seed used for this frame (for logging/reproduction)
    @discardableResult
    func makeCoherentFrame(coherence: Double, gratingContrast: Double = 1.0, seed: UInt64? = nil) -> UInt64 {
        frameCount += 1
        
        // Clamp values to valid range
        let c = max(0.0, min(1.0, coherence))
        let contrast = max(0.0, min(1.0, gratingContrast))
        
        if c == 0.0 {
            // Pure noise for catch trials
            return makeNoiseFrame(seed: seed)
        }
        
        // Use provided seed or generate new one
        let usedSeed = seed ?? SeededRandomGenerator.generateSeed()
        lastUsedSeed = usedSeed
        var rng = SeededRandomGenerator(seed: usedSeed)
        
        isCoherentFrame = true  // Mark as coherent frame
        
        // Step 1: Generate background noise pattern for the entire grid
        for row in 0..<rows {
            for col in 0..<cols {
                currentGrid[row][col] = Bool.random(using: &rng)
            }
        }
        
        // Step 2: Enforce exact balance for the background
        enforceExactBalance(using: &rng)
        
        // Step 3: Determine which Gabor patch tiles should be red based on grating contrast
        activeGaborTiles.removeAll()
        
        // Collect all Gabor patch tiles
        var gaborTiles: [(row: Int, col: Int)] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let gaborValue = gaborMask[row][col]
                if gaborValue > 0.01 {  // Tile is in Gabor patch area
                    gaborTiles.append((row, col))
                }
            }
        }
        
        // Select a percentage of Gabor tiles to be red based on grating contrast
        let numActiveGaborTiles = Int(Double(gaborTiles.count) * contrast)
        let selectedTiles = gaborTiles.shuffled(using: &rng).prefix(numActiveGaborTiles)
        
        for tile in selectedTiles {
            let tileKey = "\(tile.row),\(tile.col)"
            activeGaborTiles.insert(tileKey)
        }
        
        // Validate balance
        validateBalance()
        
        return usedSeed
    }
    
    // MARK: - Private Helper Methods
    
    /// Enforce exact 50/50 balance by flipping random tiles
    private func enforceExactBalance(using rng: inout SeededRandomGenerator) {
        let (whites, _) = countTiles()
        let totalTiles = rows * cols
        let targetWhites = totalTiles / 2
        
        if whites > targetWhites {
            // Too many whites, flip some to black
            let excess = whites - targetWhites
            flipRandomTiles(count: excess, fromValue: true, toValue: false, using: &rng)
        } else if whites < targetWhites {
            // Too few whites, flip some to black
            let deficit = targetWhites - whites
            flipRandomTiles(count: deficit, fromValue: false, toValue: true, using: &rng)
        }
    }
    
    /// Count white and black tiles
    private func countTiles() -> (whites: Int, blacks: Int) {
        var whites = 0
        var blacks = 0
        
        for row in 0..<rows {
            for col in 0..<cols {
                if currentGrid[row][col] {
                    whites += 1
                } else {
                    blacks += 1
                }
            }
        }
        
        return (whites, blacks)
    }
    
    /// Count tiles in the Gabor patches
    private func countGaborTiles() -> Int {
        var count = 0
        for row in 0..<rows {
            for col in 0..<cols {
                if gaborMask[row][col] > 0.1 {
                    count += 1
                }
            }
        }
        return count
    }
    
    /// Flip random tiles from one value to another
    private func flipRandomTiles(count: Int, fromValue: Bool, toValue: Bool, maskOnly: Bool = false, excludeMask: Bool = false, using rng: inout SeededRandomGenerator) {
        guard count > 0 else { return }
        
        // Find candidate positions
        var candidates: [(Int, Int)] = []
        for row in 0..<rows {
            for col in 0..<cols {
                let isInMask = gaborMask[row][col] > 0.1
                let meetsConstraint = maskOnly ? isInMask : (excludeMask ? !isInMask : true)
                
                if currentGrid[row][col] == fromValue && meetsConstraint {
                    candidates.append((row, col))
                }
            }
        }
        
        // Randomly select and flip using seeded RNG
        let toFlip = min(count, candidates.count)
        let selectedIndices = Array(0..<candidates.count).shuffled(using: &rng).prefix(toFlip)
        
        for index in selectedIndices {
            let (row, col) = candidates[index]
            currentGrid[row][col] = toValue
        }
    }
    
    /// Validate that the grid has exact balance
    private func validateBalance() {
        let (whites, blacks) = countTiles()
        lastBalanceCheck = (whites, blacks)
        
        let imbalance = abs(whites - blacks)
        
        if imbalance > 1 {  // Allow for odd total tiles
            print("WARNING: Grid imbalance detected! Whites: \(whites), Blacks: \(blacks), Imbalance: \(imbalance)")
        }
    }
    
    // MARK: - Static Methods for Mask Generation
    
    /// Generate Gabor patch mask for a specific quadrant
    static func generateGaborMask(rows: Int, cols: Int, quadrant: Quadrant) -> [[Double]] {
        var mask = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)
        
        let gaborCenters = StimulusParams.gaborCenters(quadrant: quadrant)
        let width = StimulusParams.gaborWidth
        let height = StimulusParams.gaborHeight
        let sigmaX = StimulusParams.gaborSigmaX
        let sigmaY = StimulusParams.gaborSigmaY
        let orientation = StimulusParams.gaborOrientation
        
        print("📊 Gabor Patch Configuration:")
        print("   Grid: \(cols)×\(rows)")
        print("   Quadrant: \(quadrant.displayName)")
        print("   Centers: \(gaborCenters)")
        print("   Each column: \(Int(width*2)) squares wide × \(Int(height*2)) squares tall")
        
        var gaborTileCount = 0
        for center in gaborCenters {
            for row in 0..<rows {
                for col in 0..<cols {
                    let dx = Double(col - center.x)
                    let dy = Double(row - center.y)
                    
                    // Rotate coordinates based on orientation
                    let x_rot = dx * cos(orientation) + dy * sin(orientation)
                    let y_rot = -dx * sin(orientation) + dy * cos(orientation)
                    
                    // Only compute Gabor within rectangular bounds
                    if abs(x_rot) <= width && abs(y_rot) <= height {
                        gaborTileCount += 1
                        // Simplified: Just use Gaussian envelope (no sinusoidal grating)
                        // This creates solid columns instead of striped patterns
                        let gaussianX = exp(-(x_rot * x_rot) / (2.0 * sigmaX * sigmaX))
                        let gaussianY = exp(-(y_rot * y_rot) / (2.0 * sigmaY * sigmaY))
                        let gaussian = gaussianX * gaussianY
                        
                        // Just use the Gaussian envelope directly
                        let normalizedGabor = gaussian.clamped(to: 0.0...1.0)
                        
                        // Take maximum if multiple Gabors overlap
                        mask[row][col] = max(mask[row][col], normalizedGabor)
                    }
                }
            }
        }
        
        print("   Total Gabor tiles: \(gaborTileCount)")
        
        // Show max Gabor value for debugging
        let maxGabor = mask.flatMap { $0 }.max() ?? 0.0
        print("   Max Gabor value: \(maxGabor)")
        
        return mask
    }
    
    // MARK: - Diagnostics
    
    /// Get current balance statistics
    func getBalanceStats() -> (whites: Int, blacks: Int, imbalance: Int, isBalanced: Bool) {
        let (whites, blacks) = countTiles()
        let imbalance = abs(whites - blacks)
        let isBalanced = imbalance <= 1  // Allow for odd total tiles
        
        return (whites, blacks, imbalance, isBalanced)
    }
    
    /// Calculate entropy of current grid (for validation)
    func calculateEntropy() -> Double {
        let (whites, blacks) = countTiles()
        let total = whites + blacks
        
        guard total > 0 else { return 0.0 }
        
        let pWhite = Double(whites) / Double(total)
        let pBlack = Double(blacks) / Double(total)
        
        var entropy = 0.0
        if pWhite > 0 { entropy -= pWhite * log2(pWhite) }
        if pBlack > 0 { entropy -= pBlack * log2(pBlack) }
        
        return entropy
    }
    
    /// Get diagnostic information
    func getDiagnosticInfo() -> [String: Any] {
        let balance = getBalanceStats()
        let entropy = calculateEntropy()
        
        return [
            "frameCount": frameCount,
            "whites": balance.whites,
            "blacks": balance.blacks,
            "imbalance": balance.imbalance,
            "isBalanced": balance.isBalanced,
            "entropy": entropy,
            "maxEntropy": 1.0,
            "entropyRatio": entropy / 1.0,
            "totalTiles": rows * cols,
            "gaborTileCount": countGaborTiles()
        ]
    }
    
    // MARK: - Reproducibility Utilities
    
    /// Reproduce a grid state from a saved seed
    /// - Parameters:
    ///   - seed: The seed used to generate the original grid
    ///   - rows: Number of rows in the grid
    ///   - cols: Number of columns in the grid
    ///   - stimulusType: "noise" or "coherent"
    ///   - coherence: Coherence level (for coherent frames)
    ///   - gratingContrast: Grating contrast (for coherent frames)
    ///   - quadrant: Quadrant for stimulus positioning (for coherent frames)
    /// - Returns: A 2D array of tile states (0=black, 1=white, 2=red)
    static func reproduceGridFromSeed(seed: UInt64, rows: Int, cols: Int, stimulusType: String, coherence: Double = 0.0, gratingContrast: Double = 1.0, quadrant: Quadrant = .topLeft) -> [[Int]] {
        // Create a temporary renderer
        let renderer = CheckerboardRenderer(rows: rows, cols: cols, quadrant: quadrant)
        
        // Generate the frame with the saved seed
        if stimulusType == "coherent" {
            renderer.makeCoherentFrame(coherence: coherence, gratingContrast: gratingContrast, seed: seed)
        } else {
            renderer.makeNoiseFrame(seed: seed)
        }
        
        // Extract grid state (0=black, 1=white, 2=red)
        var gridState: [[Int]] = Array(repeating: Array(repeating: 0, count: cols), count: rows)
        for row in 0..<rows {
            for col in 0..<cols {
                let color = renderer.getTileColor(row: row, col: col)
                if color == StimulusParams.whiteColor {
                    gridState[row][col] = 1
                } else if color == StimulusParams.blackColor {
                    gridState[row][col] = 0  // black
                } else {
                    // Any other color must be the stimulus color (red or white depending on testing mode)
                    gridState[row][col] = 2
                }
            }
        }
        
        return gridState
    }
    
    /// Verify that a seed produces the same grid state (for testing)
    static func verifySeedReproducibility(seed: UInt64, rows: Int, cols: Int, stimulusType: String, coherence: Double = 0.0, gratingContrast: Double = 1.0, quadrant: Quadrant = .topLeft) -> Bool {
        let grid1 = reproduceGridFromSeed(seed: seed, rows: rows, cols: cols, stimulusType: stimulusType, coherence: coherence, gratingContrast: gratingContrast, quadrant: quadrant)
        let grid2 = reproduceGridFromSeed(seed: seed, rows: rows, cols: cols, stimulusType: stimulusType, coherence: coherence, gratingContrast: gratingContrast, quadrant: quadrant)
        
        // Check if grids are identical
        for row in 0..<rows {
            for col in 0..<cols {
                if grid1[row][col] != grid2[row][col] {
                    return false
                }
            }
        }
        
        return true
    }
}

// MARK: - Stimulus Logger (Data Logging)
class StimulusLogger {
    
    // MARK: - Properties
    private var logEntries: [LogEntry] = []
    private let sessionId: String
    private let sessionStartTime: Date
    private var currentTrialStartTime: Date?  // Track trial start time for trialTime calculation
    
    // File management
    private var currentLogFile: URL?  // Single unified log file for all data
    
    // RT window tracking (updated by StimulusController)
    private var rtWindowStart: Date?
    private var rtWindowEnd: Date?
    
    // MARK: - Initialization
    init(sessionId: String? = nil) {
        // Use custom session ID if provided, otherwise generate UUID
        self.sessionId = sessionId ?? UUID().uuidString
        self.sessionStartTime = Date()
        
        setupLogFile()
        // Note: logSessionStart() will be called when first trial starts
    }
    
    // MARK: - Log Entry Structure
    struct LogEntry {
        let timestamp: TimeInterval
        let sessionTime: TimeInterval
        let eventType: String
        let trialIndex: Int?
        let coherence: Double?
        let quadrant: Quadrant?
        let state: String?
        let onsetFrame: Int?
        let frameCount: Int
        let displayHz: Int?
        let stimulusHz: Double?
        let updatesPerFrame: Int?
        let tilePx: Int?
        let distanceCm: Double?
        let pxPerCm: Double?
        let usingCalibration: Bool?
        let response: String?
        let reactionTime: Double?
        let additionalData: [String: Any]?
        
        init(eventType: String, frameCount: Int = 0) {
            self.timestamp = Date().timeIntervalSince1970
            self.sessionTime = Date().timeIntervalSince(Date(timeIntervalSince1970: 0)) // Will be set properly by logger
            self.eventType = eventType
            self.frameCount = frameCount
            
            // Initialize all optional fields to nil
            self.trialIndex = nil
            self.coherence = nil
            self.quadrant = nil
            self.state = nil
            self.onsetFrame = nil
            self.displayHz = nil
            self.stimulusHz = nil
            self.updatesPerFrame = nil
            self.tilePx = nil
            self.distanceCm = nil
            self.pxPerCm = nil
            self.usingCalibration = nil
            self.response = nil
            self.reactionTime = nil
            self.additionalData = nil
        }
        
        init(timestamp: TimeInterval, sessionTime: TimeInterval, eventType: String, trialIndex: Int?, coherence: Double?, quadrant: Quadrant?, state: String?, onsetFrame: Int?, frameCount: Int, displayHz: Int?, stimulusHz: Double?, updatesPerFrame: Int?, tilePx: Int?, distanceCm: Double?, pxPerCm: Double?, usingCalibration: Bool?, response: String?, reactionTime: Double?, additionalData: [String: Any]?) {
            self.timestamp = timestamp
            self.sessionTime = sessionTime
            self.eventType = eventType
            self.trialIndex = trialIndex
            self.coherence = coherence
            self.quadrant = quadrant
            self.state = state
            self.onsetFrame = onsetFrame
            self.frameCount = frameCount
            self.displayHz = displayHz
            self.stimulusHz = stimulusHz
            self.updatesPerFrame = updatesPerFrame
            self.tilePx = tilePx
            self.distanceCm = distanceCm
            self.pxPerCm = pxPerCm
            self.usingCalibration = usingCalibration
            self.response = response
            self.reactionTime = reactionTime
            self.additionalData = additionalData
        }
    }
    
    // MARK: - File Setup
    private func setupLogFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: sessionStartTime)
        
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ERROR: Could not access documents directory")
            return
        }
        
        // Single unified log file with all data
        let fileName = "noise_game_data_\(timestamp).csv"
        currentLogFile = documentsDirectory.appendingPathComponent(fileName)
        
        // Write metadata rows first
        writeMetadataRows()
        
        // Then write CSV header
        writeUnifiedCSVHeader()
        
        print("📊 Unified log file created: \(fileName)")
    }
    
    private func writeMetadataRows() {
        let settings = TrialSettings.load()
        
        var metadata = ""
        
        // TRIAL_SETTINGS section
        metadata += "# TRIAL_SETTINGS\n"
        metadata += "# cueDuration: \(settings.cueDuration)\n"
        metadata += "# minGratingOnset: \(settings.minGratingOnset)\n"
        metadata += "# maxGratingOnset: \(settings.maxGratingOnset)\n"
        metadata += "# stimulusDuration: \(settings.stimulusDuration)\n"
        metadata += "# rtWindowDelay: \(settings.rtWindowDelay)\n"
        metadata += "# rtWindowLength: \(settings.rtWindowLength)\n"
        metadata += "# gridSize: \(settings.gridSize.rawValue)\n"
        metadata += "# stimulusHz: \(settings.stimulusHz)\n"
        metadata += "# gratingContrasts: \(settings.gratingContrasts)\n"
        metadata += "# probAutomaticStimReward: \(settings.probAutomaticStimReward)\n"
        metadata += "# probFALickReward: \(settings.probFALickReward)\n"
        metadata += "# rewardLicksWindowLength: \(settings.rewardLicksWindowLength)\n"
        metadata += "# testingMode: \(settings.testingMode)\n"
        metadata += "#\n"
        
        writeToFile(metadata, to: currentLogFile)
    }
    
    private func writeUnifiedCSVHeader() {
        // Simplified header with 14 essential columns
        var headerFields: [String] = []
        
        // Timing fields
        headerFields.append("timestamp")           // Unix timestamp
        headerFields.append("sessionTime")         // Time since session start (seconds)
        headerFields.append("trialTime")           // Time since trial start (seconds)
        
        // Event identification
        headerFields.append("eventType")           // Simplified event type
        headerFields.append("sessionId")           // Session identifier
        
        // Trial parameters
        headerFields.append("trialIndex")          // Trial number
        headerFields.append("coherence")           // Signal coherence (0.0 to 1.0)
        headerFields.append("gratingContrast")     // Grating contrast (0.0 to 1.0)
        headerFields.append("quadrant")            // Stimulus location (top_left, top_right, bottom_left, bottom_right)
        
        // Frame reconstruction
        headerFields.append("frameNumber")         // Sequential frame number
        headerFields.append("seed")                // RNG seed for noise pattern reconstruction
        headerFields.append("stimulusOn")          // Whether stimulus is visible (true/false)
        
        // Response data
        headerFields.append("response")            // Response type (hit/miss/false_alarm) or behavioral outcome
        headerFields.append("reactionTime")        // Time from stimulus onset to response (seconds)
        headerFields.append("withinRTWindow")      // Whether event timestamp is within reaction time window (true/false)
        
        let header = headerFields.joined(separator: ",")
        writeToFile(header + "\n", to: currentLogFile)
    }
    
    // MARK: - Helper Methods
    
    /// Parse session ID into components (Experiment_User_Subject)
    private func parseSessionId() -> (experiment: String, user: String, subject: String) {
        let components = sessionId.split(separator: "_").map(String.init)
        if components.count >= 3 {
            return (components[0], components[1], components[2])
        }
        // If not in expected format, return sessionId for all fields
        return (sessionId, "", "")
    }
    
    /// Get session information (experiment name, user name, subject name)
    /// Public method to access parsed session info
    func getSessionInfo() -> (experiment: String, user: String, subject: String) {
        return parseSessionId()
    }
    
    /// Format timestamp as human-readable string
    /// - Parameter timestamp: Unix timestamp (seconds since 1970)
    /// - Returns: Formatted string "YYYY-MM-DD HH:mm:ss.SSS"
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
    
    /// Calculate time since current trial started
    /// - Returns: Time in seconds since trial start, or 0.0 if no trial active
    private func calculateTrialTime() -> Double {
        guard let trialStart = currentTrialStartTime else { return 0.0 }
        return Date().timeIntervalSince(trialStart)
    }
    
    /// Check if a timestamp falls within the reaction time window
    /// - Parameter timestamp: Unix timestamp (seconds since 1970) to check
    /// - Returns: true if timestamp is within RT window, false otherwise
    private func isWithinRTWindow(_ timestamp: TimeInterval) -> Bool {
        // RT window must be defined
        guard let rtStart = rtWindowStart, let rtEnd = rtWindowEnd else {
            return false
        }
        
        // Convert Date objects to TimeInterval for comparison
        let startTime = rtStart.timeIntervalSince1970
        let endTime = rtEnd.timeIntervalSince1970
        
        // Check if timestamp falls within the window (inclusive)
        return timestamp >= startTime && timestamp <= endTime
    }
    
    private func writeToFile(_ content: String, to fileURL: URL?) {
        guard let logFile = fileURL else { return }
        
        if let data = content.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile.path) {
                // Append to existing file
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                try? data.write(to: logFile)
            }
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log session start
    func logSessionStart() {
        // Session start is captured in the header metadata
        // No need for a separate data row
        print("Logging session started: \(sessionId)")
    }
    
    /// Log trial start
    func logTrialStart(_ trial: TrialConfig, frameCount: Int) {
        // Set trial start time for trialTime calculations
        currentTrialStartTime = Date()
        
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        
        // Log trial_start event with simplified format
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append("0.000")  // trialTime is 0 at trial start
        csvFields.append("trial_start")
        csvFields.append(sessionId)
        csvFields.append(String(trial.trialIndex))
        csvFields.append(String(trial.coherence))
        csvFields.append(String(trial.gratingContrast))
        csvFields.append(trial.quadrant.rawValue)
        csvFields.append("")  // frameNumber
        csvFields.append("")  // seed
        csvFields.append("false")  // stimulusOn - no stimulus at trial start
        csvFields.append("")  // response
        csvFields.append("")  // reactionTime
        csvFields.append("false")  // withinRTWindow - RT window doesn't exist at trial start
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log state change - now simplified, no separate state events logged
    func logStateChange(from: TrialState, to: TrialState, frameCount: Int) {
        // State changes are now captured in frame events with stimulusOn flag
        // No need for separate state change events
    }
    
    /// Log trial completion with simplified format
    func logTrialComplete(_ result: TrialResult, frameCount: Int) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        let trialTime = calculateTrialTime()
        
        // Map response to behavioral outcome format
        let behavioralOutcome: String
        if let response = result.response {
            switch response.lowercased() {
            case "correct", "hit":
                behavioralOutcome = "hit"
            case "incorrect", "fa", "false_alarm":
                behavioralOutcome = "false_alarm"
            case "miss":
                behavioralOutcome = "miss"
            default:
                behavioralOutcome = response.lowercased()
            }
        } else {
            behavioralOutcome = "miss"  // No response = Miss
        }
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append(String(format: "%.3f", trialTime))
        csvFields.append("trial_end")
        csvFields.append(sessionId)
        csvFields.append(String(result.config.trialIndex))
        csvFields.append(String(result.config.coherence))
        csvFields.append(String(result.config.gratingContrast))
        csvFields.append(result.config.quadrant.rawValue)
        csvFields.append("")  // frameNumber (not applicable for trial end)
        csvFields.append("")  // seed (not applicable for trial end)
        csvFields.append("false")  // stimulusOn - stimulus off at trial end
        csvFields.append(behavioralOutcome)  // response
        csvFields.append(result.reactionTime?.description ?? "")  // reactionTime
        csvFields.append(isWithinRTWindow(timestamp) ? "true" : "false")  // withinRTWindow
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
        
        // Reset trial start time
        currentTrialStartTime = nil
    }
    
    /// Log trial sequence completion
    func logTrialSequenceComplete(_ results: [TrialResult]) {
        // Sequence completion can be inferred from trial data
        // No need for separate logging event
    }
    
    // Legacy method kept for compatibility - no longer used
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        // Direct CSV writing is now done in individual log methods
    }
    
    /// Log grid update - now handled by frame logging with seeds
    func logGridUpdate(updateIndex: Int, seed: UInt64, stimulusType: String, coherence: Double, gratingContrast: Double, trialIndex: Int?, quadrant: Quadrant?) {
        // Grid updates are now captured in frame events with seeds
        // This method kept for backward compatibility but does nothing
    }
    
    /// Log click/tap event - now handled by response logging
    func logClick(clickTime: Date, trialIndex: Int?, stimulusType: String, coherence: Double, gratingContrast: Double, isValid: Bool, currentState: String, quadrant: Quadrant?) {
        // Clicks are now logged as "response" events via appendDetectionTimes
        // This method kept for backward compatibility but does nothing
    }
    
    /// Update RT window times for withinRTWindow column calculation
    func updateRTWindow(start: Date?, end: Date?) {
        self.rtWindowStart = start
        self.rtWindowEnd = end
    }
    
    // MARK: - MATLAB Compatibility Logging Methods
    
    /// Log frame event with simplified format (for stimulus reconstruction)
    func logFrameEvent(
        frameNumber: Int,
        checkSum: Int,
        flipTime: TimeInterval,
        drawScreensStart: TimeInterval,
        stimulusType: String,
        trialIndex: Int?,
        coherence: Double?,
        gratingContrast: Double?,
        quadrant: Quadrant?,
        gratingSide: String? = nil,
        gratingOn: Bool = false,
        rngSeed: UInt64? = nil
    ) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        let trialTime = calculateTrialTime()
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append(String(format: "%.3f", trialTime))
        csvFields.append("frame")
        csvFields.append(sessionId)
        csvFields.append(trialIndex?.description ?? "")
        csvFields.append(coherence?.description ?? "")
        csvFields.append(gratingContrast?.description ?? "")
        csvFields.append(quadrant?.rawValue ?? "")
        csvFields.append(String(frameNumber))
        csvFields.append(rngSeed?.description ?? "")  // Seed for reconstruction
        csvFields.append(gratingOn ? "true" : "false")  // stimulusOn - based on gratingOn parameter
        csvFields.append("")  // response
        csvFields.append("")  // reactionTime
        csvFields.append(isWithinRTWindow(timestamp) ? "true" : "false")  // withinRTWindow
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log session configuration (simplified - configuration rows removed)
    /// This method now does nothing, as configuration logging has been removed to reduce CSV clutter
    func logSessionConfiguration(
        numXRects: Int,
        numYRects: Int,
        screenWidthDeg: Double,
        screenHeightDeg: Double,
        stimulusUpdateRateHz: Double,
        displayHz: Int,
        settings: TrialSettings
    ) {
        // Configuration logging removed - all config rows between session_start and trial_start have been eliminated
        // The method signature is kept for compatibility but does nothing now
    }
    
    /// Log checkerboardParams event for MATLAB compatibility
    private func logCheckerboardParams(numXRects: Int, numYRects: Int) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(formatTimestamp(timestamp))  // timestampReadable
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append("checkerboardParams")
        csvFields.append(sessionId)
        
        // Empty fields
        for _ in 0..<15 { csvFields.append("") }
        
        // MATLAB compatibility fields
        for _ in 0..<5 { csvFields.append("") }  // checkSum through gratingSide
        csvFields.append("")  // behavioralOutcome
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log screenParameters event for MATLAB compatibility
    private func logScreenParameters(
        screenWidthDeg: Double,
        screenHeightDeg: Double,
        stimulusUpdateRateHz: Double,
        displayHz: Int
    ) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(formatTimestamp(timestamp))  // timestampReadable
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append("screenParameters")
        csvFields.append(sessionId)
        
        // Empty fields
        for _ in 0..<15 { csvFields.append("") }
        
        // MATLAB compatibility fields
        for _ in 0..<5 { csvFields.append("") }  // checkSum through gratingSide
        csvFields.append("")  // behavioralOutcome
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log GUIParameters event for MATLAB compatibility
    private func logGUIParameters(settings: TrialSettings) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(formatTimestamp(timestamp))  // timestampReadable
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append("GUIParameters")
        csvFields.append(sessionId)
        
        // Empty fields
        for _ in 0..<15 { csvFields.append("") }
        
        // MATLAB compatibility fields (empty)
        for _ in 0..<5 { csvFields.append("") }  // checkSum through gratingSide
        csvFields.append("")  // behavioralOutcome
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log RNG state event for MATLAB compatibility (initial RNG state)
    private func logRNGState(seed: UInt64) {
        let timestamp = Date().timeIntervalSince1970
        let sessionTime = Date().timeIntervalSince(sessionStartTime)
        
        var csvFields: [String] = []
        csvFields.append(String(timestamp))
        csvFields.append(formatTimestamp(timestamp))  // timestampReadable
        csvFields.append(String(format: "%.3f", sessionTime))
        csvFields.append("rngState")
        csvFields.append(sessionId)
        
        // Empty fields
        for _ in 0..<15 { csvFields.append("") }
        
        // MATLAB compatibility fields
        for _ in 0..<5 { csvFields.append("") }  // checkSum through gratingSide
        csvFields.append("")  // behavioralOutcome
        
        let csvRow = csvFields.joined(separator: ",")
        writeToFile(csvRow + "\n", to: currentLogFile)
    }
    
    /// Log static stimulus cue on event - now handled by state change logging
    func logStaticStimulusCueOn(cueSide: String) {
        // This is now handled by logStateChange when transitioning to .cue state
        // Keeping method for backward compatibility but not logging separately
    }
    
    /// Log noise stimulus on requested event - simplified
    func logNoiseStimulusOnRequested() {
        // Skip logging - too granular for analysis
    }
    
    /// Log grating stimulus on requested event - simplified
    func logGratingStimulusOnRequested() {
        // Skip logging - too granular for analysis
    }
    
    /// Log grating on event - now handled by frame events with stimulusOn flag
    func logGratingOn(trialIndex: Int?, inRTWindow: Bool = false) {
        // Grating state is now tracked via stimulusOn flag in frame events
        // This method kept for backward compatibility but does nothing
    }
    
    /// Log draw screens start event (time zero reference)
    func logDrawScreensStart() {
        // Skip logging - internal event not needed for analysis
    }
    
    // MARK: - Export
    
    /// Append detection times to the log file
    func appendDetectionTimes(_ detectionTimes: [Date]) {
        guard !detectionTimes.isEmpty, let logFile = currentLogFile else { return }
        
        for detectionTime in detectionTimes {
            let timestamp = detectionTime.timeIntervalSince1970
            let sessionTime = detectionTime.timeIntervalSince(sessionStartTime)
            let trialTime = calculateTrialTime()
            
            var csvFields: [String] = []
            csvFields.append(String(timestamp))
            csvFields.append(String(format: "%.3f", sessionTime))
            csvFields.append(String(format: "%.3f", trialTime))
            csvFields.append("response")  // Simplified from "detection"
            csvFields.append(sessionId)
            csvFields.append("")  // trialIndex
            csvFields.append("")  // coherence
            csvFields.append("")  // gratingContrast
            csvFields.append("")  // quadrant
            csvFields.append("")  // frameNumber
            csvFields.append("")  // seed
            csvFields.append("")  // stimulusOn (unknown at time of detection)
            csvFields.append("")  // response (outcome filled in trial_end)
            csvFields.append("")  // reactionTime (calculated in trial_end)
            csvFields.append(isWithinRTWindow(timestamp) ? "true" : "false")  // withinRTWindow
            
            let csvRow = csvFields.joined(separator: ",")
            writeToFile(csvRow + "\n", to: logFile)
        }
    }
    
    /// Export unified CSV file and return URL for sharing
    func exportCSV() -> URL? {
        return currentLogFile
    }
    
    /// Export unified log file (returns array for compatibility with existing code)
    func exportAllLogs() -> [URL] {
        if let logFile = currentLogFile {
            return [logFile]
        }
        return []
    }
    
    /// Log session end (when trials stop or last trial completes)
    func logSessionEnd() {
        // Session end doesn't need to be logged as a data row
        // Can be inferred from last trial_end timestamp
        print("Logging session ended: \(sessionId)")
    }
    
    deinit {
        // Cleanup only - session_end is logged when stop() is called
    }
}

// MARK: - Main Stimulus Controller (Trial State Machine)
class StimulusController: NSObject {
    
    // MARK: - Properties
    weak var delegate: StimulusControllerDelegate?
    
    private var displayTicker: DisplayTicker
    private var renderer: CheckerboardRenderer
    private(set) var logger: StimulusLogger  // Accessible for external logging
    
    // Trial management
    private var trialSequence: [TrialConfig] = []
    private var currentTrialIndex = 0
    private(set) var currentTrial: TrialConfig?  // Made accessible for UI
    private(set) var trialResults: [TrialResult] = []
    
    // Settings
    private var trialSettings: TrialSettings = TrialSettings.load()
    
    // State management
    private var currentState: TrialState = .idle
    private var stateStartTime: Date = Date()
    private var stateFrameCount = 0
    private var totalFrameCount = 0
    
    // Timing
    private var trialStartTime: Date?
    private var coherentOnsetFrame = 0
    private var coherentTargetFrame = 0
    private var _coherentStartTime: Date?
    private var currentTrialCoherentStartTime: Date?  // Store coherent start time for current trial (doesn't reset when state changes)
    
    // MATLAB compatibility tracking
    private var drawScreensStartTime: TimeInterval = 0  // Time zero reference
    private var frameCounter: Int = 0  // Sequential frame counter
    
    // Response tracking
    private var trialResponseTime: Date?  // Time when user responded in current trial
    private var trialResponseTimeRelative: Double?  // Response time relative to trial start
    private var currentClickResult: String?  // Current click result for dashboard display ("hit", "fa", etc.)
    
    // FA handling state tracking
    private var gratingRequestedFlag = false  // Whether grating has been requested to appear
    private var rewardLicksWindowEnd: Date?  // Time when reward window ends (ignore licks after rewards)
    private var rtWindowStart: Date?  // Response window start time
    private var rtWindowEnd: Date?  // Response window end time
    private var trialEndTime: Date?  // Absolute time when trial should end
    private var automaticRewardGiven: Bool = false  // Whether automatic reward was given for wrong click/miss
    
    // Control flags
    private var isRunning = false
    private var isPaused = false
    
    // MARK: - Initialization
    init(sessionId: String? = nil) {
        self.displayTicker = DisplayTicker()
        self.renderer = CheckerboardRenderer()
        self.logger = StimulusLogger(sessionId: sessionId)
        
        super.init()
        
        displayTicker.delegate = self
    }
    
    // MARK: - Public Interface
    
    /// Current coherence level (if in coherent state)
    var currentCoherence: Double {
        guard currentState == .coherent, let trial = currentTrial else { return 0.0 }
        return trial.coherence
    }
    
    /// Current tile size in pixels
    var tilePx: Int {
        return VisualGeometry.shared.currentTilePx
    }
    
    /// Current viewing distance in cm
    var distanceCm: Double {
        get { return VisualGeometry.shared.viewingDistanceCm }
        set { VisualGeometry.shared.viewingDistanceCm = newValue }
    }
    
    /// Whether using calibration
    var usingCalibration: Bool {
        get { return VisualGeometry.shared.usingCalibration }
        set { VisualGeometry.shared.usingCalibration = newValue }
    }
    
    /// Current trial state
    var state: TrialState {
        return currentState
    }
    
    /// Start time of current coherent state (for detection window validation)
    var coherentStartTime: Date? {
        return _coherentStartTime
    }
    
    /// Current trial information
    var currentTrialInfo: (index: Int, total: Int, coherence: Double)? {
        guard let trial = currentTrial else { return nil }
        return (currentTrialIndex + 1, trialSequence.count, trial.coherence)
    }
    
    /// Whether trials are currently running
    var isActive: Bool {
        return isRunning && !isPaused
    }
    
    /// Whether trials are currently paused
    var isPausedPublic: Bool {
        return isPaused
    }
    
    /// Display refresh rate
    var displayRefreshRate: Int {
        return displayTicker.refreshRate
    }
    
    /// Stimulus frame rate
    var stimulusFrameRate: Double {
        return displayTicker.actualStimulusRate
    }
    
    /// Update trial settings (reload from UserDefaults)
    func updateSettings() {
        trialSettings = TrialSettings.load()
        trialSettings.applyGridSize()  // Apply grid size to StimulusParams
        trialSettings.applyStimulusHz()  // Apply stimulus Hz to StimulusParams
        
        // Update renderer with new grid size
        renderer.updateGridSize(newRows: StimulusParams.rows, newCols: StimulusParams.cols)
    }
    
    /// Get current trial settings
    var currentSettings: TrialSettings {
        return trialSettings
    }
    
    /// Get session information (experiment name, user name, subject name)
    var sessionInfo: (experiment: String, user: String, subject: String) {
        // Access logger's sessionId and parse it
        // The logger's sessionId is private, so we need to access it through the logger
        // Since we can't access it directly, we'll use a workaround by getting the session ID from UserDefaults
        // or by exposing it through the logger
        // For now, let's parse the logger's sessionId if we can access it
        // Actually, let's add a method to the logger to get session info
        return logger.getSessionInfo()
    }
    
    /// Mark that automatic reward was given (called when automatic reward is granted for wrong click)
    func markAutomaticRewardGiven() {
        automaticRewardGiven = true
    }
    
    /// Check if automatic reward was given for the current/last trial
    var wasAutomaticRewardGiven: Bool {
        return automaticRewardGiven
    }
    
    // MARK: - Response Registration
    
    /// Register a user response (tap) during a trial
    /// New simplified logic:
    /// - Click between 0 and (stimulus_start + RT_delay) → false alarm (early)
    /// - Click between (stimulus_start + RT_delay) and (stimulus_end + RT_delay) → hit
    /// - Click between (stimulus_end + RT_delay) and trial_end → false alarm (late)
    /// - No click → miss (determined at trial end)
    /// - Parameter responseTime: The time when the user tapped
    /// - Returns: Response outcome type: "hit", "fa_extended", "fa_timeout", "ignored", or nil
    @discardableResult
    func registerResponse(at responseTime: Date) -> String? {
        guard let trial = currentTrial, let startTime = trialStartTime else { return nil }
        
        let now = Date()
        let relativeTime = responseTime.timeIntervalSince(startTime)
        
        // Check if lick is in reward window (ignore it - it's due to a previous reward)
        if let rewardWindowEnd = rewardLicksWindowEnd, now < rewardWindowEnd {
            print("🔇 Response ignored (within reward window after previous reward)")
            return "ignored"
        }
        
        // Only record first response
        guard trialResponseTime == nil else { return nil }
        
        // Get actual stimulus timing
        let actualCoherentStartTime: Date? = _coherentStartTime
        
        // Calculate timing boundaries
        let hitWindowStart: Date?
        let hitWindowEnd: Date?
        
        if let stimulusStart = actualCoherentStartTime {
            // Stimulus has appeared - calculate hit window
            let stimulusEnd = stimulusStart.addingTimeInterval(trial.settings.stimulusDuration)
            hitWindowStart = stimulusStart.addingTimeInterval(trial.settings.rtWindowDelay)
            hitWindowEnd = stimulusEnd.addingTimeInterval(trial.settings.rtWindowDelay)
        } else {
            // Stimulus hasn't appeared yet - cannot be a hit
            hitWindowStart = nil
            hitWindowEnd = nil
        }
        
        // Determine response type based on timing
        if let hitStart = hitWindowStart, let hitEnd = hitWindowEnd {
            // Stimulus has appeared - check if click is in hit window
            if responseTime >= hitStart && responseTime <= hitEnd {
                // HIT: Click within hit window [stimulus_start + RT_delay, stimulus_end + RT_delay]
                trialResponseTime = responseTime
                trialResponseTimeRelative = relativeTime
                currentClickResult = "hit"
                
                let startOffset = hitStart.timeIntervalSince(startTime)
                let endOffset = hitEnd.timeIntervalSince(startTime)
                print("✅ HIT registered: \(String(format: "%.3f", relativeTime))s after trial start (hit window: \(String(format: "%.3f", startOffset))s - \(String(format: "%.3f", endOffset))s)")
                
                return "hit"
            } else if responseTime < hitStart {
                // FALSE ALARM (EARLY): Click before hit window starts [0, stimulus_start + RT_delay)
                trialResponseTime = responseTime
                trialResponseTimeRelative = relativeTime
                currentClickResult = "fa"
                let startOffset = hitStart.timeIntervalSince(startTime)
                print("⚠️ FA registered (EARLY): \(String(format: "%.3f", relativeTime))s after trial start - clicked before hit window (window starts at \(String(format: "%.3f", startOffset))s)")
                
                // Handle FA based on trial timing
                let faResult = handleFalseAlarm(at: responseTime, relativeTime: relativeTime)
                switch faResult {
                case .extended:
                    return "fa_extended"
                case .rewarded:
                    return "fa_rewarded"
                case .timeout:
                    return "fa_timeout"
                }
            } else {
                // FALSE ALARM (LATE): Click after hit window ends (stimulus_end + RT_delay, trial_end]
                trialResponseTime = responseTime
                trialResponseTimeRelative = relativeTime
                currentClickResult = "fa"
                let endOffset = hitEnd.timeIntervalSince(startTime)
                print("⚠️ FA registered (LATE): \(String(format: "%.3f", relativeTime))s after trial start - clicked after hit window (window ends at \(String(format: "%.3f", endOffset))s)")
                
                // Handle FA based on trial timing
                let faResult = handleFalseAlarm(at: responseTime, relativeTime: relativeTime)
                switch faResult {
                case .extended:
                    return "fa_extended"
                case .rewarded:
                    return "fa_rewarded"
                case .timeout:
                    return "fa_timeout"
                }
            }
        } else {
            // Stimulus hasn't appeared yet - this is an EARLY FALSE ALARM
            trialResponseTime = responseTime
            trialResponseTimeRelative = relativeTime
            currentClickResult = "fa"
            print("⚠️ FA registered (EARLY): \(String(format: "%.3f", relativeTime))s after trial start - clicked before stimulus appeared")
            
            // Handle FA based on trial timing
            let faResult = handleFalseAlarm(at: responseTime, relativeTime: relativeTime)
            switch faResult {
            case .extended:
                return "fa_extended"
            case .rewarded:
                return "fa_rewarded"
            case .timeout:
                return "fa_timeout"
            }
        }
    }
    
    /// FA handling result
    private enum FAHandlingResult {
        case extended    // Early FA - trial extended
        case rewarded    // FA rewarded - trial continues
        case timeout     // Late FA - trial ends
    }
    
    /// Handle false alarm based on trial timing (matches MATLAB logic)
    /// - Parameters:
    ///   - responseTime: Absolute time of FA response
    ///   - relativeTime: Time relative to trial start
    /// - Returns: FA handling result
    private func handleFalseAlarm(at responseTime: Date, relativeTime: Double) -> FAHandlingResult {
        guard let _ = currentTrial, let _ = trialStartTime else { return .timeout }
        
        // Check if we should reward this FA
        if Double.random(in: 0.0..<1.0) < trialSettings.probFALickReward {
            // Reward the FA and continue trial
            print("🎁 FA rewarded (prob=\(trialSettings.probFALickReward))")
            
            // Set reward window to ignore subsequent licks
            rewardLicksWindowEnd = Date().addingTimeInterval(trialSettings.rewardLicksWindowLength)
            
            // Note: In actual implementation, you'd trigger reward delivery here
            // Trial continues with reward
            
            return .rewarded  // Trial continues, FA was rewarded
        }
        
        // Don't reward - handle based on grating timing
        if !gratingRequestedFlag {
            // EARLY FA: Grating hasn't been requested yet - EXTEND TRIAL
            print("🔄 FAExtendTrial: Early FA detected, extending trial")
            extendTrialOnEarlyFA()
            return .extended  // Trial was extended
        } else {
            // LATE FA: Grating already requested - cannot stop it from appearing
            // Mark trial as FA and end immediately
            print("❌ Late FA: Grating already requested, cannot extend. Ending trial as FA.")
            
            // Record this as an FA response
            trialResponseTime = responseTime
            trialResponseTimeRelative = relativeTime
            
            // End trial immediately (go to inter-trial interval)
            // The trial will be completed as FA
            changeState(.interTrial)
            
            return .timeout  // Trial marked as FA, ended immediately
        }
    }
    
    /// Extend trial on early FA (FAExtendTrial logic)
    /// Resets timing from current moment, giving animal a second chance
    private func extendTrialOnEarlyFA() {
        guard let trial = currentTrial, let _ = trialStartTime else { return }
        
        let now = Date()
        
        // Reset trial start time to now (trial extends from this point)
        trialStartTime = now
        
        // Reset response tracking
        trialResponseTime = nil
        trialResponseTimeRelative = nil
        
        // Reset grating requested flag
        gratingRequestedFlag = false
        
        // Recalculate coherent onset from NOW
        // The onset time is relative, so we keep the same relative time
        let framesPerSecond = Int(displayTicker.actualStimulusRate)
        let onsetFrames = Int(trial.onsetTime * Double(framesPerSecond))
        coherentTargetFrame = onsetFrames
        
        // Reset state frame count for the noise phase (we're back in noise phase)
        // We need to stay in noise phase until new grating onset
        if currentState != .noise {
            changeState(.noise)
        }
        stateFrameCount = 0  // Reset frame count for noise phase
        
        // Recalculate RT window times (will be set when grating appears)
        rtWindowStart = nil
        rtWindowEnd = nil
        logger.updateRTWindow(start: nil, end: nil)
        
        // Recalculate trial end time from new start
        let newTrialEndTime = now.addingTimeInterval(trial.onsetTime + trial.settings.stimulusDuration)
        trialEndTime = newTrialEndTime
        
        // Reset reward window
        rewardLicksWindowEnd = nil
        
        print("📅 Trial extended: New grating onset in \(trial.onsetTime)s, trial ends in \(trial.onsetTime + trial.settings.stimulusDuration)s")
        
        // Note: Cue would be re-shown in original implementation
        // In our simplified version, we just continue in noise phase
    }
    
    // MARK: - Trial Control
    
    /// Start trials with specified sequence (nil for randomized default)
    func startTrials(sequence: [Double]? = nil) {
        guard !isRunning else {
            print("Trials already running")
            return
        }
        
        // Reload settings to get latest configuration
        trialSettings = TrialSettings.load()
        trialSettings.applyGridSize()  // Apply grid size to StimulusParams
        trialSettings.applyStimulusHz()  // Apply stimulus Hz to StimulusParams
        
        // Update renderer with current grid size
        renderer.updateGridSize(newRows: StimulusParams.rows, newCols: StimulusParams.cols)
        
        // Generate trial sequence
        if let customSequence = sequence {
            trialSequence = customSequence.enumerated().map { index, coherence in
                TrialConfig(coherence: coherence, trialIndex: index, settings: trialSettings)
            }
        } else {
            trialSequence = generateRandomizedSequence()
        }
        
        // Reset state
        currentTrialIndex = 0
        trialResults.removeAll()
        totalFrameCount = 0
        frameCounter = 0
        
        // Log session start (when first trial starts)
        logger.logSessionStart()
        
        // Start display ticker
        // IMPORTANT: Ensure stimulus Hz is applied before starting DisplayTicker
        // so it uses the correct flicker rate for duration calculations
        trialSettings.applyStimulusHz()  // Ensure targetStimHz is up to date
        isRunning = true
        isPaused = false
        
        // Log draw screens start (time zero reference for MATLAB compatibility)
        drawScreensStartTime = Date().timeIntervalSince1970
        logger.logDrawScreensStart()
        
        print("📊 Starting trials with stimulus Hz: \(trialSettings.stimulusHz) Hz (targetStimHz: \(StimulusParams.targetStimHz))")
        displayTicker.start()
        
        // Log session configuration (for MATLAB compatibility)
        // Calculate screen dimensions in degrees from geometry
        let screenWidthPx = Double(UIScreen.main.bounds.width)
        let screenHeightPx = Double(UIScreen.main.bounds.height)
        let pxPerCm = VisualGeometry.shared.pxPerCm
        let distanceCm = VisualGeometry.shared.viewingDistanceCm
        let screenWidthCm = screenWidthPx / pxPerCm
        let screenHeightCm = screenHeightPx / pxPerCm
        let screenWidthDeg = atan((screenWidthCm / 2.0) / distanceCm) * 2.0 * (180.0 / .pi)
        let screenHeightDeg = atan((screenHeightCm / 2.0) / distanceCm) * 2.0 * (180.0 / .pi)
        logger.logSessionConfiguration(
            numXRects: StimulusParams.cols,
            numYRects: StimulusParams.rows,
            screenWidthDeg: screenWidthDeg,
            screenHeightDeg: screenHeightDeg,
            stimulusUpdateRateHz: displayTicker.actualStimulusRate,
            displayHz: displayTicker.refreshRate,
            settings: trialSettings
        )
        
        // Begin first trial
        startNextTrial()
        
        print("Started trials: \(trialSequence.count) trials, coherence levels: \(trialSequence.map { $0.coherence })")
    }
    
    /// Stop all trials
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        isPaused = false
        displayTicker.stop()
        
        // Complete current trial if in progress
        if currentTrial != nil {
            completeCurrentTrial()
        }
        
        // Notify delegate
        delegate?.stimulusController(self, didCompleteTrials: trialResults)
        
        // Log final results
        logger.logTrialSequenceComplete(trialResults)
        
        // Log session end
        logger.logSessionEnd()
        
        print("Stopped trials: \(trialResults.count) completed")
    }
    
    /// Toggle pause state
    func togglePause() {
        guard isRunning else { return }
        
        isPaused.toggle()
        
        if isPaused {
            print("⏸️  Trials paused")
        } else {
            print("▶️  Trials resumed")
        }
    }
    
    /// End current trial early and start next trial immediately
    func endCurrentTrialAndStartNext() {
        guard isRunning, currentTrial != nil else { return }
        
        print("⏭️ Ending trial early and starting next trial")
        
        // IMPORTANT: Reset state to .noise immediately to clear any coherent stimulus
        // This prevents artifacts where the old trial's coherent state persists
        // and shows up with the new trial's quadrant
        if currentState == .coherent {
            print("🔄 Resetting state from .coherent to .noise to clear stimulus artifacts")
            changeState(.noise)
        }
        
        // Complete current trial (this will log results and increment trial index)
        completeCurrentTrial()
        
        // Start next trial immediately (skip inter-trial interval)
        // startNextTrial() will handle state transition to .cue
        startNextTrial()
    }
    
    // MARK: - Private Trial Management
    
    private func generateRandomizedSequence(startingIndex: Int = 0) -> [TrialConfig] {
        var sequence: [TrialConfig] = []
        
        // Get grating contrast levels from settings
        let gratingContrastLevels = trialSettings.parsedGratingContrasts
        
        // If no valid contrast levels, use default
        let contrastLevels = gratingContrastLevels.isEmpty ? [1.0] : gratingContrastLevels
        
        // Always use maximum coherence (1.0) for red stimulus
        let fixedCoherence = 1.0
        
        // Create trials for each grating contrast level
        // Note: Quadrant will be randomly selected at cue time, not here
        var trialIndex = startingIndex
        for contrast in contrastLevels {
            let trial = TrialConfig(
                coherence: fixedCoherence,
                gratingContrast: contrast,
                trialIndex: trialIndex,
                settings: trialSettings,
                quadrant: nil  // Quadrant will be randomly selected when cue appears
            )
            print("🎲 Generated trial \(trialIndex): contrast=\(contrast) (quadrant will be selected at cue time)")
            sequence.append(trial)
            trialIndex += 1
        }
        
        // Shuffle the sequence to randomize order
        let shuffled = sequence.shuffled()
        print("🔀 Shuffled sequence: \(shuffled.map { "\($0.gratingContrast)" }.joined(separator: ", "))")
        return shuffled
    }
    
    private func startNextTrial() {
        // If we've reached the end of the sequence, regenerate and shuffle for continuous trials
        if currentTrialIndex >= trialSequence.count {
            // Regenerate the sequence for continuous trials, starting from current total count
            let startingIndex = trialSequence.count
            let newSequence = generateRandomizedSequence(startingIndex: startingIndex)
            trialSequence.append(contentsOf: newSequence)
            print("🔄 Generated \(newSequence.count) new trials (total now: \(trialSequence.count))")
        }
        
        // SAFEGUARD: Ensure we're not in a coherent state when starting a new trial
        // This prevents artifacts where coherent stimulus from previous trial persists
        if currentState == .coherent {
            print("⚠️ WARNING: Starting new trial while in .coherent state - resetting to .noise")
            changeState(.noise)
        }
        
        // Get the trial from sequence
        var trial = trialSequence[currentTrialIndex]
        
        // IMPORTANT: Randomly select quadrant NOW (at cue time), not when trial was generated
        // This ensures we don't know which quadrant until the cue appears
        let randomQuadrant = Quadrant.random()
        trial.quadrant = randomQuadrant
        currentTrial = trial
        
        print("▶️ Starting trial \(currentTrialIndex): contrast=\(trial.gratingContrast)")
        print("🎲 Randomly selected quadrant: \(trial.quadrant.displayName) (selected at cue time)")
        
        // Verify stimulus position calculation
        let gaborCenters = StimulusParams.gaborCenters(quadrant: trial.quadrant)
        print("   Stimulus centers (col,row): \(gaborCenters.map { "(\($0.x), \($0.y))" }.joined(separator: ", "))")
        print("   Grid dimensions: \(StimulusParams.cols)×\(StimulusParams.rows)")
        
        // Update renderer quadrant for this trial
        renderer.updateQuadrant(trial.quadrant)
        
        // Calculate coherent onset frame
        let framesPerSecond = Int(displayTicker.actualStimulusRate)
        let onsetFrames = Int(trial.onsetTime * Double(framesPerSecond))
        coherentTargetFrame = onsetFrames
        
        // Reset counters
        stateFrameCount = 0
        coherentOnsetFrame = 0
        
        // Reset response tracking
        trialResponseTime = nil
        trialResponseTimeRelative = nil
        currentClickResult = nil  // Reset click result for new trial
        automaticRewardGiven = false
        currentTrialCoherentStartTime = nil  // Reset for new trial
        
        // Reset FA handling state
        gratingRequestedFlag = false
        rewardLicksWindowEnd = nil
        rtWindowStart = nil
        rtWindowEnd = nil
        logger.updateRTWindow(start: nil, end: nil)
        
        // Notify delegate (this happens immediately, before the cue delay)
        delegate?.stimulusController(self, didStartTrial: trial)
        
        // Log trial start (this happens immediately, before the cue delay)
        logger.logTrialStart(trial, frameCount: totalFrameCount)
        
        // Add a 0.5 second delay before showing the cue to allow user to reset their mind
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            // Set trial start time when cue actually appears (so timing is correct)
            self.trialStartTime = Date()
            
            // Calculate trial end time based on actual trial start
            self.trialEndTime = self.trialStartTime!.addingTimeInterval(trial.onsetTime + trial.settings.stimulusDuration)
            
            // Start with cue phase to show which quadrant the stimulus will appear in
            self.changeState(.cue)
        }
    }
    
    private func completeCurrentTrial() {
        guard let trial = currentTrial, let startTime = trialStartTime else { return }
        
        // Determine response type using the same logic as registerResponse
        // New simplified logic:
        // - Click between 0 and (stimulus_start + RT_delay) → false alarm (early)
        // - Click between (stimulus_start + RT_delay) and (stimulus_end + RT_delay) → hit
        // - Click between (stimulus_end + RT_delay) and trial_end → false alarm (late)
        // - No click → miss
        let responseType: String?
        let wasInWindow: Bool
        
        if let responseTime = trialResponseTime {
            // There was a response - classify it based on timing
            // Get actual stimulus timing
            let actualCoherentStartTime: Date? = currentTrialCoherentStartTime
            
            if let stimulusStart = actualCoherentStartTime {
                // Stimulus has appeared - calculate hit window
                let stimulusEnd = stimulusStart.addingTimeInterval(trial.settings.stimulusDuration)
                let hitWindowStart = stimulusStart.addingTimeInterval(trial.settings.rtWindowDelay)
                let hitWindowEnd = stimulusEnd.addingTimeInterval(trial.settings.rtWindowDelay)
                
                // Check if response is within hit window
                if responseTime >= hitWindowStart && responseTime <= hitWindowEnd {
                    // HIT: Click within hit window [stimulus_start + RT_delay, stimulus_end + RT_delay]
                    responseType = "hit"
                    wasInWindow = true
                } else {
                    // FALSE ALARM: Click outside hit window
                    responseType = "fa"
                    wasInWindow = false
                }
            } else {
                // Stimulus hasn't appeared - this is an EARLY FALSE ALARM
                responseType = "fa"
                wasInWindow = false
            }
        } else {
            // No response - this is a MISS
            responseType = "miss"
            wasInWindow = false
            
            // Check for automatic reward on MISS (no click, but should have clicked)
            if !automaticRewardGiven {
                let probAutomaticReward = trial.settings.probAutomaticStimReward
                if Double.random(in: 0.0..<1.0) < probAutomaticReward {
                    automaticRewardGiven = true
                    print("🎁 Automatic reward given for MISS (prob=\(probAutomaticReward))")
                }
            }
        }
        
        // Calculate reaction time (time from visual stimulus onset to response)
        var reactionTime: Double? = nil
        if let responseTime = trialResponseTime, let coherentStartTime = currentTrialCoherentStartTime {
            // Reaction time is response time minus the actual visual stimulus onset time
            reactionTime = responseTime.timeIntervalSince(coherentStartTime)
        }
        
        let result = TrialResult(
            config: trial,
            startTime: startTime,
            endTime: Date(),
            coherentOnsetFrame: coherentOnsetFrame,
            totalFrames: stateFrameCount,
            response: responseType,
            reactionTime: reactionTime,
            responseTime: trialResponseTimeRelative,
            wasInResponseWindow: wasInWindow,
            receivedAutomaticReward: automaticRewardGiven
        )
        
        trialResults.append(result)
        logger.logTrialComplete(result, frameCount: totalFrameCount)
        
        // Log outcome
        if let response = responseType {
            print("📊 Trial completed: \(response.uppercased())")
        } else {
            print("📊 Trial completed: no response")
        }
        
        currentTrial = nil
        currentTrialIndex += 1
    }
    
    private func changeState(_ newState: TrialState) {
        let previousState = currentState
        currentState = newState
        stateStartTime = Date()
        stateFrameCount = 0
        
        // Set coherent start time for detection window validation
        if newState == .coherent {
            _coherentStartTime = stateStartTime
            currentTrialCoherentStartTime = stateStartTime  // Save for reaction time calculation
            
            // CRITICAL: Recalculate RT window times based on ACTUAL stimulus start time
            // This ensures the response window is only active after the stimulus actually appears
            if let trial = currentTrial {
                rtWindowStart = stateStartTime.addingTimeInterval(trial.settings.rtWindowDelay)
                rtWindowEnd = rtWindowStart!.addingTimeInterval(trial.settings.rtWindowLength)
                logger.updateRTWindow(start: rtWindowStart, end: rtWindowEnd)
                
                if let startTime = trialStartTime {
                    print("🎯 RT window recalculated based on actual stimulus appearance: [\(String(format: "%.3f", rtWindowStart!.timeIntervalSince(startTime)))s - \(String(format: "%.3f", rtWindowEnd!.timeIntervalSince(startTime)))s]")
                }
            }
        } else if previousState == .coherent {
            _coherentStartTime = nil
            // Don't reset currentTrialCoherentStartTime - we need it for reaction time calculation
        }
        
        // Log state change
        logger.logStateChange(from: previousState, to: newState, frameCount: totalFrameCount)
        
        // Log explicit state transition events (for MATLAB compatibility)
        switch newState {
        case .noise:
            logger.logNoiseStimulusOnRequested()
        case .coherent:
            logger.logGratingStimulusOnRequested()
            // Log gratingOn for each frame (will be called in updateForCurrentFrame)
        case .cue:
            // Log static cue (if we support side-specific cues, would pass 'L' or 'R')
            // For now, single screen, so no side specified
            logger.logStaticStimulusCueOn(cueSide: "")
        default:
            break
        }
        
        // Notify delegate
        delegate?.stimulusController(self, didChangeState: newState)
        
        print("State: \(previousState.rawValue) -> \(newState.rawValue)")
    }
    
    // MARK: - Frame Update Logic
    
    private func updateForCurrentFrame() {
        guard let trial = currentTrial else { return }
        
        stateFrameCount += 1
        totalFrameCount += 1
        frameCounter += 1
        
        // Generate seed for this frame BEFORE logging
        // This ensures we log the seed that will actually be used
        let rngSeed = SeededRandomGenerator.generateSeed()
        
        // Calculate frame checksum (based on previous frame state)
        let checkSum = renderer.calculateChecksum()
        let now = Date().timeIntervalSince1970
        let flipTime = now  // Approximate flip time (actual would be from CADisplayLink)
        
        // Determine stimulus type
        let stimulusType: String
        let gratingOn: Bool
        switch currentState {
        case .coherent:
            stimulusType = "coherent"
            gratingOn = true
            // Log gratingOn event for each coherent frame
            logger.logGratingOn(trialIndex: trial.trialIndex)
        case .noise, .cue, .fixation, .interTrial:
            // All these states now show flickering noise to prevent checkerboard freezing
            stimulusType = "noise"
            gratingOn = false
        default:
            stimulusType = "unknown"
            gratingOn = false
        }
        
        // Log frame event with checksum BEFORE generating new frame
        // Use the pre-generated seed that will be passed to the renderer
        logger.logFrameEvent(
            frameNumber: frameCounter,
            checkSum: checkSum,
            flipTime: flipTime,
            drawScreensStart: drawScreensStartTime,
            stimulusType: stimulusType,
            trialIndex: trial.trialIndex,
            coherence: trial.coherence,
            gratingContrast: trial.gratingContrast,
            quadrant: trial.quadrant,
            gratingSide: trial.quadrant.rawValue,  // Use quadrant value
            gratingOn: gratingOn,
            rngSeed: rngSeed
        )
        
        // Now request frame update with the pre-generated seed
        switch currentState {
        case .idle:
            // Should not be updating in idle state
            break
            
        case .cue:
            // During cue phase, continue showing noise (flickering) with the cue indicator on top
            // The UI will handle showing the cue indicator arrow
            delegate?.stimulusController(self, requestsFrameUpdate: .noise(seed: rngSeed))
            
            // Check if cue duration is complete
            let cueFrames = Int(trial.settings.cueDuration * displayTicker.actualStimulusRate)
            if stateFrameCount >= cueFrames {
                changeState(.fixation)
            }
            
        case .fixation:
            // Continue showing noise during fixation period (keep flickering)
            delegate?.stimulusController(self, requestsFrameUpdate: .noise(seed: rngSeed))
            
            // Check if fixation period is complete
            let fixationFrames = Int(StimulusParams.fixationDuration * displayTicker.actualStimulusRate)
            if stateFrameCount >= fixationFrames {
                changeState(.noise)
            }
            
        case .noise:
            delegate?.stimulusController(self, requestsFrameUpdate: .noise(seed: rngSeed))
            
            // Check if we should transition to coherent
            if stateFrameCount >= coherentTargetFrame {
                // Grating is being requested to appear
                gratingRequestedFlag = true
                coherentOnsetFrame = totalFrameCount
                
                // DO NOT set RT window times here - they will be set when the stimulus actually appears
                // This ensures the response window is only active after the visual stimulus is visible
                guard trialStartTime != nil else { break }
                
                print("🎯 Grating requested (expected onset: \(String(format: "%.3f", trial.onsetTime))s, RT window will be set when stimulus appears)")
                
                // Log how many grid flicker frames the stimulus will be shown for
                // IMPORTANT: This uses actualStimulusRate from DisplayTicker, which should match trialSettings.stimulusHz
                let coherentFrames = Int(trial.settings.stimulusDuration * displayTicker.actualStimulusRate)
                let expectedHz = Double(trial.settings.stimulusHz)
                let actualHz = displayTicker.actualStimulusRate
                print("🔴 Starting coherent stimulus:")
                print("   Duration: \(String(format: "%.2f", trial.settings.stimulusDuration))s")
                print("   Expected flicker rate: \(String(format: "%.1f", expectedHz)) Hz")
                print("   Actual flicker rate: \(String(format: "%.1f", actualHz)) Hz")
                print("   Will show for: \(coherentFrames) grid flicker frames")
                if abs(expectedHz - actualHz) > 0.1 {
                    print("   ⚠️ WARNING: Flicker rate mismatch! Expected \(expectedHz) Hz but DisplayTicker is using \(actualHz) Hz")
                    print("   ⚠️ This may happen if DisplayTicker started before settings were updated. Restart trials to apply new Hz setting.")
                }
                
                // Update trialEndTime to be based on coherent start time, not trial start time
                // This ensures the trial end time matches the actual coherent stimulus duration
                let coherentStartTime = Date()
                trialEndTime = coherentStartTime.addingTimeInterval(trial.settings.stimulusDuration)
                
                changeState(.coherent)
            }
            
        case .coherent:
            delegate?.stimulusController(self, requestsFrameUpdate: .coherent(coherence: trial.coherence, gratingContrast: trial.gratingContrast, seed: rngSeed))
            
            let now = Date()
            
            // FIRST: Check if coherent window is complete using WALL-CLOCK TIME
            // This ensures the stimulus shows for exactly stimulusDuration seconds
            // regardless of flicker rate (e.g., 3.0 seconds = 3.0 seconds of actual time)
            // IMPORTANT: Check duration FIRST so stimulus always shows for full duration
            guard let coherentStart = _coherentStartTime else {
                // Should not happen, but fallback to frame-based if start time missing
                let coherentFrames = Int(trial.settings.stimulusDuration * displayTicker.actualStimulusRate)
                if stateFrameCount >= coherentFrames {
                    changeState(.interTrial)
                }
                return
            }
            
            let timeSinceCoherentStart = now.timeIntervalSince(coherentStart)
            
            // Debug logging every frame to track duration
            if stateFrameCount <= 10 || stateFrameCount % 10 == 0 {
                print("   [Coherent frame \(stateFrameCount)] Time elapsed: \(String(format: "%.3f", timeSinceCoherentStart))s / \(String(format: "%.2f", trial.settings.stimulusDuration))s")
            }
            
            if timeSinceCoherentStart >= trial.settings.stimulusDuration {
                // Stimulus duration complete - check for MISS before transitioning
                let actualFrames = stateFrameCount
                let expectedFrames = Int(trial.settings.stimulusDuration * displayTicker.actualStimulusRate)
                print("✅ Coherent stimulus complete:")
                print("   Requested duration: \(String(format: "%.2f", trial.settings.stimulusDuration))s")
                print("   Actual wall-clock time: \(String(format: "%.2f", timeSinceCoherentStart))s")
                print("   Grid flicker frames shown: \(actualFrames) (expected ~\(expectedFrames) at \(String(format: "%.1f", displayTicker.actualStimulusRate)) Hz)")
                
                // Check if we've passed RT window end without a response (MISS)
                // Only log it now, don't transition early - we already completed the full duration
                if let rtEnd = rtWindowEnd, now > rtEnd, trialResponseTime == nil {
                    print("⏱️ MISS: Past RT window end without response")
                }
                
                changeState(.interTrial)
                return
            }
            
            // SECOND: Check if we've passed RT window end without a response (MISS)
            // Log it but DON'T transition - let stimulus continue for full duration
            if let rtEnd = rtWindowEnd, now > rtEnd, trialResponseTime == nil {
                // Past RT window with no response - this is a MISS
                // But we continue showing the stimulus for the full duration
                // Only log once to avoid spam
                if stateFrameCount == 1 || (stateFrameCount % 10 == 0) {
                    // Log occasionally or on first frame after RT window ends
                    let timePastRTWindow = now.timeIntervalSince(rtEnd)
                    if timePastRTWindow < 0.1 || (stateFrameCount % 30 == 0) {
                        // Log only very close to RT window end or every 30 frames
                        print("⏱️ MISS: Past RT window end without response (stimulus continuing for full \(String(format: "%.2f", trial.settings.stimulusDuration))s duration)")
                    }
                }
            }
            
            // NOTE: trialEndTime check removed from coherent phase
            // The duration check above handles this correctly using wall-clock time
            // The trialEndTime was calculated from trialStartTime + onsetTime + stimulusDuration,
            // but there may be timing delays, so we use coherentStartTime + stimulusDuration instead
            
        case .interTrial:
            // Continue showing noise during inter-trial interval (keep flickering)
            delegate?.stimulusController(self, requestsFrameUpdate: .noise(seed: rngSeed))
            
            // Check if inter-trial interval is complete
            let itiFrames = Int(StimulusParams.interTrialInterval * displayTicker.actualStimulusRate)
            if stateFrameCount >= itiFrames {
                completeCurrentTrial()
                startNextTrial()
            }
        }
    }
    
    // MARK: - Diagnostics
    
    /// Get current status information
    func getStatusInfo() -> [String: Any] {
        var info: [String: Any] = [
            "isRunning": isRunning,
            "isPaused": isPaused,
            "currentState": currentState.rawValue,
            "totalFrames": totalFrameCount,
            "stateFrames": stateFrameCount,
            "displayHz": displayTicker.refreshRate,
            "stimulusHz": displayTicker.actualStimulusRate,
            "updatesPerFrame": displayTicker.stimulusUpdatesPerFrame
        ]
        
        if let trial = currentTrial {
            info["currentTrial"] = currentTrialIndex + 1
            info["totalTrials"] = trialSequence.count
            info["coherence"] = trial.coherence
            info["onsetTime"] = trial.onsetTime
        }
        
        // Add geometry info
        let geometryInfo = VisualGeometry.shared.getDiagnosticInfo()
        info.merge(geometryInfo) { (_, new) in new }
        
        // Add renderer info
        let rendererInfo = renderer.getDiagnosticInfo()
        info.merge(rendererInfo) { (_, new) in new }
        
        return info
    }
    
    /// Get timing statistics
    func getTimingStats() -> TimingStats? {
        return displayTicker.getTimingStats()
    }
    
    // MARK: - Performance Statistics
    
    /// Get performance statistics from completed trials
    func getPerformanceStats() -> (hitRate: Double?, meanRT: Double?, recentResults: [String]) {
        guard !trialResults.isEmpty else {
            return (nil, nil, [])
        }
        
        // Calculate hit rate (hits / total valid trials)
        let validTrials = trialResults.filter { $0.config.gratingContrast > 0 }
        guard !validTrials.isEmpty else {
            return (nil, nil, [])
        }
        
        let hits = validTrials.filter { $0.response?.lowercased() == "hit" }.count
        let hitRate = Double(hits) / Double(validTrials.count)
        
        // Calculate mean reaction time (only for hits)
        let hitTrials = validTrials.filter { $0.response?.lowercased() == "hit" && $0.reactionTime != nil }
        let meanRT: Double? = hitTrials.isEmpty ? nil : hitTrials.compactMap { $0.reactionTime }.reduce(0, +) / Double(hitTrials.count)
        
        // Get recent results (last 10)
        let recentResults = trialResults.suffix(10).compactMap { $0.response }
        
        return (hitRate, meanRT, recentResults)
    }
    
    /// Get current trial progress (0.0 to 1.0)
    func getCurrentTrialProgress() -> Double {
        guard let trial = currentTrial, let startTime = trialStartTime else {
            return 0.0
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalDuration = trial.onsetTime + trial.settings.stimulusDuration + trial.settings.cueDuration + StimulusParams.fixationDuration + StimulusParams.interTrialInterval
        
        return min(1.0, max(0.0, elapsed / totalDuration))
    }
    
    /// Get current click result for dashboard display
    /// Returns: "hit", "fa", or nil if no click has occurred in current trial
    func getCurrentClickResult() -> String? {
        return currentClickResult
    }
    
    /// Get expected result if clicked right now (for progress bar color indication)
    /// Returns: "hit" if click now would be a HIT, "fa" if it would be a FA
    func getExpectedClickResult() -> String {
        // If already clicked, return the actual result
        if let actualResult = currentClickResult {
            return actualResult
        }
        
        // If no trial is active, return FA
        guard let trial = currentTrial else {
            return "fa"
        }
        
        // Check if we're in coherent state with visible stimulus
        // This is the most direct indicator: if state is .coherent and contrast > 0, stimulus is visible
        let isInCoherentState = currentState == .coherent
        let stimulusVisible = isInCoherentState && trial.gratingContrast > 0
        
        // If stimulus is currently visible (in coherent state), clicking would be a HIT
        if stimulusVisible {
            return "hit"
        }
        
        // Otherwise (before stimulus appears, after it disappears, or during noise/cue/fixation phases), clicking would be a FA
        return "fa"
    }
    
    /// Get response window status
    /// Returns: (isActive: Bool, timeRemaining: Double?)
    /// - If active: timeRemaining is seconds remaining in window
    /// - If not started: timeRemaining is nil (we don't show countdown before stimulus appears)
    /// - If passed: timeRemaining is nil
    /// CRITICAL: Window is ONLY active after stimulus has actually appeared (_coherentStartTime exists)
    func getResponseWindowStatus() -> (isActive: Bool, timeRemaining: Double?) {
        // CRITICAL: Response window can ONLY be active if:
        // 1. Stimulus has actually appeared (_coherentStartTime exists)
        // 2. RT window times have been set (based on actual appearance time)
        guard let coherentStart = _coherentStartTime,
              let rtStart = rtWindowStart,
              let rtEnd = rtWindowEnd else {
            // Stimulus hasn't appeared yet or RT window not set - window is not active
            return (false, nil)
        }
        
        // Verify RT window times are based on actual start time (not calculated)
        // This ensures window is only active after visual stimulus appears
        let expectedRTStart = coherentStart.addingTimeInterval(currentTrial?.settings.rtWindowDelay ?? 0)
        
        // Only proceed if RT window times match the actual start time (within small tolerance)
        // This prevents window from being active with old calculated times
        let timeDiff = abs(rtStart.timeIntervalSince(expectedRTStart))
        guard timeDiff < 0.1 else {
            // RT window times don't match actual start - they might be old calculated times
            return (false, nil)
        }
        
        let now = Date()
        
        if now >= rtStart && now <= rtEnd {
            // Active window - return time remaining
            let remaining = rtEnd.timeIntervalSince(now)
            return (true, remaining)
        } else if now < rtStart {
            // Window hasn't started yet - return time until start
            let timeUntilStart = rtStart.timeIntervalSince(now)
            return (false, timeUntilStart)
        } else {
            // Window has passed
            return (false, nil)
        }
    }
    
    /// Export trial results (main log only)
    func exportResults() -> URL? {
        return logger.exportCSV()
    }
    
    /// Export all log files (main, grid updates, clicks)
    func exportAllResults() -> [URL] {
        return logger.exportAllLogs()
    }
    
    deinit {
        stop()
    }
}

// MARK: - DisplayTickerDelegate
extension StimulusController: DisplayTickerDelegate {
    
    func displayTicker(_ ticker: DisplayTicker, shouldUpdateFrame frameCount: Int) {
        guard isRunning && !isPaused else { return }
        updateForCurrentFrame()
    }
    
    func displayTicker(_ ticker: DisplayTicker, didDetectRefreshRate hz: Int) {
        print("Display refresh rate detected: \(hz) Hz")
        // Display info is now in metadata comment rows, not logged as event
    }
}
