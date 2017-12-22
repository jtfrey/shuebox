//
// SBFoundation : ObjC Class Library for Solaris
// SBStream.h
//
// Generalized i/o streams.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBStream.h"
#import "SBString.h"
#import "SBValue.h"
#import "SBData.h"
#import "SBHost.h"
#import "SBInetAddress.h"
#import "SBError.h"
#import "SBFileManager.h"
#import "SBStreamPrivate.h"
#import "SBRunLoop.h"
#import "SBRunLoopPrivate.h"

#include <sys/socket.h>

SBString* const SBStreamFileCurrentOffsetKey = @"SBStreamFileCurrentOffsetKey";
SBString* const SBStreamDataWrittenToMemoryStreamKey = @"SBStreamDataWrittenToMemoryStreamKey";

SBString* const SBStreamSocketSecurityLevelKey = @"SBStreamSocketSecurityLevelKey";
SBString* const SBStreamSocketSecurityLevelNone = @"";
SBString* const SBStreamSocketSecurityLevelSSLv2 = @"SSLv2";
SBString* const SBStreamSocketSecurityLevelSSLv3 = @"SSLv3";
SBString* const SBStreamSocketSecurityLevelTLSv1 = @"TLSv1";
SBString* const SBStreamSocketSecurityLevelNegotiatedSSL = @"SSLv23";

@implementation SBStream

  - (void) open {}
  - (void) close {}
  
//

  - (id<SBStreamDelegate>) delegate { return self; }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
  }

//

  - (id) propertyForKey:(SBString*)aKey { return nil; }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus { return SBStreamStatusError; }
  - (SBError*) streamError { return nil; }

//

  - (void) stream:(SBStream*)aStream
    handleEvent:(SBStreamEvent)eventCode
  {
  }
  
//

  - (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
  }

//

  - (void) removeFromRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
  }

@end

//
#pragma mark -
//

enum {
  SBStreamFileFlagsCloseWhenDone        = 1 << 0,
  SBStreamFileFlagsShouldAppend         = 1 << 1,
  SBStreamFileFlagsWillNotBlock         = 1 << 2,
  SBStreamFileFlagsRemovingFromRunLoop  = 1 << 3
};

@interface SBBufferInputStream : SBInputStream
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  SBData*               _inputData;
  const void*           _inputDataPtr;
  unsigned int          _readPtr, _endPtr;
}

@end

@interface SBFileInputStream : SBInputStream <SBFileDescriptorStream>
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  SBString*             _pathToFile;
  unsigned int          _flags;
  int                   _fd;
}

@end

//
// Forward-declare since SBSocketInputStream depends on the
// output side of the connection to know when the connection has
// completed and the stream is ready for i/o:
//
//   (1) Socket set to O_NONBLOCK
//   (2) Connect the socket to the remote address
//   
//   Since the socket is non-blocking, connect() will return 0 or
//   non-zero.  If non-zero and errno is EINPROGRESS, then the
//   connection attempt hasn't completed.  Polling for write and
//   error using pselect() against the socket can be used to eventually
//   figure out when the connection attempt completes, at which point
//   the two stream objects can transition from SBStreamStatusOpening
//   to SBStreamStatusOpen or SBStreamStatusError:
//
//   (3) Use pselect() with socket in write and error sets; once
//       set for write, => SBStreamStatusOpen, or set for error,
//       => SBStreamStatusError.
//       (a) For error, the SBError can be constructed by means of
//           grabbing the socket errno using:
//
//             int             local_errno;
//             socklen_t       local_errno_size = sizeof(local_errno);
//             getsockopt(sock, SOL_SOCKET, SO_ERROR, &local_errno, &local_errno_size)
//
// Once in SBStreamStatusOpen, further Runloop 
@class SBSocketOutputStream;

@interface SBSocketInputStream : SBInputStream <SBFileDescriptorStream>
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  unsigned int          _flags;
  int                   _socket;
  SBSocketOutputStream* _outputStream;
}

- (id) initWithSocketOutputStream:(SBSocketOutputStream*)outputStream;

- (void) syncStatusWithOutputStream;

@end

//
#pragma mark -
//

@interface SBBufferOutputStream : SBOutputStream
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  SBMutableData*        _outputData;
  const void*           _outputDataPtr;
  unsigned int          _outputDataCapacity;
}

@end

@interface SBFileOutputStream : SBOutputStream <SBFileDescriptorStream>
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  SBString*             _pathToFile;
  unsigned int          _flags;
  int                   _fd;
}

@end

@interface SBSocketOutputStream : SBOutputStream <SBFileDescriptorStream>
{
  SBStreamStatus        _streamStatus;
  SBError*              _streamError;
  id<SBStreamDelegate>  _delegate;
  SBHost*               _host;
  int                   _port;
  SBSocketInputStream*  _inputStream;
  unsigned int          _flags;
  int                   _socket;
  SBString*             _securityLevel;
}

- (id) initWithHost:(SBHost*)aHost port:(int)port;
- (BOOL) pollForConnectCompletion;
- (SBInputStream*) inputStream;

@end

//
#pragma mark -
//

