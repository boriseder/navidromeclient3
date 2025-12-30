//
//  CoverArtManager+ScenePhase.swift
//  NavidromeClient
//
//  UPDATED: Swift 6 Concurrency Compliance
//  - Safe Observer Handling
//

import SwiftUI

extension CoverArtManager {
    
    func setupScenePhaseObserver() {
        // Will resign active (backgrounding)
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppLogger.cache.debug("[CoverArtManager] App will resign active")
            }
        }
        
        // Did become active (foregrounding)
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleAppActivation()
            }
        }
        
        // Store observers
        sceneObservers.append(resignObserver)
        sceneObservers.append(activeObserver)
    }
    
    func handleAppActivation() async {
        AppLogger.cache.info("[CoverArtManager] App became active - refreshing cache state")
        incrementCacheGeneration()
    }
    
    func cleanupObservers() {
        sceneObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        sceneObservers.removeAll()
        AppLogger.cache.debug("[CoverArtManager] Scene observers cleaned up")
    }
}
