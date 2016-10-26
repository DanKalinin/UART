//
//  PeripheralsTVC.m
//  App
//
//  Created by Dan Kalinin on 25/10/16.
//  Copyright © 2016 Dan Kalinin. All rights reserved.
//

#import "PeripheralsTVC.h"
#import "CommandsTVC.h"
#import "AppDelegate.h"
#import <HUD/HUD.h>



@interface PeripheralsTVC () <BTCentralManagerDelegate>

@property AppDelegate *appDelegate;

@property NSMutableArray<CBPeripheral *> *peripherals;

@end



@implementation PeripheralsTVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.appDelegate.UARTCentralManager.delegate = self;
    self.peripherals = [NSMutableArray array];
    
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    CommandsTVC *vc = segue.destinationViewController;
    vc.peripheral = self.peripherals[self.tableView.indexPathForSelectedRow.row];
}

#pragma mark - Actions

- (void)onRefresh {
    [self.refreshControl performSelector:@selector(endRefreshing) withObject:nil afterDelay:1.0];
    
    if (self.appDelegate.UARTCentralManager.state != CBManagerStatePoweredOn) {
        self.hudText.label.text = @"Bluetooth is turned off";
        [self.hudText showAnimated:YES forTime:2.0];
        return;
    }
    
    [self.peripherals removeAllObjects];
    [self.tableView reloadData];
    
    [self.appDelegate.UARTCentralManager scanForPeripherals];
}

#pragma mark - Table view

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.peripherals.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CBPeripheral *peripheral = self.peripherals[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = peripheral.name;
    cell.detailTextLabel.text = peripheral.identifier.UUIDString;
    return cell;
}

#pragma mark - Central manager

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *,id> *)dict {
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([self.peripherals containsObject:peripheral]) return;
    
    [self.peripherals addObject:peripheral];
    [self.tableView reloadData];
}

@end