@implementation SBStream(SBSocketStreamCreationExtensions)

  + (void) getStreamsToHost:(SBHost*)host
    port:(int)port
    inputStream:(SBInputStream**)inputStream
    outputStream:(SBOutputStream**)outputStream
  {
    *outputStream = [[[SBSocketOutputStream alloc] initWithHost:host port:port] autorelease];
    *inputStream = [(SBSocketOutputStream*)(*outputStream) inputStream];
  }

@end

//
#pragma mark -
//

@implementation SBInputStream

  + (id) inputStreamWithData:(SBData*)theData
  {
    return [[[SBBufferInputStream alloc] initWithData:theData] autorelease];
  }
  
//

  + (id) inputStreamWithFileAtPath:(SBString*)aPath
  {
    return [[[SBFileInputStream alloc] initWithFileAtPath:aPath] autorelease];
  }
  
//

  - (id) initWithData:(SBData*)theData
  {
    if ( [self class] == [SBInputStream class] ) {
      [self release];
      self = [[SBBufferInputStream alloc] initWithData:theData];
    } else {
      self = [self init];
    }
  }
  
//

  - (id) initWithFileAtPath:(SBString*)aPath
  {
    if ( [self class] == [SBInputStream class] ) {
      [self release];
      self = [[SBFileInputStream alloc] initWithFileAtPath:aPath];
    } else {
      self = [self init];
    }
  }
  
//

  - (size_t) read:(void*)buffer
    maxLength:(size_t)length
  {
    return 0;
  }
  
//

  - (BOOL) getBuffer:(void**)buffer
    length:(size_t*)length
  {
    return NO;
  }
  
