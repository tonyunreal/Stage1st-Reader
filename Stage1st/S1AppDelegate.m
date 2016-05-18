//
//  S1AppDelegate.m
//  Stage1st
//
//  Created by Suen Gabriel on 2/12/13.
//  Copyright (c) 2013 Renaissance. All rights reserved.
//

#import "S1AppDelegate.h"
#import "S1TopicListViewController.h"
#import "NavigationControllerDelegate.h"
#import "S1ContentViewController.h"
#import "S1URLCache.h"
#import "S1Topic.h"
#import "S1Tracer.h"
#import "S1Parser.h"
#import "S1DataCenter.h"
#import "CloudKitManager.h"
#import "DatabaseManager.h"
#import "CrashlyticsLogger.h"
#import "DDErrorLevelFormatter.h"
#import "S1CacheDatabaseManager.h"
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>



S1AppDelegate *MyAppDelegate;

@implementation S1AppDelegate

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        // Store global reference
        MyAppDelegate = self;
        // Configure logging

#ifdef DEBUG
        id <DDLogger> logger = [DDTTYLogger sharedInstance];
        [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
        [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(194, 99, 107) backgroundColor:nil forFlag:DDLogFlagError];
        [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(211, 142, 118) backgroundColor:nil forFlag:DDLogFlagWarning];
        [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(118, 164, 211) backgroundColor:nil forFlag:DDLogFlagInfo];
        [[DDTTYLogger sharedInstance] setForegroundColor:DDMakeColor(167, 173, 187) backgroundColor:nil forFlag:DDLogFlagVerbose];
#else
        id <DDLogger> logger = [CrashlyticsLogger sharedInstance];
        [logger setLogFormatter:[[DDErrorLevelFormatter alloc] init]];
#endif
        [DDLog addLogger:logger];
    }
    return self;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Crashlytics
    [Fabric with:@[[Crashlytics class]]];

    // Setup User Defaults
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (![userDefaults valueForKey:@"Order"]) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [userDefaults setObject:order forKey:@"Order"];
    }
    if ([userDefaults objectForKey:@"Display"] == nil) {
        [userDefaults setBool:YES forKey:@"Display"];
    }
    if ([userDefaults objectForKey:@"BaseURL"] == nil) {
        [userDefaults setObject:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    if ([userDefaults objectForKey:@"FontSize"] == nil) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [userDefaults setObject:@"18px" forKey:@"FontSize"];
        } else {
            [userDefaults setObject:@"17px" forKey:@"FontSize"];
        }
    }
    if ([userDefaults objectForKey:@"HistoryLimit"] == nil) {
        [userDefaults setObject:@-1 forKey:@"HistoryLimit"];
    }
    if ([userDefaults objectForKey:@"ReplyIncrement"] == nil) {
        [userDefaults setBool:YES forKey:@"ReplyIncrement"];
    }
    if ([userDefaults objectForKey:@"RemoveTails"] == nil) {
        [userDefaults setBool:YES forKey:@"RemoveTails"];
    }
    if ([userDefaults objectForKey:@"UseAPI"] == nil) {
        [userDefaults setBool:YES forKey:@"UseAPI"];
    }
    if ([userDefaults objectForKey:@"PrecacheNextPage"] == nil) {
        [userDefaults setBool:YES forKey:@"PrecacheNextPage"];
    }
    if ([userDefaults objectForKey:@"ForcePortraitForPhone"] == nil) {
        [userDefaults setBool:YES forKey:@"ForcePortraitForPhone"];
    }
    if ([userDefaults objectForKey:@"NightMode"] == nil) {
        [userDefaults setBool:NO forKey:@"NightMode"];
    }
    if ([userDefaults objectForKey:@"EnableSync"] == nil) {
        [userDefaults setBool:NO forKey:@"EnableSync"];
    }

    // Start database & cloudKit (in that order)
    [DatabaseManager initialize];
    if ([userDefaults boolForKey:@"EnableSync"]) {
        [CloudKitManager initialize];
    }

    // Migrate to v3.4
    NSArray *array = [userDefaults valueForKey:@"Order"];
    NSArray *array0 =[array firstObject];
    NSArray *array1 =[array lastObject];
    if([array0 indexOfObject:@"模玩专区"] == NSNotFound && [array1 indexOfObject:@"模玩专区"]== NSNotFound) {
        DDLogDebug(@"Update Order List");
        NSString *path = [[NSBundle mainBundle] pathForResource:@"InitialOrder" ofType:@"plist"];
        NSArray *order = [NSArray arrayWithContentsOfFile:path];
        [userDefaults setObject:order forKey:@"Order"];
        [userDefaults setObject:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
        [userDefaults removeObjectForKey:@"UserID"];
        [userDefaults removeObjectForKey:@"UserPassword"];
    }
    if (![[userDefaults objectForKey:@"BaseURL"] isEqualToString:@"http://bbs.saraba1st.com/2b/"]) {
        [userDefaults setObject:@"http://bbs.saraba1st.com/2b/" forKey:@"BaseURL"];
    }
    
    // Migrate to v3.6
    [S1Tracer upgradeDatabase];
    
    // Migrate to v3.7
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [[userDefaults objectForKey:@"FontSize"] isEqualToString:@"17px"]) {
        [userDefaults setObject:@"18px" forKey:@"FontSize"];
    }
    // Migrate to v3.8
    if([array0 indexOfObject:@"真碉堡山"] == NSNotFound && [array1 indexOfObject:@"真碉堡山"]== NSNotFound) {
        NSArray *order = @[array0, [array1 arrayByAddingObject:@"真碉堡山"]];
        [userDefaults setValue:order forKey:@"Order"];
    }

    [self migrate];
    
    // Preload floor cache database
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [S1CacheDatabaseManager sharedInstance];
    });

    if ([userDefaults boolForKey:@"EnableSync"]) {
        // Register for push notifications
        UIUserNotificationSettings *notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge + UIUserNotificationTypeSound + UIUserNotificationTypeAlert categories:nil];
        [application registerUserNotificationSettings:notificationSettings];
    }

    // Reachability
    _reachability = [Reachability reachabilityForInternetConnection];
    [_reachability startNotifier];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];

    // URL Cache
    S1URLCache *URLCache = [[S1URLCache alloc] initWithMemoryCapacity:10 * 1024 * 1024 diskCapacity:100 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];

    // Appearence
    [[APColorManager sharedInstance] updateGlobalAppearance];

    //[KMCGeigerCounter sharedGeigerCounter].enabled = YES;

    self.window = [[UIWindow alloc] init];
    [self.window makeKeyAndVisible];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithNavigationBarClass:nil toolbarClass:nil];
    self.navigationDelegate = [[NavigationControllerDelegate alloc] initWithNavigationController:navigationController];
    navigationController.delegate = self.navigationDelegate;
    navigationController.viewControllers = @[[[S1TopicListViewController alloc] initWithNibName:nil bundle:nil]];
    navigationController.navigationBarHidden = YES;
    self.window.rootViewController = navigationController;

