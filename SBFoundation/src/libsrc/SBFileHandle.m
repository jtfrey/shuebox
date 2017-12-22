//
// SBFoundation : ObjC Class Library for Solaris
// SBFileHandle.m
//
// Generalized interface to Unix file handles.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBFileHandle.h"
#import "SBFileManager.h"
#import "SBData.h"
#import "SBString.h"
#import "SBException.h"

SBString* const SBFileHandleOperationException = @"SBFileHandleOperationException";

//

typedef SBUInteger SBFileHandleCapabilities;
enum {
  SBFileHandleRead              = 1 << 0,
  SBFileHandleWrite             = 1 << 1,
  SBFileHandleShouldNotClose    = 1 << 2
};

//
#pragma mark -
//

@interface SBNullFileHandle : SBFileHandle

@end

@interface SBGenericFileHandle : SBFileHandle
{
  int                         _fileDescriptor;
  SBFileHandleCapabilities    _fileHandleCapabilities;
}

@end

//
#pragma mark -
//

@interface SBFileHandle(SBFileHandlePrivate)

- (void) setFileDescriptor:(int)fileDescriptor;

- (SBFileHandleCapabilities) fileHandleCapabilities;
- (void) setFileHandleCapabilities:(SBFileHandleCapabilities)fileHandleCapabilities;

@end

@implementation SBFileHandle(SBFileHandlePrivate)

  - (void) setFileDescriptor:(int)fileDescriptor
  {
  }

//

  - (SBFileHandleCapabilities) fileHandleCapabilities
  {
    return 0;
  }
  
//

  - (void) setFileHandleCapabilities:(SBFileHandleCapabilities)fileHandleCapabilities
  {
  }

@end

//

@implementation SBFileHandle

  - (void) dealloc
  {
    [self closeFile];
    [super dealloc];
  }

//

  - (BOOL) isReadable
  {
    return ( ([self fileHandleCapabilities] & SBFileHandleRead) ? YES : NO );
  }

//

  - (BOOL) isWritable
  {
    return ( ([self fileHandleCapabilities] & SBFileHandleWrite) ? YES : NO );
  }

//

  - (SBData*) availableData
  {
    if ( ([self fileHandleCapabilities] & SBFileHandleRead) )
      return [self readDataToEndOfFile];
    
    [SBException raise:SBFileHandleOperationException format:"Attempt to read data on a write-only file handle."];
  }

//

  - (SBData*) readDataToEndOfFile
  {
    if ( ([self fileHandleCapabilities] & SBFileHandleRead) ) {
      int                 fd = [self fileDescriptor];
      
      if ( fd < 0 )
        return nil;
      
      SBMutableData*      d = [[SBMutableData alloc] init];
      SBUInteger          offset = 0;
      char                buffer[256];
      
      while ( 1 ) {
        ssize_t           c;
        
        // Try a read:
        if ( (c = read(fd, buffer, sizeof(buffer))) < 0 ) {
          [d release];
          [SBException raise:SBFileHandleOperationException format:"Failed while reading data from file:  errno = %d", errno];
        }
        if ( c )
          [d appendBytes:buffer length:c];
        else
          break;
      }
      
      SBData*             result = [d copy];
      
      [d release];
      return result;
    }
    [SBException raise:SBFileHandleOperationException format:"Attempt to read data on a write-only file handle."];
  }
  
//

  - (SBData*) readDataOfLength:(SBUInteger)length
  {
    if ( ([self fileHandleCapabilities] & SBFileHandleRead) ) {
      int                 fd = [self fileDescriptor];
      
      if ( fd < 0 )
        return nil;
      SBMutableData*      d = [[SBMutableData alloc] init];
      SBUInteger          offset = 0;
      char                buffer[256];
      
      while ( length ) {
        ssize_t           c;
        
        // Try a read:
        if ( (c = read(fd, buffer, ( length > sizeof(buffer) ? sizeof(buffer) : length ))) < 0 ) {
          [d release];
          [SBException raise:SBFileHandleOperationException format:"Failed while reading data from file:  errno = %d", errno];
        }
        if ( c ) {
          [d appendBytes:buffer length:c];
          length -= c;
        } else
          break;
      }
      
      SBData*             result = [d copy];
      
      [d release];
      return result;
    }
    [SBException raise:SBFileHandleOperationException format:"Attempt to read data on a write-only file handle."];
  }
  