//

  - (BOOL) hasBytesAvailable
  {
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBOutputStream

  + (id) outputStreamToMemory
  {
    return [[[SBBufferOutputStream alloc] initToMemory] autorelease];
  }
  
//

  + (id) outputStreamToBuffer:(void*)buffer
    capacity:(size_t)capacity
  {
    return [[[SBBufferOutputStream alloc] initToBuffer:buffer capacity:capacity] autorelease];
  }
  
//

  + (id) outputStreamToFileAtPath:(SBString*)path
    append:(BOOL)shouldAppend
  {
    return [[[SBFileOutputStream alloc] initToFileAtPath:path append:shouldAppend] autorelease];
  }

//

  - (id) initToMemory
  {
    if ( [self class] == [SBBufferOutputStream class] ) {
      [self release];
      self = [[SBBufferOutputStream alloc] initToMemory];
    } else {
      self = [self init];
    }
  }
  
//

  - (id) initToBuffer:(void*)buffer
    capacity:(size_t)capacity
  {
    if ( [self class] == [SBBufferOutputStream class] ) {
      [self release];
      self = [[SBBufferOutputStream alloc] initToBuffer:buffer capacity:capacity];
    } else {
      self = [self init];
    }
  }
  
//

  - (id) initToFileAtPath:(SBString*)aPath
    append:(BOOL)shouldAppend
  {
    if ( [self class] == [SBFileOutputStream class] ) {
      [self release];
      self = [[SBFileOutputStream alloc] initToFileAtPath:aPath append:shouldAppend];
    } else {
      self = [self init];
    }
  }

//

  - (size_t) write:(void*)buffer
    length:(size_t)length
  {
    return 0;
  }
  
//

  - (BOOL) hasSpaceAvailable
  {
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBBufferInputStream

  - (id) initWithData:(SBData*)theData
  {
    if ( (self = [super init]) ) {
      if ( theData ) {
        if ( [theData isKindOf:[SBMutableData class]] )
          _inputData = [theData copy];
        else
          _inputData = [theData retain];
        _inputDataPtr = [_inputData bytes];
        _endPtr = [_inputData length];
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _streamError ) [_streamError release];
    if ( _inputData ) [_inputData release];
    [super dealloc];
  }

//

  - (void) open
  {
    // Skip if it's already open:
    switch ( _streamStatus ) {
    
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
        return;
    
    }
      
    _streamStatus = SBStreamStatusOpening;
      
    if ( _inputData ) {
      // Stream is open:
      _streamStatus = SBStreamStatusOpen;
      [_delegate stream:self handleEvent:SBStreamEventOpenCompleted];
      
      // Prepare for read:
      _readPtr = 0;
    } else {
      // No buffer to look at, kinda like a non-existent file:
      if ( _streamError ) [_streamError release];
      _streamError = [[SBError alloc] initWithDomain:@"Cannot open input stream for nil data." code:0 supportingData:nil];
      _streamStatus = SBStreamStatusError;
      [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
    }
  }
  
//

  - (void) close
  {
    switch ( _streamStatus ) {
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
      case SBStreamStatusError:
        _streamStatus = SBStreamStatusClosed;
        break;
    }
  }
  
//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    if ( _inputData && [aKey isEqualToString:SBStreamFileCurrentOffsetKey] )
      return [SBNumber numberWithUnsignedInt:_readPtr];
    return nil;
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    if ( _inputData && [aKey isEqualToString:SBStreamFileCurrentOffsetKey] ) {
      unsigned int      newPos = [property unsignedIntValue];
      
      if ( newPos <= _endPtr ) {
        _readPtr = newPos;
        // Possibly clear an end-of-stream status:
        _streamStatus = SBStreamStatusOpen;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus { return _streamStatus; }
  - (SBError*) streamError { return _streamError; }

//

  - (size_t) read:(void*)buffer
    maxLength:(size_t)length
  {
    size_t      actualRead = 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      unsigned int      available = _endPtr - _readPtr;
      
      _streamStatus = SBStreamStatusReading;
      if ( available ) {
        actualRead = ( (length > available) ? available : length );
        memcpy(buffer, _inputDataPtr + _readPtr, actualRead);
        _readPtr += actualRead;
        _streamStatus = SBStreamStatusOpen;
      } else {
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      }
    }
    return actualRead;
  }
  
//

  - (BOOL) getBuffer:(const void**)buffer
    length:(size_t*)length
  {
    BOOL          rc = NO;
    
    if ( _streamStatus == SBStreamStatusOpen ) {
      unsigned int      available = _endPtr - _readPtr;
      
      if ( available ) {
        *buffer = _inputDataPtr + _readPtr;
        *length = available;
        rc = YES;
      }
    }
    return rc;
  }
  
//

  - (BOOL) hasBytesAvailable
  {
    if ( (_streamStatus == SBStreamStatusOpen) && (_readPtr < _endPtr) )
      return YES;
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBFileInputStream

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    if ( (self = [super init]) ) {
      _fd = fd;
      if ( closeWhenDone )
        _flags = SBStreamFileFlagsCloseWhenDone;
      _streamStatus = SBStreamStatusOpen;
    }
    return self;
  }

//

  - (id) initWithFileAtPath:(SBString*)aPath
  {
    if ( (self = [self initWithFileDescriptor:-1 closeWhenDone:YES]) ) {
      _streamStatus = SBStreamStatusNotOpen;
      _pathToFile = [aPath copy];
    }
    return self;
  }

//

  - (void) dealloc
  {
    [[SBRunLoop currentRunLoop] removeInputSource:self];
    if ( _pathToFile ) [_pathToFile release];
    if ( _streamError ) [_streamError release];
    if ( (_flags & SBStreamFileFlagsCloseWhenDone) && (_fd >= 0) ) close(_fd);
    [super dealloc];
  }

//

  - (void) open
  {
    // Skip if it's already open:
    switch ( _streamStatus ) {
    
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
        return;
    
    }
      
    _streamStatus = SBStreamStatusOpening;
    
    if ( _pathToFile ) {
      SBFileManager*      fm = [SBFileManager sharedFileManager];
      
      // Readable file?
      if ( [fm isReadableFileAtPath:_pathToFile] ) {
        _fd = [fm openPath:_pathToFile withFlags:O_RDONLY mode:0666];
        if ( _fd < 0 ) {
          // Error while opening file, make a POSIX SBError;
          if ( _streamError ) [_streamError release];
          _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
          _streamStatus = SBStreamStatusError;
          [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
        } else {
          // Stream is open:
          _streamStatus = SBStreamStatusOpen;
          [_delegate stream:self handleEvent:SBStreamEventOpenCompleted];
        }
      } else {
        // No such file!
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:ENOENT supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      }
    } else {
      // No file path present!
      if ( _streamError ) [_streamError release];
      _streamError = [[SBError alloc] initWithDomain:@"No file path to open." code:0 supportingData:nil];
      _streamStatus = SBStreamStatusError;
      [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
    }
  }

//

  - (void) close
  {
    switch ( _streamStatus ) {
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
      case SBStreamStatusError: {
        if ( _flags & SBStreamFileFlagsCloseWhenDone ) {
          close(_fd); _fd = -1;
          _streamStatus = SBStreamStatusClosed;
        }
        break;
      }
    }
  }

//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    if ( (_fd >= 0) && ([aKey isEqualToString:SBStreamFileCurrentOffsetKey]) ) {
      off_t       fpos = lseek(_fd, 0, SEEK_CUR);
      
      if ( fpos >= 0 )
        return [SBNumber numberWithInt64:(int64_t)fpos];
    }
    return nil;
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    if ( (_fd >= 0) && [aKey isEqualToString:SBStreamFileCurrentOffsetKey] ) {
      off_t     fpos = [property int64Value];
      
      if ( fpos >= 0 ) {
        if ( lseek(_fd, fpos, SEEK_SET) > -1 ) {
          // Possibly clear an end-of-stream status:
          _streamStatus = SBStreamStatusOpen;
          return YES;
        }
      }
    }
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus { return _streamStatus; }
  - (SBError*) streamError { return _streamError; }

//

  - (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop addInputSource:self forMode:aMode];
  }
  - (void) removeFromRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop removeInputSource:self forMode:aMode];
  }

//

  - (void) stream:(SBStream*)aStream
    handleEvent:(SBStreamEvent)eventCode
  {
    switch ( eventCode ) {
    
        case SBStreamEventBytesAvailable:
          _flags |= SBStreamFileFlagsWillNotBlock;
          break;
          
        
        case SBStreamEventEndEncountered:
          _streamStatus = SBStreamStatusAtEnd;
          break;
        
    }
  }

//

  - (size_t) read:(void*)buffer
    maxLength:(size_t)length
  {
    size_t      actualRead = 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      ssize_t   count;
      
      _streamStatus = SBStreamStatusReading;
      _flags &= ~SBStreamFileFlagsWillNotBlock;
      count = read(_fd, buffer, length);
      if ( count == 0 ) {
        // End of file:
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      } else if ( count < 0 ) {
        // Some kind of error, create a POSIX-domain SBError:
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      } else {
        _streamStatus = SBStreamStatusOpen;
        actualRead = count;
      }
    }
    return actualRead;
  }
  
//

  - (BOOL) getBuffer:(const void**)buffer
    length:(size_t*)length
  {
    return NO;
  }
  
//

  - (BOOL) hasBytesAvailable
  {
    if ( _flags & SBStreamFileFlagsWillNotBlock )
      return YES;
    if ( _streamStatus == SBStreamStatusOpen ) {
      fd_set            checkFDs;
      struct timeval    immediate = { 0, 0 };
      sigset_t          sigmask;
      
      //
      // Do a pselect() on our _fd -- the zero timeval effects
      // a polling operation:
      //
      FD_ZERO(&checkFDs);
      FD_SET(_fd, &checkFDs);
      sigemptyset(&sigmask);
      sigaddset(&sigmask, SIGHUP);
      sigaddset(&sigmask, SIGALRM);
      sigaddset(&sigmask, SIGCHLD);
      sigaddset(&sigmask, SIGVTALRM);
      if ( pselect(_fd + 1, &checkFDs, NULL, NULL, (const struct timespec*)&immediate, &sigmask) == 1 )
        return YES;
    }
    return NO;
  }

//

  - (unsigned int) flagsForStream { return _flags; }
  - (int) fileDescriptorForStream
  {
    return _fd;
  }
  - (void) fileDescriptorReady
  {
    _flags |= SBStreamFileFlagsWillNotBlock;
    [_delegate stream:self handleEvent:SBStreamEventBytesAvailable];
  }
  - (void) fileDescriptorHasError:(int)errno
  {
    // Some kind of error, create a POSIX-domain SBError:
    if ( _streamError ) [_streamError release];
    _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
    _streamStatus = SBStreamStatusError;
    [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
  }

@end

//
#pragma mark -
//

@implementation SBSocketInputStream

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    [self release];
    return nil;
  }

//

  - (id) initWithSocketOutputStream:(SBSocketOutputStream*)outputStream
  {
    if ( (self = [super init]) ) {
      _socket = -1;
      _outputStream = [outputStream retain];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    [[SBRunLoop currentRunLoop] removeInputSource:self];
    if ( _streamError ) [_streamError release];
    if ( _outputStream ) [_outputStream release];
    [super dealloc];
  }

//

  - (void) syncStatusWithOutputStream
  {
    _socket = [_outputStream fileDescriptorForStream];
    _streamStatus = [_outputStream streamStatus];
    _streamError = [[_outputStream streamError] retain];
  }

//

  - (void) open
  {
    [_outputStream open];
  }

//

  - (void) close
  {
    [_outputStream close];
  }

//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    return [_outputStream propertyForKey:aKey];
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    return [_outputStream setProperty:property forKey:aKey];
  }
  
//

  - (SBStreamStatus) streamStatus { return _streamStatus; }
  - (SBError*) streamError { return _streamError; }

//

  - (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop addInputSource:self forMode:aMode];
  }
  - (void) removeFromRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    if ( ! (_flags & SBStreamFileFlagsRemovingFromRunLoop) ) {
      [theRunLoop removeInputSource:self forMode:aMode];
      _flags |= SBStreamFileFlagsRemovingFromRunLoop;
      [_outputStream removeFromRunLoop:theRunLoop forMode:aMode];
      _flags &= ~SBStreamFileFlagsRemovingFromRunLoop;
    }
  }

