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

@property NSError *error;

@property CBPeripheral *peripheral;

@property dispatch_time_t startTime;
@property NSTimeInterval roundtripTime;

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
    dispatch_semaphore_wait(self.peripheral.semaphore, DISPATCH_TIME_FOREVER);
    
    self.startTime = dispatch_time(DISPATCH_TIME_NOW, 0);
    
    self.peripheral.delegate = self;
    
    CBCharacteristic *characteristic = self.peripheral[UARTService][TXCharacteristic];
    [self.peripheral writeValue:self.TXPacket.data forCharacteristic:characteristic];
    
    __weak typeof(self) this = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        this.error = [this.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandTimedOut];
        [this invokeHandler];
    });
    
    dispatch_semaphore_wait(self.peripheral.semaphore, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_signal(self.peripheral.semaphore);
}

- (BOOL)isResponse:(UARTPacket *)RXPacket {
    return YES;
}

- (BOOL)isCancellableBy:(UARTCommand *)command {
    return YES;
}

#pragma mark - Peripheral

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if ([self isCancelled]) {
        error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
    }
    
    if (error) {
        self.error = error;
        [self invokeHandler];
    } else if (!self.waitForResponse) {
        [self invokeHandler];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if ([self isCancelled]) {
        error = [self.bundle errorWithDomain:UARTErrorDomain code:UARTErrorCommandCancelled];
    }
    
    if (error) {
        self.error = error;
        [self invokeHandler];
    } else {
        UARTPacket *RXPacket = [[UARTPacket alloc] initWithData:characteristic.value];
        if ([self isResponse:RXPacket]) {
            self.RXPacket = RXPacket;
            [self invokeHandler];
        }
    }
}

#pragma mark - Helpers

- (void)invokeHandler {
    
    dispatch_time_t endTime = dispatch_time(DISPATCH_TIME_NOW, 0);
    dispatch_time_t deltaTime = endTime - self.startTime;
    self.roundtripTime = (NSTimeInterval)deltaTime / NSEC_PER_SEC;
    
    [NSOperationQueue.mainQueue addOperationWithBlock:^{
        UARTCommandHandler handler = self.peripheral.handlers[@(self.hash)];
        if (handler) {
            handler(self);
            self.peripheral.handlers[@(self.hash)] = nil;
        }
        dispatch_semaphore_signal(self.peripheral.semaphore);
    }];
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

- (void)setSemaphore:(dispatch_semaphore_t)semaphore {
    objc_setAssociatedObject(self, @selector(semaphore), semaphore, OBJC_ASSOCIATION_RETAIN);
}

- (dispatch_semaphore_t)semaphore {
    dispatch_semaphore_t semaphore = objc_getAssociatedObject(self, @selector(semaphore));
    if (semaphore) return semaphore;
    
    semaphore = dispatch_semaphore_create(1);
    self.semaphore = semaphore;
    return semaphore;
}

- (void)setHandlers:(NSMutableDictionary *)handlers {
    objc_setAssociatedObject(self, @selector(handlers), handlers, OBJC_ASSOCIATION_RETAIN);
}

- (NSMutableDictionary *)handlers {
    NSMutableDictionary *handlers = objc_getAssociatedObject(self, @selector(handlers));
    if (handlers) return handlers;
    
    handlers = [NSMutableDictionary dictionary];
    self.handlers = handlers;
    return handlers;
}

- (void)sendCommand:(UARTCommand *)command completion:(UARTCommandHandler)completion {
    command.peripheral = self;
    self.handlers[@(command.hash)] = completion;
    [self.commandQueue addOperation:command];
    
    if (command.cancelPrevious ) {
        NSArray *commands = self.commandQueue.operations;
        NSUInteger index = [commands indexOfObject:command];
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