//

  - (void) writeData:(SBData*)data
  {
    if ( ([self fileHandleCapabilities] & SBFileHandleWrite) ) {
      SBUInteger          length = [data length], wrote;
      int                 fd = [self fileDescriptor];
      
      if ( fd < 0 )
        return;
      
      if ( length && ((wrote = write(fd, [data bytes], length)) < length) ) {
        [SBException raise:SBFileHandleOperationException format:"Attempt to write " SBUIntegerFormat " bytes, wrote only " SBUIntegerFormat " bytes.",
            length, wrote];
      }
    } else
      [SBException raise:SBFileHandleOperationException format:"Attempt to write data on a read-only file handle."];
  }
  
//

  - (SBFileOffset) offsetInFile
  {
    int                   fd = [self fileDescriptor];
    
    if ( fd < 0 )
      return (off_t)-1;
      
    off_t                 offset = lseek(fd, 0, SEEK_CUR);
    
    if ( offset == (off_t)-1 )
      [SBException raise:SBFileHandleOperationException format:"Unable to determine offset in file:  errno = %d", errno];
    return (SBFileOffset)offset;
  }
  
//

  - (SBFileOffset) seekToEndOfFile
  {
    int                   fd = [self fileDescriptor];
    
    if ( fd < 0 )
      return (off_t)-1;
      
    off_t                 offset = lseek(fd, 0, SEEK_END);
    
    if ( offset == (off_t)-1 )
      [SBException raise:SBFileHandleOperationException format:"Unable to move offset to end of file:  errno = %d", errno];
    return (SBFileOffset)offset;
  }
  
//

  - (void) seekToFileOffset:(SBFileOffset)offset
  {
    int                   fd = [self fileDescriptor];
    
    if ( fd < 0 )
      return;
      
    off_t                 result = lseek(fd, offset, SEEK_SET);
    
    if ( result == (off_t)-1 )
      [SBException raise:SBFileHandleOperationException format:"Unable to set offset in file:  errno = %d", errno];
  }
  
//

  - (void) truncateFileAtOffset:(SBFileOffset)offset
  {
    if ( ([self fileHandleCapabilities] & SBFileHandleWrite) ) {
      int                 fd = [self fileDescriptor];
      
      if ( fd < 0 )
        return;
        
      if ( ftruncate(fd, offset) != 0 )
        [SBException raise:SBFileHandleOperationException format:"Unable to trucate file to length " SBUIntegerFormat ":  errno = %d", offset, errno];
    } else
      [SBException raise:SBFileHandleOperationException format:"Attempt to truncate a read-only file handle."];
  }
  
//

  - (void) synchronizeFile
  {
    int                   fd = [self fileDescriptor];
    
    if ( fd < 0 )
      return;
      
    if ( fsync(fd) != 0 )
      [SBException raise:SBFileHandleOperationException format:"Unable to synchronize file:  errno = %d", errno];
  }
  
//

  - (void) closeFile
  {
    if ( ! ([self fileHandleCapabilities] & SBFileHandleShouldNotClose) ) {
      close([self fileDescriptor]);
      [self setFileDescriptor:-1];
    }
  }

@end

//

@implementation SBFileHandle(SBFileHandleCreation)

  + (id) fileHandleWithStandardInput
  {
    static SBFileHandle*  __stdinFileHandle = nil;
    
    if ( ! __stdinFileHandle ) {
      if ( (__stdinFileHandle = [[SBGenericFileHandle alloc] initWithFileDescriptor:STDIN_FILENO]) )
        [__stdinFileHandle setFileHandleCapabilities:SBFileHandleRead | SBFileHandleShouldNotClose];
    }
    return __stdinFileHandle;
  }
  
//

  + (id) fileHandleWithStandardOutput
  {
    static SBFileHandle*  __stdoutFileHandle = nil;
    
    if ( ! __stdoutFileHandle ) {
      if ( (__stdoutFileHandle = [[SBGenericFileHandle alloc] initWithFileDescriptor:STDOUT_FILENO]) )
        [__stdoutFileHandle setFileHandleCapabilities:SBFileHandleWrite | SBFileHandleShouldNotClose];
    }
    return __stdoutFileHandle;
  }
  
//

  + (id) fileHandleWithStandardError
  {
    static SBFileHandle*  __stderrFileHandle = nil;
    
    if ( ! __stderrFileHandle ) {
      if ( (__stderrFileHandle = [[SBGenericFileHandle alloc] initWithFileDescriptor:STDERR_FILENO]) )
        [__stderrFileHandle setFileHandleCapabilities:SBFileHandleWrite | SBFileHandleShouldNotClose];
    }
    return __stderrFileHandle;
  }
  
//

  + (id) fileHandleWithNullDevice
  {
    static SBFileHandle* __nullFileHandle = nil;
    
    if ( ! __nullFileHandle )
      __nullFileHandle = [[SBNullFileHandle alloc] init];
    return __nullFileHandle;
  }
  
