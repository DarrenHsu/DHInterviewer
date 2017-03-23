//
//  DHLocalRoom.m
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHLocalRoom.h"
#import "DHSocketServer.h"
#import "DHSocketConnection.h"

@interface DHLocalRoom () <DHSocketConnectionDelegate,DHSocketServerDelegate>

@property (nonatomic, strong) DHSocketServer *server;
@property (nonatomic, strong) NSMutableSet *clients;

@end

@implementation DHLocalRoom

- (id) init {
    self = [super init];
    if (self) {
        _clients = [NSMutableSet new];
    }
    return self;
}

- (BOOL) start:(NSString *) roomName {
    _server = [DHSocketServer new];
    _server.delegate = self;
    
    if (![_server start:roomName]) {
        _server = nil;
        return NO;
    }
    
    return YES;
}

- (void) stop {
    [_server stop];
    _server = nil;
    
    [_clients makeObjectsPerformSelector:@selector(close)];
}

- (void) broadcastChatMessage:(NSString *) message fromUser:(NSString *) name {
    if (self.delegate && [self.delegate respondsToSelector:@selector(displayChatMessage:fromUser:)])
        [self.delegate displayChatMessage:message fromUser:name];
    
    NSDictionary* packet = [NSDictionary dictionaryWithObjectsAndKeys:message, kMessage, name, kFrom, nil];
    
    [_clients makeObjectsPerformSelector:@selector(sendNetworkPacket:) withObject:packet];
}

#pragma mark - ServerDelegate Method Implementations
- (void) serverFailed:(DHSocketServer *) server reason:(NSString *)reason {
    [self stop];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(roomTerminated:reason:)])
        [self.delegate roomTerminated:self reason:reason];
}


- (void) handleNewConnection:(DHSocketConnection *) connection {
    connection.delegate = self;
    [_clients addObject:connection];
}


#pragma mark - ConnectionDelegate Method Implementations
- (void) connectionAttemptFailed:(DHSocketConnection *) connection {
    
}

- (void) connectionTerminated:(DHSocketConnection *) connection {
    [_clients removeObject:connection];
}

- (void) receivedNetworkPacket:(NSDictionary *) packet viaConnection:(DHSocketConnection *) connection {
    if (self.delegate && [self.delegate respondsToSelector:@selector(displayChatMessage:fromUser:)])
        [self.delegate displayChatMessage:[packet objectForKey:kMessage] fromUser:[packet objectForKey:kFrom]];
    
    [_clients makeObjectsPerformSelector:@selector(sendNetworkPacket:) withObject:packet];
}

@end
