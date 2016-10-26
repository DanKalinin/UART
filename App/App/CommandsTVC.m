//
//  CommandsTVC.m
//  App
//
//  Created by Dan Kalinin on 25/10/16.
//  Copyright © 2016 Dan Kalinin. All rights reserved.
//

#import "CommandsTVC.h"
#import "AppDelegate.h"



@interface CommandsTVC () <BTCentralManagerDelegate>

@property AppDelegate *appDelegate;

@end



@implementation CommandsTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    
    self.appDelegate.UARTCentralManager.delegate = self;
    [self.appDelegate.UARTCentralManager connectPeripheral:self.peripheral];
}

#pragma mark - Central manager

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    uint8_t bytes[] = {85, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 170};
    NSData *data = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    
    UARTPacket *TXPacket = [[UARTPacket alloc] initWithData:data];
    UARTCommand *command = [[UARTCommand alloc] initWithTXPacket:TXPacket];
    
    [self.peripheral sendCommand:command completion:^(UARTCommand *command) {
        NSLog(@"xxxxxx ------- %f", command.roundtripTime);
    }];
    
    command = [[UARTCommand alloc] initWithTXPacket:TXPacket];
    
    [self.peripheral sendCommand:command completion:^(UARTCommand *command) {
        NSLog(@"yyyyyy ------- %f", command.roundtripTime);
    }];
}

#pragma mark - Helpers

@end
