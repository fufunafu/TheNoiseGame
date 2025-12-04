import UIKit

/// View to display trial set information before trials begin
class TrialInfoView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let experimentLabel = UILabel()
    private let playerLabel = UILabel()
    private let usernameLabel = UILabel()
    private let continueButton = UIButton(type: .system)
    
    var onContinue: (() -> Void)?
    
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
        
        // Experiment label
        experimentLabel.font = UIFont.systemFont(ofSize: 18)
        experimentLabel.textAlignment = .left
        experimentLabel.textColor = .label
        experimentLabel.numberOfLines = 0
        experimentLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(experimentLabel)
        
        // Player label
        playerLabel.font = UIFont.systemFont(ofSize: 18)
        playerLabel.textAlignment = .left
        playerLabel.textColor = .label
        playerLabel.numberOfLines = 0
        playerLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(playerLabel)
        
        // Username label
        usernameLabel.font = UIFont.systemFont(ofSize: 18)
        usernameLabel.textAlignment = .left
        usernameLabel.textColor = .label
        usernameLabel.numberOfLines = 0
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(usernameLabel)
        
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
            containerView.widthAnchor.constraint(equalToConstant: 350),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Experiment label
            experimentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            experimentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            experimentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Player label
            playerLabel.topAnchor.constraint(equalTo: experimentLabel.bottomAnchor, constant: 16),
            playerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            playerLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Username label
            usernameLabel.topAnchor.constraint(equalTo: playerLabel.bottomAnchor, constant: 16),
            usernameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            usernameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 24),
            continueButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 44),
            continueButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(experimentName: String, playerName: String, username: String) {
        experimentLabel.text = "Experiment: \(experimentName.isEmpty ? "Not set" : experimentName)"
        playerLabel.text = "Player: \(playerName.isEmpty ? "Not set" : playerName)"
        usernameLabel.text = "Username: \(username.isEmpty ? "Not set" : username)"
    }
    
    // MARK: - Actions
    
    @objc private func continueButtonTapped() {
        onContinue?()
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

