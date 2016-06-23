//
//  DHSocketServerBrowser.h
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DHSocketServerBrowserDelegate;

@interface DHSocketServerBrowser : NSObject

@property (nonatomic, weak) id<DHSocketServerBrowserDelegate> delegate;

- (BOOL)start;
- (void)stop;

@end

@protocol DHSocketServerBrowserDelegate <NSObject>
@optional
- (void) serverBrowser:(DHSocketServerBrowser *) serverBrowser addService:(NSNetService *) service;
- (void) serverBrowser:(DHSocketServerBrowser *) serverBrowser removeService:(NSNetService *) service;
@end