//

  - (void) stream:(SBStream*)aStream
    handleEvent:(SBStreamEvent)eventCode
  {
    switch ( eventCode ) {
    
        case SBStreamEventBytesAvailable:
          _flags |= SBStreamFileFlagsWillNotBlock;
          break;
          
        
        case SBStreamEventEndEncountered:
          _streamStatus = SBStreamStatusAtEnd;
          break;
        
    }
  }
  
//

  - (size_t) read:(void*)buffer
    maxLength:(size_t)length
  {
    size_t      actualRead = 0;
    
    if ( (_streamStatus == SBStreamStatusOpening) && ! [_outputStream pollForConnectCompletion] )
      return 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      ssize_t   count;
      
      _streamStatus = SBStreamStatusReading;
      _flags &= ~SBStreamFileFlagsWillNotBlock;
      count = read(_socket, buffer, length);
      if ( count == 0 ) {
        // End of file:
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      } else if ( count < 0 ) {
        // Some kind of error, create a POSIX-domain SBError:
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      } else {
        _streamStatus = SBStreamStatusOpen;
        actualRead = count;
      }
    }
    return actualRead;
  }
  
//

  - (BOOL) getBuffer:(const void**)buffer
    length:(size_t*)length
  {
    return NO;
  }
  
//

  - (BOOL) hasBytesAvailable
  {
    if ( _flags & SBStreamFileFlagsWillNotBlock )
      return YES;
    if ( (_streamStatus == SBStreamStatusOpen) || ((_streamStatus == SBStreamStatusOpening) && [_outputStream pollForConnectCompletion]) ) {
      fd_set            checkFDs;
      struct timeval    immediate = { 0, 0 };
      sigset_t          sigmask;
      
      //
      // Do a pselect() on our _fd -- the zero timeval effects
      // a polling operation:
      //
      FD_ZERO(&checkFDs);
      FD_SET(_socket, &checkFDs);
      sigemptyset(&sigmask);
      sigaddset(&sigmask, SIGHUP);
      sigaddset(&sigmask, SIGALRM);
      sigaddset(&sigmask, SIGCHLD);
      sigaddset(&sigmask, SIGVTALRM);
      if ( pselect(_socket + 1, &checkFDs, NULL, NULL, (const struct timespec*)&immediate, &sigmask) == 1 )
        return YES;
    }
    return NO;
  }

