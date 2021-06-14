/**
 *  https://github.com/tadija/AEConsole
 *  Copyright © 2016-2020 Marko Tadić
 *  Licensed under the MIT license
 */

import UIKit
import AELog

/// Facade for displaying debug log in Console UI overlay on top of your app.
open class Console: LogDelegate {
    
    // MARK: - Properties

    /// Singleton
    public static let shared = Console()

    /// Console Settings
    public var settings: Settings {
        return brain.settings
    }
    
    private var isAppActive = false

    internal let brain = Brain(with: Settings())
    private weak var window: UIWindow?
    
    // MARK: - API

    /// Enable Console UI by calling this method in AppDelegate's `didFinishLaunchingWithOptions:`
    ///
    /// - Parameter window: Main window for the app (AppDelegate's window).
    open func configure(in window: UIWindow?) {
        Log.shared.delegate = self
        self.window = window
        self.brain.configureConsole(in: window)
        if isAppActive {
            activateConsoleUI()
        }
    }
    
    /// Current state of Console UI visibility
    open var isHidden: Bool {
        return !(brain.console?.isOnScreen == true)
    }
    
    /// Toggle Console UI
    open func toggle() {
        if let view = brain.console {
            if !view.isOnScreen {
                activateConsoleUI()
            }
            view.toggleUI()
        }
    }

    /// Add any log line manually (lines from AELog will automatically be added)
    open func addLogLine(line: CustomStringConvertible) {
        DispatchQueue.main.async { [weak self] in
            self?.brain.addLogLine(line)
        }
    }

    /// Export all log lines to AELog_{timestamp}.txt file inside of App Documents directory.
    open func exportLogFile(completion: @escaping (() throws -> URL) -> Void) {
        brain.exportLogFile(completion: completion)
    }
    
    // MARK: - Init
    
    fileprivate init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(activateConsoleUI),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    fileprivate func activateConsoleUI() {
        isAppActive = true
        if let window = window, let console = brain.console {
            window.bringSubviewToFront(console)
            if settings.isShakeGestureEnabled {
                console.becomeFirstResponder()
            }
        }
    }

    // MARK: - LogDelegate

    open func didLog(line: Line, mode: Log.Mode) {
        addLogLine(line: line)
    }
    
}
