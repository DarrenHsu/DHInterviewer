//
//  DHRemoteRoom.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHRoom.h"
#import "DHSocketConnection.h"

@interface DHRemoteRoom : DHRoom

@property (nonatomic, strong) DHSocketConnection *connection;

- (id)initWithHost:(NSString *) host andPort:(NSInteger) port;
- (id)initWithNetService:(NSNetService *) netService;

- (BOOL) start;
- (void) stop;
- (void) broadcastChatMessage:(NSString*)message fromUser:(NSString*)name;

@end