//

  - (unsigned int) flagsForStream { return _flags; }
  - (int) fileDescriptorForStream
  {
    return _socket;
  }
  - (void) fileDescriptorReady
  {
    _flags |= SBStreamFileFlagsWillNotBlock;
    [_delegate stream:self handleEvent:SBStreamEventBytesAvailable];
  }
  - (void) fileDescriptorHasError:(int)errno
  {
    // Some kind of error, create a POSIX-domain SBError:
    if ( _streamError ) [_streamError release];
    _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
    _streamStatus = SBStreamStatusError;
    [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
  }

@end

//
#pragma mark -
//

@implementation SBBufferOutputStream

  - (id) initToMemory
  {
    if ( (self = [super init]) ) {
      _outputDataCapacity = UINT_MAX;
    }
    return self;
  }
  
//

  - (id) initToBuffer:(void*)buffer
    capacity:(size_t)capacity
  {
    if ( (self = [super init]) ) {
      _outputDataPtr = buffer;
      _outputDataCapacity = capacity;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _streamError ) [_streamError release];
    if ( _outputData ) [_outputData release];
    [super dealloc];
  }

//

  - (void) open
  {
    // Skip if it's already open:
    switch ( _streamStatus ) {
    
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
        return;
    
    }
      
    _streamStatus = SBStreamStatusOpening;
    
    // Create the mutable data object:
    if ( _outputDataPtr ) {
      _outputData = [[SBMutableData alloc] initWithBytesNoCopy:_outputDataPtr length:_outputDataCapacity freeWhenDone:NO];
      [_outputData setLength:0];
    } else {
      _outputData = [[SBMutableData alloc] init];
    }
    if ( _outputData ) {
      // Stream is open:
      _streamStatus = SBStreamStatusOpen;
      [_delegate stream:self handleEvent:SBStreamEventOpenCompleted];
    } else {
      // Out-of-memory error:
      if ( _streamError ) [_streamError release];
      _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:ENOMEM supportingData:nil];
      _streamStatus = SBStreamStatusError;
      [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
    }
  }
  
//

  - (void) close
  {
    switch ( _streamStatus ) {
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
      case SBStreamStatusError:
        [_outputData release];
        _outputData = nil;
        _streamStatus = SBStreamStatusClosed;
        break;
    }
  }
  
//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    if ( _outputData ) {
      if ( [aKey isEqualToString:SBStreamDataWrittenToMemoryStreamKey] ) {
        return _outputData;
      }
      else if ( [aKey isEqualToString:SBStreamFileCurrentOffsetKey] ) {
        return [SBNumber numberWithUnsignedInt:[_outputData length]];
      }
    }
    return nil;
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    if ( _outputData && [aKey isEqualToString:SBStreamFileCurrentOffsetKey] ) {
      unsigned int      newPos = [property unsignedIntValue];
      
      if ( newPos >= 0 && ((_outputDataPtr == NULL) || (newPos <= _outputDataCapacity)) ) {
        [_outputData setLength:newPos];
        // Possibly clear an end-of-stream status:
        _streamStatus = SBStreamStatusOpen;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus { return _streamStatus; }
  - (SBError*) streamError { return _streamError; }

//

  - (size_t) write:(void*)buffer
    length:(size_t)length
  {
    size_t      actualWrite = 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      size_t    startLength = [_outputData length];
      
      _streamStatus = SBStreamStatusWriting;
      if ( _outputDataCapacity && (startLength + length > _outputDataCapacity) ) {
        [_outputData appendBytes:buffer length:(actualWrite = _outputDataCapacity - startLength)];
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      } else {
        [_outputData appendBytes:buffer length:length];
        actualWrite = [_outputData length] - startLength;
        if ( actualWrite == 0 ) {
          // Out-of-memory error:
          if ( _streamError ) [_streamError release];
          _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:ENOMEM supportingData:nil];
          _streamStatus = SBStreamStatusError;
          [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
        } else {
          _streamStatus = SBStreamStatusOpen;
        }
      }
    }
    return actualWrite;
  }
  
//

  - (BOOL) hasSpaceAvailable
  {
    if ( _streamStatus == SBStreamStatusOpen ) {
      if ( (_outputDataPtr == NULL) || ([_outputData length] < _outputDataCapacity) )
        return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBFileOutputStream

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    if ( (self = [super init]) ) {
      _fd = fd;
      if ( closeWhenDone )
        _flags = SBStreamFileFlagsCloseWhenDone;
      _streamStatus = SBStreamStatusOpen;
    }
    return self;
  }

//

  - (id) initToFileAtPath:(SBString*)aPath
    append:(BOOL)shouldAppend
  {
    if ( (self = [self initWithFileDescriptor:-1 closeWhenDone:YES]) ) {
      _streamStatus = SBStreamStatusNotOpen;
      if ( shouldAppend )
        _flags |= SBStreamFileFlagsShouldAppend;
      _pathToFile = [aPath copy];
    }
    return self;
  }

//

  - (void) dealloc
  {
    [[SBRunLoop currentRunLoop] removeOutputSource:self];
    if ( _pathToFile ) [_pathToFile release];
    if ( _streamError ) [_streamError release];
    if ( (_flags & SBStreamFileFlagsCloseWhenDone) && (_fd >= 0) ) close(_fd);
    [super dealloc];
  }

//

  - (void) open
  {
    // Skip if it's already open:
    switch ( _streamStatus ) {
    
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
        return;
    
    }
    
    _streamStatus = SBStreamStatusOpening;
    
    if ( _pathToFile ) {
      SBFileManager*      fm = [SBFileManager sharedFileManager];
      
      // Try opening/creating the file:
      _fd = [fm openPath:_pathToFile withFlags:O_CREAT | O_WRONLY mode:0666];
      if ( _fd < 0 ) {
        // Error while opening file, make a POSIX SBError;
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      } else {
        // If we're set for append, then skip to the end:
        if ( (_flags & SBStreamFileFlagsShouldAppend) && (lseek(_fd, 0, SEEK_END) < 0) ) {
          // Error while seeking to end, make a POSIX SBError;
          if ( _streamError ) [_streamError release];
          _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
          _streamStatus = SBStreamStatusError;
          [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
        } else {
          // Stream is open:
          _streamStatus = SBStreamStatusOpen;
          [_delegate stream:self handleEvent:SBStreamEventOpenCompleted];
        }
      }
    } else {
      // No file path present!
      if ( _streamError ) [_streamError release];
      _streamError = [[SBError alloc] initWithDomain:@"No file path to open." code:0 supportingData:nil];
      _streamStatus = SBStreamStatusError;
      [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
    }
  }

//

  - (void) close
  {
    switch ( _streamStatus ) {
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
      case SBStreamStatusError: {
        if ( _flags & SBStreamFileFlagsCloseWhenDone ) {
          close(_fd); _fd = -1;
          _streamStatus = SBStreamStatusClosed;
        }
        break;
      }
    }
  }

//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    if ( (_fd >= 0) && ([aKey isEqualToString:SBStreamFileCurrentOffsetKey]) ) {
      off_t       fpos = lseek(_fd, 0, SEEK_CUR);
      
      if ( fpos >= 0 )
        return [SBNumber numberWithInt64:(int64_t)fpos];
    }
    return nil;
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    if ( (_fd >= 0) && [aKey isEqualToString:SBStreamFileCurrentOffsetKey] ) {
      off_t     fpos = [property int64Value];
      
      if ( fpos >= 0 ) {
        if ( lseek(_fd, fpos, SEEK_SET) > -1 ) {
          // Possibly clear an end-of-stream status:
          _streamStatus = SBStreamStatusOpen;
          return YES;
        }
      }
    }
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus { return _streamStatus; }
  - (SBError*) streamError { return _streamError; }

//

  - (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop addOutputSource:self forMode:aMode];
  }
  - (void) removeFromRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop removeOutputSource:self forMode:aMode];
  }

