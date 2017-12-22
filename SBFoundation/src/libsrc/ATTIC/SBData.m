//
// SBFoundation : ObjC Class Library for Solaris
// SBData.h
//
// Class that wraps basic binary data.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBData.h"
#import "SBString.h"

@interface SBData(SBDataPrivate)

- (BOOL) growToByteLength:(size_t)newSize;
- (void) replaceBytesInRange:(SBRange)range withBytes:(void*)altBytes length:(size_t)altLen;

@end

@implementation SBData(SBDataPrivate)

  - (BOOL) growToByteLength:(size_t)newSize
  {
    if ( _flags.ownsBuffer ) {
      void*      p = NULL;

      if ( _bytes ) {
        if ( ( p = (void*) objc_realloc(_bytes, newSize) ) ) {
          // Make sure we zero-out the added bytes:
          bzero(p + _allocLength, newSize - _allocLength);
        }
      } else {
        p = (void*) objc_calloc(1, newSize);
      }
      if ( p ) {
        _bytes = p;
        _allocLength = newSize;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (void) replaceBytesInRange:(SBRange)range
    withBytes:(void*)altBytes
    length:(size_t)altLen
  {
    if ( _bytes ) {
      size_t          newLen = _length - (range.length - altLen);
      unsigned int    end = SBRangeMax(range);
      
      //
      // If we're replacing with MORE characters than the buffer will hold,
      // then we need to resize the buffer.  Otherwise, we're merely doing
      // a memmove and (possibly) a memcpy.
      //
      if ( (range.length  >= altLen) || (_allocLength >= newLen) ) {
        // Shift some data:
        if ( range.length != altLen )
          memmove(_bytes + range.start + altLen, _bytes + end, _length - end + 1);
        
        // Copy-in the new characters:
        if ( altLen )
          memcpy(_bytes + range.start, altBytes, altLen);
        
        // Done, reset flags accordingly:
        _length = newLen;
        _flags.hashCalculated = NO;
      } else if ( [self growToByteLength:newLen] ) {
        // Move data up off the original end to make room for the incoming
        // chars:
        if ( range.start + altLen  < end )
          memmove(_bytes + range.start + altLen, _bytes + end, _length - end + 1);
        
        // Insert the new chars:
        if ( altLen )
          memcpy(_bytes + range.start, altBytes, altLen);
        
        // Done, reset flags accordingly:
        _length = newLen;
        _flags.hashCalculated = NO;
      }
      
    } else if ( altBytes && altLen ) {
      //
      // We don't yet have a buffer, so just make a duplicate copy of altBytes
      // and reset all flags accordingly:
      //
      if ( [self growToByteLength:altLen] ) {
        memcpy(_bytes, altBytes, altLen);
        _length = altLen;
        _flags.hashCalculated = NO;
      }
    }
  }

@end

//
#pragma mark -
//

@implementation SBData

  + (SBData*) emptyData
  {
    static SBData* sharedEmptyInstance = nil;
    
    if ( sharedEmptyInstance == nil )
      sharedEmptyInstance = [[SBData alloc] initWithBytesNoCopy:"" length:0];
    return sharedEmptyInstance;
  }
  
//

  + (SBData*) data
  {
    return [[[SBData alloc] init] autorelease];
  }

//

  + (SBData*) dataWithCapacity:(size_t)length
  {
    return [[[SBData alloc] initWithCapacity:length] autorelease];
  }

//

  + (SBData*) dataWithBytes:(const void*)bytes
    length:(size_t)length
  {
    return [[[SBData alloc] initWithBytes:bytes length:length] autorelease];
  }
  
//

  + (SBData*) dataWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
  {
    return [[[SBData alloc] initWithBytesNoCopy:bytes length:length] autorelease];
  }
  
//

  + (SBData*) dataWithContentsOfFile:(SBString*)path
  {
    return [[[SBData alloc] initWithContentsOfFile:path] autorelease];
  }

//

  - (id) init
  {
    if ( self = [super init] )
      _flags.freeWhenDone = _flags.ownsBuffer = YES;
    return self;
  }

//

  - (id) initWithCapacity:(size_t)length
  {
    if ( self = [self init] ) {
      if ( ! [self growToByteLength:length] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithBytes:(const void*)bytes
    length:(size_t)length
  {
    if ( self = [self initWithCapacity:length] ) {
      [self appendBytes:bytes length:length];
    }
    return self;
  }

//

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
  {
    if ( self = [self init] ) {
      _bytes = (void*)bytes;
      _length = length;
      _allocLength = length;
      _flags.ownsBuffer = _flags.freeWhenDone = NO;
    }
    return self;
  }

//

  - (id) initWithContentsOfFile:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
    
      int       fd = open(path_utf8, O_RDONLY);
      
      if ( fd >= 0 ) {
        off_t   eof = lseek(fd, 0, SEEK_END);
        
        if ( eof > 0 ) {
          if ( self = [self initWithCapacity:eof] ) {
            if ( read(fd, (char*)[self bytes], eof) != eof ) {
              [self release];
              self = nil;
            }
          }
        } else {
          [self release];
          self = nil;
        }
        close(fd);
      }
    
    SBSTRING_AS_UTF8_END
    
    [self release];
    return nil;
  }

//

  - (void) dealloc
  {
    if ( _bytes && _flags.freeWhenDone )
      objc_free(_bytes);
    [super dealloc];
  }

//

  - (unsigned int) hash
  {
    if ( ! _flags.hashCalculated ) {
      _storedHash = [self hashForData:_bytes byteLength:_length];
      _flags.hashCalculated = YES;
    }
    return _storedHash;
  }

//

  - (BOOL) isEqual:(id)anObject
  {
    if ( [anObject isKindOf:[SBData class]] && (_length == [anObject length]) ) {
      if ( _bytes )
        return ( (memcmp(_bytes, [anObject bytes], _length) == 0) ? YES : NO );
      else
        return YES;
    }
    return NO;
  }

//

  - (size_t) length
  {
    return _length;
  }

//

  - (const void*) bytes
  {
    return _bytes;
  }

//

  - (void) getBytes:(void*)buffer
  {
    [self getBytes:buffer length:_length offset:0];
  }
  
//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
  {
    [self getBytes:buffer length:length offset:0];
  }
  
//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
    offset:(size_t)offset
  {
    memcpy(buffer, _bytes + offset, length);
  }

//

  - (void) replaceBytesInRange:(SBRange)range
    withData:(SBData*)aData
  {
    [self replaceBytesInRange:range withBytes:(void*)[aData bytes] length:[aData length]];
  }

//

  - (void) appendData:(SBData*)aData
  {
    [self replaceBytesInRange:SBRangeCreate([self length],0) withData:aData];
  }
  
//

  - (void) appendBytes:(const void*)bytes
    length:(size_t)length
  {
    [self replaceBytesInRange:SBRangeCreate([self length],0) withBytes:(void*)bytes length:length];
  }

//

  - (void) insertData:(SBData*)aData
    atIndex:(unsigned int)index
  {
    [self replaceBytesInRange:SBRangeCreate(index,0) withData:aData];
  }

//

  - (void) insertBytes:(const void*)bytes
    length:(size_t)length
    atIndex:(unsigned int)index
  {
    [self replaceBytesInRange:SBRangeCreate(index,0) withBytes:(void*)bytes length:length];
  }
    
//

  - (void) deleteBytesInRange:(SBRange)range
  {
    [self replaceBytesInRange:range withBytes:"" length:0];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    char*     p = _bytes;
    size_t    c = 0;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  capacity: %d\n"
        "  length:   %d\n"
        "  hash:     %08X\n"
        "  bytes:    ",
        _allocLength,
        _length,
        [self hash]
      );
    while ( c < _length ) {
      fprintf(stream, "%02hhX ", *p);
      p++;
      if ( ++c % 16 == 0 )
        fprintf(stream, "\n            ");
    }
    if ( c % 16 )
      fprintf(stream, "\n}\n");
    else
      fprintf(stream, "}\n");
  }

@end
