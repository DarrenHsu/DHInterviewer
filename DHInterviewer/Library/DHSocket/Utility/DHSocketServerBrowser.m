//
//  DHSocketServerBrowser.m
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHSocketServerBrowser.h"

@interface NSNetService (BrowserViewControllerAdditions)

- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *) aService;

@end

@implementation NSNetService (BrowserViewControllerAdditions)

- (NSComparisonResult) localizedCaseInsensitiveCompareByName:(NSNetService *) aService {
    return [[self name] localizedCaseInsensitiveCompare:[aService name]];
}

@end


@interface DHSocketServerBrowser () <NSNetServiceBrowserDelegate>

@property (nonatomic, strong) NSNetServiceBrowser* netServiceBrowser;
@property (nonatomic, strong) NSMutableArray* servers;

@end

@implementation DHSocketServerBrowser

- (id) init {
    self = [super init];
    if (self) {
        _servers = [NSMutableArray new];
    }
    return self;
}

- (BOOL) start {
    // Restarting?
    if (_netServiceBrowser)
        [self stop];
    
    _netServiceBrowser = [NSNetServiceBrowser new];
    if(!_netServiceBrowser)
        return NO;
    
    _netServiceBrowser.delegate = self;
    [_netServiceBrowser searchForServicesOfType:@"_chatty._tcp." inDomain:@""];
    
    return YES;
}

- (void)stop {
    if (!_netServiceBrowser)
        return;
    
    [_netServiceBrowser stop];
    _netServiceBrowser = nil;
    
    [_servers removeAllObjects];
}

- (void) sortServers {
    [_servers sortUsingSelector:@selector(localizedCaseInsensitiveCompareByName:)];
}

#pragma mark - NSNetServiceBrowser Delegate Method Implementations
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didFindService:(NSNetService *) netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    // New service was found
    // Make sure that we don't have such service already (why would this happen? not sure)
    if (![_servers containsObject:netService]) {
        // Add it to our list
        [_servers addObject:netService];
    }
    
    // If more entries are coming, no need to update UI just yet
    if (moreServicesComing )
        return;
    
    // Sort alphabetically and let our delegate know
    [self sortServers];
    
    if (_delegate && [_delegate respondsToSelector:@selector(serverBrowser:addService:)])
        [_delegate serverBrowser:self addService:netService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    // Service was removed
    // Remove from list
    [_servers removeObject:netService];
    
    // If more entries are coming, no need to update UI just yet
    if (moreServicesComing)
        return;
    
    // Sort alphabetically and let our delegate know
    [self sortServers];
    
    if (_delegate && [_delegate respondsToSelector:@selector(serverBrowser:removeService:)])
        [_delegate serverBrowser:self removeService:netService];
}

@end