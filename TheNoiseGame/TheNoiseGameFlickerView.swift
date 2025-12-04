import UIKit

/// Delegate protocol for grid update notifications
protocol FlickerGridViewDelegate: AnyObject {
    func flickerGridViewDidUpdate(_ view: FlickerGridView)
}

/// A view where each tile flickers independently, synchronized with display refresh
/// Uses CADisplayLink for smooth, gap-free flickering
class FlickerGridView: UIView {
    
    // MARK: - Properties
    weak var delegate: FlickerGridViewDelegate?
    
    private var tileLayers: [[CALayer]] = []
    private var rows: Int = 0
    private var cols: Int = 0
    private var tilePx: Int = 0
    private var gridOrigin: CGPoint = .zero
    
    // Flicker control - now using CADisplayLink instead of Timer
    private var displayLink: CADisplayLink?
    private var isFlickering = false
    private var flickerFrequency: Double = 30.0  // Target Hz
    private var frameCount: Int = 0
    private var updatesPerFrame: Int = 1  // How many display frames per flicker update
    
    // Debug: Track timing
    private var lastUpdateTime: Date?
    private var updateCounter: Int = 0
    
    // Renderer for pattern generation (for coherent stimuli)
    private var renderer: CheckerboardRenderer?
    private var showCoherentStimulus = false
    private var currentCoherence: Double = 0.0
    private var currentGratingContrast: Double = 1.0
    private var currentQuadrant: Quadrant = .topLeft
    
    // Seed tracking for reproducibility
    private var lastUsedSeed: UInt64 = 0
    private var nextSeedToUse: UInt64? = nil  // Seed provided by controller for next frame
    
    // Flicker indicator square (top left)
    private var flickerIndicatorSquare: CALayer?
    private var isFlickerSquareWhite = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = StimulusParams.blackColor
        isOpaque = true
        layer.drawsAsynchronously = false
        
