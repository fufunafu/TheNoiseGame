import Foundation
import UIKit

// MARK: - Visual Geometry (Calibration & Calculations)
class VisualGeometry {
    
    // MARK: - Singleton
    static let shared = VisualGeometry()
    private init() {}
    
    // MARK: - Properties
    
    /// Whether calibration is currently being used
    var usingCalibration: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "VisualGeometry.usingCalibration")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "VisualGeometry.usingCalibration")
        }
    }
    
    // MARK: - Core Calculations
    
    /// Convert PPI to pixels per centimeter
    func pixelsPerCm(nominalPPI: Double) -> Double {
        return nominalPPI / 2.54
    }
    
    /// Calculate tile size in pixels for 2° visual angle
    func tilePx(distanceCm: Double, pxPerCm: Double) -> Int {
        // 2° tile: size_cm = 2 * D * tan(1°)
        let angleRadians = 1.0 * .pi / 180.0  // 1° in radians
        let sizeCm = 2.0 * distanceCm * tan(angleRadians)
        return Int(round(sizeCm * pxPerCm))
    }
    
    /// Get current pixels per cm (PPI-derived)
    var pxPerCm: Double {
        return pixelsPerCm(nominalPPI: StimulusParams.nominalPPI)
    }
    
    /// Get current viewing distance
    var viewingDistanceCm: Double {
        get {
            return UserDefaults.standard.double(forKey: StimulusParams.viewingDistanceCmKey) != 0 ?
                UserDefaults.standard.double(forKey: StimulusParams.viewingDistanceCmKey) :
                StimulusParams.defaultViewingDistanceCm
        }
        set {
            UserDefaults.standard.set(newValue, forKey: StimulusParams.viewingDistanceCmKey)
        }
    }
    
    
    
    // MARK: - Current Tile Size
    
    /// Get current tile size in pixels
    var currentTilePx: Int {
        return tilePx(distanceCm: viewingDistanceCm, pxPerCm: pxPerCm)
    }
    
    /// Get tile size that fits the grid within a fixed screen area
    func adaptiveTilePx(screenSize: CGSize) -> Int {
        // Define the fixed grid area as a percentage of screen size
        let gridAreaPercent: CGFloat = 0.8  // Use 80% of screen area
        let availableWidth = screenSize.width * gridAreaPercent
        let availableHeight = screenSize.height * gridAreaPercent
        
        // Calculate tile size needed to fit current grid dimensions in the available area
        let tileFromWidth = Int(availableWidth / CGFloat(StimulusParams.cols))
        let tileFromHeight = Int(availableHeight / CGFloat(StimulusParams.rows))
        
        // Use the smaller dimension to ensure grid fits in both directions
        let calculatedTilePx = min(tileFromWidth, tileFromHeight)
        
        // Define reasonable bounds for tile size
        let minimumTilePx = 4   // Minimum for visibility
        let maximumTilePx = 50  // Maximum for reasonable visual angle
        
        // Clamp to reasonable bounds
        let finalTilePx = max(minimumTilePx, min(calculatedTilePx, maximumTilePx))
        
        return finalTilePx
    }
    
    /// Get grid dimensions in pixels
    var gridSize: CGSize {
        let tileSize = CGFloat(currentTilePx)
        let baseSize = CGSize(
            width: tileSize * CGFloat(StimulusParams.cols),
            height: tileSize * CGFloat(StimulusParams.rows)
        )
        
        // Apply grid size percentage scaling
        let settings = TrialSettings.load()
        let scaleFactor = CGFloat(settings.gridSizePercent / 100.0)
        
        return CGSize(
            width: baseSize.width * scaleFactor,
            height: baseSize.height * scaleFactor
        )
    }
    
    /// Get adaptive grid dimensions that always fit within the designated screen area
    func adaptiveGridSize(screenSize: CGSize) -> CGSize {
        let tileSize = CGFloat(adaptiveTilePx(screenSize: screenSize))
        let baseSize = CGSize(
            width: tileSize * CGFloat(StimulusParams.cols),
            height: tileSize * CGFloat(StimulusParams.rows)
        )
        
        // Apply grid size percentage scaling
        let settings = TrialSettings.load()
        let scaleFactor = CGFloat(settings.gridSizePercent / 100.0)
        
        return CGSize(
            width: baseSize.width * scaleFactor,
            height: baseSize.height * scaleFactor
        )
    }
    
    // MARK: - Visual Angle Validation
    
    /// Calculate actual visual angle for current tile size
    func actualVisualAngleDegrees() -> Double {
        let tileSizeCm = Double(currentTilePx) / pxPerCm
        let angleRadians = atan(tileSizeCm / (2.0 * viewingDistanceCm))
        return angleRadians * 180.0 / .pi * 2.0  // Convert to degrees and double for full tile
    }
    
    /// Calculate actual visual angle for adaptive tile size
    func actualAdaptiveVisualAngleDegrees(screenSize: CGSize) -> Double {
        let adaptiveTilePx = adaptiveTilePx(screenSize: screenSize)
        let tileSizeCm = Double(adaptiveTilePx) / pxPerCm
        let angleRadians = atan(tileSizeCm / (2.0 * viewingDistanceCm))
        return angleRadians * 180.0 / .pi * 2.0  // Convert to degrees and double for full tile
    }
    
    /// Check if current configuration is close to target 2°
    func isVisualAngleAccurate(tolerance: Double = 0.1) -> Bool {
        let actual = actualVisualAngleDegrees()
        return abs(actual - 2.0) <= tolerance
    }
    
    // MARK: - Calibration
    
    
    
    // MARK: - Diagnostic Info
    
    /// Get diagnostic information about current geometry
    func getDiagnosticInfo() -> [String: Any] {
        // Use main screen size for diagnostics
        let screenSize = UIScreen.main.bounds.size
        let adaptiveTilePx = adaptiveTilePx(screenSize: screenSize)
        let adaptiveGridSize = adaptiveGridSize(screenSize: screenSize)
        
        // Calculate grid area usage
        let gridAreaPercent: CGFloat = 0.8
        let availableWidth = screenSize.width * gridAreaPercent
        let availableHeight = screenSize.height * gridAreaPercent
        
        return [
            "viewingDistanceCm": viewingDistanceCm,
            "pxPerCm": pxPerCm,
            "idealTilePx": currentTilePx,
            "adaptiveTilePx": adaptiveTilePx,
            "tilePx": adaptiveTilePx,  // Use adaptive for compatibility
            "gridWidthPx": adaptiveGridSize.width,
            "gridHeightPx": adaptiveGridSize.height,
            "screenWidthPx": screenSize.width,
            "screenHeightPx": screenSize.height,
            "availableWidthPx": availableWidth,
            "availableHeightPx": availableHeight,
            "actualVisualAngleDegrees": actualAdaptiveVisualAngleDegrees(screenSize: screenSize),
            "idealVisualAngleDegrees": actualVisualAngleDegrees(),
            "isVisualAngleAccurate": isVisualAngleAccurate(),
            "isGridAdaptive": adaptiveTilePx != currentTilePx,
            "gridFitsInArea": adaptiveGridSize.width <= availableWidth && adaptiveGridSize.height <= availableHeight
        ]
    }
}

