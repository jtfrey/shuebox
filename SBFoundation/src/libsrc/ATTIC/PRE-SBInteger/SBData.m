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
#import "SBException.h"

SBString* SBDataBadIndexException = @"SBDataBadIndexException";
SBString* SBDataMemoryException = @"SBDataMemoryException";

@interface SBDataSubData : SBData
{
  SBData*         _parentData;
  SBRange         _range;
}

+ (id) subDataWithParentData:(SBData*)parentData range:(SBRange)range;
- (id) initWithParentData:(SBData*)parentData range:(SBRange)range;

@end

@interface SBConcreteData : SBData
{
  const void*     _bytes;
  size_t          _length;
  unsigned int    _storedHash;
  struct {
    unsigned int  freeWhenDone : 1;
    unsigned int  hashCalculated : 1;
  } _flags;
}

@end

@interface SBConcreteDataSubData : SBConcreteData
{
  SBData*         _parentData;
}

+ (id) subDataWithParentData:(SBData*)parentData range:(SBRange)range;
- (id) initWithParentData:(SBData*)parentData range:(SBRange)range;

@end

@interface SBConcreteMutableData : SBMutableData
{
  void*           _bytes;
  size_t          _length, _capacity;
  unsigned int    _storedHash;
  struct {
    unsigned int  freeWhenDone : 1;
    unsigned int  externalBuffer : 1;
    unsigned int  hashCalculated : 1;
  } _flags;
}

@end

//
#pragma mark -
//

@implementation SBDataSubData

  + (id) subDataWithParentData:(SBData*)parentData
    range:(SBRange)range
  {
    return [[[self alloc] initWithParentData:parentData range:range] autorelease];
  }

//

  - (id) initWithParentData:(SBData*)parentData
    range:(SBRange)range
  {
    if ( (self = [super init]) ) {
      size_t      len = [parentData length];
      
      _parentData = [parentData retain];
      if ( range.start >= len ) {
        range = SBRangeCreate(0,-1);
      } else if ( SBRangeMax(range) > len ) {
        range.length = len - range.start;
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _parentData ) [_parentData release];
    [super dealloc];
  }

//

  - (const void*) bytes
  {
    return ([_parentData bytes] + _range.start);
  }
  
//

  - (size_t) length
  {
    return _range.length;
  }

@end

//
#pragma mark -
//

@implementation SBConcreteData

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    if ( (self = [self init]) ) {
      _bytes = bytes;
      _length = length;
      _flags.freeWhenDone = freeWhenDone;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _bytes && _length && _flags.freeWhenDone )
      objc_free((void*)_bytes);
    [super dealloc];
  }
  
//

  - (unsigned int) hash
  {
    if ( ! _flags.hashCalculated ) {
      _storedHash = 0;
      if ( _length )
        _storedHash = [self hashForData:_bytes byteLength:_length];
      _flags.hashCalculated = YES;
    }
    return _storedHash;
  }
  
//

  - (size_t) length { return _length; }
  - (const void*) bytes { return _bytes; }

//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
  {
    if ( _length < length )
      length = _length;
    memcpy(buffer, _bytes, length);
  }
  
//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
    offset:(size_t)offset
  {
    const void*     ptr = _bytes;
    size_t          len = _length;
    
    if ( offset >= len )
      return;
    ptr += offset;
    len -= offset;
    if ( len < length )
      length = len;
    memcpy(buffer, ptr, length);
  }

//

  - (BOOL) isEqualToData:(SBData*)otherData
  {
    if ( _length == [otherData length] ) {
      if ( memcmp(_bytes, [otherData bytes], _length) == 0 )
        return YES;
    }
    return NO;
  }
  
//
  
  - (SBData*) subdataWithRange:(SBRange)range
  {
    return [SBConcreteDataSubData subDataWithParentData:self range:range];
  }

@end

//
#pragma mark -
//

@implementation SBConcreteDataSubData

  + (id) subDataWithParentData:(SBData*)parentData
    range:(SBRange)range
  {
    return [[[self alloc] initWithParentData:parentData range:range] autorelease];
  }