//

  + (id) fileHandleForReadingAtPath:(SBString*)path
  {
    SBFileHandle*   newFileHandle = nil;
    int             fd = [[SBFileManager sharedFileManager] openPath:path withFlags:O_RDONLY mode:0666];
    
    if ( fd >= 0 ) {
      newFileHandle = [[[SBGenericFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] autorelease];
      
      if ( newFileHandle )
        [newFileHandle setFileHandleCapabilities:SBFileHandleRead];
    }
    return newFileHandle;
  }
  
//

  + (id) fileHandleForWritingAtPath:(SBString*)path
  {
    SBFileHandle*   newFileHandle = nil;
    int             fd = [[SBFileManager sharedFileManager] openPath:path withFlags:O_WRONLY|O_CREAT mode:0666];
    
    if ( fd >= 0 ) {
      newFileHandle = [[[SBGenericFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] autorelease];
      
      if ( newFileHandle )
        [newFileHandle setFileHandleCapabilities:SBFileHandleWrite];
    }
    return newFileHandle;
  }
  
//

  + (id) fileHandleForUpdatingAtPath:(SBString*)path
  {
    SBFileHandle*   newFileHandle = nil;
    int             fd = [[SBFileManager sharedFileManager] openPath:path withFlags:O_RDWR|O_CREAT mode:0666];
    
    if ( fd >= 0 ) {
      newFileHandle = [[[SBGenericFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES] autorelease];
      
      if ( newFileHandle )
        [newFileHandle setFileHandleCapabilities:SBFileHandleRead | SBFileHandleWrite];
    }
    return newFileHandle;
  }

@end

//

@implementation SBFileHandle(SBFileHandleUnixSpecific)

  - (id) initWithFileDescriptor:(int)fd
  {
    return [self initWithFileDescriptor:fd closeOnDealloc:NO];
  }

//

  - (id) initWithFileDescriptor:(int)fd
    closeOnDealloc:(BOOL)shouldClose
  {
    if ( (self = [super init]) ) {
      [self setFileDescriptor:fd];
      [self setFileHandleCapabilities:SBFileHandleRead | SBFileHandleWrite | (shouldClose ? 0 : SBFileHandleShouldNotClose)];
    }
    return self;
  }

//

  - (int) fileDescriptor
  {
    return -1;
  }

@end

//
#pragma mark -
//

@implementation SBNullFileHandle

  - (SBData*) readDataToEndOfFile
  {
    // Return zero-length data, indicating end of file:
    return [SBData data];
  }
  
//

  - (SBData*) readDataOfLength:(SBUInteger)length
  {
    // Return zero-length data, indicating end of file:
    return [SBData data];
  }
  
//

  - (void) writeData:(SBData*)data
  {
    // No op
  }

//

  - (SBFileHandleCapabilities) fileHandleCapabilities
  {
    return SBFileHandleRead | SBFileHandleWrite | SBFileHandleShouldNotClose;
  }

@end

//
#pragma mark -
//

@implementation SBGenericFileHandle

  - (int) fileDescriptor { return _fileDescriptor; }
  - (void) setFileDescriptor:(int)fileDescriptor
  {
    _fileDescriptor = fileDescriptor;
  }
  
//
 
  - (SBFileHandleCapabilities) fileHandleCapabilities { return _fileHandleCapabilities; }
  - (void) setFileHandleCapabilities:(SBFileHandleCapabilities)fileHandleCapabilities
  {
    _fileHandleCapabilities = fileHandleCapabilities;
  }

@end

//
#pragma mark -
//

@implementation SBPipe

  + (id) pipe
  {
    return [[[SBPipe alloc] init] autorelease];
  }

//

  - (id) init
  {
    int           fd[2];
    
    if ( (self = [super init]) ) {
      if ( pipe(fd) != 0 ) {
        [self release];
        self = nil;
      } else {
        _fileHandleForReading = [[SBGenericFileHandle alloc] initWithFileDescriptor:fd[0] closeOnDealloc:YES];
        _fileHandleForWriting = [[SBGenericFileHandle alloc] initWithFileDescriptor:fd[1] closeOnDealloc:YES];
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _fileHandleForReading ) [_fileHandleForReading release];
    if ( _fileHandleForWriting ) [_fileHandleForWriting release];
    [super dealloc];
  }

//

  - (SBFileHandle*) fileHandleForReading { return _fileHandleForReading; }
  - (SBFileHandle*) fileHandleForWriting { return _fileHandleForWriting; }

@end

