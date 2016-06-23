//
//  DHSocketConnection.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DHSocketConnectionDelegate;

@interface DHSocketConnection : NSObject

@property (nonatomic, weak) id<DHSocketConnectionDelegate> delegate;

- (id) initWithHostAddress:(NSString *) host andPort:(NSInteger) port;
- (id) initWithNativeSocketHandle:(CFSocketNativeHandle) nativeSocketHandle;
- (id) initWithNetService:(NSNetService *) netService;

- (BOOL) connect;
- (void) close;

- (void) sendNetworkPacket:(NSDictionary *) packet;

@end

@protocol DHSocketConnectionDelegate <NSObject>
@optional
- (void) connectionAttemptFailed:(DHSocketConnection *) connection;
- (void) connectionTerminated:(DHSocketConnection *) connection;
- (void) receivedNetworkPacket:(NSDictionary *) message viaConnection:(DHSocketConnection *) connection;

@end