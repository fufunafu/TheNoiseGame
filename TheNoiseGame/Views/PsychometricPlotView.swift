import Foundation
import UIKit

// MARK: - Psychometric Plot View
class PsychometricPlotView: UIView {
    
    private var dataPoints: [(contrast: Double, accuracy: Double, total: Int)] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }
    
    func setData(_ contrastPerformance: [Double: (total: Int, correct: Int)]) {
        // Only include data points where there were actual trials (total > 0)
        dataPoints = contrastPerformance
            .filter { $0.value.total > 0 }
            .map { (contrast: $0.key, accuracy: Double($0.value.correct) / Double($0.value.total), total: $0.value.total) }
            .sorted { $0.contrast < $1.contrast }
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Clear background
        context.clear(rect)
        
        guard !dataPoints.isEmpty else {
            // Draw "No data" message
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5)
            ]
            let text = "No data available"
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedString.size()
            let textRect = CGRect(
                x: (rect.width - textSize.width) / 2,
                y: (rect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedString.draw(in: textRect)
            return
        }
        
        // Set up drawing area with padding
        let padding: CGFloat = 40
        let plotRect = rect.insetBy(dx: padding, dy: padding)
        let plotWidth = plotRect.width
        let plotHeight = plotRect.height
        
        // Draw axes
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(1.0)
        
        // X-axis (contrast)
        context.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        context.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        context.strokePath()
        
        // Y-axis (accuracy)
        context.move(to: CGPoint(x: plotRect.minX, y: plotRect.minY))
        context.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        context.strokePath()
        
        // Draw axis labels
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        
        // X-axis label (positioned below trial count labels)
        let xLabel = "Contrast"
        let xLabelAttributed = NSAttributedString(string: xLabel, attributes: labelAttributes)
        let xLabelSize = xLabelAttributed.size()
        // Position below trial count labels (tick label + trial count + spacing)
        let estimatedTickLabelHeight: CGFloat = 14
        let estimatedCountLabelHeight: CGFloat = 12
        xLabelAttributed.draw(at: CGPoint(x: plotRect.midX - xLabelSize.width / 2, y: plotRect.maxY + 8 + estimatedTickLabelHeight + 4 + estimatedCountLabelHeight + 4))
        
        // Y-axis label
        let yLabel = "Accuracy"
        let yLabelAttributed = NSAttributedString(string: yLabel, attributes: labelAttributes)
        let yLabelSize = yLabelAttributed.size()
        context.saveGState()
        context.translateBy(x: 8, y: plotRect.midY + yLabelSize.width / 2)
        context.rotate(by: -CGFloat.pi / 2)
        yLabelAttributed.draw(at: .zero)
        context.restoreGState()
        
        // Draw tick marks and labels
        let minContrast = dataPoints.first?.contrast ?? 0.0
        let maxContrast = dataPoints.last?.contrast ?? 1.0
        let contrastRange = maxContrast - minContrast
        
        // X-axis ticks (contrast values)
        for point in dataPoints {
            let x = plotRect.minX + CGFloat((point.contrast - minContrast) / max(contrastRange, 0.001)) * plotWidth
            let tickY = plotRect.maxY
            context.move(to: CGPoint(x: x, y: tickY - 5))
            context.addLine(to: CGPoint(x: x, y: tickY + 5))
            context.strokePath()
            
            let tickLabel = String(format: "%.2f", point.contrast)
            let tickLabelAttributed = NSAttributedString(string: tickLabel, attributes: labelAttributes)
            let tickLabelSize = tickLabelAttributed.size()
            tickLabelAttributed.draw(at: CGPoint(x: x - tickLabelSize.width / 2, y: tickY + 8))
            
            // Draw trial count below the contrast value
            let countLabel = "n=\(point.total)"
            let countAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7)
            ]
            let countAttributed = NSAttributedString(string: countLabel, attributes: countAttributes)
            let countSize = countAttributed.size()
            countAttributed.draw(at: CGPoint(x: x - countSize.width / 2, y: tickY + 8 + tickLabelSize.height + 4))
        }
        
        // Y-axis ticks (0.0 to 1.0)
        let yTicks = [0.0, 0.25, 0.5, 0.75, 1.0]
        for tick in yTicks {
            let y = plotRect.maxY - CGFloat(tick) * plotHeight
            let tickX = plotRect.minX
            context.move(to: CGPoint(x: tickX - 5, y: y))
            context.addLine(to: CGPoint(x: tickX + 5, y: y))
            context.strokePath()
            
            let tickLabel = String(format: "%.2f", tick)
            let tickLabelAttributed = NSAttributedString(string: tickLabel, attributes: labelAttributes)
            let tickLabelSize = tickLabelAttributed.size()
            tickLabelAttributed.draw(at: CGPoint(x: tickX - tickLabelSize.width - 8, y: y - tickLabelSize.height / 2))
        }
        
        // Draw data points and connecting lines
        guard dataPoints.count > 1 else {
            // Single point - just draw it
            if let point = dataPoints.first {
                let x = plotRect.minX + CGFloat((point.contrast - minContrast) / max(contrastRange, 0.001)) * plotWidth
                let y = plotRect.maxY - CGFloat(point.accuracy) * plotHeight
                
                context.setFillColor(UIColor.systemBlue.cgColor)
                context.fillEllipse(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
            }
            return
        }
        
        // Draw connecting line
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        
        var pathPoints: [CGPoint] = []
        for point in dataPoints {
            let x = plotRect.minX + CGFloat((point.contrast - minContrast) / max(contrastRange, 0.001)) * plotWidth
            let y = plotRect.maxY - CGFloat(point.accuracy) * plotHeight
            pathPoints.append(CGPoint(x: x, y: y))
        }
        
        if !pathPoints.isEmpty {
            context.move(to: pathPoints[0])
            for i in 1..<pathPoints.count {
                context.addLine(to: pathPoints[i])
            }
            context.strokePath()
        }
        
        // Draw data points
        for point in dataPoints {
            let x = plotRect.minX + CGFloat((point.contrast - minContrast) / max(contrastRange, 0.001)) * plotWidth
            let y = plotRect.maxY - CGFloat(point.accuracy) * plotHeight
            
            // Draw point
            context.setFillColor(UIColor.systemBlue.cgColor)
            context.fillEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
        }
    }
}
