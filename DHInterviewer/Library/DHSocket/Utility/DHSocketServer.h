//
//  DHSocketServer.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DHSocketConnection.h"

@protocol DHSocketServerDelegate;

@interface DHSocketServer : NSObject

@property (nonatomic, weak) id<DHSocketServerDelegate> delegate;

- (BOOL) start:(NSString *) chatName;
- (void) stop;

@end

@protocol DHSocketServerDelegate <NSObject>
@optional
- (void) serverFailed:(DHSocketServer *) server reason:(NSString*)reason;
- (void) handleNewConnection:(DHSocketConnection *) connection;
@end