import Foundation
import UIKit

// MARK: - Checkerboard View (Stimulus Rendering)
class CheckerboardView: UIView {
    
    // MARK: - Properties
    private var renderer: CheckerboardRenderer
    private var fixationDot: UIView?
    private var showFixation = false
    private var showCheckerboardGrid = true  // Track if checkerboard should be visible
    
    // Geometry
    private var tilePx: Int = 0
    private var gridOrigin: CGPoint = .zero
    
    // Performance optimization
    private var tileViews: [[UIView]] = []
    private var isUsingTileViews = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        self.renderer = CheckerboardRenderer()
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.renderer = CheckerboardRenderer()
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = StimulusParams.grayColor
        isUserInteractionEnabled = false
    }
    
    // MARK: - Geometry Updates
    
    /// Update the geometry of the checkerboard based on current settings
    func updateGeometry() {
        let tilePx = VisualGeometry.shared.currentTilePx
        let gridSize = VisualGeometry.shared.adaptiveGridSize(screenSize: bounds.size)
        let gridOrigin = CGPoint(
            x: (bounds.width - gridSize.width) / 2,
            y: (bounds.height - gridSize.height) / 2
        )
        
        self.tilePx = tilePx
        self.gridOrigin = gridOrigin
        
        // Update renderer grid size
        renderer.updateGridSize(newRows: StimulusParams.rows, newCols: StimulusParams.cols)
        
        // Recreate tile views if needed
        setupTileViews()
        
        // Update fixation dot
        updateFixationDot()
    }
    
    // MARK: - Tile Views Setup
    
    private func setupTileViews() {
        // Remove existing tile views
        tileViews.forEach { row in
            row.forEach { $0.removeFromSuperview() }
        }
        tileViews.removeAll()
        
        guard showCheckerboardGrid else { return }
        
        let rows = StimulusParams.rows
        let cols = StimulusParams.cols
        
        // Create tile views
        for row in 0..<rows {
            var tileRow: [UIView] = []
            for col in 0..<cols {
                let tileView = UIView()
                tileView.frame = CGRect(
                    x: gridOrigin.x + CGFloat(col * tilePx),
                    y: gridOrigin.y + CGFloat(row * tilePx),
                    width: CGFloat(tilePx),
                    height: CGFloat(tilePx)
                )
                tileView.backgroundColor = StimulusParams.grayColor
                addSubview(tileView)
                tileRow.append(tileView)
            }
            tileViews.append(tileRow)
        }
        
        isUsingTileViews = true
        updateTileColors()
    }
    
    // MARK: - Tile Colors Update
    
    private func updateTileColors() {
        guard isUsingTileViews else { return }
        
        let rows = StimulusParams.rows
        let cols = StimulusParams.cols
        
        for row in 0..<rows {
            for col in 0..<cols {
                guard row < tileViews.count && col < tileViews[row].count else { continue }
                let tileView = tileViews[row][col]
                let color = renderer.getTileColor(row: row, col: col)
                tileView.backgroundColor = color
            }
        }
    }
    
    // MARK: - Fixation Dot
    
    private func updateFixationDot() {
        if showFixation {
            if fixationDot == nil {
                let dot = UIView()
                dot.backgroundColor = StimulusParams.fixationColor
                dot.layer.cornerRadius = CGFloat(StimulusParams.fixationDotRadius)
                addSubview(dot)
                fixationDot = dot
            }
            
            if let dot = fixationDot {
                let centerX = bounds.width / 2
                let centerY = bounds.height / 2
                dot.frame = CGRect(
                    x: centerX - CGFloat(StimulusParams.fixationDotRadius),
                    y: centerY - CGFloat(StimulusParams.fixationDotRadius),
                    width: CGFloat(StimulusParams.fixationDotRadius * 2),
                    height: CGFloat(StimulusParams.fixationDotRadius * 2)
                )
            }
        } else {
            fixationDot?.removeFromSuperview()
            fixationDot = nil
        }
    }
    
    // MARK: - Public Interface
    
    /// Show fixation dot
    func showFixationDot() {
        showFixation = true
        updateFixationDot()
    }
    
    /// Hide fixation dot
    func hideFixationDot() {
        showFixation = false
        updateFixationDot()
    }
    
    /// Update the checkerboard pattern from renderer
    func updatePattern() {
        updateTileColors()
    }
    
    /// Show checkerboard grid
    func showGrid() {
        showCheckerboardGrid = true
        setupTileViews()
    }
    
    /// Hide checkerboard grid
    func hideGrid() {
        showCheckerboardGrid = false
        tileViews.forEach { row in
            row.forEach { $0.removeFromSuperview() }
        }
        tileViews.removeAll()
        isUsingTileViews = false
    }
}