#ifdef DEBUG
    DDLogVerbose(@"%@", [[NSUserDefaults standardUserDefaults] dictionaryRepresentation]);
#endif

    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[S1DataCenter sharedDataCenter] cleaning];
}

#pragma mark - URL Scheme

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    DDLogDebug(@"[URL Scheme] %@ from %@", url, sourceApplication);
    
    //Open Specific Topic Case
    NSDictionary *queryDict = [S1Parser extractQuerysFromURLString:[url absoluteString]];
    if ([[url host] isEqualToString:@"open"]) {
        NSString *topicIDString = [queryDict valueForKey:@"tid"];
        
        if (topicIDString) {
            NSNumber *topicID = [NSNumber numberWithInteger:[topicIDString integerValue]];
            S1Topic *topic = [[S1DataCenter sharedDataCenter] tracedTopic:topicID];
            if (topic == nil) {
                topic = [[S1Topic alloc] init];
                topic.topicID = topicID;
            }
            [self presentContentViewControllerForTopic:topic];
            return YES;
        }
    }
    
    if ([[url host] isEqualToString:@"settings"]) {
        for (NSString *key in queryDict) {
            if ([key isEqualToString:@"ForcePortraitForPhone"]) {
                NSString *value = [queryDict valueForKey:key];
                if ([value isEqualToString:@"YES"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ForcePortraitForPhone"];
                }
                if ([value isEqualToString:@"NO"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"ForcePortraitForPhone"];
                }
            }
            if ([key isEqualToString:@"EnableSync"]) {
                NSString *value = [queryDict valueForKey:key];
                if ([value isEqualToString:@"YES"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"EnableSync"];
                }
                if ([value isEqualToString:@"NO"]) {
                    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"EnableSync"];
                }
            }
            
        }
    }
    
    return YES;
}