//

  - (id) initWithParentData:(SBData*)parentData
    range:(SBRange)range
  {
    if ( (self = [super init]) ) {
      const void*   ptr = [parentData bytes];
      size_t        len = [parentData length];
      
      _parentData = [parentData retain];
      if ( range.start >= len ) {
        range = SBRangeCreate(0,-1);
      } else if ( SBRangeMax(range) > len ) {
        range.length = len - range.start;
      }
      self = [self initWithBytesNoCopy:ptr + range.start length:range.length freeWhenDone:NO];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parentData ) [_parentData release];
    [super dealloc];
  }

@end

//
#pragma mark -
//

static SBConcreteData* __SBNullData = nil;

@implementation SBData

  + (id) initialize
  {
    if ( self == [SBData class] ) {
      __SBNullData = [[SBConcreteData alloc] init];
    }
  }

//

  + (id) alloc
  {
    /* If SBData is being asked to alloc, then alloc an SBConcreteData;
       otherwise, pass along the usual object alloc: */
    if ( self == [SBData class] )
      return [SBConcreteData alloc];
    return [super alloc];
  }

//

  - (id) copy
  {
    return [self retain];
  }

//

  - (id) mutableCopy
  {
    return [[SBConcreteMutableData alloc] initWithData:self];
  }

//

  - (unsigned int) hash
  {
    const void*     ptr = [self bytes];
    size_t          len = [self length];
    
    if ( ptr && len )
      return [self hashForData:ptr byteLength:len];
    return 0;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    const uint8_t*  _bytes = (const uint8_t*)[self bytes];
    size_t          _length = [self length];
    size_t          c = 0;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  length:   %d\n"
        "  hash:     %08X\n"
        "  bytes:    ",
        _length,
        [self hash]
      );
    while ( c < _length ) {
      fprintf(stream, "%02hhX ", *_bytes);
      _bytes++;
      if ( ++c % 16 == 0 )
        fprintf(stream, "\n            ");
    }
    if ( c % 16 )
      fprintf(stream, "\n}\n");
    else
      fprintf(stream, "}\n");
  }
  
//

  - (size_t) length { return 0; }
  
//

  - (const void*) bytes { return NULL; }

@end

@implementation SBData(SBDataCreation)

  + (id) data
  {
    return __SBNullData;
  }
  
//

  + (id) dataWithBytes:(const void*)bytes
    length:(size_t)length
  {
    return [[[self alloc] initWithBytes:bytes length:length] autorelease];
  }
  
//

  + (id) dataWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
  {
    return [[[self alloc] initWithBytesNoCopy:bytes length:length] autorelease];
  }
  
//

  + (id) dataWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [[[self alloc] initWithBytesNoCopy:bytes length:length freeWhenDone:freeWhenDone] autorelease];
  }
  
//

  + (id) dataWithContentsOfFile:(SBString*)path
  {
    return [[[self alloc] initWithContentsOfFile:path] autorelease];
  }
  
//

  + (id) dataWithData:(SBData*)otherData
  {
    return [[[self alloc] initWithData:otherData] autorelease];
  }
  
//

  - (id) init
  {
    return [super init];
  }

//

  - (id) initWithBytes:(const void*)bytes
    length:(size_t)length
  {
    const void*     ptr = NULL;
    
    if ( bytes && length ) {
      if ( (ptr = objc_malloc(length)) ) {
        memcpy((void*)ptr, bytes, length);
      } else {
        [self release];
        self = nil;
      }
    }
    if ( self )
      self = [self initWithBytesNoCopy:ptr length:length freeWhenDone:YES];
    return self;
  }
  
//

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
  {
    return [self initWithBytesNoCopy:bytes length:length freeWhenDone:NO];
  }
  
//

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [self init];
  }
  
