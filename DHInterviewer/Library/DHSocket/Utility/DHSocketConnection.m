//
//  DHSocketConnection.m
//  DHInterviewer
//
//  Created by Darren720 on 6/23/16.
//  Copyright © 2016 D.H. All rights reserved.
//

#import "DHSocketConnection.h"

@interface DHSocketConnection () <NSNetServiceDelegate>

@property (nonatomic, strong) NSString * host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) CFSocketNativeHandle connectedSocketHandle;

@property (nonatomic, strong) NSNetService * netService;

// Read stream
@property (nonatomic, assign) CFReadStreamRef readStream;
@property (nonatomic, assign) BOOL readStreamOpen;
@property (nonatomic, strong) NSMutableData * incomingDataBuffer;
@property (nonatomic, assign) NSInteger packetBodySize;

// Write stream
@property (nonatomic, assign) CFWriteStreamRef writeStream;
@property (nonatomic, assign) BOOL writeStreamOpen;
@property (nonatomic, strong) NSMutableData * outgoingDataBuffer;

@end

@implementation DHSocketConnection

- (id) init {
    self = [super init];
    if (self) {
        _connectedSocketHandle = -1;
        _packetBodySize = -1;
    }
    return self;
}

- (id) initWithHostAddress:(NSString *) host andPort:(NSInteger) port {
    self = [self init];
    if (self) {
        _host = host;
        _port = port;
    }
    return self;
}

- (id) initWithNativeSocketHandle:(CFSocketNativeHandle) nativeSocketHandle {
    self = [self init];
    if (self) {
        _connectedSocketHandle = nativeSocketHandle;
    }
    return self;
}

- (id) initWithNetService:(NSNetService *) netService {
    // Has it been resolved?
    if (netService.hostName)
        return [self initWithHostAddress:netService.hostName andPort:netService.port];
    
    self = [self init];
    if (self) {
        _netService = netService;
    }
    return self;
}

- (BOOL) connect {
    if (_host) {
        // Bind read/write streams to a new socket
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           (__bridge CFStringRef)_host,
                                           (int)_port,
                                           &_readStream,
                                           &_writeStream);
        
        // Do the rest
        return [self setupSocketStreams];
        
    } else if (_connectedSocketHandle != -1) {
        // Bind read/write streams to a socket represented by a native socket handle
        CFStreamCreatePairWithSocket(kCFAllocatorDefault,
                                     _connectedSocketHandle,
                                     &_readStream,
                                     &_writeStream);
        
        // Do the rest
        return [self setupSocketStreams];
    } else if (_netService) {
        // Still need to resolve?
        if (_netService.hostName) {
            CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                               (__bridge CFStringRef)_netService.hostName,
                                               (int)_netService.port,
                                               &_readStream,
                                               &_writeStream);
            
            return [self setupSocketStreams];
        }
        
        // Start resolving
        _netService.delegate = self;
        [_netService resolveWithTimeout:5.0];
        
        return YES;
    }
    
    // Nothing was passed, connection is not possible
    return NO;
}

- (BOOL)setupSocketStreams {
    // Make sure streams were created correctly
    if ( !_readStream || !_writeStream) {
        [self close];
        return NO;
    }
    
    // Create buffers
    _incomingDataBuffer = [[NSMutableData alloc] init];
    _outgoingDataBuffer = [[NSMutableData alloc] init];
    
    // Indicate that we want socket to be closed whenever streams are closed
    CFReadStreamSetProperty(_readStream,
                            kCFStreamPropertyShouldCloseNativeSocket,
                            kCFBooleanTrue);
    
    CFWriteStreamSetProperty(_writeStream,
                             kCFStreamPropertyShouldCloseNativeSocket,
                             kCFBooleanTrue);
    
    // We will be handling the following stream events
    CFOptionFlags registeredEvents = kCFStreamEventOpenCompleted | kCFStreamEventHasBytesAvailable | kCFStreamEventCanAcceptBytes | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred;
    
    // Setup stream context - reference to 'self' will be passed to stream event handling callbacks
    CFStreamClientContext ctx = {0, (__bridge_retained void *)self , NULL, NULL, NULL};
    
    // Specify callbacks that will be handling stream events
    CFReadStreamSetClient(_readStream, registeredEvents, (CFReadStreamClientCallBack)&readStreamEventHandler, &ctx);
    CFWriteStreamSetClient(_writeStream, registeredEvents, (CFWriteStreamClientCallBack)&writeStreamEventHandler, &ctx);
    
    // Schedule streams with current run loop
    CFReadStreamScheduleWithRunLoop(_readStream,
                                    CFRunLoopGetCurrent(),
                                    kCFRunLoopCommonModes);
    
    CFWriteStreamScheduleWithRunLoop(_writeStream,
                                     CFRunLoopGetCurrent(),
                                     kCFRunLoopCommonModes);
    
    // Open both streams
    if (!CFReadStreamOpen(_readStream) || !CFWriteStreamOpen(_writeStream)) {
        [self close];
        return NO;
    }
    
    return YES;
}

