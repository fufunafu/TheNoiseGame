import Foundation
import UIKit
import AVFoundation
import AudioToolbox
import MessageUI

// MARK: - Main View Controller
class ViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    // MARK: - Properties
    
    // Stimulus system
    private var stimulusController: StimulusController?
    var checkerboardView: CheckerboardView?  // Accessible to extensions
    var flickerGridView: FlickerGridView?  // Main flickering view
    
    // UI Elements
    private let controlPanel = UIView()
    private let statusLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let emailButton = UIButton(type: .system)
    private let resetButton = UIButton(type: .system)
    
    // Control panel toggle
    private let toggleControlsButton = UIButton(type: .system)
    private var isControlPanelVisible = true
    
    // Feedback views for stimulus detection
    private var heartFeedbackView: UIView?
    private var sadFaceFeedbackView: UIView?
    private var stimulusDetectionTimes: [Date] = []
    
    // Settings controls
    private let distanceSlider = UISlider()
    private let distanceLabel = UILabel()
    private let coherenceSegment = UISegmentedControl(items: ["Single", "Sequence"])
    private let coherenceSlider = UISlider()
    private let coherenceLabel = UILabel()
    
    // Additional parameter controls
    private let stimulusHzSlider = UISlider()
    private let stimulusHzLabel = UILabel()
    private let fixationDurationSlider = UISlider()
    private let fixationDurationLabel = UILabel()
    private let minOnsetSlider = UISlider()
    private let maxOnsetSlider = UISlider()
    private let coherentWindowSlider = UISlider()
    private let coherentWindowLabel = UILabel()
    private let interTrialSlider = UISlider()
    private let interTrialLabel = UILabel()
    private let fixationRadiusSlider = UISlider()
    private let fixationRadiusLabel = UILabel()
    private let gridColsSlider = UISlider()
    
    // New TrialSettings controls (text fields for precise input)
    private let minOnsetTextField = UITextField()
    private let maxOnsetTextField = UITextField()
    private let rtWindowDelayTextField = UITextField()
    private let rtWindowDelayLabel = UILabel()
    private let rtWindowLengthTextField = UITextField()
    private let rtWindowLengthLabel = UILabel()
    private let gridSizeTextField = UITextField()
    private let gridSizeLabel = UILabel()
    private let probAutomaticRewardTextField = UITextField()
    private let probAutomaticRewardLabel = UILabel()
    private let gridColsTextField = UITextField()
    private let gridRowsTextField = UITextField()
    private let gridSizeSegmentedControl = UISegmentedControl(items: GridSize.allCases.map { $0.displayName })
    private let gridSizeSegmentLabel = UILabel()
    private let stimulusHzTextField = UITextField()
    private let stimulusHzTextFieldLabel = UILabel()
    private let stimulusDurationTextField = UITextField()
    private let stimulusDurationLabel = UILabel()
    private let gratingContrastsTextField = UITextField()
    private let gratingContrastsLabel = UILabel()
    private let testingModeToggle = UISwitch()
    private let testingModeLabel = UILabel()
    
    // Trial settings instance
    private var trialSettings = TrialSettings.load()
    
    // New dedicated settings stack
    private let newTrialSettingsStack = UIStackView()
    private let gridRowsSlider = UISlider()
    
    // Labels for the new trial settings
    private let minOnsetLabel = UILabel()
    private let maxOnsetLabel = UILabel()
    private let gridColsLabel = UILabel()
    private let gridRowsLabel = UILabel()
    private let resetDefaultsButton = UIButton(type: .system)
    
    // Settings organization
    private let settingsScrollView = UIScrollView()
    private let settingsContentView = UIView()
    private let sessionInfoStack = UIStackView()  // Session info stack
    private let basicSettingsStack = UIStackView()
    private let timingSettingsStack = UIStackView()
    private let displaySettingsStack = UIStackView()
    
    // Help popover
    private var helpPopover: HelpPopoverView?
    
    // Status display
    private let diagnosticsLabel = UILabel()
    private var diagnosticsTimer: Timer?
    
    // Psychometric plot view
    private var psychometricPlotView: PsychometricPlotView?
    private var psychometricPlotContainer: UIView?
    
    // Coherence display label
    private let coherenceDisplayLabel = UILabel()
    
    // Trial number label (bottom of screen)
    private let trialNumberLabel = UILabel()
    
    // Quadrant arrow cue
    private var quadrantArrowView: UIView?
    
    // Store the quadrant for the current coherent stimulus to prevent mid-stimulus changes
    var currentCoherentQuadrant: Quadrant?
    
    // Performance dashboard
    private var performanceDashboard: PerformanceDashboardView?
    private var dashboardUpdateTimer: Timer?
    private var isDashboardVisible = false  // Track dashboard visibility state
    
    // Trial info view
    private var trialInfoView: TrialInfoView?
    private var pendingTrialSequence: [Double]?  // Store sequence to start after info is dismissed
    
    // Session info fields
    private let experimentNameTextField = UITextField()
    private let experimentNameLabel = UILabel()
    private let playerNameTextField = UITextField()
    private let playerNameLabel = UILabel()
    private let usernameTextField = UITextField()
    private let usernameLabel = UILabel()
    private var sessionInfo = SessionInfo.load()
    
    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure audio session to play sounds even when silent switch is on
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            print("✅ Audio session configured for playback")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
        
        print("✅ ViewController.viewDidLoad called")
        
        // Apply grid size and stimulus Hz from loaded settings
        trialSettings.applyGridSize()
        trialSettings.applyStimulusHz()
        
        setupComponents()
        print("✅ setupComponents completed")
        setupUI()
        print("✅ setupUI completed")
        startDiagnosticsTimer()
        print("✅ ViewController fully initialized")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        checkerboardView?.updateGeometry()
        
        // Configure the flicker grid with current geometry
        if let flickerGridView = flickerGridView {
            let tilePx = VisualGeometry.shared.adaptiveTilePx(screenSize: view.bounds.size)
            let gridSize = VisualGeometry.shared.adaptiveGridSize(screenSize: view.bounds.size)
            let gridOrigin = CGPoint(
                x: (view.bounds.width - gridSize.width) / 2,
                y: (view.bounds.height - gridSize.height) / 2
            )
            
            // Preserve the current quadrant when reconfiguring
            let currentQuadrant = flickerGridView.getCurrentQuadrant()
            flickerGridView.configureGrid(
                rows: StimulusParams.rows,
                cols: StimulusParams.cols,
                tilePx: tilePx,
                origin: gridOrigin,
                quadrant: currentQuadrant
            )
            
            // Set flicker frequency from settings
            flickerGridView.setFlickerFrequency(Double(trialSettings.stimulusHz))
        }
    }
    
    deinit {
        diagnosticsTimer?.invalidate()
        dashboardUpdateTimer?.invalidate()
        stimulusController?.stop()
        flickerGridView?.stopFlickering()
    }
    
    // MARK: - Help Text Dictionary
    
    private var helpTexts: [String: String] {
        return [
            // Trial Settings
            "minGratingOnset": "Earliest time after trial starts when the grating stimulus can appear. Used with Max Onset to create an exponential distribution favoring earlier times.",
            "maxGratingOnset": "Latest time the grating can appear. 95% of onset times will fall between Min and Max using an exponential distribution.",
            "rtWindowDelay": "Delay after grating appears before responses are accepted. Allows time for stimulus processing before the response window opens.",
            "rtWindowLength": "Duration the subject has to respond once the response window opens. Responses outside this window are not counted.",
            "stimulusDuration": "How long the stimulus remains visible on screen after it appears.",
            "probAutomaticReward": "Probability (0-1) of giving an automatic reward even without a correct response. Used for training and motivation.",
            "probFAReward": "Probability (0-1) of rewarding a false alarm lick. Used for training purposes.",
            "rewardWindowLength": "Duration after reward delivery during which licks are ignored to prevent reward stacking.",
            "stimulusHz": "Stimulus refresh rate in Hz - how fast the checkerboard grid flickers between patterns.",
            "gratingContrasts": "Space-separated list of contrast levels to test (0-1 range). E.g., '0 .1 .2 .4 .6 .8 1' tests multiple difficulty levels.",
            "normalMode": "Toggle between Testing Mode (red stimulus, dashboard visible) and Normal Mode (white stimulus, dashboard hidden for actual experiments).",
            
            // Session Info
            "experimentName": "Name of the current experiment. Used for organizing and identifying data files.",
            "playerName": "Name or ID of the subject/participant being tested.",
            "username": "Name of the experimenter or user running the session.",
            
            // Basic Settings
            "viewingDistance": "Distance from the screen in centimeters. Used to calculate visual angles and stimulus size in degrees of visual angle.",
            
            // Legacy Timing Settings
            "fixationDuration": "How long the fixation dot is displayed before stimulus onset (legacy parameter).",
            "coherentWindow": "Duration of the coherent stimulus presentation window (legacy parameter).",
            "interTrial": "Time between trials during which no stimulus is shown (legacy parameter).",
            
            // Legacy Display Settings
            "fixationRadius": "Radius of the central fixation dot in pixels. Helps subjects maintain gaze at screen center.",
            "gridCols": "Number of columns in the checkerboard grid. More columns = finer spatial resolution (legacy parameter).",
            "gridRows": "Number of rows in the checkerboard grid. More rows = finer spatial resolution (legacy parameter)."
        ]
    }
    
    // MARK: - Setup
    
    private func setupComponents() {
        // Load session info and create sessionId
        sessionInfo = SessionInfo.load()
        let sessionId = sessionInfo.sessionId
        
        // Initialize stimulus system with sessionId
        stimulusController = StimulusController(sessionId: sessionId)
        stimulusController?.delegate = self
        
        // Keep old checkerboard view as fallback (hidden)
        checkerboardView = CheckerboardView()
        checkerboardView?.isHidden = true
        
        // Create and setup flicker grid view
        flickerGridView = FlickerGridView()
        flickerGridView?.translatesAutoresizingMaskIntoConstraints = false
        if let flickerGridView = flickerGridView {
            view.insertSubview(flickerGridView, at: 0)  // Behind other UI elements
            // Make it fill the entire view
            NSLayoutConstraint.activate([
                flickerGridView.topAnchor.constraint(equalTo: view.topAnchor),
                flickerGridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                flickerGridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                flickerGridView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            // Configure grid with initial dimensions (will be updated in viewDidLayoutSubviews)
            let screenSize = (view.bounds.size.width == 0 || view.bounds.size.height == 0) ? UIScreen.main.bounds.size : view.bounds.size
            let tilePx = VisualGeometry.shared.adaptiveTilePx(screenSize: screenSize)
            let gridSize = VisualGeometry.shared.adaptiveGridSize(screenSize: screenSize)
            let gridOrigin = CGPoint(
                x: (screenSize.width - gridSize.width) / 2,
                y: (screenSize.height - gridSize.height) / 2
            )
            // Preserve the current quadrant when reconfiguring (or use default if not set yet)
            let currentQuadrant = flickerGridView.getCurrentQuadrant()
            flickerGridView.configureGrid(
                rows: StimulusParams.rows,
                cols: StimulusParams.cols,
                tilePx: tilePx,
                origin: gridOrigin,
                quadrant: currentQuadrant
            )
            flickerGridView.setFlickerFrequency(Double(trialSettings.stimulusHz))
            // Show static checkerboard initially (no flickering until trials start)
            flickerGridView.showStaticCheckerboard()
        }
    }
    
    private func setupUI() {
        // Set background color immediately to ensure something is visible
        view.backgroundColor = StimulusParams.grayColor
        print("   Background color set to: \(StimulusParams.grayColor)")
        
        setupControlPanel()
        print("   Control panel setup complete")
        setupStatusDisplay()
        setupTrialNumberLabel()
        setupSettingsControls()
        setupPerformanceDashboard()
        layoutUI()
        print("   UI layout complete")
        updateUIState()
        print("   UI state updated")
    }
    
    private func setupControlPanel() {
        controlPanel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        controlPanel.layer.cornerRadius = 12
        controlPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlPanel)
        view.addSubview(toggleControlsButton)
        
        // Add tap gesture for stimulus detection
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.cancelsTouchesInView = false  // Allow other views to receive touches too
        view.addGestureRecognizer(tapGesture)
        
        // Setup start, export, email and reset as icon buttons (always visible in bottom right)
        setupIconButton(startButton, icon: "play.fill", color: .systemGreen, action: #selector(startButtonTapped))
        setupIconButton(exportButton, icon: "square.and.arrow.up", color: .systemPurple, action: #selector(exportButtonTapped))
        setupIconButton(emailButton, icon: "envelope.fill", color: .systemBlue, action: #selector(emailButtonTapped))
        setupIconButton(resetButton, icon: "arrow.clockwise", color: .systemYellow, action: #selector(resetButtonTapped))
        view.addSubview(startButton)
        view.addSubview(exportButton)
        view.addSubview(emailButton)
        view.addSubview(resetButton)
        
        // Toggle controls button (small button always visible)
        toggleControlsButton.setTitle("⚙️", for: .normal)
        toggleControlsButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        toggleControlsButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toggleControlsButton.layer.cornerRadius = 25
        toggleControlsButton.addTarget(self, action: #selector(toggleControlPanelTapped), for: .touchUpInside)
        
        // Setup feedback views
        setupFeedbackViews()
    }
    
    private func setupFeedbackViews() {
        // Heart feedback view
        heartFeedbackView = UIView()
        heartFeedbackView?.backgroundColor = UIColor.clear
        heartFeedbackView?.isHidden = true
        heartFeedbackView?.translatesAutoresizingMaskIntoConstraints = false
        
        let heartLabel = UILabel()
        heartLabel.text = "❤️"
        heartLabel.font = UIFont.systemFont(ofSize: 80)
        heartLabel.textAlignment = .center
        heartLabel.translatesAutoresizingMaskIntoConstraints = false
        
        heartFeedbackView?.addSubview(heartLabel)
        
        // Sad face feedback view
        sadFaceFeedbackView = UIView()
        sadFaceFeedbackView?.backgroundColor = UIColor.clear
        sadFaceFeedbackView?.isHidden = true
        sadFaceFeedbackView?.translatesAutoresizingMaskIntoConstraints = false
        
        let sadFaceLabel = UILabel()
        sadFaceLabel.text = "😞"
        sadFaceLabel.font = UIFont.systemFont(ofSize: 80)
        sadFaceLabel.textAlignment = .center
        sadFaceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        sadFaceFeedbackView?.addSubview(sadFaceLabel)
        
        // Add to view
        if let heartView = heartFeedbackView, let sadView = sadFaceFeedbackView {
            view.addSubview(heartView)
            view.addSubview(sadView)
            
            NSLayoutConstraint.activate([
                // Heart feedback constraints
                heartView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                heartView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                heartView.widthAnchor.constraint(equalToConstant: 100),
                heartView.heightAnchor.constraint(equalToConstant: 100),
                
                heartLabel.centerXAnchor.constraint(equalTo: heartView.centerXAnchor),
                heartLabel.centerYAnchor.constraint(equalTo: heartView.centerYAnchor),
                
                // Sad face feedback constraints
                sadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                sadView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                sadView.widthAnchor.constraint(equalToConstant: 100),
                sadView.heightAnchor.constraint(equalToConstant: 100),
                
                sadFaceLabel.centerXAnchor.constraint(equalTo: sadView.centerXAnchor),
                sadFaceLabel.centerYAnchor.constraint(equalTo: sadView.centerYAnchor)
            ])
        }
    }
    
    private func setupButton(_ button: UIButton, title: String, color: UIColor, action: Selector) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color
        button.layer.cornerRadius = 8
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    private func setupIconButton(_ button: UIButton, icon: String, color: UIColor, action: Selector) {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconImage = UIImage(systemName: icon, withConfiguration: config)
        button.setImage(iconImage, for: .normal)
        button.tintColor = .white
        button.backgroundColor = color
        button.layer.cornerRadius = 25
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupStatusDisplay() {
        statusLabel.text = "Ready"
        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        diagnosticsLabel.text = ""
        diagnosticsLabel.textColor = UIColor.lightGray
        diagnosticsLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        diagnosticsLabel.numberOfLines = 0
        diagnosticsLabel.textAlignment = .left
        
        // Setup coherence display label
        coherenceDisplayLabel.text = "Coherence: --"
        coherenceDisplayLabel.textColor = .white
        coherenceDisplayLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        coherenceDisplayLabel.textAlignment = .center
        coherenceDisplayLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        coherenceDisplayLabel.layer.cornerRadius = 8
        coherenceDisplayLabel.layer.masksToBounds = true
        coherenceDisplayLabel.isHidden = true
        coherenceDisplayLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(coherenceDisplayLabel)
        
        // Position coherence label at top center
        NSLayoutConstraint.activate([
            coherenceDisplayLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            coherenceDisplayLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coherenceDisplayLabel.widthAnchor.constraint(equalToConstant: 200),
            coherenceDisplayLabel.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Setup quadrant arrow cue (will be shown during cue phase)
        setupQuadrantArrow()
    }
    
    private func setupTrialNumberLabel() {
        trialNumberLabel.text = ""
        trialNumberLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        trialNumberLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        trialNumberLabel.textAlignment = .center
        trialNumberLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trialNumberLabel)
        
        // Position at bottom center of screen, above buttons and control panel
        NSLayoutConstraint.activate([
            trialNumberLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            trialNumberLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])
    }
    
    private func setupSettingsControls() {
        setupSessionInfo()  // Setup session info first
        setupNewTrialSettings()  // NEW: Setup the prominent new settings first
        setupBasicSettings()
        setupTimingSettings()
        setupDisplaySettings()
        setupSettingsLayout()
        
        // Update initial displays
        updateAllParameterDisplays()
    }
    
    private func setupBasicSettings() {
        // Distance controls
        setupSliderWithLabel(distanceSlider, label: distanceLabel, 
                           title: "Distance", value: Float(StimulusParams.defaultViewingDistanceCm),
                           min: 15.0, max: 50.0, action: #selector(distanceChanged))
        
        // Coherence controls
        setupSliderWithLabel(coherenceSlider, label: coherenceLabel,
                           title: "Coherence", value: 1.0,
                           min: 0.0, max: 1.0, action: #selector(coherenceChanged))
        
        coherenceSegment.selectedSegmentIndex = 1  // Default to sequence
        coherenceSegment.addTarget(self, action: #selector(coherenceTypeChanged), for: .valueChanged)
        
        
        // Basic settings section
        let basicSectionLabel = createSectionLabel("Basic Settings")
        basicSettingsStack.axis = .vertical
        basicSettingsStack.spacing = 8
        basicSettingsStack.addArrangedSubview(basicSectionLabel)
        basicSettingsStack.addArrangedSubview(createLabelWithHelpButton(label: distanceLabel, helpText: helpTexts["viewingDistance"]))
        basicSettingsStack.addArrangedSubview(distanceSlider)
        basicSettingsStack.addArrangedSubview(coherenceSegment)
        basicSettingsStack.addArrangedSubview(coherenceLabel)
        basicSettingsStack.addArrangedSubview(coherenceSlider)
    }
    
    private func setupSessionInfo() {
        // Create a clean, modern header
        let headerLabel = UILabel()
        headerLabel.text = "Session Information"
        headerLabel.textColor = UIColor.white
        headerLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headerLabel.textAlignment = .center
        headerLabel.backgroundColor = UIColor.systemGreen
        headerLabel.layer.cornerRadius = 8
        headerLabel.layer.masksToBounds = true
        headerLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        // Load session info
        sessionInfo = SessionInfo.load()
        
        // Setup text fields
        let experimentStack = setupTextFieldWithLabel(experimentNameTextField, label: experimentNameLabel,
                                                      title: "Experiment Name", value: sessionInfo.experimentName,
                                                      action: #selector(experimentNameChanged),
                                                      helpText: helpTexts["experimentName"])
        
        let playerStack = setupTextFieldWithLabel(playerNameTextField, label: playerNameLabel,
                                                  title: "Player Name", value: sessionInfo.playerName,
                                                  action: #selector(playerNameChanged),
                                                  helpText: helpTexts["playerName"])
        
        let usernameStack = setupTextFieldWithLabel(usernameTextField, label: usernameLabel,
                                                   title: "Username", value: sessionInfo.username,
                                                   action: #selector(usernameChanged),
                                                   helpText: helpTexts["username"])
        
        // Create vertical stack
        sessionInfoStack.axis = .vertical
        sessionInfoStack.spacing = 12
        sessionInfoStack.alignment = .fill
        sessionInfoStack.distribution = .fill
        
        // Add header and fields
        sessionInfoStack.addArrangedSubview(headerLabel)
        sessionInfoStack.addArrangedSubview(experimentStack)
        sessionInfoStack.addArrangedSubview(playerStack)
        sessionInfoStack.addArrangedSubview(usernameStack)
        
        sessionInfoStack.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupNewTrialSettings() {
        // Create a clean, modern header
        let headerLabel = UILabel()
        headerLabel.text = "Trial Settings"
        headerLabel.textColor = UIColor.white
        headerLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headerLabel.textAlignment = .center
        headerLabel.backgroundColor = UIColor.systemBlue
        headerLabel.layer.cornerRadius = 8
        headerLabel.layer.masksToBounds = true
        headerLabel.heightAnchor.constraint(equalToConstant: 36).isActive = true
        
        // Setup all the new controls with compact text fields (clean formatting)
        let minOnsetStack = setupTextFieldWithLabel(minOnsetTextField, label: minOnsetLabel,
                                                   title: "Min Grating Onset (sec)", value: String(format: "%.1f", trialSettings.minGratingOnset),
                                                   action: #selector(minGratingOnsetChanged),
                                                   helpText: helpTexts["minGratingOnset"])
        
        let maxOnsetStack = setupTextFieldWithLabel(maxOnsetTextField, label: maxOnsetLabel,
                                                   title: "Max Grating Onset (sec)", value: String(format: "%.1f", trialSettings.maxGratingOnset),
                                                   action: #selector(maxGratingOnsetChanged),
                                                   helpText: helpTexts["maxGratingOnset"])
        
        let rtWindowDelayStack = setupTextFieldWithLabel(rtWindowDelayTextField, label: rtWindowDelayLabel,
                                                         title: "RT Window Delay (sec)", value: String(format: "%.1f", trialSettings.rtWindowDelay),
                                                         action: #selector(rtWindowDelayChanged),
                                                         helpText: helpTexts["rtWindowDelay"])
        
        let rtWindowLengthStack = setupTextFieldWithLabel(rtWindowLengthTextField, label: rtWindowLengthLabel,
                                                          title: "RT Window Length (sec)", value: String(format: "%.1f", trialSettings.rtWindowLength),
                                                          action: #selector(rtWindowLengthChanged),
                                                          helpText: helpTexts["rtWindowLength"])
        
        let stimulusDurationStack = setupTextFieldWithLabel(stimulusDurationTextField, label: stimulusDurationLabel,
                                                           title: "Stimulus Duration (sec)", value: String(format: "%.1f", trialSettings.stimulusDuration),
                                                           action: #selector(stimulusDurationChanged),
                                                           helpText: helpTexts["stimulusDuration"])
        
        let probAutomaticRewardStack = setupTextFieldWithLabel(probAutomaticRewardTextField, label: probAutomaticRewardLabel,
                                                              title: "Auto Reward Probability", value: String(format: "%.2f", trialSettings.probAutomaticStimReward),
                                                              action: #selector(probAutomaticRewardChanged),
                                                              helpText: helpTexts["probAutomaticReward"])
        
        let stimulusHzStack = setupTextFieldWithLabel(stimulusHzTextField, label: stimulusHzTextFieldLabel,
                                                     title: "Stimulus Frequency (Hz)", value: String(trialSettings.stimulusHz),
                                                     action: #selector(stimulusHzTextFieldChanged),
                                                     helpText: helpTexts["stimulusHz"])
        
        let gratingContrastsStack = setupTextFieldWithLabel(gratingContrastsTextField, label: gratingContrastsLabel,
                                                           title: "Grating Contrasts (0-1)", value: trialSettings.gratingContrasts,
                                                           action: #selector(gratingContrastsChanged),
                                                           helpText: helpTexts["gratingContrasts"])
        
        // Setup testing mode toggle (normal mode toggle)
        // When toggle is OFF = test mode (red stimulus, dashboard visible)
        // When toggle is ON = normal mode (white stimulus, dashboard hidden)
        testingModeLabel.text = "Normal Mode"
        testingModeLabel.textColor = .white
        testingModeLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        testingModeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // Initialize toggle: OFF = test mode (testingMode = true), ON = normal mode (testingMode = false)
        testingModeToggle.isOn = !trialSettings.testingMode
        testingModeToggle.onTintColor = UIColor.systemBlue
        testingModeToggle.addTarget(self, action: #selector(testingModeToggleChanged), for: .valueChanged)
        
        var testingModeComponents: [UIView] = [testingModeLabel]
        if let helpText = helpTexts["normalMode"] {
            testingModeComponents.append(createHelpButton(helpText: helpText))
        }
        testingModeComponents.append(testingModeToggle)
        
        let testingModeStack = UIStackView(arrangedSubviews: testingModeComponents)
        testingModeStack.axis = .horizontal
        testingModeStack.spacing = 8
        testingModeStack.alignment = .center
        testingModeStack.distribution = .fill
        
        // Configure the new settings stack with clean, modern styling
        newTrialSettingsStack.axis = .vertical
        newTrialSettingsStack.spacing = 10
        newTrialSettingsStack.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.1)
        newTrialSettingsStack.layer.cornerRadius = 12
        newTrialSettingsStack.layer.borderWidth = 1
        newTrialSettingsStack.layer.borderColor = UIColor.systemGray4.cgColor
        newTrialSettingsStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        newTrialSettingsStack.isLayoutMarginsRelativeArrangement = true
        
        // Add all controls to the stack with compact layout
        newTrialSettingsStack.addArrangedSubview(headerLabel)
        
        // Timing settings (compact horizontal layout)
        newTrialSettingsStack.addArrangedSubview(minOnsetStack)
        newTrialSettingsStack.addArrangedSubview(maxOnsetStack)
        newTrialSettingsStack.addArrangedSubview(rtWindowDelayStack)
        newTrialSettingsStack.addArrangedSubview(rtWindowLengthStack)
        newTrialSettingsStack.addArrangedSubview(stimulusDurationStack)
        
        // Visual settings (compact horizontal layout)
        newTrialSettingsStack.addArrangedSubview(probAutomaticRewardStack)
        newTrialSettingsStack.addArrangedSubview(stimulusHzStack)
        newTrialSettingsStack.addArrangedSubview(gratingContrastsStack)
        
        // Testing mode toggle (at the end)
        newTrialSettingsStack.addArrangedSubview(testingModeStack)
        
    }
    
    private func setupGridSizeSegmentedControl() {
        gridSizeSegmentLabel.text = "Grid Size (Tiles)"
        gridSizeSegmentLabel.textColor = UIColor.white
        gridSizeSegmentLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        
        // Set the current selection based on trial settings
        if let currentIndex = GridSize.allCases.firstIndex(of: trialSettings.gridSize) {
            gridSizeSegmentedControl.selectedSegmentIndex = currentIndex
        } else {
            gridSizeSegmentedControl.selectedSegmentIndex = GridSize.allCases.firstIndex(of: .extraLarge) ?? 0
        }
        
        gridSizeSegmentedControl.backgroundColor = UIColor.systemGray6
        gridSizeSegmentedControl.selectedSegmentTintColor = UIColor.systemBlue
        gridSizeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .normal)
        gridSizeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        gridSizeSegmentedControl.addTarget(self, action: #selector(gridSizeSegmentChanged), for: .valueChanged)
    }
    
    
    private func setupTimingSettings() {
        // Setup timing parameter sliders (legacy - reduced set)
        setupSliderWithLabel(fixationDurationSlider, label: fixationDurationLabel,
                           title: "Fixation Duration", value: Float(StimulusParams.fixationDuration),
                           min: 0.5, max: 3.0, action: #selector(fixationDurationChanged))
        
        setupSliderWithLabel(coherentWindowSlider, label: coherentWindowLabel,
                           title: "Coherent Window", value: Float(StimulusParams.coherentWindowDuration),
                           min: 0.2, max: 3.0, action: #selector(coherentWindowChanged))
        
        setupSliderWithLabel(interTrialSlider, label: interTrialLabel,
                           title: "Inter-trial Interval", value: Float(StimulusParams.interTrialInterval),
                           min: 0.5, max: 5.0, action: #selector(interTrialChanged))
        
        // Timing settings section (legacy controls only)
        let timingSectionLabel = createSectionLabel("Legacy Timing Settings")
        timingSettingsStack.axis = .vertical
        timingSettingsStack.spacing = 8
        timingSettingsStack.addArrangedSubview(timingSectionLabel)
        timingSettingsStack.addArrangedSubview(createLabelWithHelpButton(label: fixationDurationLabel, helpText: helpTexts["fixationDuration"]))
        timingSettingsStack.addArrangedSubview(fixationDurationSlider)
        timingSettingsStack.addArrangedSubview(createLabelWithHelpButton(label: coherentWindowLabel, helpText: helpTexts["coherentWindow"]))
        timingSettingsStack.addArrangedSubview(coherentWindowSlider)
        timingSettingsStack.addArrangedSubview(createLabelWithHelpButton(label: interTrialLabel, helpText: helpTexts["interTrial"]))
        timingSettingsStack.addArrangedSubview(interTrialSlider)
    }
    
    private func setupDisplaySettings() {
        // Setup display parameter sliders (legacy controls only)
        setupSliderWithLabel(stimulusHzSlider, label: stimulusHzLabel,
                           title: "Stimulus Hz", value: Float(StimulusParams.targetStimHz),
                           min: 1, max: 120, action: #selector(stimulusHzChanged))
        
        setupSliderWithLabel(fixationRadiusSlider, label: fixationRadiusLabel,
                           title: "Fixation Radius", value: Float(StimulusParams.fixationDotRadius),
                           min: 1.0, max: 10.0, action: #selector(fixationRadiusChanged))
        
        setupSliderWithLabel(gridColsSlider, label: gridColsLabel,
                           title: "Grid Columns", value: Float(StimulusParams.cols),
                           min: 10, max: 40, action: #selector(gridColsChanged))
        
        setupSliderWithLabel(gridRowsSlider, label: gridRowsLabel,
                           title: "Grid Rows", value: Float(StimulusParams.rows),
                           min: 8, max: 25, action: #selector(gridRowsChanged))
        
        // Reset defaults button
        resetDefaultsButton.setTitle("Reset to Defaults", for: .normal)
        resetDefaultsButton.setTitleColor(.white, for: .normal)
        resetDefaultsButton.backgroundColor = UIColor.systemGray
        resetDefaultsButton.layer.cornerRadius = 8
        resetDefaultsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        resetDefaultsButton.addTarget(self, action: #selector(resetDefaultsTapped), for: .touchUpInside)
        
        // Display settings section (legacy controls only)
        let displaySectionLabel = createSectionLabel("Legacy Display Settings")
        displaySettingsStack.axis = .vertical
        displaySettingsStack.spacing = 8
        displaySettingsStack.addArrangedSubview(displaySectionLabel)
        displaySettingsStack.addArrangedSubview(createLabelWithHelpButton(label: stimulusHzLabel, helpText: helpTexts["stimulusHz"]))
        displaySettingsStack.addArrangedSubview(stimulusHzSlider)
        displaySettingsStack.addArrangedSubview(createLabelWithHelpButton(label: fixationRadiusLabel, helpText: helpTexts["fixationRadius"]))
        displaySettingsStack.addArrangedSubview(fixationRadiusSlider)
        displaySettingsStack.addArrangedSubview(createLabelWithHelpButton(label: gridColsLabel, helpText: helpTexts["gridCols"]))
        displaySettingsStack.addArrangedSubview(gridColsSlider)
        displaySettingsStack.addArrangedSubview(createLabelWithHelpButton(label: gridRowsLabel, helpText: helpTexts["gridRows"]))
        displaySettingsStack.addArrangedSubview(gridRowsSlider)
        displaySettingsStack.addArrangedSubview(resetDefaultsButton)
    }
    
    
    private func setupSliderWithLabel(_ slider: UISlider, label: UILabel, title: String, value: Float, min: Float, max: Float, action: Selector, helpText: String? = nil) {
        label.text = "\(title): \(value)"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
    }
    
    /// Creates a horizontal stack containing a label and an optional help button
    private func createLabelWithHelpButton(label: UILabel, helpText: String?) -> UIView {
        if let helpText = helpText {
            let container = UIStackView()
            container.axis = .horizontal
            container.spacing = 8
            container.alignment = .center
            
            let helpButton = createHelpButton(helpText: helpText)
            
            container.addArrangedSubview(label)
            container.addArrangedSubview(helpButton)
            
            return container
        } else {
            return label
        }
    }
    
    private func setupTextFieldWithLabel(_ textField: UITextField, label: UILabel, title: String, value: String, action: Selector, helpText: String? = nil) -> UIStackView {
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        textField.text = value
        textField.backgroundColor = UIColor.systemGray6
        textField.textColor = .black
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.borderStyle = .roundedRect
        textField.layer.cornerRadius = 6
        // Use default keyboard for text fields (grating contrasts, session info), decimal pad for numeric fields
        let isTextField = action == #selector(gratingContrastsChanged) ||
                         action == #selector(experimentNameChanged) ||
                         action == #selector(playerNameChanged) ||
                         action == #selector(usernameChanged)
        textField.keyboardType = isTextField ? .default : .decimalPad
        textField.returnKeyType = .done
        textField.addTarget(self, action: action, for: .editingDidEnd)
        
        // Make text field compact (but wider for grating contrasts and session info)
        let isWideField = action == #selector(gratingContrastsChanged) ||
                          action == #selector(experimentNameChanged) ||
                          action == #selector(playerNameChanged) ||
                          action == #selector(usernameChanged)
        textField.widthAnchor.constraint(equalToConstant: isWideField ? 200 : 80).isActive = true
        textField.heightAnchor.constraint(equalToConstant: 32).isActive = true
        
        // Add toolbar with Done button for number pad
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: textField, action: #selector(UITextField.resignFirstResponder))
        toolbar.setItems([doneButton], animated: false)
        textField.inputAccessoryView = toolbar
        
        // Create components array for horizontal stack
        var stackComponents: [UIView] = [label]
        
        // Add help button if help text is provided
        if let helpText = helpText {
            let helpButton = createHelpButton(helpText: helpText)
            stackComponents.append(helpButton)
        }
        
        stackComponents.append(textField)
        
        // Create horizontal stack for label + help button + text field
        let horizontalStack = UIStackView(arrangedSubviews: stackComponents)
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 8
        horizontalStack.alignment = .center
        horizontalStack.distribution = .fill
        
        return horizontalStack
    }
    
    // MARK: - Help Button Creation
    
    private func createHelpButton(helpText: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("?", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        button.layer.cornerRadius = 10
        button.widthAnchor.constraint(equalToConstant: 20).isActive = true
        button.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        // Store help text in the button's accessibilityHint for retrieval
        button.accessibilityHint = helpText
        
        button.addTarget(self, action: #selector(helpButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func helpButtonTapped(_ sender: UIButton) {
        guard let helpText = sender.accessibilityHint else { return }
        
        // Dismiss existing popover if any
        helpPopover?.hide()
        
        // Create and show new popover
        let popover = HelpPopoverView(text: helpText)
        helpPopover = popover
        
        // Show below the button in the main view
        popover.show(below: sender, in: view)
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak popover] in
            popover?.hide()
        }
        
        // Also dismiss on tap anywhere
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissHelpPopover))
        view.addGestureRecognizer(tapGesture)
        
        // Remove only this specific gesture after dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) { [weak self, weak tapGesture] in
            if let gesture = tapGesture {
                self?.view.removeGestureRecognizer(gesture)
            }
        }
    }
    
    @objc private func dismissHelpPopover() {
        helpPopover?.hide()
    }
    
    private func setupSettingsLayout() {
        // Setup scroll view for settings
        settingsScrollView.showsVerticalScrollIndicator = true
        settingsScrollView.alwaysBounceVertical = true
        
        // Add the session info stack FIRST, then other settings
        settingsContentView.addSubview(sessionInfoStack)
        settingsContentView.addSubview(newTrialSettingsStack)
        settingsContentView.addSubview(basicSettingsStack)
        settingsContentView.addSubview(timingSettingsStack)
        settingsContentView.addSubview(displaySettingsStack)
        settingsScrollView.addSubview(settingsContentView)
        
        // Configure stack views
        [sessionInfoStack, newTrialSettingsStack, basicSettingsStack, timingSettingsStack, displaySettingsStack].forEach { stack in
            stack.translatesAutoresizingMaskIntoConstraints = false
        }
        settingsContentView.translatesAutoresizingMaskIntoConstraints = false
        settingsScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // SESSION INFO (at the top)
            sessionInfoStack.topAnchor.constraint(equalTo: settingsContentView.topAnchor, constant: 10),
            sessionInfoStack.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor, constant: 10),
            sessionInfoStack.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor, constant: -10),
            
            // NEW TRIAL SETTINGS (below session info)
            newTrialSettingsStack.topAnchor.constraint(equalTo: sessionInfoStack.bottomAnchor, constant: 10),
            newTrialSettingsStack.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor, constant: 10),
            newTrialSettingsStack.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor, constant: -10),
            
            // Basic settings (moved down)
            basicSettingsStack.topAnchor.constraint(equalTo: newTrialSettingsStack.bottomAnchor, constant: 20),
            basicSettingsStack.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor),
            basicSettingsStack.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor),
            
            // Timing settings
            timingSettingsStack.topAnchor.constraint(equalTo: basicSettingsStack.bottomAnchor, constant: 16),
            timingSettingsStack.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor),
            timingSettingsStack.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor),
            
            // Display settings
            displaySettingsStack.topAnchor.constraint(equalTo: timingSettingsStack.bottomAnchor, constant: 16),
            displaySettingsStack.leadingAnchor.constraint(equalTo: settingsContentView.leadingAnchor),
            displaySettingsStack.trailingAnchor.constraint(equalTo: settingsContentView.trailingAnchor),
            displaySettingsStack.bottomAnchor.constraint(equalTo: settingsContentView.bottomAnchor),
            
            // Content view
            settingsContentView.topAnchor.constraint(equalTo: settingsScrollView.topAnchor),
            settingsContentView.leadingAnchor.constraint(equalTo: settingsScrollView.leadingAnchor),
            settingsContentView.trailingAnchor.constraint(equalTo: settingsScrollView.trailingAnchor),
            settingsContentView.bottomAnchor.constraint(equalTo: settingsScrollView.bottomAnchor),
            settingsContentView.widthAnchor.constraint(equalTo: settingsScrollView.widthAnchor)
        ])
    }
    
    private func createSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        return label
    }
    
    private func layoutUI() {
        // No button stack needed - all buttons are now icon buttons in bottom right
        let mainStack = UIStackView(arrangedSubviews: [statusLabel, newTrialSettingsStack, diagnosticsLabel])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        controlPanel.addSubview(mainStack)
        
        // Setup constraints
        toggleControlsButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Control panel
            controlPanel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            controlPanel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            controlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Main stack
            mainStack.topAnchor.constraint(equalTo: controlPanel.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: controlPanel.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: controlPanel.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: controlPanel.bottomAnchor, constant: -16),
            
            // Settings scroll view height constraint (increased for new settings)
            settingsScrollView.heightAnchor.constraint(lessThanOrEqualToConstant: 500),
            
            // Toggle controls button (top-right corner)
            toggleControlsButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            toggleControlsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            toggleControlsButton.widthAnchor.constraint(equalToConstant: 50),
            toggleControlsButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Start, export, email and reset buttons (bottom-right corner, always visible, stacked vertically)
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            resetButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            resetButton.widthAnchor.constraint(equalToConstant: 50),
            resetButton.heightAnchor.constraint(equalToConstant: 50),
            
            exportButton.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -12),
            exportButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            exportButton.widthAnchor.constraint(equalToConstant: 50),
            exportButton.heightAnchor.constraint(equalToConstant: 50),
            
            emailButton.bottomAnchor.constraint(equalTo: exportButton.topAnchor, constant: -12),
            emailButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            emailButton.widthAnchor.constraint(equalToConstant: 50),
            emailButton.heightAnchor.constraint(equalToConstant: 50),
            
            startButton.bottomAnchor.constraint(equalTo: emailButton.topAnchor, constant: -12),
            startButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            startButton.widthAnchor.constraint(equalToConstant: 50),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            
            // No constraints needed for removed stimulus detection button
        ])
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        guard let stimulusController = stimulusController else { return }
        
        if stimulusController.isActive {
            stimulusController.stop()
        } else {
            let sequence: [Double]?
            if coherenceSegment.selectedSegmentIndex == 0 {
                // Single coherence
                sequence = [Double(coherenceSlider.value)]
            } else {
                // Full sequence
                sequence = nil
            }
            
            // Show trial info before starting
            showTrialInfo(sequence: sequence)
        }
    }
    
    /// Show trial information view before starting trials
    private func showTrialInfo(sequence: [Double]?) {
        // Store the sequence to start after info is dismissed
        pendingTrialSequence = sequence
        
        // Load current session info (from ViewController's sessionInfo property)
        sessionInfo = SessionInfo.load()
        
        // Create and configure info view with current values
        let infoView = TrialInfoView()
        infoView.configure(
            experimentName: sessionInfo.experimentName,
            playerName: sessionInfo.playerName,
            username: sessionInfo.username
        )
        
        // Set up continue handler - save edited values and recreate controller
        infoView.onContinue = { [weak self] experimentName, playerName, username in
            guard let self = self else { return }
            
            // Update session info with edited values
            self.sessionInfo.experimentName = experimentName
            self.sessionInfo.playerName = playerName
            self.sessionInfo.username = username
            self.sessionInfo.save()
            
            // Update text fields in settings panel to match
            self.experimentNameTextField.text = experimentName
            self.playerNameTextField.text = playerName
            self.usernameTextField.text = username
            
            // Recreate stimulus controller with new session ID
            self.recreateStimulusController()
            
            // Hide the info view and start trials
            infoView.hide {
                guard let stimulusController = self.stimulusController else { return }
                // Start trials after info view is dismissed
                stimulusController.startTrials(sequence: self.pendingTrialSequence)
                self.pendingTrialSequence = nil
            }
        }
        
        // Show the info view
        infoView.show(in: view)
        trialInfoView = infoView
    }
    
    
    @objc private func exportButtonTapped() {
        exportAllData()
    }
    
    @objc private func emailButtonTapped() {
        // Check if mail is available
        guard MFMailComposeViewController.canSendMail() else {
            showAlert(title: "Mail Not Available", message: "Please configure a Mail account in Settings to use this feature.")
            return
        }
        
        // Append detection times to the main log file before exporting
        if !stimulusDetectionTimes.isEmpty {
            stimulusController?.logger.appendDetectionTimes(stimulusDetectionTimes)
        }
        
        // Export single unified CSV file with all data
        guard let logURL = stimulusController?.exportResults() else {
            showAlert(title: "No Data", message: "No data available to export.")
            return
        }
        
        // Create mail composer
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        
        // Set subject with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        mailComposer.setSubject("Noise Game Data Export - \(timestamp)")
        
        // Attach CSV file
        if let csvData = try? Data(contentsOf: logURL) {
            mailComposer.addAttachmentData(csvData, mimeType: "text/csv", fileName: logURL.lastPathComponent)
        }
        
        // Present mail composer
        present(mailComposer, animated: true)
    }
    
    @objc private func resetButtonTapped() {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Reset Session",
            message: "This will clear all collected data (stimulus detections and trial results). This action cannot be undone. Continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            self.performReset()
        })
        
        present(alert, animated: true)
    }
    
    @objc private func toggleControlPanelTapped() {
        isControlPanelVisible.toggle()
        updateControlPanelVisibility()
    }
    
    @objc private func screenTapped() {
        print("👆 TAP DETECTED - Starting tap handler")
        
        // Only process taps during active trials
        guard let controller = stimulusController else {
            print("❌ No stimulus controller")
            return
        }
        
        guard controller.isActive == true else {
            print("❌ Trials not active (isActive: \(controller.isActive))")
            return
        }
        
        let detectionTime = Date()
        stimulusDetectionTimes.append(detectionTime)
        
        // Get current state
        let currentState = controller.state
        print("📊 Current state: \(currentState.rawValue)")
        
        // Register response with stimulus controller and check if it's a hit
        var responseType: String? = nil
        responseType = controller.registerResponse(at: detectionTime)
        print("📊 Response type: \(responseType ?? "nil")")
        
        // Check if stimulus is currently visible (coherent state)
        let isStimulusVisible = currentState == .coherent
        print("📊 Stimulus visible: \(isStimulusVisible)")
        
        // Handle correct click (stimulus is visible) - end trial immediately
        if isStimulusVisible {
            print("✅ STIMULUS VISIBLE - Correct click! Ending trial and starting next.")
            showPositiveFeedback()
            playGoodSound()
            
            // End current trial and start next trial immediately
            controller.endCurrentTrialAndStartNext()
            return
        }
        
        // Handle hit (correct response, even if timing slightly off)
        if responseType == "hit" {
            print("✅ HIT DETECTED - Correct response! Ending trial and starting next.")
            showPositiveFeedback()
            playGoodSound()
            
            // End current trial and start next trial immediately
            controller.endCurrentTrialAndStartNext()
            return
        }
        
        // Handle wrong clicks (FA - False Alarm)
        // The registerResponse function already handles FA logic including:
        // - probFALickReward (rewarded FA continues trial)
        // - Early FA extends trial (extendTrialOnEarlyFA)
        // - Late FA ends trial immediately
        // We just need to handle feedback here based on response type
        
        guard controller.currentTrial != nil else { return }
        
        // Check what registerResponse returned to determine handling
        if responseType == "fa_extended" {
            // Early FA - trial was extended (no feedback needed, trial continues)
            print("⚠️ EARLY FA - Trial extended, continuing...")
            // No feedback - trial continues silently (matches MATLAB behavior)
            return
        } else if responseType == "fa_rewarded" {
            // FA that was rewarded (probFALickReward) - trial continues
            print("⚠️ FA REWARDED - Trial continues")
            // No feedback - trial just continues (matches MATLAB behavior)
            // The reward window is already set in handleFalseAlarm
            return
        } else if responseType == "fa_timeout" {
            // Late FA - trial will end immediately
            print("⚠️ LATE FA - Ending trial immediately")
            // End trial and start next (no negative feedback - matches MATLAB behavior)
            controller.endCurrentTrialAndStartNext()
            return
        } else {
            // Edge case: response type unclear
            print("⚠️ WRONG CLICK - Response type unclear: \(responseType ?? "none"), State: \(currentState.rawValue)")
            // End trial to be safe
            controller.endCurrentTrialAndStartNext()
            return
        }
    }
    
    private func isDetectionWithinWindow(detectionTime: Date) -> Bool {
        // Check if we're in the coherent state and within the detection window
        guard let controller = stimulusController,
              controller.state == .coherent,
              let coherentStartTime = controller.coherentStartTime else {
            return false
        }
        
        let timeSinceCoherentStart = detectionTime.timeIntervalSince(coherentStartTime)
        
        // Valid detection window: from coherent start to end of coherent window
        let validWindow = StimulusParams.coherentWindowDuration
        
        return timeSinceCoherentStart >= 0 && timeSinceCoherentStart <= validWindow
    }
    
    func showPositiveFeedback() {
        print("❤️ showPositiveFeedback() called")
        
        guard let heartView = heartFeedbackView else {
            print("❌ Heart feedback view is nil!")
            return
        }
        
        print("❤️ Showing heart - isHidden was: \(heartView.isHidden)")
        
        // Ensure we're on main thread
        DispatchQueue.main.async {
            heartView.isHidden = false
            heartView.alpha = 1.0
            
            // Bring to front
            if let superview = heartView.superview {
                superview.bringSubviewToFront(heartView)
            }
            
            print("❤️ Heart view is now visible: \(!heartView.isHidden), alpha: \(heartView.alpha)")
            
            // Animate the heart with a scale effect
            heartView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            UIView.animate(withDuration: 0.3, animations: {
                heartView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    heartView.transform = CGAffineTransform.identity
                }) { _ in
                    // Hide after 1 second total
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        UIView.animate(withDuration: 0.3) {
                            heartView.alpha = 0.0
                        } completion: { _ in
                            heartView.isHidden = true
                            print("❤️ Heart hidden again")
                        }
                    }
                }
            }
        }
    }
    
    func showNegativeFeedback() {
        sadFaceFeedbackView?.isHidden = false
        sadFaceFeedbackView?.alpha = 1.0
        
        // Animate the sad face with a shake effect
        let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shakeAnimation.values = [0, -10, 10, -5, 5, 0]
        shakeAnimation.duration = 0.5
        sadFaceFeedbackView?.layer.add(shakeAnimation, forKey: "shake")
        
        // Hide after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            UIView.animate(withDuration: 0.3) {
                self.sadFaceFeedbackView?.alpha = 0.0
            } completion: { _ in
                self.sadFaceFeedbackView?.isHidden = true
            }
        }
    }
    
    func playGoodSound() {
        print("🔊 playGoodSound() called")
        // Play a pleasant, happy sound for correct detection
        // Using system sound 1057 (SMS received) - a reliable pleasant chime
        AudioServicesPlaySystemSound(1057) // SMS received - pleasant and reliable
        print("🔊 Sound played (system sound 1057)")
        
        // Alternative: Try 1315 (Peek) if available, but 1057 is more widely supported
        // AudioServicesPlaySystemSound(1315) // Peek sound
    }
    
    func playBadSound() {
        // Play an error sound for incorrect detection
        AudioServicesPlaySystemSound(1053) // Error sound
    }
    
    // MARK: - Parameter Change Actions (consolidated)
    
    @objc private func distanceChanged() {
        let distance = Double(distanceSlider.value)
        stimulusController?.distanceCm = distance
        distanceLabel.text = "Distance: \(String(format: "%.1f", distance)) cm"
        checkerboardView?.updateGeometry()
    }
    
    @objc private func coherenceChanged() {
        let coherence = Double(coherenceSlider.value)
        coherenceLabel.text = "Coherence: \(String(format: "%.2f", coherence))"
    }
    
    @objc private func coherenceTypeChanged() {
        let isSingle = coherenceSegment.selectedSegmentIndex == 0
        coherenceSlider.isEnabled = isSingle
        coherenceLabel.isHidden = !isSingle
    }
    
    
    @objc private func stimulusHzChanged() {
        let value = Int(stimulusHzSlider.value)
        StimulusParams.targetStimHz = value
        stimulusHzLabel.text = "Stimulus Hz: \(value)"
        
        // Update the TrialSettings and text field to match
        trialSettings.stimulusHz = value
        trialSettings.save()
        stimulusHzTextField.text = String(value)
    }
    
    @objc private func fixationDurationChanged() {
        StimulusParams.fixationDuration = Double(fixationDurationSlider.value)
        fixationDurationLabel.text = "Fixation Duration: \(String(format: "%.1f", StimulusParams.fixationDuration))s"
    }
    
    @objc private func minGratingOnsetChanged() {
        guard let text = minOnsetTextField.text, let value = Double(text), value >= 0 else {
            minOnsetTextField.text = String(format: "%.1f", trialSettings.minGratingOnset)
            return
        }
        
        trialSettings.minGratingOnset = value
        
        // Ensure max onset is always >= min onset
        if trialSettings.maxGratingOnset < trialSettings.minGratingOnset {
            trialSettings.maxGratingOnset = trialSettings.minGratingOnset + 1.0
            maxOnsetTextField.text = String(format: "%.1f", trialSettings.maxGratingOnset)
        }
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func maxGratingOnsetChanged() {
        guard let text = maxOnsetTextField.text, let value = Double(text), value >= 0 else {
            maxOnsetTextField.text = String(format: "%.1f", trialSettings.maxGratingOnset)
            return
        }
        
        trialSettings.maxGratingOnset = value
        
        // Ensure min onset is always <= max onset
        if trialSettings.minGratingOnset > trialSettings.maxGratingOnset {
            trialSettings.minGratingOnset = trialSettings.maxGratingOnset - 1.0
            minOnsetTextField.text = String(format: "%.1f", trialSettings.minGratingOnset)
        }
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func coherentWindowChanged() {
        StimulusParams.coherentWindowDuration = Double(coherentWindowSlider.value)
        coherentWindowLabel.text = "Coherent Window: \(String(format: "%.1f", StimulusParams.coherentWindowDuration))s"
    }
    
    @objc private func interTrialChanged() {
        StimulusParams.interTrialInterval = Double(interTrialSlider.value)
        interTrialLabel.text = "Inter-trial Interval: \(String(format: "%.1f", StimulusParams.interTrialInterval))s"
    }
    
    @objc private func fixationRadiusChanged() {
        StimulusParams.fixationDotRadius = CGFloat(fixationRadiusSlider.value)
        fixationRadiusLabel.text = "Fixation Radius: \(String(format: "%.1f", StimulusParams.fixationDotRadius))px"
        checkerboardView?.updateGeometry()  // Update fixation dot appearance
    }
    
    @objc private func gridColsChanged() {
        guard let text = gridColsTextField.text, let value = Int(text), value > 0 else {
            gridColsTextField.text = String(StimulusParams.cols)
            return
        }
        
        StimulusParams.cols = value
        checkerboardView?.updateGeometry()  // Update grid layout
    }
    
    @objc private func gridRowsChanged() {
        guard let text = gridRowsTextField.text, let value = Int(text), value > 0 else {
            gridRowsTextField.text = String(StimulusParams.rows)
            return
        }
        
        StimulusParams.rows = value
        checkerboardView?.updateGeometry()  // Update grid layout
    }
    
    // MARK: - Session Info Action Methods
    
    @objc private func experimentNameChanged() {
        sessionInfo.experimentName = experimentNameTextField.text ?? ""
        sessionInfo.save()
        recreateStimulusController()
    }
    
    @objc private func playerNameChanged() {
        sessionInfo.playerName = playerNameTextField.text ?? ""
        sessionInfo.save()
        recreateStimulusController()
    }
    
    @objc private func usernameChanged() {
        sessionInfo.username = usernameTextField.text ?? ""
        sessionInfo.save()
        recreateStimulusController()
    }
    
    /// Recreate StimulusController with new sessionId when session info changes
    private func recreateStimulusController() {
        // Stop any running trials
        let wasRunning = stimulusController?.isActive == true
        if wasRunning {
            stimulusController?.stop()
        }
        
        // Create new sessionId
        let sessionId = sessionInfo.sessionId
        
        // Recreate stimulus controller with new sessionId
        stimulusController = StimulusController(sessionId: sessionId)
        stimulusController?.delegate = self
        stimulusController?.distanceCm = Double(distanceSlider.value)
        
        // Update UI
        updateUIState()
        
        print("StimulusController recreated with sessionId: \(sessionId)")
    }
    
    // MARK: - New TrialSettings Action Methods
    
    @objc private func rtWindowDelayChanged() {
        guard let text = rtWindowDelayTextField.text, let value = Double(text), value >= 0 else {
            rtWindowDelayTextField.text = String(format: "%.1f", trialSettings.rtWindowDelay)
            return
        }
        
        trialSettings.rtWindowDelay = value
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func rtWindowLengthChanged() {
        guard let text = rtWindowLengthTextField.text, let value = Double(text), value > 0 else {
            rtWindowLengthTextField.text = String(format: "%.1f", trialSettings.rtWindowLength)
            return
        }
        
        trialSettings.rtWindowLength = value
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func stimulusDurationChanged() {
        guard let text = stimulusDurationTextField.text, let value = Double(text), value > 0 else {
            stimulusDurationTextField.text = String(format: "%.1f", trialSettings.stimulusDuration)
            return
        }
        
        trialSettings.stimulusDuration = value
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func gridSizeChanged() {
        guard let text = gridSizeTextField.text, let value = Double(text), value > 0 && value <= 200 else {
            gridSizeTextField.text = String(format: "%.0f", trialSettings.gridSizePercent)
            return
        }
        
        trialSettings.gridSizePercent = value
        trialSettings.save()
        stimulusController?.updateSettings()
        
        // Update the visual grid size immediately
        checkerboardView?.updateGeometry()
    }
    
    @objc private func probAutomaticRewardChanged() {
        guard let text = probAutomaticRewardTextField.text, let value = Double(text), value >= 0 && value <= 1 else {
            probAutomaticRewardTextField.text = String(format: "%.2f", trialSettings.probAutomaticStimReward)
            return
        }
        
        trialSettings.probAutomaticStimReward = value
        trialSettings.save()
        stimulusController?.updateSettings()
    }
    
    @objc private func gridSizeSegmentChanged() {
        let selectedIndex = gridSizeSegmentedControl.selectedSegmentIndex
        guard selectedIndex >= 0 && selectedIndex < GridSize.allCases.count else { return }
        
        let selectedGridSize = GridSize.allCases[selectedIndex]
        trialSettings.gridSize = selectedGridSize
        trialSettings.applyGridSize()  // Apply to StimulusParams
        trialSettings.save()
        stimulusController?.updateSettings()
        
        // Update the visual grid immediately
        checkerboardView?.updateGeometry()
        
        print("Grid size changed to: \(selectedGridSize.displayName) (\(selectedGridSize.dimensions.cols)×\(selectedGridSize.dimensions.rows))")
    }
    
    
    @objc private func stimulusHzTextFieldChanged() {
        guard let text = stimulusHzTextField.text, let value = Int(text), value >= 1 && value <= 120 else {
            stimulusHzTextField.text = String(trialSettings.stimulusHz)
            return
        }
        
        trialSettings.stimulusHz = value
        trialSettings.applyStimulusHz()  // Apply to StimulusParams
        trialSettings.save()
        stimulusController?.updateSettings()
        
        // Update the legacy slider to match
        stimulusHzSlider.value = Float(value)
        stimulusHzLabel.text = "Stimulus Hz: \(value)"
        
        // Note: Display ticker will need to be restarted for frequency changes to take effect
        print("Stimulus frequency changed to \(value) Hz. Restart trials for changes to take effect.")
    }
    
    @objc private func gratingContrastsChanged() {
        guard let text = gratingContrastsTextField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            gratingContrastsTextField.text = trialSettings.gratingContrasts
            return
        }
        
        // Validate the input format - should be space-separated numbers
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        let components = trimmedText.split(separator: " ").map { String($0) }
        
        // Try to parse each component as a double, preserving original format
        struct ValidatedValue {
            let originalString: String
            let value: Double
        }
        
        var validatedValues: [ValidatedValue] = []
        var hasInvalidValues = false
        
        for component in components {
            let trimmedComponent = component.trimmingCharacters(in: .whitespaces)
            if let value = Double(trimmedComponent) {
                if value >= 0.0 && value <= 1.0 {
                    validatedValues.append(ValidatedValue(originalString: trimmedComponent, value: value))
                } else {
                    hasInvalidValues = true
                    let clampedValue = max(0.0, min(1.0, value))
                    print("⚠️ Warning: Contrast value \(value) is out of range [0, 1]. Clamping to valid range.")
                    // Format clamped value with sufficient precision
                    validatedValues.append(ValidatedValue(originalString: formatDouble(clampedValue), value: clampedValue))
                }
            } else {
                hasInvalidValues = true
                print("⚠️ Warning: Invalid contrast value '\(component)' will be ignored.")
            }
        }
        
        // If no valid values, restore previous value
        if validatedValues.isEmpty {
            showAlert(title: "Invalid Input", message: "Please enter valid contrast values (0-1) separated by spaces. Example: '0 .1 .2 .4 .6 .8 1'")
            gratingContrastsTextField.text = trialSettings.gratingContrasts
            return
        }
        
        // Sort by value but preserve original string format
        let sortedValues = validatedValues.sorted(by: { $0.value < $1.value })
        let formattedString = sortedValues.map { $0.originalString }.joined(separator: " ")
        trialSettings.gratingContrasts = formattedString
        trialSettings.save()
        stimulusController?.updateSettings()
        
        // Update text field with formatted version
        gratingContrastsTextField.text = formattedString
        
        if hasInvalidValues {
            showAlert(title: "Input Processed", message: "Some invalid values were ignored. Using: \(formattedString)")
        } else {
            print("✅ Grating contrasts updated to: \(formattedString) (parsed: \(trialSettings.parsedGratingContrasts))")
        }
    }
    
    /// Format a Double value preserving precision (removes trailing zeros but keeps significant digits)
    private func formatDouble(_ value: Double) -> String {
        // Use enough precision to avoid rounding issues, but remove trailing zeros
        let formatted = String(format: "%.10f", value)
        // Remove trailing zeros and decimal point if not needed
        return formatted.replacingOccurrences(of: "0*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
    }
    
    @objc private func testingModeToggleChanged() {
        // Toggle OFF = test mode (testingMode = true): red stimulus, dashboard visible
        // Toggle ON = normal mode (testingMode = false): white stimulus, dashboard hidden
        trialSettings.testingMode = !testingModeToggle.isOn
        trialSettings.save()
        stimulusController?.updateSettings()
        
        // Update dashboard visibility based on testing mode
        updateDashboardVisibility()
        
        // Hide coherence display if switching to normal mode, or show it if in test mode and currently coherent
        if !trialSettings.testingMode {
            hideCoherenceDisplay()
        } else if let controller = stimulusController, controller.state == .coherent {
            // If in test mode and currently showing coherent stimulus, update the display
            updateCoherenceDisplay(coherence: controller.currentCoherence)
        }
        
        // Force a refresh of the stimulus display to update color
        checkerboardView?.setNeedsDisplay()
        
        print("Testing mode: \(trialSettings.testingMode ? "ON" : "OFF") (Stimulus: \(trialSettings.testingMode ? "RED" : "WHITE"))")
    }
    
    @objc private func resetDefaultsTapped() {
        // Reset all parameters to their defaults
        StimulusParams.fixationDuration = 1.0
        StimulusParams.minOnsetTime = 4.0
        StimulusParams.maxOnsetTime = 12.0
        StimulusParams.coherentWindowDuration = 1.0
        StimulusParams.interTrialInterval = 2.0
        StimulusParams.fixationDotRadius = 3.0
        StimulusParams.cols = 32
        StimulusParams.rows = 24
        
        // Reset TrialSettings to defaults
        trialSettings = TrialSettings()
        trialSettings.applyGridSize()  // Apply default grid size to StimulusParams
        trialSettings.applyStimulusHz()  // Apply default stimulus Hz to StimulusParams
        trialSettings.save()
        
        // Update all controls to reflect new values (with clean formatting)
        stimulusHzSlider.value = Float(StimulusParams.targetStimHz)
        fixationDurationSlider.value = Float(StimulusParams.fixationDuration)
        minOnsetTextField.text = String(format: "%.1f", trialSettings.minGratingOnset)
        maxOnsetTextField.text = String(format: "%.1f", trialSettings.maxGratingOnset)
        rtWindowDelayTextField.text = String(format: "%.1f", trialSettings.rtWindowDelay)
        rtWindowLengthTextField.text = String(format: "%.1f", trialSettings.rtWindowLength)
        probAutomaticRewardTextField.text = String(format: "%.2f", trialSettings.probAutomaticStimReward)
        stimulusHzTextField.text = String(trialSettings.stimulusHz)
        gratingContrastsTextField.text = trialSettings.gratingContrasts
        coherentWindowSlider.value = Float(StimulusParams.coherentWindowDuration)
        interTrialSlider.value = Float(StimulusParams.interTrialInterval)
        fixationRadiusSlider.value = Float(StimulusParams.fixationDotRadius)
        distanceSlider.value = Float(StimulusParams.defaultViewingDistanceCm)
        coherenceSlider.value = 1.0
        
        // Update all labels and apply changes
        updateAllParameterDisplays()
        checkerboardView?.updateGeometry()
        
        // Provide feedback
        let alert = UIAlertController(title: "Settings Reset", message: "All parameters have been reset to their default values.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateAllParameterDisplays() {
        distanceChanged()
        coherenceChanged()
        stimulusHzChanged()  // Updates slider display
        fixationDurationChanged()
        minGratingOnsetChanged()
        maxGratingOnsetChanged()
        rtWindowDelayChanged()
        rtWindowLengthChanged()
        gridSizeChanged()
        probAutomaticRewardChanged()
        updateStimulusHzTextFieldDisplay()  // Just update display, don't validate
        gratingContrastsChanged()  // Update display, validates input
        coherentWindowChanged()
        interTrialChanged()
        fixationRadiusChanged()
    }
    
    private func updateStimulusHzTextFieldDisplay() {
        stimulusHzTextField.text = String(trialSettings.stimulusHz)
    }
    
    
    // MARK: - Data Export
    
    private func exportAllData() {
        // Append detection times to the main log file before exporting
        if !stimulusDetectionTimes.isEmpty {
            stimulusController?.logger.appendDetectionTimes(stimulusDetectionTimes)
        }
        
        // Export single unified CSV file with all data
        guard let logURL = stimulusController?.exportResults() else {
            showAlert(title: "No Data", message: "No data available to export.")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [logURL], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        present(activityVC, animated: true)
    }
    
    // MARK: - Reset Functionality
    
    private func performReset() {
        // Stop any running trials and flickering
        if stimulusController?.isActive == true {
            stimulusController?.stop()
        }
        
        // Clear all collected data
        stimulusDetectionTimes.removeAll()
        
        // Reset stimulus controller (this will clear trial results)
        // Reload session info to get current sessionId
        sessionInfo = SessionInfo.load()
        let sessionId = sessionInfo.sessionId
        stimulusController = StimulusController(sessionId: sessionId)
        stimulusController?.delegate = self
        stimulusController?.distanceCm = Double(distanceSlider.value)
        
        // Update UI state
        updateUIState()
        
        // Show confirmation
        showAlert(title: "Reset Complete", message: "All data has been cleared and the session has been reset.")
        
        print("Session reset completed")
    }
    
    // MARK: - UI Updates
    
    func updateUIState() {
        let isRunning = stimulusController?.isActive == true
        
        // Update start button icon and color
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        if isRunning {
            startButton.setImage(UIImage(systemName: "stop.fill", withConfiguration: config), for: .normal)
            startButton.backgroundColor = UIColor.systemRed
        } else {
            startButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
            startButton.backgroundColor = UIColor.systemGreen
        }
        
        // Disable controls during trials
        settingsScrollView.isUserInteractionEnabled = !isRunning
        
        exportButton.isEnabled = stimulusController?.exportResults() != nil
        emailButton.isEnabled = stimulusController?.exportResults() != nil
        
        // Disable reset button during active trials
        resetButton.isEnabled = !isRunning
        
        // Update dashboard visibility based on testing mode and running state
        updateDashboardVisibility()
        
        // Auto-hide control panel when trials start
        if isRunning && isControlPanelVisible {
            isControlPanelVisible = false
            updateControlPanelVisibility()
        }
    }
    
    private func updateControlPanelVisibility() {
        UIView.animate(withDuration: 0.3) {
            self.controlPanel.alpha = self.isControlPanelVisible ? 1.0 : 0.0
            self.toggleControlsButton.setTitle(self.isControlPanelVisible ? "✕" : "⚙️", for: .normal)
        }
    }
    
    private func updateDashboardVisibility() {
        let isRunning = stimulusController?.isActive == true
        let shouldShowDashboard = isRunning && trialSettings.testingMode
        
        // Show/hide performance dashboard based on testing mode and running state
        if shouldShowDashboard && !isDashboardVisible {
            performanceDashboard?.show()
            isDashboardVisible = true
            startDashboardUpdateTimer()
        } else if !shouldShowDashboard && isDashboardVisible {
            performanceDashboard?.hide()
            isDashboardVisible = false
            stopDashboardUpdateTimer()
        }
    }
    
    private func updateStatusLabel() {
        var statusText = ""
        
        if stimulusController?.isActive == true {
            if let trialInfo = stimulusController?.currentTrialInfo {
                statusText += "Trial \(trialInfo.index)/\(trialInfo.total) - "
                statusText += "State: \(stimulusController?.state.displayName ?? "Unknown") - "
                statusText += "Coherence: \(String(format: "%.2f", trialInfo.coherence))"
            } else {
                statusText += "Running trials..."
            }
        } else {
            statusText += "Ready"
        }
        
        statusLabel.text = statusText
    }
    
    private func startDiagnosticsTimer() {
        diagnosticsTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.updateDiagnostics()
        }
    }
    
    private func startDashboardUpdateTimer() {
        // Update dashboard every 0.1 seconds for smooth real-time updates
        dashboardUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updatePerformanceDashboard()
        }
    }
    
    private func stopDashboardUpdateTimer() {
        dashboardUpdateTimer?.invalidate()
        dashboardUpdateTimer = nil
    }
    
    private func updatePerformanceDashboard() {
        guard let dashboard = performanceDashboard,
              let controller = stimulusController,
              controller.isActive else {
            return
        }
        
        // Get performance statistics
        let (hitRate, meanRT, recentResults) = controller.getPerformanceStats()
        
        // Get completed trials count
        let completedTrials = controller.trialResults.count
        
        // Get current trial progress
        let progress = controller.getCurrentTrialProgress()
        
        // Get response window status
        let (isActive, timeRemaining) = controller.getResponseWindowStatus()
        
        // Get expected click result (what would happen if clicked now)
        let expectedClickResult = controller.getExpectedClickResult()
        
        // Update dashboard on main thread
        DispatchQueue.main.async {
            dashboard.updateStats(
                hitRate: hitRate,
                meanRT: meanRT,
                completedTrials: completedTrials,
                recentResults: recentResults,
                currentTrialProgress: progress,
                responseWindowActive: isActive,
                responseWindowTimeRemaining: timeRemaining,
                currentClickResult: expectedClickResult
            )
        }
    }
    
    private func updateDiagnostics() {
        let geometry = VisualGeometry.shared.getDiagnosticInfo()
        
        var text = ""
        
        // Current trial status
        if let trialInfo = stimulusController?.currentTrialInfo, stimulusController?.isActive == true {
            text += "\n📊 Progress: Trial \(trialInfo.index)/\(trialInfo.total)"
            if let totalResults = stimulusController?.trialResults.count, totalResults > 0 {
                text += " (\(totalResults) completed)"
            }
            text += "\n"
            
            // Update trial number label at bottom of screen
            // Always show "/300" as the goal, but continue counting beyond 300
            trialNumberLabel.text = "Trial \(trialInfo.index)/300"
        } else {
            // Hide trial number when not running
            trialNumberLabel.text = ""
        }
        
        // Performance warning
        let gridFitsInArea = geometry["gridFitsInArea"] as? Bool ?? true
        if !gridFitsInArea {
            text += "\n⚠️ Grid exceeds screen area!"
        }
        
        diagnosticsLabel.text = text
        updateStatusLabel()
    }
    
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Psychometric Curve Display
    
    func showPsychometricCurve(results: [TrialResult]) {
        // Calculate performance by contrast level
        var contrastPerformance: [Double: (total: Int, correct: Int)] = [:]
        
        for result in results {
            let contrast = result.config.gratingContrast
            if contrastPerformance[contrast] == nil {
                contrastPerformance[contrast] = (total: 0, correct: 0)
            }
            
            var stats = contrastPerformance[contrast]!
            stats.total += 1
            
            // Count as correct if there was a hit (response within the valid response window)
            // This means: stimulus was present (contrast > 0) AND response was a "hit"
            // The response window accounts for rtWindowDelay and rtWindowLength
            if contrast > 0 && result.response?.lowercased() == "hit" {
                stats.correct += 1
            }
            
            contrastPerformance[contrast] = stats
        }
        
        // Remove existing plot if any
        psychometricPlotView?.removeFromSuperview()
        psychometricPlotContainer?.removeFromSuperview()
        
        // Create container view
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Create plot view
        let plotView = PsychometricPlotView()
        plotView.backgroundColor = UIColor.clear
        plotView.translatesAutoresizingMaskIntoConstraints = false
        plotView.setData(contrastPerformance)
        
        // Close button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        closeButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        closeButton.layer.cornerRadius = 20
        closeButton.addTarget(self, action: #selector(closePsychometricPlot), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = "Psychometric Curve"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(plotView)
        container.addSubview(closeButton)
        view.addSubview(container)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            container.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            
            plotView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            plotView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            plotView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            plotView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            
            closeButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        psychometricPlotView = plotView
        psychometricPlotContainer = container
        
        // Animate in
        container.alpha = 0
        container.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
            container.transform = .identity
        }
    }
    
    @objc func closePsychometricPlot() {
        guard let container = psychometricPlotContainer else { return }
        
        UIView.animate(withDuration: 0.3, animations: {
            container.alpha = 0
            container.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            container.removeFromSuperview()
            self.psychometricPlotView?.removeFromSuperview()
            self.psychometricPlotView = nil
            self.psychometricPlotContainer = nil
        }
    }
    
    // MARK: - Coherence Display
    
    func updateCoherenceDisplay(coherence: Double) {
        // Only show coherence display in test mode
        guard trialSettings.testingMode else {
            coherenceDisplayLabel.isHidden = true
            return
        }
        
        coherenceDisplayLabel.text = String(format: "Coherence: %.2f", coherence)
        coherenceDisplayLabel.isHidden = false
    }
    
    func hideCoherenceDisplay() {
        coherenceDisplayLabel.isHidden = true
    }
    
    // MARK: - Quadrant Arrow Cue
    
    private func setupQuadrantArrow() {
        // Arrow will be created dynamically when needed
        // No need to create it here, just initialize the property
    }
    
    private func setupPerformanceDashboard() {
        let dashboard = PerformanceDashboardView()
        dashboard.translatesAutoresizingMaskIntoConstraints = false
        dashboard.isHidden = true
        view.addSubview(dashboard)
        
        // Position at top-left (above control panel)
        NSLayoutConstraint.activate([
            dashboard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            dashboard.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            dashboard.widthAnchor.constraint(equalToConstant: 320),
            dashboard.heightAnchor.constraint(equalToConstant: 300)
        ])
        
        performanceDashboard = dashboard
    }
    
    func showQuadrantArrow(quadrant: Quadrant) {
        // Remove existing outline if any
        hideQuadrantArrow()
        
        // Get grid bounds from flicker grid view
        guard let flickerGrid = flickerGridView else { 
            print("⚠️ Cannot show cue: flickerGridView is nil")
            return 
        }
        let gridBounds = flickerGrid.getGridBounds()
        let gridOrigin = gridBounds.origin
        let gridWidth = gridBounds.width
        let gridHeight = gridBounds.height
        
        // Each quadrant is half the width and half the height
        let quadrantWidth = gridWidth / 2
        let quadrantHeight = gridHeight / 2
        
        // Calculate quadrant position based on which quadrant
        // IMPORTANT: These coordinates must match the stimulus position calculation in gaborCenters()
        // Stimulus centers are at: centerX ± cols/4, centerY ± rows/4
        // For a grid divided into 4 quadrants, the boundaries are at gridWidth/2 and gridHeight/2
        var quadrantRect: CGRect
        switch quadrant {
        case .topLeft:
            // Top-left quadrant: left half, top half
            quadrantRect = CGRect(
                x: gridOrigin.x,
                y: gridOrigin.y,
                width: quadrantWidth,
                height: quadrantHeight
            )
        case .topRight:
            // Top-right quadrant: right half, top half
            quadrantRect = CGRect(
                x: gridOrigin.x + quadrantWidth,
                y: gridOrigin.y,
                width: quadrantWidth,
                height: quadrantHeight
            )
        case .bottomLeft:
            // Bottom-left quadrant: left half, bottom half
            quadrantRect = CGRect(
                x: gridOrigin.x,
                y: gridOrigin.y + quadrantHeight,
                width: quadrantWidth,
                height: quadrantHeight
            )
        case .bottomRight:
            // Bottom-right quadrant: right half, bottom half
            quadrantRect = CGRect(
                x: gridOrigin.x + quadrantWidth,
                y: gridOrigin.y + quadrantHeight,
                width: quadrantWidth,
                height: quadrantHeight
            )
        }
        
        // Verify stimulus position matches cue position
        // Calculate where stimulus should actually appear (in screen coordinates)
        let gaborCenters = StimulusParams.gaborCenters(quadrant: quadrant)
        // Calculate tile size from grid dimensions
        let tilePx = gridWidth / CGFloat(StimulusParams.cols)
        let stimulusCenterCol = gaborCenters[1].x  // Use center column
        let stimulusCenterRow = gaborCenters[1].y  // Use center row
        let stimulusScreenX = gridOrigin.x + CGFloat(stimulusCenterCol) * tilePx
        let stimulusScreenY = gridOrigin.y + CGFloat(stimulusCenterRow) * tilePx
        
        // Verify stimulus is within the cue rectangle
        let stimulusInCue = quadrantRect.contains(CGPoint(x: stimulusScreenX, y: stimulusScreenY))
        
        print("🎯 Cue Debug:")
        print("   Quadrant: \(quadrant.displayName)")
        print("   Cue rect: (\(Int(quadrantRect.origin.x)), \(Int(quadrantRect.origin.y))) size=(\(Int(quadrantRect.width))×\(Int(quadrantRect.height)))")
        print("   Stimulus center (col,row): (\(stimulusCenterCol), \(stimulusCenterRow))")
        print("   Stimulus screen pos: (\(Int(stimulusScreenX)), \(Int(stimulusScreenY)))")
        print("   Stimulus in cue rect: \(stimulusInCue ? "✓" : "✗ MISMATCH!")")
        
        if !stimulusInCue {
            print("   ⚠️ WARNING: Stimulus position does not match cue quadrant!")
            print("   This suggests a coordinate system mismatch.")
        }
        
        // Create outline view
        let outlineView = UIView()
        outlineView.backgroundColor = UIColor.clear
        outlineView.frame = quadrantRect
        
        // Create outline border using CAShapeLayer
        let outlineLayer = CAShapeLayer()
        let outlinePath = UIBezierPath(rect: CGRect(x: 0, y: 0, width: quadrantRect.width, height: quadrantRect.height))
        
        outlineLayer.path = outlinePath.cgPath
        outlineLayer.fillColor = UIColor.clear.cgColor
        outlineLayer.strokeColor = UIColor.white.cgColor
        outlineLayer.lineWidth = 5
        outlineLayer.lineDashPattern = nil  // Solid line
        outlineLayer.lineCap = .round
        outlineLayer.lineJoin = .round
        
        outlineView.layer.addSublayer(outlineLayer)
        
        // Add shadow for better visibility
        outlineView.layer.shadowColor = UIColor.black.cgColor
        outlineView.layer.shadowOffset = CGSize(width: 2, height: 2)
        outlineView.layer.shadowRadius = 4
        outlineView.layer.shadowOpacity = 0.5
        
        // Add to view
        view.addSubview(outlineView)
        
        // Store reference
        quadrantArrowView = outlineView
        
        // Animate in
        outlineView.alpha = 0
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            outlineView.alpha = 1.0
        })
    }
    
    func hideQuadrantArrow() {
        guard let arrowView = quadrantArrowView else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            arrowView.alpha = 0
            arrowView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }) { _ in
            arrowView.removeFromSuperview()
            self.quadrantArrowView = nil
        }
    }
    
    // MARK: - MFMailComposeViewControllerDelegate
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Handle any errors
        if let error = error {
            controller.dismiss(animated: true) {
                self.showAlert(title: "Email Error", message: "Failed to send email: \(error.localizedDescription)")
            }
            return
        }
        
        // Show feedback based on result
        controller.dismiss(animated: true) {
            switch result {
            case .sent:
                self.showAlert(title: "Email Sent", message: "Data has been sent successfully.")
            case .saved:
                self.showAlert(title: "Email Saved", message: "Email has been saved to drafts.")
            case .cancelled:
                // No feedback needed for cancellation
                break
            case .failed:
                self.showAlert(title: "Email Failed", message: "Failed to send email.")
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Trial Info View
/// View to display and edit trial set information before trials begin
class TrialInfoView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let experimentTextField = UITextField()
    private let experimentLabel = UILabel()
    private let playerTextField = UITextField()
    private let playerLabel = UILabel()
    private let usernameTextField = UITextField()
    private let usernameLabel = UILabel()
    private let continueButton = UIButton(type: .system)
    
    var onContinue: ((String, String, String) -> Void)?  // Now passes edited values
    
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
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        // Container view
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.3
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Title label
        titleLabel.text = "Trial Set Information"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Experiment label and text field
        experimentLabel.text = "Experiment Name:"
        experimentLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        experimentLabel.textAlignment = .left
        experimentLabel.textColor = .label
        experimentLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(experimentLabel)
        
        experimentTextField.backgroundColor = UIColor.systemGray6
        experimentTextField.textColor = .label
        experimentTextField.font = UIFont.systemFont(ofSize: 16)
        experimentTextField.borderStyle = .roundedRect
        experimentTextField.layer.cornerRadius = 6
        experimentTextField.keyboardType = .default
        experimentTextField.returnKeyType = .next
        experimentTextField.autocapitalizationType = .none
        experimentTextField.autocorrectionType = .no
        experimentTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(experimentTextField)
        
        // Player label and text field
        playerLabel.text = "Player Name:"
        playerLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        playerLabel.textAlignment = .left
        playerLabel.textColor = .label
        playerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(playerLabel)
        
        playerTextField.backgroundColor = UIColor.systemGray6
        playerTextField.textColor = .label
        playerTextField.font = UIFont.systemFont(ofSize: 16)
        playerTextField.borderStyle = .roundedRect
        playerTextField.layer.cornerRadius = 6
        playerTextField.keyboardType = .default
        playerTextField.returnKeyType = .next
        playerTextField.autocapitalizationType = .none
        playerTextField.autocorrectionType = .no
        playerTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(playerTextField)
        
        // Username label and text field
        usernameLabel.text = "Username:"
        usernameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        usernameLabel.textAlignment = .left
        usernameLabel.textColor = .label
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(usernameLabel)
        
        usernameTextField.backgroundColor = UIColor.systemGray6
        usernameTextField.textColor = .label
        usernameTextField.font = UIFont.systemFont(ofSize: 16)
        usernameTextField.borderStyle = .roundedRect
        usernameTextField.layer.cornerRadius = 6
        usernameTextField.keyboardType = .default
        usernameTextField.returnKeyType = .done
        usernameTextField.autocapitalizationType = .none
        usernameTextField.autocorrectionType = .no
        usernameTextField.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(usernameTextField)
        
        // Set up text field navigation
        experimentTextField.addTarget(self, action: #selector(experimentFieldReturn), for: .editingDidEndOnExit)
        playerTextField.addTarget(self, action: #selector(playerFieldReturn), for: .editingDidEndOnExit)
        usernameTextField.addTarget(self, action: #selector(usernameFieldReturn), for: .editingDidEndOnExit)
        
        // Continue button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        continueButton.backgroundColor = .systemBlue
        continueButton.setTitleColor(.white, for: .normal)
        continueButton.layer.cornerRadius = 8
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        containerView.addSubview(continueButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Container view - centered
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 400),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Experiment label
            experimentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            experimentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            experimentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Experiment text field
            experimentTextField.topAnchor.constraint(equalTo: experimentLabel.bottomAnchor, constant: 8),
            experimentTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            experimentTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            experimentTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Player label
            playerLabel.topAnchor.constraint(equalTo: experimentTextField.bottomAnchor, constant: 16),
            playerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            playerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Player text field
            playerTextField.topAnchor.constraint(equalTo: playerLabel.bottomAnchor, constant: 8),
            playerTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            playerTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            playerTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Username label
            usernameLabel.topAnchor.constraint(equalTo: playerTextField.bottomAnchor, constant: 16),
            usernameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            usernameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Username text field
            usernameTextField.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 8),
            usernameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            usernameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            usernameTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 24),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 44),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(experimentName: String, playerName: String, username: String) {
        experimentTextField.text = experimentName
        playerTextField.text = playerName
        usernameTextField.text = username
    }
    
    // MARK: - Actions
    
    @objc private func experimentFieldReturn() {
        playerTextField.becomeFirstResponder()
    }
    
    @objc private func playerFieldReturn() {
        usernameTextField.becomeFirstResponder()
    }
    
    @objc private func usernameFieldReturn() {
        usernameTextField.resignFirstResponder()
        continueButtonTapped()
    }
    
    @objc private func continueButtonTapped() {
        // Get values from text fields
        let experimentName = experimentTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let playerName = playerTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let username = usernameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Pass edited values to continuation handler
        onContinue?(experimentName, playerName, username)
    }
    
    // MARK: - Presentation
    
    /// Show the view with animation
    func show(in superview: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        superview.addSubview(self)
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            leadingAnchor.constraint(equalTo: superview.leadingAnchor),
            trailingAnchor.constraint(equalTo: superview.trailingAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor)
        ])
        
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        } completion: { _ in
            // Auto-focus the first text field after animation completes
            self.experimentTextField.becomeFirstResponder()
        }
    }
    
    /// Hide the view with animation
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Help Popover View
class HelpPopoverView: UIView {
    private let textLabel = UILabel()
    private let arrowLayer = CAShapeLayer()
    
    init(text: String) {
        super.init(frame: .zero)
        setupView(text: text)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView(text: String) {
        backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        textLabel.text = text
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: 13)
        textLabel.numberOfLines = 0
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    func show(below sourceView: UIView, in containerView: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(self)
        
        // Position below the source view
        let sourceFrame = sourceView.convert(sourceView.bounds, to: containerView)
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: containerView.topAnchor, constant: sourceFrame.maxY + 8),
            leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 16),
            trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            centerXAnchor.constraint(equalTo: containerView.leadingAnchor, constant: sourceFrame.midX)
        ])
        
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
        }
    }
    
    func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.15, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
}

