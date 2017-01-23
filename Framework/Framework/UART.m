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
@property dispatch_semaphore_t semaphore;
@property NSMutableDictionary *handlers;

@end










#pragma mark - Packet

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
    NSString *string = [NSString.alloc initWithData:self.data encoding:NSUTF8StringEncoding];
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










#pragma mark - Command

@interface UARTCommand () <BTPeripheralDelegate> {
    BOOL executing;
    BOOL finished;
    
    NSString *isExecutingKey;
    NSString *isFinishedKey;
    
    dispatch_time_t startTime;
}

@property UARTPacket *RXPacket;

@property CBPeripheral *peripheral;

@property NSError *error;

@property NSTimeInterval roundtripTime;

@end



@implementation UARTCommand

- (instancetype)init {
    self = [super init];
    if (self) {
        self.timeout = 60.0;
        self.waitForResponse = YES;
        self.cancelPrevious = NO;
        
        executing = finished = NO;
        isExecutingKey = NSStringFromSelector(@selector(isExecuting));
        isFinishedKey = NSStringFromSelector(@selector(isFinished));
    }
    return self;
}

- (instancetype)initWithTXPacket:(UARTPacket *)packet {
    self = [self init];
    if (self) {
        self.TXPacket = packet;
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return executing;
}

- (BOOL)isFinished {
    return finished;
}

- (void)start {
    if ([self isCancelled]) {
        [self willChangeValueForKey:isFinishedKey];
        
        self.error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
        
        finished = YES;
        
        [self didChangeValueForKey:isFinishedKey];
        return;
    }
    
    [self willChangeValueForKey:isExecutingKey];
    
    startTime = dispatch_time(DISPATCH_TIME_NOW, 0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self isExecuting]) {
            self.error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandTimedOut];
            [self completeOperation];
        }
    });
    
    self.peripheral.delegate = self;
    
    CBCharacteristic *characteristic = self.peripheral[UARTService][TXCharacteristic];
    [self.peripheral writeValue:self.TXPacket.data forCharacteristic:characteristic];
    
    executing = YES;
    
    [self didChangeValueForKey:isExecutingKey];
}

- (void)completeOperation {
    [self willChangeValueForKey:isFinishedKey];
    [self willChangeValueForKey:isExecutingKey];
    
    dispatch_time_t completionTime = dispatch_time(DISPATCH_TIME_NOW, 0);
    self.roundtripTime = (NSTimeInterval)(completionTime - startTime) / NSEC_PER_SEC;
    
    executing = NO;
    finished = YES;
    
    [self didChangeValueForKey:isExecutingKey];
    [self didChangeValueForKey:isFinishedKey];
}

- (BOOL)isResponse:(UARTPacket *)RXPacket {
    return YES;
}

- (BOOL)isCancellableBy:(UARTCommand *)command {
    return NO;
}

#pragma mark - Peripheral

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if ([self isCancelled]) {
        error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
    }
    
    if (error) {
        self.error = error;
        [self completeOperation];
    } else {
        if (!self.waitForResponse) {
            [self completeOperation];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if ([self isCancelled]) {
        error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
    }
    
    if (error) {
        self.error = error;
        [self completeOperation];
    } else {
        UARTPacket *RXPacket = [UARTPacket.alloc initWithData:characteristic.value];
        if ([self isResponse:RXPacket]) {
            self.RXPacket = RXPacket;
            [self completeOperation];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDisconnectWithError:(NSError *)error {
    [peripheral.commandQueue cancelAllOperations];
    peripheral.commandQueue = nil;
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
    
    __block typeof(command) cmd = command;
    command.completionBlock = ^{
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            completion(cmd);
            cmd = nil;
        }];
    };
    
    if (command.cancelPrevious) {
        UARTCommand *lastCommand = self.commandQueue.operations.lastObject;
        if (lastCommand && [lastCommand isCancellableBy:command]) {
            [lastCommand cancel];
        }
    }
    
    [self.commandQueue addOperation:command];
}

@end
