//
//  UARTManager.h
//  Framework
//
//  Created by Dan Kalinin on 25/10/16.
//  Copyright © 2016 Dan Kalinin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <BTConfiguration/BTConfiguration.h>

FOUNDATION_EXPORT double UARTVersionNumber;
FOUNDATION_EXPORT const unsigned char UARTVersionString[];

extern NSString *const UARTErrorDomain;

typedef NS_ENUM(NSInteger, UARTError) {
    UARTErrorCommandTimedOut = 0,
    UARTErrorCommandCancelled = 1
};










#pragma mark - Packet, Command

@interface UARTPacket : NSObject

- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithString:(NSString *)string;
- (instancetype)initWithArray:(NSArray<NSNumber *> *)array;

@property (readonly) NSData *data;
@property (readonly) NSString *string;
@property (readonly) NSArray<NSNumber *> *array;

@end










@interface UARTCommand : NSOperation

typedef void (^UARTCommandHandler)(UARTCommand *command, NSError *error);

- (instancetype)initWithTXPacket:(UARTPacket *)packet;

@property (readonly) UARTPacket *TXPacket;
@property (readonly) UARTPacket *RXPacket;

@property NSTimeInterval timeout;
@property BOOL waitForResponse;
@property BOOL cancelPrevious;

- (BOOL)isResponse:(UARTPacket *)RXPacket;
- (BOOL)isCancellableBy:(UARTCommand *)command;

@end










#pragma mark - Peripheral

@interface CBPeripheral (UART)

- (void)sendCommand:(UARTCommand *)command completion:(UARTCommandHandler)completion;

@end