        // Setup flicker indicator square in top left
        setupFlickerIndicatorSquare()
    }
    
    private func setupFlickerIndicatorSquare() {
        // Remove existing square if any
        flickerIndicatorSquare?.removeFromSuperlayer()
        
        // Create a square layer for the flicker indicator
        let squareSize: CGFloat = 50.0  // Size of the square in points
        let squareLayer = CALayer()
        squareLayer.frame = CGRect(
            x: 20,  // 20 points from left edge
            y: 20,  // 20 points from top edge (accounting for safe area)
            width: squareSize,
            height: squareSize
        )
        
        // Start with black
        squareLayer.backgroundColor = StimulusParams.blackColor.cgColor
        
        // Optimize for performance
        squareLayer.drawsAsynchronously = false
        squareLayer.allowsEdgeAntialiasing = false
        
        layer.addSublayer(squareLayer)
        flickerIndicatorSquare = squareLayer
        isFlickerSquareWhite = false
    }
    
    // MARK: - Configuration
    
    /// Configure the grid dimensions and tile size
    func configureGrid(rows: Int, cols: Int, tilePx: Int, origin: CGPoint, quadrant: Quadrant = .topLeft) {
        // Check if dimensions actually changed - if not, just update positions
        let dimensionsChanged = self.rows != rows || self.cols != cols || self.tilePx != tilePx
        let positionChanged = self.gridOrigin != origin
        let quadrantChanged = self.currentQuadrant != quadrant
        
        // Only recreate layers if dimensions changed
        if dimensionsChanged {
            self.rows = rows
            self.cols = cols
            self.tilePx = tilePx
            
            // Create renderer for coherent stimuli with initial quadrant
            self.renderer = CheckerboardRenderer(rows: rows, cols: cols, quadrant: quadrant)
            
            setupTileLayers()
        } else {
            // Dimensions unchanged - just update positions if needed
            if positionChanged {
                self.gridOrigin = origin
                updateTilePositions()
            }
            
            // Update quadrant if changed (this doesn't require recreating layers)
            if quadrantChanged {
                self.currentQuadrant = quadrant
                renderer?.updateQuadrant(quadrant)
            }
        }
    }
    
    /// Update tile layer positions without recreating them
    private func updateTilePositions() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for row in 0..<rows {
            for col in 0..<cols {
                tileLayers[row][col].frame = CGRect(
                    x: gridOrigin.x + CGFloat(col * tilePx),
                    y: gridOrigin.y + CGFloat(row * tilePx),
                    width: CGFloat(tilePx),
                    height: CGFloat(tilePx)
                )
            }
        }
        
        CATransaction.commit()
    }
    
    /// Get the current quadrant
    func getCurrentQuadrant() -> Quadrant {
        return currentQuadrant
    }
    
    /// Update the quadrant for stimulus positioning
    func updateQuadrant(_ quadrant: Quadrant) {
        self.currentQuadrant = quadrant
        renderer?.updateQuadrant(quadrant)
    }
    
    /// Get the grid bounds (origin and size)
    func getGridBounds() -> (origin: CGPoint, width: CGFloat, height: CGFloat) {
        let width = CGFloat(cols * tilePx)
        let height = CGFloat(rows * tilePx)
        return (origin: gridOrigin, width: width, height: height)
    }
    
    /// Set the flicker frequency in Hz
    func setFlickerFrequency(_ hz: Double) {
        self.flickerFrequency = hz
        
        // Recalculate updates per frame based on display refresh rate
        let displayHz = Double(UIScreen.main.maximumFramesPerSecond)
        updatesPerFrame = max(1, Int(round(displayHz / hz)))
        
        print("FlickerGridView: Set frequency to \(hz) Hz (updating every \(updatesPerFrame) display frames at \(displayHz) Hz)")
        
        // No need to restart - the display link will automatically use new updatesPerFrame
    }
    
    // MARK: - Tile Layer Setup
    
    private func setupTileLayers() {
        // Remove existing layers
        for row in tileLayers {
            for layer in row {
                layer.removeFromSuperlayer()
            }
        }
        tileLayers.removeAll()
        
        // Create new tile layers
        tileLayers = Array(repeating: Array(repeating: CALayer(), count: cols), count: rows)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for row in 0..<rows {
            for col in 0..<cols {
                let tileLayer = CALayer()
                tileLayer.frame = CGRect(
                    x: gridOrigin.x + CGFloat(col * tilePx),
                    y: gridOrigin.y + CGFloat(row * tilePx),
                    width: CGFloat(tilePx),
                    height: CGFloat(tilePx)
                )
                
                // Start with random color
                tileLayer.backgroundColor = Bool.random() ? 
                    StimulusParams.whiteColor.cgColor : 
                    StimulusParams.blackColor.cgColor
                
                // Optimize for performance
                tileLayer.drawsAsynchronously = false
                tileLayer.allowsEdgeAntialiasing = false
                
                layer.addSublayer(tileLayer)
                tileLayers[row][col] = tileLayer
            }
        }
        
        CATransaction.commit()
        
        // Ensure flicker indicator square stays on top of all tiles
        if let squareLayer = flickerIndicatorSquare {
            squareLayer.removeFromSuperlayer()
            layer.addSublayer(squareLayer)
        }
    }
    
    // MARK: - Flicker Control
    
    /// Start continuous flickering synchronized with display refresh
    func startFlickering() {
        guard !isFlickering else { return }
        
        isFlickering = true
        frameCount = 0
        updateCounter = 0
        lastUpdateTime = nil
        
        // Calculate updates per frame based on display refresh rate
        let displayHz = Double(UIScreen.main.maximumFramesPerSecond)
        updatesPerFrame = max(1, Int(round(displayHz / flickerFrequency)))
        
        // Create display link - this syncs with screen refresh for gap-free updates
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        
        let actualHz = displayHz / Double(updatesPerFrame)
        print("\n=== Grid Updates Starting: \(String(format: "%.1f", actualHz)) Hz ===")
    }
    
    /// Stop flickering
    func stopFlickering() {
        guard isFlickering else { return }
        
        isFlickering = false
        displayLink?.invalidate()
        displayLink = nil
        frameCount = 0
        
        print("=== Grid Updates Stopped: \(updateCounter) total updates ===\n")
    }
    
    /// Display link callback - called every screen refresh
    @objc private func displayLinkFired() {
        guard isFlickering else { return }
        
        frameCount += 1
        
        // Only update tiles at the target frequency (not every display frame)
        if frameCount % updatesPerFrame == 0 {
            updateCounter += 1
            lastUpdateTime = Date()
            
            updateAllTiles()
        }
    }
    
    // MARK: - Tile Updates
    
    /// Update all tiles with new random colors (or coherent pattern)
    /// This is optimized to run as fast as possible with zero gaps between updates
    private func updateAllTiles() {
        // Print CSV header on first update
        if updateCounter == 1 {
            print("\ntimestamp,updateIndex,seed,stimulusType,coherence,gratingContrast")
        }
        
        // Step 1: Generate the new pattern FIRST (before starting transaction)
        // This ensures the pattern is ready before we start modifying layers
        let stimulusType = showCoherentStimulus ? "coherent" : "noise"
        let timestamp = Date().timeIntervalSince1970
        
        // Use the pre-generated seed from controller if available
        let seedToUse = nextSeedToUse ?? SeededRandomGenerator.generateSeed()
        nextSeedToUse = nil  // Clear after use
        
        if showCoherentStimulus, let renderer = renderer {
            lastUsedSeed = renderer.makeCoherentFrame(coherence: currentCoherence, gratingContrast: currentGratingContrast, seed: seedToUse)
        } else if let renderer = renderer {
            lastUsedSeed = renderer.makeNoiseFrame(seed: seedToUse)
        }
        
        // Log in clean CSV format
        print("\(String(format: "%.3f", timestamp)),\(updateCounter),\(lastUsedSeed),\(stimulusType),\(String(format: "%.1f", currentCoherence)),\(String(format: "%.1f", currentGratingContrast))")
        
        // Step 2: Now update ALL tile layers in a single atomic transaction
        // This ensures all tiles update simultaneously with zero visible gaps
        CATransaction.begin()
        CATransaction.setDisableActions(true)  // No implicit animations
        CATransaction.setAnimationDuration(0)   // Zero duration
        
        if let renderer = renderer {
            // Apply pre-generated pattern to all tiles
            for row in 0..<rows {
                for col in 0..<cols {
                    let color = renderer.getTileColor(row: row, col: col)
                    tileLayers[row][col].backgroundColor = color.cgColor
                }
            }
        } else {
            // Fallback: truly random independent tiles (no renderer)
            for row in 0..<rows {
                for col in 0..<cols {
                    tileLayers[row][col].backgroundColor = Bool.random() ?
                        StimulusParams.whiteColor.cgColor :
                        StimulusParams.blackColor.cgColor
                }
            }
        }
        
        CATransaction.commit()
        
        // Update flicker indicator square (alternate between black and white)
        if let squareLayer = flickerIndicatorSquare {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            CATransaction.setAnimationDuration(0)
            
            isFlickerSquareWhite.toggle()
            squareLayer.backgroundColor = isFlickerSquareWhite ?
                StimulusParams.whiteColor.cgColor :
                StimulusParams.blackColor.cgColor
            
            CATransaction.commit()
        }
        
        // Notify delegate that grid has been updated (legacy callback)
        delegate?.flickerGridViewDidUpdate(self)
    }
    
    // MARK: - Stimulus Control
    
    /// Show pure noise flickering with pre-generated seed
    func showNoise(seed: UInt64) {
        let wasCoherent = showCoherentStimulus
        showCoherentStimulus = false
        currentCoherence = 0.0
        currentGratingContrast = 1.0
        nextSeedToUse = seed
        
        if wasCoherent {
            print("🔵 FlickerGrid: Switch to NOISE (seed=\(seed))")
        }
    }
    
    /// Show coherent stimulus with given coherence level, grating contrast, and pre-generated seed
    func showCoherent(coherence: Double, gratingContrast: Double = 1.0, seed: UInt64) {
        let wasNoise = !showCoherentStimulus
        showCoherentStimulus = true
        currentCoherence = coherence
        currentGratingContrast = gratingContrast
        nextSeedToUse = seed
        
        if wasNoise {
            print("🔴 FlickerGrid: Switch to COHERENT (coherence=\(coherence), contrast=\(gratingContrast), seed=\(seed))")
        }
    }
    
    /// Show static checkerboard pattern (alternating black and white)
    func showStaticCheckerboard() {
        // Stop flickering first
        stopFlickering()
        
        // Generate a classic checkerboard pattern
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0)
        
        for row in 0..<rows {
            for col in 0..<cols {
                // Checkerboard: alternate colors based on (row + col) being even or odd
                let isWhite = (row + col) % 2 == 0
                let color = isWhite ? StimulusParams.whiteColor : StimulusParams.blackColor
                tileLayers[row][col].backgroundColor = color.cgColor
            }
        }
        
        CATransaction.commit()
        
        print("🟩 FlickerGrid: Showing static checkerboard pattern")
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopFlickering()
    }
}

