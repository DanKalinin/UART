//
//  AppDelegate.m
//  App
//
//  Created by Dan Kalinin on 25/10/16.
//  Copyright © 2016 Dan Kalinin. All rights reserved.
//

#import "AppDelegate.h"



@interface AppDelegate () <BTCentralManagerDelegate>

@end



@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    BTCentralConfiguration *configuration = [[BTCentralConfiguration alloc] initWithName:@"UARTCentralConfiguration" bundle:nil];
    self.UARTCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil configuration:configuration];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Central manager

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict {
    
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
}

@end
