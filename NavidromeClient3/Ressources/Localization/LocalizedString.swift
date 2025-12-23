//
//  LocalizedString.swift
//  NavidromeClient
//
//  Type-safe localized string access
//  All user-facing strings are defined here and resolved at runtime
//

import Foundation

enum LocalizedString {
    
    // MARK: - Navigation & Tabs
    
    case tabExplore
    case tabAlbums
    case tabArtists
    case tabGenres
    case tabFavorites
    
    // MARK: - Common Actions
    
    case actionRefresh
    case actionSave
    case actionCancel
    case actionOK
    case actionRetry
    case actionContinue
    case actionDelete
    case actionClear
    case actionEdit
    case actionClose
    case actionGetStarted
    case actionPlayAll
    case actionShuffleAll
    case actionTryAgain
    case actionGoOnline
    case actionConfigureServer
    case actionOpenSettings
    
    // MARK: - Settings
    
    case settingsTitle
    case settingsInitialSetup
    case settingsGeneral
    case settingsAppearance
    case settingsServer
    case settingsCache
    case settingsDebug
    case settingsDangerZone
    
    case settingTheme
    case settingAccentColor
    case settingSelectTheme
    
    case settingServerURL
    case settingUsername
    case settingPassword
    case settingPort
    case settingHost
    case settingProtocol
    
    case settingStatus
    case settingNetworkStatus
    case settingConnectionQuality
    case settingResponseTime
    case settingServerHealth
    
    case settingConnected
    case settingDisconnected
    
    case settingCoverArtCache
    case settingDownloadCache
    case settingMemoryCache
    case settingActiveRequests
    case settingCachedImages
    case settingCacheSize
    case settingUsage
    case settingDownloadedMusic
    
    // MARK: - Server Setup
    
    case serverSetupTitle
    case serverEditTitle
    case serverConnection
    case serverTestConnection
    case serverSaveAndContinue
    case serverConfigSuccess
    case serverConfigError
    case serverInitializingServices
    
    case serverFooterText
    case serverOnlineWarningTitle
    case serverOnlineWarningMessage
    case serverSwitchToOnline
    
    case serverResponseTime
    case serverConnectionQuality
    case serverConnectionDetails
    
    // MARK: - Welcome
    
    case welcomeTitle
    case welcomeMessage
    
    // MARK: - Albums
    
    case albumsTitle
    case albumsSortAlphabetical
    case albumsSortRecent
    case albumsSortFrequent
    case albumsSortRandom
    case albumsAllAlbums
    case albumsDownloadedOnly
    case albumsFilter
    
    case albumSongs
    case albumDuration
    case albumYear
    case albumGenre
    
    // MARK: - Artists
    
    case artistsTitle
    case artistAlbums
    
    // MARK: - Genres
    
    case genresTitle
    
    // MARK: - Favorites
    
    case favoritesTitle
    case favoritesYourFavorites
    case favoritesClearAll
    case favoritesClearConfirmTitle
    case favoritesClearConfirmMessage
    case favoritesStats
    
    // MARK: - Explore
    
    case exploreTitle
    case exploreRecentlyPlayed
    case exploreNewlyAdded
    case exploreOftenPlayed
    case exploreRandom
    case exploreDownloadedAlbums
    case exploreRefreshRandom
    
    // MARK: - Player
    
    case playerNowPlaying
    case playerQueue
    case playerShuffle
    case playerRepeat
    case playerRepeatOff
    case playerRepeatAll
    case playerRepeatOne
    
    // MARK: - Search
    
    case searchPlaceholder
    case searchAlbums
    case searchArtists
    case searchSongs
    case searchFavorites
    
    // MARK: - Downloads
    
    case downloadButton
    case downloadAll
    case downloadDelete
    case downloadDeleteAll
    case downloadedAlbums
    
    // MARK: - Offline Mode
    
    case offlineModeActive
    case offlineNoConnection
    case offlineUsingDownloadedContent
    case offlineLimitedConnectivity
    
    case offlineReasonNoNetwork
    case offlineReasonPoorConnection
    case offlineReasonUserChoice
    case offlineReasonServerUnreachable
    
    // MARK: - Loading States
    
    case loadingMusic
    case loadingAlbums
    case loadingArtists
    case loadingGenres
    case loadingFavorites
    case loadingContent
    case loadingLibrary
    
    // MARK: - Empty States
    
    case emptyAlbums
    case emptyArtists
    case emptyGenres
    case emptySongs
    case emptyFavorites
    case emptySearch
    case emptyDownloads
    
    case emptyAlbumsMessage
    case emptyArtistsMessage
    case emptyGenresMessage
    case emptySongsMessage
    case emptyFavoritesMessage
    case emptySearchMessage
    case emptyDownloadsMessage
    
    case emptyAlbumsOffline
    case emptyFavoritesOffline
    
    // MARK: - Error States
    
    case errorNoConnection
    case errorServerError
    case errorUnauthorized
    case errorSetupRequired
    
    case errorNoConnectionMessage
    case errorServerErrorMessage
    case errorUnauthorizedMessage
    case errorSetupRequiredMessage
    
    // MARK: - Cache Management
    
    case cacheManagement
    case cacheCoverArt
    case cacheDownloads
    case cachePerformance
    case cacheClear
    case cacheClearCoverArt
    case cacheClearSuccess
    case cacheClearConfirmTitle
    case cacheClearConfirmMessage
    
    // MARK: - Factory Reset
    
    case factoryResetTitle
    case factoryResetButton
    case factoryResetConfirmTitle
    case factoryResetConfirmMessage
    case factoryResetInProgress
    case factoryResetClearing
    case factoryResetFooter
    
    // MARK: - Debug
    
    case debugCoverArt
    case debugNetwork
    
    // MARK: - Time & Stats
    
    case timeMinutes
    case timeSongs
    case statsSongCount
    case statsTotalDuration
    case statsAverageRating
    
    // MARK: - Misc
    
    case serverInfo
    case serverSettings
    case cacheAndDownloads
    case loginInfo
    case connectionStatus
    case qualityDescription
    
    var key: String {
        String(describing: self)
    }
    
    var localized: String {
        NSLocalizedString(key, bundle: .main, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        String(format: localized, arguments: arguments)
    }
}

extension String {
    static func localized(_ string: LocalizedString) -> String {
        string.localized
    }
    
    static func localized(_ string: LocalizedString, _ arguments: CVarArg...) -> String {
        string.localized(with: arguments)
    }
}
