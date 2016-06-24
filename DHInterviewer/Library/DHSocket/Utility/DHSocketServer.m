//
//  DHSocketServer.m
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHSocketServer.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <CFNetwork/CFSocketStream.h>

@interface DHSocketServer () <NSNetServiceDelegate>

@property (nonatomic, assign) uint16_t port;
@property (nonatomic, assign) CFSocketRef listeningSocket;
@property (nonatomic, strong) NSNetService *netService;

@end

@implementation DHSocketServer

- (BOOL) start:(NSString *) chatName {
    // Start the socket server
    if (![self createServer])
        return NO;
    
    // Announce the server via Bonjour
    if (![self publishService:chatName]) {
        [self terminateServer];
        return NO;
    }
    
    return YES;
}

- (void) stop {
    [self terminateServer];
    [self unpublishService];
}

- (BOOL)createServer {
    //// PART 1: Create a socket that can accept connections
    CFSocketContext socketCtxt = {0, (__bridge void *)(self), NULL, NULL, NULL};
    
    _listeningSocket = CFSocketCreate(kCFAllocatorDefault,
                                      PF_INET,                  // The protocol family for the socket
                                      SOCK_STREAM,              // The socket type to create
                                      IPPROTO_TCP,              // The protocol for the socket. TCP vs UDP.
                                      kCFSocketAcceptCallBack,  // New connections will be automatically accepted and the callback is called with the data argument being a pointer to a CFSocketNativeHandle of the child socket.
                                      (CFSocketCallBack)&serverAcceptCallback,
                                      &socketCtxt);
    
    // Previous call might have failed
    if (!_listeningSocket)
        return NO;
    
    // getsockopt will return existing socket option value via this variable
    int existingValue = 1;
    
    // Make sure that same listening socket address gets reused after every connection
    setsockopt(CFSocketGetNative(_listeningSocket),
               SOL_SOCKET,
               SO_REUSEADDR,
               (void *)&existingValue,
               sizeof(existingValue));
    
    
    //// PART 2: Bind our socket to an endpoint.
    // We will be listening on all available interfaces/addresses.
    // Port will be assigned automatically by kernel.
    struct sockaddr_in socketAddress;
    memset(&socketAddress, 0, sizeof(socketAddress));
    socketAddress.sin_len = sizeof(socketAddress);
    socketAddress.sin_family = AF_INET;     // Address family (IPv4 vs IPv6)
    socketAddress.sin_port = 0;             // Actual port will get assigned automatically by kernel
    socketAddress.sin_addr.s_addr = htonl(INADDR_ANY);    // We must use "network byte order" format (big-endian) for the value here
    
    // Convert the endpoint data structure into something that CFSocket can use
    NSData *socketAddressData = [NSData dataWithBytes:&socketAddress length:sizeof(socketAddress)];
    
    // Bind our socket to the endpoint. Check if successful.
    if (CFSocketSetAddress(_listeningSocket, (CFDataRef)socketAddressData) != kCFSocketSuccess) {
        // Cleanup
        if (!_listeningSocket) {
            CFRelease(_listeningSocket);
            _listeningSocket = nil;
        }
        return NO;
    }
    
    
    //// PART 3: Find out what port kernel assigned to our socket
    // We need it to advertise our service via Bonjour
    NSData *socketAddressActualData = (NSData *)CFBridgingRelease(CFSocketCopyAddress(_listeningSocket));
    
    // Convert socket data into a usable structure
    struct sockaddr_in socketAddressActual;
    memcpy(&socketAddressActual, [socketAddressActualData bytes],
           [socketAddressActualData length]);
    
    _port = ntohs(socketAddressActual.sin_port);
    
    //// PART 4: Hook up our socket to the current run loop
    CFRunLoopRef currentRunLoop = CFRunLoopGetCurrent();
    CFRunLoopSourceRef runLoopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _listeningSocket, 0);
    CFRunLoopAddSource(currentRunLoop, runLoopSource, kCFRunLoopCommonModes);
    CFRelease(runLoopSource);
    
    return YES;
}


- (void) terminateServer {
    if (_listeningSocket) {
        CFSocketInvalidate(_listeningSocket);
        CFRelease(_listeningSocket);
        _listeningSocket = nil;
    }
}

static void serverAcceptCallback(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    // This function will be used as a callback while creating our listening socket via 'CFSocketCreate'
    DHSocketServer *server = (__bridge DHSocketServer *)info;
    
    // We can only process "connection accepted" calls here
    if ( type != kCFSocketAcceptCallBack )
        return;
    
    // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
    CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle*)data;
    
    [server handleNewNativeSocket:nativeSocketHandle];
}

- (void)handleNewNativeSocket:(CFSocketNativeHandle) nativeSocketHandle {
    DHSocketConnection* connection = [[DHSocketConnection alloc] initWithNativeSocketHandle:nativeSocketHandle];
    
    // In case of errors, close native socket handle
    if ( connection == nil ) {
        close(nativeSocketHandle);
        return;
    }
    
    // finish connecting
    if ( ! [connection connect] ) {
        [connection close];
        return;
    }
    
    // Pass this on to our delegate
    if (_delegate && [_delegate respondsToSelector:@selector(handleNewNativeSocket:)])
        [_delegate handleNewConnection:connection];
}

- (BOOL) publishService:(NSString *) chatRoomName {
    // create new instance of netService
    _netService = [[NSNetService alloc] initWithDomain:@"" type:@"_chatty._tcp." name:chatRoomName port:_port];
    if (!_netService)
        return NO;
    
    // Add service to current run loop
    [_netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    
    // NetService will let us know about what's happening via delegate methods
    [_netService setDelegate:self];
    
    // Publish the service
    [_netService publish];
    
    return YES;
}

- (void) unpublishService {
    if (_netService ) {
        [_netService stop];
        [_netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _netService = nil;
    }
}


#pragma mark - NSNetService Delegate Method Implementations
- (void)netServiceWillPublish:(NSNetService *)sender; {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netServiceDidPublish:(NSNetService *)sender {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netService:(NSNetService*)sender didNotPublish:(NSDictionary*)errorDict {
    NSLog(@"%@",NSStringFromSelector(_cmd));
    
    // Delegate method, called by NSNetService in case service publishing fails for whatever reason
    if (sender != _netService)
        return;
    
    // Stop socket server
    [self terminateServer];
    
    // Stop Bonjour
    [self unpublishService];
    
    // Let delegate know about failure
    if (_delegate && [_delegate respondsToSelector:@selector(serverFailed:reason:)])
        [_delegate serverFailed:self reason:@"Failed to publish service via Bonjour (duplicate server name?)"];
}

- (void)netServiceWillResolve:(NSNetService *)sender {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

- (void)netService:(NSNetService *)sender didAcceptConnectionWithInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    NSLog(@"%@",NSStringFromSelector(_cmd));
}

@end