//
//  DHRemoteRoom.m
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHRemoteRoom.h"
#import "DHSocketServer.h"
#import "DHSocketConnection.h"

@interface DHRemoteRoom () <DHSocketServerDelegate, DHSocketConnectionDelegate>

@end

@implementation DHRemoteRoom

- (id)initWithHost:(NSString *) host andPort:(NSInteger) port {
    self = [self init];
    if (self) {
        _connection = [[DHSocketConnection alloc] initWithHostAddress:host andPort:port];
    }
    return self;
}

- (id)initWithNetService:(NSNetService *) netService {
    self = [self init];
    if (self) {
        _connection = [[DHSocketConnection alloc] initWithNetService:netService];
    }
    return self;
}

- (BOOL) start {
    if (!_connection)
        return NO;

    _connection.delegate = self;
    
    return [_connection connect];
}

- (void) stop {
    if (!_connection)
        return;
    
    [_connection close];
    _connection = nil;
}

- (void) broadcastChatMessage:(NSString *)message fromUser:(NSString *) name {
    NSDictionary* packet = [NSDictionary dictionaryWithObjectsAndKeys:message, kMessage, name, kFrom, nil];
    
    [_connection sendNetworkPacket:packet];
}

#pragma mark - ConnectionDelegate Method Implementations
- (void)connectionAttemptFailed:(DHSocketConnection *)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(roomTerminated:reason:)])
        [self.delegate roomTerminated:self reason:@"Wasn't able to connect to server"];
}

- (void)connectionTerminated:(DHSocketConnection*)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(roomTerminated:reason:)])
        [self.delegate roomTerminated:self reason:@"Connection to server closed"];
}

- (void)receivedNetworkPacket:(NSDictionary *)packet viaConnection:(DHSocketConnection *)connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(displayChatMessage:fromUser:)])
        [self.delegate displayChatMessage:[packet objectForKey:kMessage] fromUser:[packet objectForKey:kFrom]];
}

@end
