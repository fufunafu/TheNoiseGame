import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var mainViewController: UIViewController?
    private var loadingProgressTimer: Timer?
    private var loadingProgress: Float = 0.0

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Create window
        window = UIWindow(windowScene: windowScene)
        
        // Show launch screen with loading bar first
        showLaunchScreen()
        
        // Prepare main view controller in background
        prepareMainViewController()
        
        // Listen for loading completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(launchScreenDidFinishLoading),
            name: NSNotification.Name("LaunchViewControllerDidFinishLoading"),
            object: nil
        )
        
        window?.makeKeyAndVisible()
        print("✅ Window made key and visible")
    }
    
    private func showLaunchScreen() {
        // Create loading screen with progress bar
        createFallbackLoadingScreen()
    }
    
    private func createFallbackLoadingScreen() {
        let loadingVC = UIViewController()
        loadingVC.view.backgroundColor = .white
        
        // Create progress bar
        let progressBar = UIProgressView(progressViewStyle: .bar)
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = UIColor.lightGray.withAlphaComponent(0.3)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progress = 0.0
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        loadingVC.view.addSubview(progressBar)
        
        // Create loading label
        let loadingLabel = UILabel()
        loadingLabel.text = "Loading..."
        loadingLabel.font = UIFont.systemFont(ofSize: 28, weight: .semibold)
        loadingLabel.textColor = .darkGray
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingVC.view.addSubview(loadingLabel)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            progressBar.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            progressBar.centerYAnchor.constraint(equalTo: loadingVC.view.centerYAnchor, constant: 20),
            progressBar.leadingAnchor.constraint(equalTo: loadingVC.view.leadingAnchor, constant: 80),
            progressBar.trailingAnchor.constraint(equalTo: loadingVC.view.trailingAnchor, constant: -80),
            progressBar.heightAnchor.constraint(equalToConstant: 6),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingVC.view.centerXAnchor),
            loadingLabel.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -30),
        ])
        
        // Animate progress bar
        loadingProgress = 0.0
        loadingProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.loadingProgress += 0.02
            if self.loadingProgress < 0.9 {
                self.loadingProgress += Float.random(in: 0...0.01)
            }
            
            if self.loadingProgress >= 1.0 {
                self.loadingProgress = 1.0
                timer.invalidate()
                self.loadingProgressTimer = nil
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.launchScreenDidFinishLoading()
                }
            }
            
            DispatchQueue.main.async {
                progressBar.setProgress(self.loadingProgress, animated: true)
            }
        }
        
        window?.rootViewController = loadingVC
    }
    
    private func prepareMainViewController() {
        // Create ViewController programmatically using Objective-C runtime
        // This bypasses storyboard issues and ensures we get the correct class
        print("Creating ViewController programmatically...")
        
        if let viewControllerClass = NSClassFromString("TheNoiseGame.ViewController") as? UIViewController.Type {
            let viewController = viewControllerClass.init()
            print("✅ Created ViewController programmatically")
            mainViewController = viewController
        } else {
            print("❌ ERROR: Could not find ViewController class")
            print("   Attempted class name: TheNoiseGame.ViewController")
            
            // Fallback: Create a test view controller to see if window works
            let fallbackVC = UIViewController()
            fallbackVC.view.backgroundColor = .systemBlue
            let label = UILabel()
            label.text = "ViewController class not found!\nCheck if ViewControllers/ViewController.swift\nis included in the build target."
            label.textColor = .white
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            fallbackVC.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: fallbackVC.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: fallbackVC.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: fallbackVC.view.leadingAnchor, constant: 40),
                label.trailingAnchor.constraint(equalTo: fallbackVC.view.trailingAnchor, constant: -40)
            ])
            mainViewController = fallbackVC
        }
    }
    
    @objc private func launchScreenDidFinishLoading() {
        // Transition to main view controller
        guard let mainVC = mainViewController else {
            print("❌ ERROR: Main view controller not prepared")
            return
        }
        
        UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.window?.rootViewController = mainVC
        }, completion: { _ in
            print("✅ Transitioned to main ViewController")
        })
        
        // Remove observer
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("LaunchViewControllerDidFinishLoading"), object: nil)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
