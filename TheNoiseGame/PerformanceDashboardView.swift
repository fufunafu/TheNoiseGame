import UIKit

/// Real-time performance dashboard showing live statistics during trials
class PerformanceDashboardView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    
    // Statistics labels
    private let hitRateLabel = UILabel()
    private let meanRTLabel = UILabel()
    private let completedTrialsLabel = UILabel()
    private let recentPerformanceLabel = UILabel()
    
    // Progress indicators
    private let trialProgressBar = UIProgressView(progressViewStyle: .bar)
    private let responseWindowIndicator = UIView()
    private let responseWindowLabel = UILabel()
    
    // Recent performance history
    private let recentResultsStack = UIStackView()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        // Container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Title
        titleLabel.text = "Performance Dashboard"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Statistics labels setup
        setupStatLabel(hitRateLabel, title: "Hit Rate")
        setupStatLabel(meanRTLabel, title: "Mean RT")
        setupStatLabel(completedTrialsLabel, title: "Trials Completed")
        setupStatLabel(recentPerformanceLabel, title: "Recent (Last 5)")
        
        // Trial progress bar
        trialProgressBar.progressTintColor = .systemBlue
        trialProgressBar.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        trialProgressBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(trialProgressBar)
        
        // Response window indicator
        responseWindowIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
        responseWindowIndicator.layer.cornerRadius = 8
        responseWindowIndicator.layer.borderWidth = 2
        responseWindowIndicator.layer.borderColor = UIColor.systemGreen.cgColor
        responseWindowIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(responseWindowIndicator)
        
        responseWindowLabel.text = "Response Window"
        responseWindowLabel.textColor = .white
        responseWindowLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        responseWindowLabel.textAlignment = .center
        responseWindowLabel.translatesAutoresizingMaskIntoConstraints = false
        responseWindowIndicator.addSubview(responseWindowLabel)
        
        // Recent results stack
        recentResultsStack.axis = .horizontal
        recentResultsStack.spacing = 4
        recentResultsStack.distribution = .fillEqually
        recentResultsStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(recentResultsStack)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Statistics row 1
            hitRateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            hitRateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            hitRateLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.45),
            
            meanRTLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            meanRTLabel.leadingAnchor.constraint(equalTo: hitRateLabel.trailingAnchor, constant: 8),
            meanRTLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Statistics row 2
            completedTrialsLabel.topAnchor.constraint(equalTo: hitRateLabel.bottomAnchor, constant: 10),
            completedTrialsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            completedTrialsLabel.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.45),
            
            recentPerformanceLabel.topAnchor.constraint(equalTo: meanRTLabel.bottomAnchor, constant: 10),
            recentPerformanceLabel.leadingAnchor.constraint(equalTo: completedTrialsLabel.trailingAnchor, constant: 8),
            recentPerformanceLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Trial progress bar
            trialProgressBar.topAnchor.constraint(equalTo: completedTrialsLabel.bottomAnchor, constant: 12),
            trialProgressBar.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            trialProgressBar.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            trialProgressBar.heightAnchor.constraint(equalToConstant: 8),
            
            // Response window indicator
            responseWindowIndicator.topAnchor.constraint(equalTo: trialProgressBar.bottomAnchor, constant: 12),
            responseWindowIndicator.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            responseWindowIndicator.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            responseWindowIndicator.heightAnchor.constraint(equalToConstant: 40),
            
            responseWindowLabel.centerXAnchor.constraint(equalTo: responseWindowIndicator.centerXAnchor),
            responseWindowLabel.centerYAnchor.constraint(equalTo: responseWindowIndicator.centerYAnchor),
            
            // Recent results
            recentResultsStack.topAnchor.constraint(equalTo: responseWindowIndicator.bottomAnchor, constant: 12),
            recentResultsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            recentResultsStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            recentResultsStack.heightAnchor.constraint(equalToConstant: 30),
            recentResultsStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    private func setupStatLabel(_ label: UILabel, title: String) {
        label.text = "\(title): --"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        containerView.addSubview(label)
    }
    
    // MARK: - Update Methods
    
    /// Update all dashboard statistics
    func updateStats(
        hitRate: Double?,
        meanRT: Double?,
        completedTrials: Int,
        recentResults: [String],
        currentTrialProgress: Double,
        responseWindowActive: Bool,
        responseWindowTimeRemaining: Double?,
        currentClickResult: String?
    ) {
        // Update hit rate
        if let hitRate = hitRate {
            hitRateLabel.text = String(format: "Hit Rate\n%.1f%%", hitRate * 100)
            hitRateLabel.textColor = hitRate >= 0.7 ? .systemGreen : (hitRate >= 0.5 ? .systemYellow : .systemRed)
        } else {
            hitRateLabel.text = "Hit Rate\n--"
            hitRateLabel.textColor = .white
        }
        
        // Update mean RT
        if let meanRT = meanRT {
            meanRTLabel.text = String(format: "Mean RT\n%.0f ms", meanRT * 1000)
        } else {
            meanRTLabel.text = "Mean RT\n--"
        }
        
        // Update completed trials
        completedTrialsLabel.text = "Trials Completed\n\(completedTrials)"
        
        // Update recent performance
        if recentResults.isEmpty {
            recentPerformanceLabel.text = "Recent (Last 5)\n--"
        } else {
            let recentText = recentResults.joined(separator: ", ")
            recentPerformanceLabel.text = "Recent (Last 5)\n\(recentText)"
        }
        
        // Update trial progress
        trialProgressBar.setProgress(Float(currentTrialProgress), animated: true)
        
        // Update progress bar color based on click result
        if let clickResult = currentClickResult {
            switch clickResult.lowercased() {
            case "hit", "correct":
                trialProgressBar.progressTintColor = .systemGreen
            case "fa", "false_alarm":
                trialProgressBar.progressTintColor = .systemOrange
            case "miss":
                trialProgressBar.progressTintColor = .systemRed
            default:
                trialProgressBar.progressTintColor = .systemBlue
            }
        } else {
            // No click yet - default blue color
            trialProgressBar.progressTintColor = .systemBlue
        }
        
        // Update response window indicator
        if responseWindowActive {
            // Active window - green indicator
            responseWindowIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.4)
            responseWindowIndicator.layer.borderColor = UIColor.systemGreen.cgColor
            
            if let timeRemaining = responseWindowTimeRemaining {
                let seconds = Int(timeRemaining)
                let milliseconds = Int((timeRemaining - Double(seconds)) * 10)
                responseWindowLabel.text = String(format: "⏱️ Response Window Active - %d.%d s remaining", seconds, milliseconds)
            } else {
                responseWindowLabel.text = "⏱️ Response Window Active"
            }
        } else if let timeUntilStart = responseWindowTimeRemaining, timeUntilStart > 0 {
            // Window hasn't started yet - show countdown
            responseWindowIndicator.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
            responseWindowIndicator.layer.borderColor = UIColor.systemBlue.cgColor
            
            let seconds = Int(timeUntilStart)
            let milliseconds = Int((timeUntilStart - Double(seconds)) * 10)
            responseWindowLabel.text = String(format: "⏳ Response Window starts in %d.%d s", seconds, milliseconds)
        } else {
            // Window not set or has passed
            responseWindowIndicator.backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
            responseWindowIndicator.layer.borderColor = UIColor.systemGray.cgColor
            responseWindowLabel.text = "Waiting for Response Window..."
        }
        
        // Update recent results indicators
        updateRecentResultsIndicators(recentResults)
    }
    
    private func updateRecentResultsIndicators(_ results: [String]) {
        // Clear existing indicators
        recentResultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Show last 5 results
        let displayResults = Array(results.suffix(5))
        
        // If we have fewer than 5, pad with empty indicators
        let totalSlots = 5
        let emptySlots = totalSlots - displayResults.count
        
        // Add empty slots first
        for _ in 0..<emptySlots {
            let indicator = createResultIndicator(result: nil)
            recentResultsStack.addArrangedSubview(indicator)
        }
        
        // Add actual results
        for result in displayResults {
            let indicator = createResultIndicator(result: result)
            recentResultsStack.addArrangedSubview(indicator)
        }
    }
    
    private func createResultIndicator(result: String?) -> UIView {
        let indicator = UIView()
        indicator.layer.cornerRadius = 4
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = result?.uppercased() ?? "--"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        indicator.addSubview(label)
        
        // Set background color based on result
        if let result = result {
            switch result.lowercased() {
            case "hit", "correct":
                indicator.backgroundColor = .systemGreen
            case "fa", "false_alarm":
                indicator.backgroundColor = .systemOrange
            case "miss":
                indicator.backgroundColor = .systemRed
            default:
                indicator.backgroundColor = .systemGray
            }
        } else {
            indicator.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        }
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: indicator.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: indicator.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: indicator.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: indicator.trailingAnchor, constant: -4)
        ])
        
        return indicator
    }
    
    /// Show the dashboard with animation (only if not already visible)
    func show() {
        guard isHidden || alpha < 0.5 else { return }  // Already visible, don't animate again
        
        isHidden = false
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.alpha = 1.0
            self.transform = .identity
        })
    }
    
    /// Hide the dashboard with animation (only if currently visible)
    func hide() {
        guard !isHidden && alpha > 0.5 else { return }  // Already hidden, don't animate again
        
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.isHidden = true
        }
    }
}