//

  - (id) initWithContentsOfFile:(SBString*)path
  {
    SBSTRING_AS_UTF8_BEGIN(path)
      int   fd = open(path_utf8, O_RDONLY);
      
      if ( fd >= 0 ) {
        off_t   eof = lseek(fd, 0, SEEK_END);
        char*   buffer = NULL;
        
        if ( eof ) {
          if ( ! (buffer = objc_malloc(eof)) ) {
            close(fd);
            [SBException raise:SBDataMemoryException format:"Unable to allocate memory."];
          }
          if ( read(fd, buffer, eof) != eof ) {
            [self release];
            return nil;
          }
        }
        self = [self initWithBytesNoCopy:buffer length:eof freeWhenDone:YES];
        
      }
    SBSTRING_AS_UTF8_END
        
    return self;
  }
  
//

  - (id) initWithData:(SBData*)otherData
  {
    return [self initWithBytes:[otherData bytes] length:[otherData length]];
  }

@end

@implementation SBData(SBExtendedData)

  - (void) getBytes:(void*)buffer
    length:(size_t)length
  {
    const void*     ptr = [self bytes];
    size_t          len = [self length];
    
    if ( len < length )
      length = len;
    memcpy(buffer, ptr, length);
  }
  
//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
    offset:(size_t)offset
  {
    const void*     ptr = [self bytes];
    size_t          len = [self length];
    
    if ( offset >= len )
      return;
    ptr += offset;
    len -= offset;
    if ( len < length )
      length = len;
    memcpy(buffer, ptr, length);
  }

//

  - (BOOL) isEqualToData:(SBData*)otherData
  {
    if ( [self length] == [otherData length] ) {
      const void*   p1 = [self bytes];
      const void*   p2 = [otherData bytes];
      
      if ( memcmp(p1, p2, [self length]) == 0 )
        return YES;
    }
    return NO;
  }
  
//
  
  - (SBData*) subdataWithRange:(SBRange)range
  {
    return [SBDataSubData subDataWithParentData:self range:range];
  }

@end

//
#pragma mark -
//

@implementation SBMutableData

  + (id) alloc
  {
    /* If SBMutableData is being asked to alloc, then alloc an SBConcreteMutableData;
       otherwise, pass along the usual object alloc: */
    if ( self == [SBMutableData class] )
      return [SBConcreteMutableData alloc];
    return [super alloc];
  }

//

  + (id) data
  {
    return [[[self alloc] initWithCapacity:0] autorelease];
  }
  
//

  - (id) init
  {
    return [self initWithCapacity:0];
  }

//

  - (id) initWithBytes:(const void*)bytes
    length:(size_t)length
  {
    if ( (self = [self initWithCapacity:length]) )
      [self appendBytes:bytes length:length];
    return self;
  }
  
//

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [self initWithBytes:bytes length:length];
  }
  
//

  - (id) initWithContentsOfFile:(SBString*)path
  {
    int       fd = -1;
    
    TRY_BEGIN
      SBSTRING_AS_UTF8_BEGIN(path)
        if ( (fd = open(path_utf8, O_RDONLY)) >= 0 ) {
          off_t   eof = lseek(fd, 0, SEEK_END);
          
          if ( (self = [self initWithLength:eof]) ) {
            if ( eof ) {
              if ( read(fd, (char*)[self mutableBytes], eof) != eof ) {
                [self release];
                self = nil;
              }
            }
          }
          close(fd);
        }
      
      SBSTRING_AS_UTF8_END
    TRY_CATCH(dataException)
      
      // This would be an exception coming from initWithLength; cleanup
      // the file and re-raise the exception:
      if ( fd != -1 )
        close(fd);
      [dataException raise];
      
    TRY_END
    
    return self;
  }
  
//

  - (id) copy
  {
    return [[SBData alloc] initWithBytes:[self mutableBytes] length:[self length]];
  }

//

  - (const void*) bytes
  {
    return (const void*)[self mutableBytes];
  }

//

  - (void) setLength:(size_t)length
  {
    [SBException raise:SBDataMemoryException format:"Unable to allocate memory."];
  }
  
//

  - (void*) mutableBytes
  {
    return NULL;
  }

@end

@implementation SBMutableData(SBMutableDataCreation)

  + (id) dataWithCapacity:(size_t)capacity
  {
    return [[[self alloc] initWithCapacity:capacity] autorelease];
  }
  