//

  - (void) stream:(SBStream*)aStream
    handleEvent:(SBStreamEvent)eventCode
  {
    switch ( eventCode ) {
    
        case SBStreamEventSpaceAvailable:
          _flags |= SBStreamFileFlagsWillNotBlock;
          break;
          
        
        case SBStreamEventEndEncountered:
          _streamStatus = SBStreamStatusAtEnd;
          break;
        
    }
  }

//

  - (size_t) write:(void*)buffer
    length:(size_t)length
  {
    size_t      actualWrite = 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      ssize_t   count;
      
      _streamStatus = SBStreamStatusWriting;
      _flags &= ~SBStreamFileFlagsWillNotBlock;
      count = write(_fd, buffer, length);
      if ( count == 0 ) {
        // End of file???
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      } else if ( count < 0 ) {
        // Some kind of error, create a POSIX-domain SBError:
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      } else {
        _streamStatus = SBStreamStatusOpen;
        actualWrite = count;
      }
    }
    return actualWrite;
  }
  
//

  - (BOOL) hasSpaceAvailable
  {
    if ( _flags & SBStreamFileFlagsWillNotBlock )
      return YES;
    if ( _streamStatus == SBStreamStatusOpen )
      return YES;
    return NO;
  }

//

  - (unsigned int) flagsForStream { return _flags; }
  - (int) fileDescriptorForStream
  {
    return _fd;
  }
  - (void) fileDescriptorReady
  {
    _flags |= SBStreamFileFlagsWillNotBlock;
    [_delegate stream:self handleEvent:SBStreamEventSpaceAvailable];
  }
  - (void) fileDescriptorHasError:(int)errno
  {
    // Some kind of error, create a POSIX-domain SBError:
    if ( _streamError ) [_streamError release];
    _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
    _streamStatus = SBStreamStatusError;
    [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
  }

@end

//
#pragma mark -
//

@implementation SBSocketOutputStream

  - (id) initWithHost:(SBHost*)aHost
    port:(int)port
  {
    if ( (self = [self initWithFileDescriptor:-1 closeWhenDone:YES]) ) {
      _inputStream = [[SBSocketInputStream alloc] initWithSocketOutputStream:self];
      if ( _inputStream ) {
        _streamStatus = SBStreamStatusNotOpen;
        if ( aHost ) _host = [aHost retain];
        if ( port < 65536 && port > 0 )
          _port = port;
        _socket = -1;
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    if ( (self = [super init]) ) {
      _socket = fd;
      if ( closeWhenDone )
        _flags = SBStreamFileFlagsCloseWhenDone;
      _streamStatus = SBStreamStatusOpen;
    }
    return self;
  }

//

  - (void) dealloc
  {
    [[SBRunLoop currentRunLoop] removeOutputSource:self];
    if ( _host ) [_host release];
    if ( (_flags & SBStreamFileFlagsCloseWhenDone) && (_socket > -1) ) {
      shutdown(_socket, SHUT_RDWR);
      close(_socket);
    }
    if ( _streamError ) [_streamError release];
    if ( _inputStream ) [_inputStream dealloc];
    [super dealloc];
  }
  
//

  - (void) open
  {
    SBInetAddress*      hostIP = nil;
    
    // Skip if it's already open:
    switch ( _streamStatus ) {
    
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
        return;
    
    }
    
    _streamStatus = SBStreamStatusOpening;
    [_inputStream syncStatusWithOutputStream];
    
    // Get the host's IP address:
    if ( _host ) {
      if ( hostIP = [_host ipAddress] ) {
        // Are we opening a connection using IPv4 or IPv6?
        switch ( [hostIP addressFamily] ) {
        
          case kSBInetAddressIPv4Family: {
            struct sockaddr_in      sockAddress;
            
            if ( [hostIP setSockAddr:(struct sockaddr*)&sockAddress byteSize:sizeof(sockAddress)] ) {
              sockAddress.sin_port = htons(_port);
              
              _socket = socket(AF_INET, SOCK_STREAM, PF_UNSPEC);
              if ( _socket >= 0 ) {
                // Don't block while opening the connection:
                int       fd_flags = fcntl(_socket, F_GETFL, 0);
                fcntl(_socket, F_SETFL, fd_flags | O_NONBLOCK);
                if ( (connect(_socket, (struct sockaddr*)&sockAddress, sizeof(sockAddress)) == 0) || (errno == EINPROGRESS) ) {
                  // If errno is not EINPROGRESS, then the connection opened immediately and we're
                  // ready to roll; otherwise, we need to continue polling for its being ready:
                  if ( errno == 0 )
                    _streamStatus = SBStreamStatusOpen;
                } else {
                  close(_socket); _socket = -1;
                  if ( _streamError ) [_streamError release];
                  _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
                  _streamStatus = SBStreamStatusError;
                  [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
                }
              } else {
                if ( _streamError ) [_streamError release];
                _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
                _streamStatus = SBStreamStatusError;
                [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
              }
            }
            break;
          }
          
          case kSBInetAddressIPv6Family: {
            struct sockaddr_in6     sockAddress;
            
            if ( [hostIP setSockAddr:(struct sockaddr*)&sockAddress byteSize:sizeof(sockAddress)] ) {
              sockAddress.sin6_port = htons(_port);
              
              _socket = socket(AF_INET6, SOCK_STREAM, PF_UNSPEC);
              if ( _socket >= 0 ) {
                // Don't block while opening the connection:
                int       fd_flags = fcntl(_socket, F_GETFL, 0);
                fcntl(_socket, F_SETFL, fd_flags | O_NONBLOCK);
                if ( (connect(_socket, (struct sockaddr*)&sockAddress, sizeof(sockAddress)) == 0) || (errno == EINPROGRESS) ) {
                  // If errno is not EINPROGRESS, then the connection opened immediately and we're
                  // ready to roll; otherwise, we need to continue polling for its being ready:
                  if ( errno == 0 )
                    _streamStatus = SBStreamStatusOpen;
                } else {
                  close(_socket); _socket = -1;
                  if ( _streamError ) [_streamError release];
                  _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
                  _streamStatus = SBStreamStatusError;
                  [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
                }
              } else {
                if ( _streamError ) [_streamError release];
                _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
                _streamStatus = SBStreamStatusError;
                [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
              }
            }
            break;
          }
          
          default: {
            if ( _streamError ) [_streamError release];
            _streamError = [[SBError alloc] initWithDomain:@"Unexpected address family." code:0 supportingData:nil];
            _streamStatus = SBStreamStatusError;
            [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
            break;
          }
        
        }
      } else {
        // No IP address could be found for host!
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:@"Unable to lookup IP address for host." code:0 supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      }
    } else {
      // No host present!
      if ( _streamError ) [_streamError release];
      _streamError = [[SBError alloc] initWithDomain:@"No host specified for connection." code:0 supportingData:nil];
      _streamStatus = SBStreamStatusError;
      [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
    }
    
    [_inputStream syncStatusWithOutputStream];
  }
  
//

  - (void) close
  {
    switch ( _streamStatus ) {
      case SBStreamStatusOpen:
      case SBStreamStatusAtEnd:
      case SBStreamStatusError: {
        if ( _flags & SBStreamFileFlagsCloseWhenDone ) {
          shutdown(_socket, SHUT_RDWR);
          close(_socket); _socket = -1;
          _streamStatus = SBStreamStatusClosed;
          [_inputStream syncStatusWithOutputStream];
        }
        break;
      }
    }
  }

//

  - (id<SBStreamDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBStreamDelegate>)delegate
  {
    _delegate = ( delegate ? delegate : (id<SBStreamDelegate>)self );
  }

//

  - (id) propertyForKey:(SBString*)aKey
  {
    return nil;
  }
  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    return NO;
  }
  
//

  - (SBStreamStatus) streamStatus
  {
    if ( _streamStatus == SBStreamStatusOpening )
      [self pollForConnectCompletion];
    return _streamStatus;
  }
  - (SBError*) streamError { return _streamError; }

//

  - (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    [theRunLoop addOutputSource:self forMode:aMode];
  }
  - (void) removeFromRunLoop:(SBRunLoop*)theRunLoop
    forMode:(SBString*)aMode
  {
    if ( ! (_flags & SBStreamFileFlagsRemovingFromRunLoop) ) {
      [theRunLoop removeOutputSource:self forMode:aMode];
      _flags |= SBStreamFileFlagsRemovingFromRunLoop;
      [_inputStream removeFromRunLoop:theRunLoop forMode:aMode];
      _flags &= ~SBStreamFileFlagsRemovingFromRunLoop;
    }
  }

//

  - (void) stream:(SBStream*)aStream
    handleEvent:(SBStreamEvent)eventCode
  {
    switch ( eventCode ) {
    
        case SBStreamEventSpaceAvailable:
          _flags |= SBStreamFileFlagsWillNotBlock;
          break;
          
        
        case SBStreamEventEndEncountered:
          _streamStatus = SBStreamStatusAtEnd;
          break;
        
    }
  }

//

  - (unsigned int) flagsForStream { return _flags; }
  - (int) fileDescriptorForStream
  {
    return _socket;
  }
  - (void) fileDescriptorReady
  {
    if ( _streamStatus == SBStreamStatusOpening ) {
      int       fd_flags = fcntl(_socket, F_GETFL, 0);
      fcntl(_socket, F_SETFL, fd_flags & ~O_NONBLOCK);
      _streamStatus = SBStreamStatusOpen;
      [_inputStream syncStatusWithOutputStream];
    }
    _flags |= SBStreamFileFlagsWillNotBlock;
    [_delegate stream:self handleEvent:SBStreamEventSpaceAvailable];
  }
  - (void) fileDescriptorHasError:(int)errno
  {
    // Some kind of error, create a POSIX-domain SBError:
    if ( _streamError ) [_streamError release];
    _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
    _streamStatus = SBStreamStatusError;
    [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
  }
  
//

  - (size_t) write:(void*)buffer
    length:(size_t)length
  {
    size_t      actualWrite = 0;
    
    if ( (_streamStatus == SBStreamStatusOpening) && ! [self pollForConnectCompletion] )
      return 0;
    
    if ( (_streamStatus == SBStreamStatusOpen) && length ) {
      ssize_t   count;
      
      _streamStatus = SBStreamStatusWriting;
      _flags &= ~SBStreamFileFlagsWillNotBlock;
      count = write(_socket, buffer, length);
      if ( count == 0 ) {
        // End of file???
        _streamStatus = SBStreamStatusAtEnd;
        [_delegate stream:self handleEvent:SBStreamEventEndEncountered];
      } else if ( count < 0 ) {
        // Some kind of error, create a POSIX-domain SBError:
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
      } else {
        _streamStatus = SBStreamStatusOpen;
        actualWrite = count;
      }
    }
    return actualWrite;
  }
  
//

  - (BOOL) hasSpaceAvailable
  {
    if ( _flags & SBStreamFileFlagsWillNotBlock )
      return YES;
    if ( _streamStatus == SBStreamStatusOpen )
      return YES;
    if ( (_streamStatus == SBStreamStatusOpening) && [self pollForConnectCompletion] )
      return YES;
    return NO;
  }

//

  - (BOOL) pollForConnectCompletion
  {
    if ( _streamStatus == SBStreamStatusOpening ) {
      struct pollfd     pollSocket;
      
      pollSocket.fd = _socket;
      pollSocket.events = POLLOUT;
      pollSocket.revents = 0;
      if ( poll(&pollSocket, 1, 0) > 0 ) {
        int             local_errno;
        socklen_t       local_errno_size = sizeof(local_errno);
        
        if ( pollSocket.revents & POLLOUT ) {
          int       fd_flags = fcntl(_socket, F_GETFL, 0);
          fcntl(_socket, F_SETFL, fd_flags & ~O_NONBLOCK);
          _streamStatus = SBStreamStatusOpen;
          [_inputStream syncStatusWithOutputStream];
          return YES;
        }
        getsockopt(_socket, SOL_SOCKET, SO_ERROR, &local_errno, &local_errno_size);
        if ( _streamError ) [_streamError release];
        _streamError = [[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:local_errno supportingData:nil];
        _streamStatus = SBStreamStatusError;
        [_delegate stream:self handleEvent:SBStreamEventErrorOccurred];
        [_inputStream syncStatusWithOutputStream];
      }
    }
    return NO;
  }
  
//

  - (SBInputStream*) inputStream { return _inputStream; }

@end
