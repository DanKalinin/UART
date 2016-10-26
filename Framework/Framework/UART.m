//
//  UARTManager.m
//  Framework
//
//  Created by Dan Kalinin on 25/10/16.
//  Copyright © 2016 Dan Kalinin. All rights reserved.
//

#import "UART.h"
#import <Helpers/Helpers.h>
#import <objc/runtime.h>

NSString *const UARTErrorDomain = @"UARTErrorDomain";

static NSString *const UARTService = @"UART";
static NSString *const RXCharacteristic = @"RX";
static NSString *const TXCharacteristic = @"TX";










#pragma mark - Selectors

@interface CBPeripheral (UARTSelectors)

@property NSOperationQueue *commandQueue;

@end










#pragma mark - Packet, Command

@interface UARTPacket ()

@property NSData *data;
@property NSString *string;
@property NSArray<NSNumber *> *array;

@end



@implementation UARTPacket

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string {
    self = [super init];
    if (self) {
        self.string = string;
    }
    return self;
}

- (instancetype)initWithArray:(NSArray<NSNumber *> *)array {
    self = [super init];
    if (self) {
        self.array = array;
    }
    return self;
}

- (void)setString:(NSString *)string {
    self.data = [string dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)string {
    NSString *string = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
    return string;
}

- (void)setArray:(NSArray<NSNumber *> *)array {
    uint8_t bytes[array.count];
    for (NSUInteger index = 0; index < array.count; index++) {
        bytes[index] = array[index].unsignedCharValue;
    }
    self.data = [NSData dataWithBytes:bytes length:array.count];
}

- (NSArray<NSNumber *> *)array {
    uint8_t bytes[self.data.length];
    [self.data getBytes:bytes length:self.data.length];
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger index = 0; index < self.data.length; index++) {
        uint8_t byte = bytes[index];
        NSNumber *number = @(byte);
        [array addObject:number];
    }
    return array;
}

@end










@interface UARTCommand () <CBPeripheralDelegate>

@property UARTPacket *TXPacket;
@property UARTPacket *RXPacket;

@property CBPeripheral *peripheral;
@property (copy) UARTCommandHandler completion;

@property dispatch_semaphore_t writeSemaphore;
@property dispatch_semaphore_t updateSemaphore;


@end



@implementation UARTCommand

- (instancetype)initWithTXPacket:(UARTPacket *)packet {
    self = [self init];
    if (self) {
        self.TXPacket = packet;
        self.timeout = 60.0;
        self.waitForResponse = YES;
        self.cancelPrevious = NO;
    }
    return self;
}

- (void)main {
    NSLog(@"a");
    NSError *cancelError = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
    
    if ([self isCancelled]) {
        [self invokeHandler:cancelError];
        return;
    }
    
    CBCharacteristic *characteristic = self.peripheral[UARTService][TXCharacteristic];
    
    self.peripheral.delegate = self;
    [self.peripheral writeValue:self.TXPacket.data forCharacteristic:characteristic];
    
    self.writeSemaphore = dispatch_semaphore_create(0);
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC));
    BOOL expired = dispatch_semaphore_wait(self.writeSemaphore, timeout);
    NSLog(@"b");
    if ([self isCancelled]) {
        [self invokeHandler:cancelError];
        return;
    }
    
    NSError *timeoutError = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandTimedOut];
    
    if (expired) {
        [self invokeHandler:timeoutError];
        return;
    }
    
    if (!self.waitForResponse) {
        [self invokeHandler:nil];
        return;
    }
    
    self.updateSemaphore = dispatch_semaphore_create(0);
    expired = dispatch_semaphore_wait(self.updateSemaphore, timeout);
    if (expired) {
        [self invokeHandler:timeoutError];
    }
}

- (BOOL)isResponse:(UARTPacket *)RXPacket {
    return YES;
}

- (BOOL)isCancellableBy:(UARTCommand *)command {
    return NO;
}

#pragma mark - Peripheral

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    dispatch_semaphore_signal(self.writeSemaphore);
    if (error) {
        [self invokeHandler:error];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        dispatch_semaphore_signal(self.updateSemaphore);
        [self invokeHandler:error];
    } else {
        UARTPacket *RXPacket = [[UARTPacket alloc] initWithData:characteristic.value];
        if ([self isResponse:RXPacket]) {
            dispatch_semaphore_signal(self.updateSemaphore);
            self.RXPacket = RXPacket;
            [self invokeHandler:nil];
        }
    }
}

#pragma mark - Helpers

- (void)invokeHandler:(NSError *)error {
    if (self.completion) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            self.completion(self, error);
        }];
    }
}

@end










#pragma mark - Peripheral

@implementation CBPeripheral (UART)

- (void)setCommandQueue:(NSOperationQueue *)commandQueue {
    objc_setAssociatedObject(self, @selector(commandQueue), commandQueue, OBJC_ASSOCIATION_RETAIN);
}

- (NSOperationQueue *)commandQueue {
    NSOperationQueue *commandQueue = objc_getAssociatedObject(self, @selector(commandQueue));
    if (commandQueue) return commandQueue;

    commandQueue = [NSOperationQueue new];
    commandQueue.maxConcurrentOperationCount = 1;
    self.commandQueue = commandQueue;
    return commandQueue;
}

- (void)sendCommand:(UARTCommand *)command completion:(UARTCommandHandler)completion {
    command.peripheral = self;
    command.completion = completion;
    [self.commandQueue addOperation:command];
    
    if (command.cancelPrevious ) {
        NSArray *commands = self.commandQueue.operations;
        NSUInteger index = [commands indexOfObject:self];
        if (index > 0) {
            index--;
            UARTCommand *prevCommand = commands[index];
            if ([prevCommand isCancellableBy:command]) {
                [prevCommand cancel];
            }
        }
    }
}

@end
