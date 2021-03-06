//
//  DHLocalRoom.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHRoom.h"

@interface DHLocalRoom : DHRoom

- (BOOL) start:(NSString *) roomName;
- (void) stop;
- (void) broadcastChatMessage:(NSString *) message fromUser:(NSString *) name;

@end