#pragma mark - Push Notification For Sync

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
    DDLogDebug(@"[APS] application:didRegisterUserNotificationSettings: %@", notificationSettings);
    [application registerForRemoteNotifications];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    DDLogDebug(@"[APS] Registered for Push notifications with token: %@", deviceToken);
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    DDLogWarn(@"[APS] Push subscription failed: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler {
    DDLogDebug(@"[APS] Push received: %@", userInfo);
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"EnableSync"]) {
        DDLogDebug(@"[APS] push notification received when user do not enable sync feature.");
        completionHandler(UIBackgroundFetchResultNoData);
        return;
    }

    __block UIBackgroundFetchResult combinedFetchResult = UIBackgroundFetchResultNoData;
    
    [[CloudKitManager sharedInstance] fetchRecordChangesWithCompletionHandler:
        ^(UIBackgroundFetchResult fetchResult, BOOL moreComing) {
        if (fetchResult == UIBackgroundFetchResultNewData) {
            combinedFetchResult = UIBackgroundFetchResultNewData;
        }
        else if (fetchResult == UIBackgroundFetchResultFailed && combinedFetchResult == UIBackgroundFetchResultNoData) {
            combinedFetchResult = UIBackgroundFetchResultFailed;
        }
        
        if (!moreComing) {
            completionHandler(combinedFetchResult);
        }
    }];
}

#pragma mark - Background Sync

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    DDLogInfo(@"[Backgournd Fetch] fetch called");
    completionHandler(UIBackgroundFetchResultNoData);
    // TODO: user forum notification can be fetched here, then send a local notification to user.
}

#pragma mark - Hand Off

- (BOOL)application:(UIApplication *)application willContinueUserActivityWithType:(NSString *)userActivityType {
    return YES;
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray *))restorationHandler {
    DDLogDebug(@"Receive Hand Off: %@", userActivity.userInfo);
    NSNumber *topicID = [userActivity.userInfo valueForKey:@"topicID"];
    if (topicID) {
        S1Topic *topic = [[S1DataCenter sharedDataCenter] tracedTopic:topicID];
        if (topic) {
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic = [topic copy];
                topic.lastViewedPage = lastViewedPage;
            }
        } else {
            topic = [[S1Topic alloc] init];
            topic.topicID = topicID;
            NSNumber *lastViewedPage = [userActivity.userInfo valueForKey:@"page"];
            if (lastViewedPage) {
                topic.lastViewedPage = lastViewedPage;
            }
        }
        [self presentContentViewControllerForTopic:topic];
        return YES;
    } else {
        NSString *urlString = [userActivity.webpageURL absoluteString];
        S1Topic *parsedTopic = [S1Parser extractTopicInfoFromLink:urlString];
        if (parsedTopic.topicID) {
            S1Topic *tracedTopic = [[S1DataCenter sharedDataCenter] tracedTopic:parsedTopic.topicID];
            if (tracedTopic) {
                NSNumber *lastViewedPage = parsedTopic.lastViewedPage;
                if (lastViewedPage) {
                    tracedTopic = [tracedTopic copy];
                    tracedTopic.lastViewedPage = lastViewedPage;
                }
                [self presentContentViewControllerForTopic:tracedTopic];
                return YES;
            } else {
                [self presentContentViewControllerForTopic:parsedTopic];
                return YES;
            }
        }
    }
    return NO;
}

#pragma mark - Reachability

- (void)reachabilityChanged:(NSNotification *)notification {
    Reachability *reachability = notification.object;
    if ([reachability isReachableViaWiFi]) {
        DDLogDebug(@"[Reachability] WIFI: display picture");
    } else {
        DDLogDebug(@"[Reachability] WWAN: display placeholder");
    }
}

#pragma mark - Helper

- (void)presentContentViewControllerForTopic:(S1Topic *)topic {
    id rootvc = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    if ([rootvc isKindOfClass:[UINavigationController class]]) {
        S1ContentViewController *contentViewController = [[S1ContentViewController alloc] initWithNibName:nil bundle:nil];
        [contentViewController setTopic:topic];
        [contentViewController setDataCenter:[S1DataCenter sharedDataCenter]];
        [(UINavigationController *)rootvc pushViewController:contentViewController animated:YES];
    }
}

@end
