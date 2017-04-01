//
//  S1AppDelegate.swift
//  Stage1st
//
//  Created by Zheng Li on 4/4/16.
//  Copyright © 2016 Renaissance. All rights reserved.
//

import Foundation
import CocoaLumberjack
import CloudKit

// swiftlint:disable type_name
struct Constants {
    struct defaults {
        static let displayImageKey = "Display"
        static let showsReplyIncrementKey = "ReplyIncrement"
        static let removeTailsKey = "RemoveTails"
        static let precacheNextPageKey = "PrecacheNextPage"
        static let forcePortraitForPhoneKey = "ForcePortraitForPhone"
        static let nightModeKey = "NightMode"
        static let enableCloudKitSyncKey = "EnableSync"

        static let reverseActionKey = "Stage1st.Content.ReverseFloorAction"
        static let hideStickTopicsKey = "Stage1st.TopicList.HideStickTopics"

        static let historyLimitKey = "HistoryLimit"
        static let previousWebKitCacheCleaningDateKey = "PreviousWebKitCacheCleaningDate"
    }
}

// swiftlint:enable type_name

// MARK: Logging
extension S1AppDelegate {

    func setLogLevelForSwift() {
        #if DEBUG
            defaultDebugLevel = .verbose
        #else
            defaultDebugLevel = .info
        #endif
    }
}

// MARK: Migration
extension S1AppDelegate {

    func migrate() {
        migrateTo3800()
        migrateTo3900()
        migrateTo3940()
    }

    func migrateTo3800() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            DDLogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("真碉堡山") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["真碉堡山"]], forKey: "Order")
        }
    }

    func migrateTo3900() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            DDLogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("DOTA") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["DOTA", "欧美动漫"]], forKey: "Order")
        }
    }

    func migrateTo3940() {
        guard
            let orderForumArray = UserDefaults.standard.object(forKey: "Order") as? [[String]],
            orderForumArray.count == 2 else {
            DDLogError("[Migration] Order list in user defaults expected to have 2 array of forum name string but not as expected.")
            return
        }
        let displayForumArray = orderForumArray[0]
        let hiddenForumArray = orderForumArray[1]
        if !(displayForumArray + hiddenForumArray).contains("泥潭") {
            UserDefaults.standard.set([displayForumArray, hiddenForumArray + ["泥潭"]], forKey: "Order")
        }
    }
}

// MARK: Setup
extension S1AppDelegate {
    func setup() {
        // NSCoding Mapping
        NSKeyedUnarchiver.setClass(Floor.self, forClassName: "S1Floor")

        // UserDefaults
        let userDefaults = UserDefaults.standard

        if userDefaults.value(forKey: "Order") == nil {
            let path = Bundle.main.path(forResource: "InitialOrder", ofType: "plist")!
            let orderArray = NSArray(contentsOfFile: path)
            userDefaults.set(orderArray, forKey: "Order")
        }

        if UI_USER_INTERFACE_IDIOM() == .pad {
            userDefaults.s1_setObjectIfNotExist(object: "18px", key: "FontSize")
        } else {
            userDefaults.s1_setObjectIfNotExist(object: "17px", key: "FontSize")
        }

        // TODO: Use register domain.
        userDefaults.s1_setObjectIfNotExist(object: NSNumber(value: -1), key: "HistoryLimit")
        UserDefaults.standard.register(defaults: [
            Constants.defaults.displayImageKey: true,
            Constants.defaults.showsReplyIncrementKey: true,
            Constants.defaults.removeTailsKey: true,
            Constants.defaults.precacheNextPageKey: true,
            Constants.defaults.forcePortraitForPhoneKey: true,
            Constants.defaults.nightModeKey: false,
            Constants.defaults.enableCloudKitSyncKey: false,

            Constants.defaults.reverseActionKey: false,
            Constants.defaults.hideStickTopicsKey: true,
        ])

        updateStage1stDomainIfNecessary()
    }

    func updateStage1stDomainIfNecessary() {
        let publicDatabase = CKContainer.default().publicCloudDatabase
        let stage1stDomainRecordName = "cf531e8f-eb25-4931-ba11-73f8cd344d28"
        let stage1stDomainRecordID = CKRecordID(recordName: stage1stDomainRecordName)
        let fetchRecordOperation = CKFetchRecordsOperation(recordIDs: [stage1stDomainRecordID])

        fetchRecordOperation.fetchRecordsCompletionBlock = { recordsDictionary, error in
            guard let stage1stDomainRecord = recordsDictionary?[stage1stDomainRecordID] else {
                DDLogError("fetchedRecords: \(String(describing: recordsDictionary)) error: \(String(describing: error))")
                return
            }

            let modificationDate = stage1stDomainRecord.modificationDate ?? Date.distantPast
            guard let mainURL = stage1stDomainRecord["mainURL"] as? String else {
                DDLogError("No mainURL in \(stage1stDomainRecord)")
                return
            }

            let serverAddress: ServerAddress

            if let usedURLs = stage1stDomainRecord["usedURLs"] as? [String] {
                serverAddress = ServerAddress(main: mainURL, used: usedURLs, lastUpdateDate: modificationDate)
            } else {
                serverAddress = ServerAddress(main: mainURL, used: [], lastUpdateDate: modificationDate)
            }

            DDLogInfo("Updated \(serverAddress) modificationDate: \(modificationDate)")

            if let persistedServerAddress = AppEnvironment.current.cacheDatabaseManager.serverAddress(), modificationDate.timeIntervalSince(persistedServerAddress.lastUpdateDate) <= 0.0 {
                DDLogInfo("Server address do not need to update.")
                return
            }

            AppEnvironment.current.cacheDatabaseManager.set(serverAddress: serverAddress)
            AppEnvironment.current = Environment()

            DispatchQueue.main.async {
                MessageHUD.shared.post(message: "论坛地址已更新，请重新启动应用。", duration: .second(2.0))
            }
        }

        publicDatabase.add(fetchRecordOperation)
    }
}

extension S1AppDelegate {
    func notifyCleaning() {
        AppEnvironment.current.dataCenter.cleaning()
    }
}

fileprivate extension UserDefaults {
    func s1_setObjectIfNotExist(object: Any, key: String) {
        if value(forKey: key) == nil {
            `set`(object, forKey: key)
        }
    }
}
