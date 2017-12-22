//
// SBFoundation : ObjC Class Library for Solaris
// SBData.h
//
// Class that wraps plain ol' binary data.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString;

/*!
  @class SBData
  @discussion
  Instances of SBData wrap arbitrary-size chunks of binary data.
*/
@interface SBData : SBObject
{
  size_t          _length;
  size_t          _allocLength;
  void*           _bytes;
  unsigned int    _storedHash;
  struct {
    unsigned int  freeWhenDone : 1;
    unsigned int  ownsBuffer : 1;
    unsigned int  hashCalculated : 1;
  } _flags;
}

+ (SBData*) emptyData;
+ (SBData*) data;
+ (SBData*) dataWithCapacity:(size_t)length;
+ (SBData*) dataWithBytes:(const void*)bytes length:(size_t)length;
+ (SBData*) dataWithBytesNoCopy:(const void*)bytes length:(size_t)length;
+ (SBData*) dataWithContentsOfFile:(SBString*)path;

- (id) init;
- (id) initWithCapacity:(size_t)length;
- (id) initWithBytes:(const void*)bytes length:(size_t)length;
- (id) initWithBytesNoCopy:(const void*)bytes length:(size_t)length;
- (id) initWithContentsOfFile:(SBString*)path;

/*!
  @method length
  
  Return the length (in bytes) of the data held by the receiver.
*/
- (size_t) length;
/*!
  @method bytes
  
  Returns a pointer to the data held by the receiver.
*/
- (const void*) bytes;
/*!
  @method getBytes:
  
  Copy the entire byte range of the receiver's data into "buffer".
*/
- (void) getBytes:(void*)buffer;
/*!
  @method getBytes:length:
  
  Copy the first "length" bytes of the receiver's data into "buffer".
*/
- (void) getBytes:(void*)buffer length:(size_t)length;
/*!
  @method getBytes:length:
  
  Copy "length" bytes of the receiver's data, starting at the "offset" byte position,
  into "buffer".
*/
- (void) getBytes:(void*)buffer length:(size_t)length offset:(size_t)offset;

/*!
  @method replaceBytesInRange:withData:
*/
- (void) replaceBytesInRange:(SBRange)range withData:(SBData*)aData;

/*!
  @method appendData:
  
  Append the contents of aData to the receiver.
*/
- (void) appendData:(SBData*)aData;

/*!
  @method appendBytes:length:
  
  Append length bytes from the bytes buffer to the receiver.
*/
- (void) appendBytes:(const void*)bytes length:(size_t)length;

/*!
  @method insertData:atIndex:
  
  Insert the contents of aData in the receiver at the specified offset within the receiver.
*/
- (void) insertData:(SBData*)aData atIndex:(unsigned int)index;

/*!
  @method insertBytes:length:atIndex:
  
  Insert length bytes from the bytes buffer into the receiver at the specified offset
  within the receiver.
*/
- (void) insertBytes:(const void*)bytes length:(size_t)length atIndex:(unsigned int)index;

/*!
  @method deleteBytesInRange:
  
  Remove the bytes at indices in range from the receiver.
*/
- (void) deleteBytesInRange:(SBRange)range;

@end
