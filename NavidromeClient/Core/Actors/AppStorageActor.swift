//
//  AppStorageActor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 03.05.26.
//
//  Temporary singleton wrapper — to be replaced with injected StorageActor
//  once the DI layer is in place.
//

enum AppStorageActor {
    static let shared = StorageActor()
}
