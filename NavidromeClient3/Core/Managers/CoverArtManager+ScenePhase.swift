//
//  CoverArtManager+ScenePhase.swift
//  NavidromeClient3
//
//  Swift 6: Fixed Concurrency in Notification Handler
//

import SwiftUI
import UIKit

extension CoverArtManager {
    
    func setupScenePhaseObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // FIX: The closure is @Sendable (non-isolated).
            // We must explicitly enter a MainActor Task to access 'self' safely.
            Task { @MainActor in
                guard let self = self else { return }
                
                self.incrementCacheGeneration()
                
                AppLogger.cache.debug("CoverArtManager: App entered foreground, cache generation incremented")
            }
        }
        
        sceneObservers.append(observer)
    }
    
    func cleanupObservers() {
        sceneObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        sceneObservers.removeAll()
    }
}