//

  + (id) dataWithLength:(size_t)length
  {
    return [[[self alloc] initWithLength:length] autorelease];
  }
  
//

  - (id) initWithCapacity:(size_t)capacity
  {
    return [super init];
  }
  
//

  - (id) initWithLength:(size_t)length
  {
    if ( (self = [self initWithCapacity:length]) ) {
      [self setLength:length];
    }
    return self;
  }

@end

@implementation SBMutableData(SBExtendedMutableData)

  - (void) replaceBytesInRange:(SBRange)range
    withData:(SBData*)aData
  {
    [self replaceBytesInRange:range withBytes:( aData ? [aData bytes] : NULL ) length:( aData ? [aData length] : 0 )];
  }
  
//

  - (void) replaceBytesInRange:(SBRange)range
    withBytes:(const void*)bytes
    length:(size_t)length
  {
    void*         _bytes = [self mutableBytes];
    size_t        _length = [self length];
      
    if ( SBRangeMax(range) > _length )
      [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
    
    if ( _length ) {
      size_t          newLen = _length - (range.length - length);
      unsigned int    end = SBRangeMax(range);
      
      //
      // If we're replacing with MORE characters than the buffer will hold,
      // then we need to resize the buffer.  Otherwise, we're merely doing
      // a memmove and (possibly) a memcpy.
      //
      if ( range.length  >= length ) {
        // Shift some data:
        if ( range.length != length )
          memmove(_bytes + range.start + length, _bytes + end, _length - end + 1);
        
        // Copy-in the new characters:
        if ( length )
          memcpy(_bytes + range.start, bytes, length);
        
        // Note the new size:
        [self setLength:newLen];
      } else {
        // Gotta grow, first:
        [self setLength:newLen];
        _bytes = [self mutableBytes];
        
        // Move data up off the original end to make room for the incoming
        // chars:
        if ( range.start + length  < end )
          memmove(_bytes + range.start + length, _bytes + end, _length - end + 1);
        
        // Insert the new chars:
        if ( length )
          memcpy(_bytes + range.start, bytes, length);
      }
      
    } else if ( length ) {
      //
      // We don't yet have a buffer, so just make a duplicate copy of bytes
      // and reset all flags accordingly:
      //
      [self setLength:length];
      memcpy([self mutableBytes], bytes, length);
    }
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
    if ( length ) {
      void*           _bytes;
      size_t          _length = [self length];
      size_t          newLen = _length + length;
      
      // Gotta grow, first:
      [self setLength:newLen];
      _bytes = [self mutableBytes];
      
      // Insert the new bytes:
      memcpy(_bytes + _length, bytes, length);
    }
  }
  
//

  - (void) insertData:(SBData*)aData
    atIndex:(unsigned int)index
  {
    [self insertBytes:[aData bytes] length:[aData length] atIndex:index];
  }

//

  - (void) insertBytes:(const void*)bytes
    length:(size_t)length
    atIndex:(unsigned int)index
  {
    if ( length ) {
      void*         _bytes;
      size_t        _length = [self length];
      size_t        newLen = _length + length;
        
      if ( index > _length )
        [SBException raise:SBDataBadIndexException format:"Byte index exceeds limits of data object."];
      
      // Gotta grow, first:
      [self setLength:newLen];
      _bytes = [self mutableBytes];
      
      // Shift existing data when necessary:
      if ( index < _length )
        memmove(_bytes + index + length, _bytes + index, length);
      
      // Insert the new bytes:
      memcpy(_bytes + index, bytes, length);
    }
  }

//

  - (void) deleteBytesInRange:(SBRange)range
  {
    if ( range.length ) {
      void*         _bytes = [self mutableBytes];
      size_t        _length = [self length];
      unsigned int  end = SBRangeMax(range);
      
      if ( end > _length )
        [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
    
      // Shift existing data when necessary:
      if ( end < _length )
        memmove(_bytes + range.start, _bytes + end, _length - end + 1);
      
      // Shrink:
      [self setLength:_length - range.length];
    }
  }

//

  - (void) resetBytesInRange:(SBRange)range
  {
    if ( range.length ) {
      void*       _bytes = [self mutableBytes];
      size_t      _length = [self length];
      
      if ( SBRangeMax(range) > _length )
        [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
      memset(_bytes + range.start, 0, range.length);
    }
  }

//

  - (void) setData:(SBData*)aData
  {
    [self replaceBytesInRange:SBRangeCreate(0, [self length]) withData:aData];
  }

@end

//
#pragma mark -
//

@implementation SBConcreteMutableData

  - (id) initWithCapacity:(size_t)capacity
  {
    if ( (self = [super initWithCapacity:capacity]) ) {
      if ( capacity ) {
        if ( ! (_bytes = objc_malloc(capacity)) ) {
          [self release];
          [SBException raise:SBDataMemoryException format:"Unable to allocate initial capacity of data object."];
        }
        _capacity = capacity;
      }
    }
    return self;
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    length:(size_t)length
  {
    if ( (self = [self initWithCapacity:length]) ) {
      [self appendBytes:bytes length:length];
    }
    return self;
  }

//

  - (id) initWithBytesNoCopy:(const void*)bytes
    length:(size_t)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    if ( (self = [self init]) ) {
      _bytes = (void*)bytes;
      _capacity = _length = length;
      _flags.freeWhenDone = freeWhenDone;
      _flags.externalBuffer = YES;
    }
    return self;
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
      _storedHash = 0;
      if ( _length )
        _storedHash = [self hashForData:_bytes byteLength:_length];
      _flags.hashCalculated = YES;
    }
    return _storedHash;
  }
  
//

  - (size_t) length { return _length; }
  - (const void*) bytes { return (const void*)_bytes; }
  
//

  - (void) setLength:(size_t)length
  {
    if ( length <= _capacity ) {
      // Easy one:  we already have space allocated:
      if ( length > _length )
        memset(_bytes + _length, 0, length - _length);
      _length = length;
    } else if ( ! _flags.externalBuffer ) {
      // We need to reallocate to the new length:
      void*       newBytes;
      size_t      capacity = length;
      int         grain = getpagesize();
      
      // Round the requested size?
      if ( length > (4 * grain) )
        capacity = grain * ((length / grain) + ((length % grain) ? 1 : 0));
      
      // Allocate/reallocate:
      newBytes = ( _bytes ? objc_realloc(_bytes, capacity) : objc_malloc(capacity) );
      if ( ! newBytes )
        [SBException raise:SBDataMemoryException format:"Unable to extend length of binary data."];
      
      _bytes = newBytes;
      _capacity = capacity;
      
      // Set new chunk of bytes before we change _length:
      memset(_bytes + _length, 0, length - _length);
      
      _length = length;
    } else {
      [SBException raise:SBDataMemoryException format:"Unable to grow external memory buffer."];
    }
    _flags.hashCalculated = NO;
  }

//

  - (void*) mutableBytes { return _bytes; }

//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
  {
    if ( _length ) {
      if ( _length < length )
        length = _length;
      memcpy(buffer, _bytes, length);
    }
  }
  
//

  - (void) getBytes:(void*)buffer
    length:(size_t)length
    offset:(size_t)offset
  {
    if ( _length ) {
      const void*     ptr = _bytes;
      size_t          len = _length;
      
      if ( offset >= len )
        return;
      ptr += offset;
      len -= offset;
      if ( len < length )
        length = len;
      memcpy(buffer, ptr, length);
    }
  }

//

  - (BOOL) isEqualToData:(SBData*)otherData
  {
    if ( _length == [otherData length] ) {
      if ( memcmp((const void*)_bytes, [otherData bytes], _length) == 0 )
        return YES;
    }
    return NO;
  }
  
//
  
  - (SBData*) subdataWithRange:(SBRange)range
  {
    if ( SBRangeMax(range) > _length )
      [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
    return [[[SBConcreteData alloc] initWithBytes:_bytes + range.start length:range.length] autorelease];
  }

//

  - (void) replaceBytesInRange:(SBRange)range
    withBytes:(const void*)bytes
    length:(size_t)length
  {
    if ( SBRangeMax(range) > _length )
      [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
    
    if ( _length ) {
      size_t          newLen = _length - (range.length - length);
      unsigned int    end = SBRangeMax(range);
      
      //
      // If we're replacing with MORE characters than the buffer will hold,
      // then we need to resize the buffer.  Otherwise, we're merely doing
      // a memmove and (possibly) a memcpy.
      //
      if ( range.length  >= length ) {
        // Shift some data:
        if ( range.length != length )
          memmove(_bytes + range.start + length, _bytes + end, _length - end + 1);
        
        // Copy-in the new characters:
        if ( length )
          memcpy(_bytes + range.start, bytes, length);
        
        // Note the new size:
        [self setLength:newLen];
      } else {
        // Gotta grow, first:
        [self setLength:newLen];
        _bytes = [self mutableBytes];
        
        // Move data up off the original end to make room for the incoming
        // chars:
        if ( range.start + length  < end )
          memmove(_bytes + range.start + length, _bytes + end, _length - end + 1);
        
        // Insert the new chars:
        if ( length )
          memcpy(_bytes + range.start, bytes, length);
      }
      
    } else if ( length ) {
      //
      // We don't yet have a buffer, so just make a duplicate copy of bytes
      // and reset all flags accordingly:
      //
      [self setLength:length];
      memcpy(_bytes, bytes, length);
    }
  }

//

  - (void) appendBytes:(const void*)bytes
    length:(size_t)length
  {
    if ( length ) {
      size_t          origLen = _length;
      size_t          newLen = _length + length;
      
      if ( newLen <= _capacity ) {
        _length = newLen;
        _flags.hashCalculated = NO;
      } else {
        // Gotta grow, first:
        [self setLength:newLen];
      }
      // Insert the new bytes:
      memcpy(_bytes + origLen, bytes, length);
    }
  }
  
//

  - (void) insertBytes:(const void*)bytes
    length:(size_t)length
    atIndex:(unsigned int)index
  {
    if ( length ) {
      size_t        origLen = _length;
      size_t        newLen = _length + length;
        
      if ( index > _length )
        [SBException raise:SBDataBadIndexException format:"Byte index exceeds limits of data object."];
      
      if ( newLen <= _capacity ) {
        _length = newLen;
        _flags.hashCalculated = NO;
        
        // Shift existing data when necessary:
        if ( index < origLen )
          memmove(_bytes + index + length, _bytes + index, length);
        
        // Insert the new bytes:
        memcpy(_bytes + index, bytes, length);
      } else {
        // Gotta grow, first:
        [self setLength:newLen];
        
        // Shift existing data when necessary:
        if ( index < origLen )
          memmove(_bytes + index + length, _bytes + index, length);
        
        // Insert the new bytes:
        memcpy(_bytes + index, bytes, length);
      }
    }
  }

//

  - (void) deleteBytesInRange:(SBRange)range
  {
    if ( range.length ) {
      unsigned int  end = SBRangeMax(range);
      
      if ( end > _length )
        [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
    
      // Shift existing data when necessary:
      if ( end < _length )
        memmove(_bytes + range.start, _bytes + end, _length - end + 1);
      
      // Shrink:
      _length -= range.length;
      _flags.hashCalculated = NO;
    }
  }

//

  - (void) resetBytesInRange:(SBRange)range
  {
    if ( range.length ) {
      if ( SBRangeMax(range) > _length )
        [SBException raise:SBDataBadIndexException format:"Byte range exceeds limits of data object."];
      memset(_bytes + range.start, 0, range.length);
      _flags.hashCalculated = NO;
    }
  }

//

  - (void) setData:(SBData*)aData
  {
    size_t      length = [aData length];
    
    if ( length <= _capacity ) {
      if ( length )
        memcpy(_bytes, [aData bytes], length);
      _length = length;
      _flags.hashCalculated = NO;
    } else {
      [self setLength:length];
      if ( length )
        memcpy(_bytes, [aData bytes], length);
    }
  }

@end
