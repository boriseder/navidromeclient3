//
//  AppStorageActor.swift
//  NavidromeClient
//
//  Created by Boris Eder on 03.05.26.
//


//
//  AppStorageActor.swift
//  NavidromeClient
//
//  Temporary singleton wrapper. Replaced by DI in Step 7.
//

enum AppStorageActor {
    static let shared = StorageActor()
}