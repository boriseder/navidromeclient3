//
//  CoverArtManager+ScenePhase.swift
//  NavidromeClient
//
//  Detects app backgrounding and triggers cache check on activation
//

import SwiftUI

extension CoverArtManager {
    
    func setupScenePhaseObserver() {
        // Will resign active (backgrounding)
        let resignObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AppLogger.cache.debug("[CoverArtManager] App will resign active")
                // Could save state here if needed
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
        
        // CRITICAL: Store observers for cleanup
        sceneObservers.append(resignObserver)
        sceneObservers.append(activeObserver)
    }
    
    func handleAppActivation() async {
        AppLogger.cache.info("[CoverArtManager] App became active - refreshing cache state")
        
        // Single action: Increment generation to trigger view reloads
        // Views will check disk cache automatically via loadCoverArt()
        incrementCacheGeneration()
        
        AppLogger.cache.info("[CoverArtManager] Cache generation incremented - views will reload")
    }
    
    func cleanupObservers() {
        sceneObservers.forEach { observer in
            NotificationCenter.default.removeObserver(observer)
        }
        sceneObservers.removeAll()
        AppLogger.cache.debug("[CoverArtManager] Scene observers cleaned up")
    }
}
