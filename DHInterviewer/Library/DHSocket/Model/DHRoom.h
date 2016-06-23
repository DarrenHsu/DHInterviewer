//
//  DHRoom.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kMessage    @"Message"
#define kFrom       @"From"

@protocol DHRoomDelegate;

@interface DHRoom : NSObject

@property (nonatomic, weak) id<DHRoomDelegate> delegate;

@end

@protocol DHRoomDelegate <NSObject>
@optional
- (void) displayChatMessage:(NSString*)message fromUser:(NSString*)userName;
- (void) roomTerminated:(id)room reason:(NSString*)string;
@end