- (void)clean {
    _readStream = nil;
    _readStreamOpen = NO;
    
    _writeStream = nil;
    _writeStreamOpen = NO;
    
    _incomingDataBuffer = nil;
    _outgoingDataBuffer = nil;
    
    _netService = nil;
    _host = nil;
    _connectedSocketHandle = -1;
    _packetBodySize = -1;
}

- (void) close {
    // Cleanup read stream
    if (_readStream) {
        CFReadStreamUnscheduleFromRunLoop(_readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFReadStreamClose(_readStream);
        CFRelease(_readStream);
    }
    
    // Cleanup write stream
    if (_writeStream) {
        CFWriteStreamUnscheduleFromRunLoop(_writeStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFWriteStreamClose(_writeStream);
        CFRelease(_writeStream);
    }
    
    // Stop net service?
    if (_netService) {
        [_netService stop];
        _netService = nil;
    }
    
    // Reset all other variables
    [self clean];
    
}

- (void) sendNetworkPacket:(NSDictionary *) packet {
    // Encode packet
    NSData* rawPacket = [NSKeyedArchiver archivedDataWithRootObject:packet];
    
    // Write header: lengh of raw packet
    NSInteger packetLength = [rawPacket length];
    [_outgoingDataBuffer appendBytes:&packetLength length:sizeof(int)];
    
    // Write body: encoded NSDictionary
    [_outgoingDataBuffer appendData:rawPacket];
    
    // Try to write to stream
    [self writeOutgoingBufferToStream];
}

#pragma mark Read stream methods
void readStreamEventHandler(CFReadStreamRef stream, CFStreamEventType eventType, void *info) {
    // Dispatch readStream events
    DHSocketConnection *connection = (__bridge DHSocketConnection *)info;
    [connection readStreamHandleEvent:eventType];
}

- (void)readStreamHandleEvent:(CFStreamEventType) event {
    // Handle events from the read stream
    // Stream successfully opened
    if (event == kCFStreamEventOpenCompleted) {
        _readStreamOpen = YES;
        
    } else if ( event == kCFStreamEventHasBytesAvailable ) {
        // New data has arrived
        // Read as many bytes from the stream as possible and try to extract meaningful packets
        [self readFromStreamIntoIncomingBuffer];
        
    } else if ( event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred ) {
        // Connection has been terminated or error encountered (we treat them the same way)
        // Clean everything up
        [self close];
        
        // If we haven't connected yet then our connection attempt has failed
        if (!_readStreamOpen || !_writeStreamOpen) {
            if (_delegate && [_delegate respondsToSelector:@selector(connectionAttemptFailed:)])
                [_delegate connectionAttemptFailed:self];
        } else {
            if (_delegate && [_delegate respondsToSelector:@selector(connectionTerminated:)])
                [_delegate connectionTerminated:self];
        }
    }
}

- (void)readFromStreamIntoIncomingBuffer {
    // Read as many bytes from the stream as possible and try to extract meaningful packets
    // Temporary buffer to read data into
    UInt8 buf[1024];
    
    // Try reading while there is data
    while(CFReadStreamHasBytesAvailable(_readStream) ) {
        CFIndex len = CFReadStreamRead(_readStream, buf, sizeof(buf));
        if ( len <= 0 ) {
            // Either stream was closed or error occurred. Close everything up and treat this as "connection terminated"
            [self close];
            
            if (_delegate && [_delegate respondsToSelector:@selector(connectionTerminated:)])
                [_delegate connectionTerminated:self];
            
            return;
        }
        
        [_incomingDataBuffer appendBytes:buf length:len];
    }
    
    // Try to extract packets from the buffer.
    //
    // Protocol: header + body
    //  header: an integer that indicates length of the body
    //  body: bytes that represent encoded NSDictionary
    
    // We might have more than one message in the buffer - that's why we'll be reading it inside the while loop
    while(YES) {
        // Did we read the header yet?
        if (_packetBodySize == -1) {
            // Do we have enough bytes in the buffer to read the header?
            if ( [_incomingDataBuffer length] >= sizeof(int) ) {
                // extract length
                memcpy(&_packetBodySize, [_incomingDataBuffer bytes], sizeof(int));
                
                // remove that chunk from buffer
                NSRange rangeToDelete = {0, sizeof(int)};
                [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
            }
            else {
                // We don't have enough yet. Will wait for more data.
                break;
            }
        }
        
        // We should now have the header. Time to extract the body.
        if ( [_incomingDataBuffer length] >= _packetBodySize ) {
            // We now have enough data to extract a meaningful packet.
            NSData* raw = [NSData dataWithBytes:[_incomingDataBuffer bytes] length:_packetBodySize];
            NSDictionary* packet = [NSKeyedUnarchiver unarchiveObjectWithData:raw];
            
            // Tell our delegate about it
            if (_delegate && [_delegate respondsToSelector:@selector(receivedNetworkPacket:viaConnection:)])
                [_delegate receivedNetworkPacket:packet viaConnection:self];
            
            // Remove that chunk from buffer
            NSRange rangeToDelete = {0, _packetBodySize};
            [_incomingDataBuffer replaceBytesInRange:rangeToDelete withBytes:NULL length:0];
            
            // We have processed the packet. Resetting the state.
            _packetBodySize = -1;
        } else {
            // Not enough data yet. Will wait.
            break;
        }
    }
}


#pragma mark Write stream methods
void writeStreamEventHandler(CFWriteStreamRef stream, CFStreamEventType eventType, void *info) {
    // Dispatch writeStream event handling
    DHSocketConnection *connection = (__bridge DHSocketConnection *)info;
    [connection writeStreamHandleEvent:eventType];
}

- (void)writeStreamHandleEvent:(CFStreamEventType)event {
    // Handle events from the write stream
    // Stream successfully opened
    if ( event == kCFStreamEventOpenCompleted ) {
        _writeStreamOpen = YES;
        
    } else if ( event == kCFStreamEventCanAcceptBytes ) {
        // Stream has space for more data to be written
        // Write whatever data we have, as much as stream can handle
        [self writeOutgoingBufferToStream];
    } else if ( event == kCFStreamEventEndEncountered || event == kCFStreamEventErrorOccurred ) {
        // Connection has been terminated or error encountered (we treat them the same way)
        // Clean everything up
        [self close];
        
        // If we haven't connected yet then our connection attempt has failed
        if (!_readStreamOpen || !_writeStreamOpen) {
            if (_delegate && [_delegate respondsToSelector:@selector(connectionAttemptFailed:)])
                [_delegate connectionAttemptFailed:self];
        } else {
            if (_delegate && [_delegate respondsToSelector:@selector(connectionTerminated:)])
                [_delegate connectionTerminated:self];
        }
    }
}


- (void)writeOutgoingBufferToStream {
    // Write whatever data we have, as much of it as stream can handle
    // Is connection open?
    if (!_readStreamOpen || !_writeStreamOpen ) {
        // No, wait until everything is operational before pushing data through
        return;
    }
    
    // Do we have anything to write?
    if ([_outgoingDataBuffer length] == 0 )
        return;
    
    // Can stream take any data in?
    if (!CFWriteStreamCanAcceptBytes(_writeStream) ) {
        return;
    }
    
    // Write as much as we can
    CFIndex writtenBytes = CFWriteStreamWrite(_writeStream, [_outgoingDataBuffer bytes], [_outgoingDataBuffer length]);
    
    if ( writtenBytes == -1 ) {
        // Error occurred. Close everything up.
        [self close];
        
        if (_delegate && [_delegate respondsToSelector:@selector(connectionTerminated:)])
            [_delegate connectionTerminated:self];
        
        return;
    }
    
    NSRange range = {0, writtenBytes};
    [_outgoingDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
}

#pragma mark - NSNetService Delegate Method Implementations
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    // Called if we weren't able to resolve net service
    if ( sender != _netService ) {
        return;
    }
    
    // Close everything and tell delegate that we have failed
    if (_delegate && [_delegate respondsToSelector:@selector(connectionAttemptFailed:)])
        [_delegate connectionAttemptFailed:self];
    
    [self close];
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender {
    // Called when net service has been successfully resolved
    if (sender != _netService) {
        return;
    }
    
    // Save connection info
    _host = _netService.hostName;
    _port = _netService.port;
    
    // Don't need the service anymore
    self.netService = nil;
    
    // Connect!
    if (![self connect]) {
        if (_delegate && [_delegate respondsToSelector:@selector(connectionAttemptFailed:)])
            [_delegate connectionAttemptFailed:self];
        
        [self close];
    }
}

@end