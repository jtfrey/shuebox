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

/*!
  @header SBData.h
  @discussion
    SBData represents the public interface to an entire cluster of classes devoted to the
    task of representing and processing binary data.
    
    <b>Implementation Details</b>
    <blockquote>
      A little inside info, the actual class cluster under SBData looks like this:
      <ul>
        <li>SBData
          <ul>
            <li>SBDataSubData</li>
            <li>SBConcreteData
              <ul>
                <li>SBConcreteDataSubData</li>
              </ul>
            </li>
            <li>SBMutableData
              <ul>
                <li>SBConcreteMutableData</li>
              </ul>
            </li>
          </ul>
        </li>
      </ul>
      The two sub-data classes are present because the content of an immutable binary buffer
      cannot change, so a sub-data can refer directly to the original buffer rather
      than making a copy of it in memory.  SBData will return SBDataSubData objects from
      its subdata* methods; an SBDataSubData object retains a reference to the parent
      SBData object and modifies the length and bytes methods to call-through to the parent's
      method with a properly-modified offset (according to the range with which the
      SBDataSubData was initialized).  The SBConcreteDataSubData object is a subclass
      of SBConcreteData which also retains a reference to the parent SBData but sends itself
      the initWithBytesNoCopy:length:freeWhenDone: message with the applicable region 
      of the parent SBData's buffer.
    </blockquote>
*/

@class SBString;

/*!
  @constant SBDataBadIndexException
  @discussion
    Identifier of exceptions raised by SBData when a byte index is
    out of range for the receiver.
*/
extern SBString* SBDataBadIndexException;

/*!
  @constant SBDataMemoryException
  @discussion
    Identifier of exceptions raised by SBData when memory cannot be
    allocated.
*/
extern SBString* SBDataMemoryException;

/*!
  @class SBData
  @discussion
    Instances of SBData wrap arbitrary-size chunks of binary data.  Subclasses of SBData
    must AT LEAST override the following methods in order to properly inherit all behavior
    of SBData:
    
      - (SBUInteger) length
      - (const void*) bytes
      - (id) initWithBytesNoCopy:(const void*)bytes length:(SBUInteger)length freeWhenDone:(BOOL)freeWhenDone
    
    SBData objects are immutable -- once created, their content remains constant.  One gray
    are in this regard is SBData objects created to wrap external buffers:  it is up to consumer
    code to ensure that the buffer does NOT change once an SBData wrapper has been created.
*/
@interface SBData : SBObject <SBMutableCopying>

/*!
  @method length
  @discussion
    Return the length (in bytes) of the data held by the receiver.
*/
- (SBUInteger) length;

/*!
  @method bytes
  @discussion
    Returns a pointer to the data held by the receiver.  The data should be
    considered immutable -- do NOT type-cast and modify it, that's what SBMutableData
    objects are for!!
*/
- (const void*) bytes;

@end

@interface SBData(SBDataCreation)

/*!
  @method data
  @discussion
    Returns an autoreleased SBData instance containing an empty, zero-length buffer.
*/
+ (id) data;

/*!
  @method dataWithBytes:length:
  @discussion
    Returns an autoreleased SBData instance containing a copy of the length bytes of
    data originating at bytes.
*/
+ (id) dataWithBytes:(const void*)bytes length:(SBUInteger)length;

/*!
  @method dataWithBytesNoCopy:length:
  @discussion
    Returns an autoreleased SBData instance which wraps the buffer of length octets
    originating at bytes.  The buffer will not be destroyed (via objc_free()) when
    this object is deallocated.
*/
+ (id) dataWithBytesNoCopy:(const void*)bytes length:(SBUInteger)length;

/*!
  @method dataWithBytesNoCopy:length:freeWhenDone:
  @discussion
    Returns an autoreleased SBData instance which wraps the buffer of length octets
    originating at bytes.  If freeWhenDone is YES, then the buffer will be destroyed
    (via objc_free()) when this object is deallocated.
*/
+ (id) dataWithBytesNoCopy:(const void*)bytes length:(SBUInteger)length freeWhenDone:(BOOL)freeWhenDone;

/*!
  @method dataWithContentsOfFile:
  @discussion
    Returns an autoreleased SBData instance which wraps the contents of the file
    at path.
*/
+ (id) dataWithContentsOfFile:(SBString*)path;

/*!
  @method dataWithData:
  @discussion
    Returns an autoreleased SBData instance which contains a copy of the content
    of otherData.
*/
+ (id) dataWithData:(SBData*)otherData;

/*!
  @method init
  @discussion
    Initializes an SBData instance to contain an empty, zero-length buffer.
*/
- (id) init;

/*!
  @method initWithBytes:length:
  @discussion
    Initializes an SBData instance to the specified length containing a copy of
    the octets originating at bytes.
*/
- (id) initWithBytes:(const void*)bytes length:(SBUInteger)length;

/*!
  @method initWithBytesNoCopy:length:
  @discussion
    Initializes an SBData instance which wraps the buffer of length octets
    originating at bytes.  The buffer will not be destroyed (via objc_free())
    when this object is deallocated.
*/
- (id) initWithBytesNoCopy:(const void*)bytes length:(SBUInteger)length;

/*!
  @method initWithBytesNoCopy:length:freeWhenDone:
  @discussion
    Initializes an SBData instance which wraps the buffer of length octets
    originating at bytes.  If freeWhenDone is YES, then the buffer will be
    destroyed (via objc_free()) when this object is deallocated.
*/
- (id) initWithBytesNoCopy:(const void*)bytes length:(SBUInteger)length freeWhenDone:(BOOL)freeWhenDone;

/*!
  @method initWithContentsOfFile:
  @discussion
    Initializes an SBData instance which wraps the contents of the file
    at path.
*/
- (id) initWithContentsOfFile:(SBString*)path;

/*!
  @method initWithData:
  @discussion
    Initializes an SBData instance which contains a copy of the content
    of otherData.
*/
- (id) initWithData:(SBData*)otherData;

@end

@interface SBData(SBExtendedData)

/*!
  @method getBytes:length:
  @discussion
    Copy the first "length" bytes of the receiver's data into "buffer".
*/
- (void) getBytes:(void*)buffer length:(SBUInteger)length;

/*!
  @method getBytes:length:offset:
  @discussion
    Copy "length" bytes of the receiver's data, starting at the "offset" byte position,
    into "buffer".
*/
- (void) getBytes:(void*)buffer length:(SBUInteger)length offset:(SBUInteger)offset;

/*!
  @method isEqualToData:
  @discussion
    Compares two SBData objects for equality, returning YES if they are matching
    buffers (in length and binary content).
*/
- (BOOL) isEqualToData:(SBData*)otherData;

/*!
  @method subdataWithRange:
  @discussion
    Returns an SBData object which represents the given byte range of the
    receiver.
*/
- (SBData*) subdataWithRange:(SBRange)range;

@end

/*!
  @class SBMutableData
  @discussion
    SBMutableData is similar to its parent class, SBData, except that its binary content can
    be modified after object creation.
    
    Subclasses of SBMutableData must AT LEAST override the following methods in order to properly
    inherit all behavior of SBData and SBMutableData:
    
      - (SBUInteger) length
      - (void) setLength:(SBUInteger)length
      - (void*) mutableBytes
      - (id) initWithCapacity:(SBUInteger)capacity
    
    Note that the "no copy" initialization method by default DOES make a copy of the passed-in
    buffer.  If your subclass wishes to override this behavior and actually work with the
    passed-in buffer then override the initWithBufferNoCopy:length:freeWhenDone: method of
    SBMutableData.
*/
@interface SBMutableData : SBData

/*!
  @method setLength:
  @discussion
    Modify the length (in bytes) of the receiver's data buffer.
*/
- (void) setLength:(SBUInteger)length;

/*!
  @method mutableBytes
  @discussion
    Returns a pointer to the receiver's data buffer.
*/
- (void*) mutableBytes;

@end

@interface SBMutableData(SBMutableDataCreation)

/*!
  @method dataWithCapacity:
  @discussion
    Returns an autoreleased SBMutableData instance which initially has a buffer
    sized at least equal to capacity but containing no bytes (length of zero).
*/
+ (id) dataWithCapacity:(SBUInteger)capacity;

/*!
  @method dataWithLength:
  @discussion
    Returns an autoreleased SBMutableData instance which has a buffer sized
    at least equal to length and containing the given number of zeroed bytes.
*/
+ (id) dataWithLength:(SBUInteger)length;

/*!
  @method initWithCapacity:
  @discussion
    Initialize an SBMutableData instance to initially have a buffer sized at
    least equal to capacity but containing no bytes (length of zero).
*/
- (id) initWithCapacity:(SBUInteger)capacity;

/*!
  @method initWithLength:
  @discussion
    Initialize an SBMutableData instance which has a buffer sized at least equal
    to length and containing the given number of zeroed bytes.
*/
- (id) initWithLength:(SBUInteger)length;

@end

@interface SBMutableData(SBExtendedMutableData)

/*!
  @method replaceBytesInRange:withData:
  @discussion
    Delete octets in the given byte range and insert the content of
    aData in its place.
*/
- (void) replaceBytesInRange:(SBRange)range withData:(SBData*)aData;

/*!
  @method replaceBytesInRange:withBytes:length:
  @discussion
    Delete octets in the given byte range and insert the length octets originating
    at bytes in its place.
*/
- (void) replaceBytesInRange:(SBRange)range withBytes:(const void*)bytes length:(SBUInteger)length;

/*!
  @method appendData:
  @discussion
    Append the contents of aData to the end of the receiver's buffer.
*/
- (void) appendData:(SBData*)aData;

/*!
  @method appendBytes:length:
  @discussion
    Append length bytes from the bytes buffer to the end receiver's buffer.
*/
- (void) appendBytes:(const void*)bytes length:(SBUInteger)length;

/*!
  @method insertData:atIndex:
  @discussion
    Insert the contents of aData in the receiver at the specified offset within the 
    receiver's buffer.
*/
- (void) insertData:(SBData*)aData atIndex:(unsigned int)index;

/*!
  @method insertBytes:length:atIndex:
  @discussion
    Insert length bytes from the bytes buffer into the receiver at the specified offset
    within the receiver's buffer.
*/
- (void) insertBytes:(const void*)bytes length:(SBUInteger)length atIndex:(unsigned int)index;

/*!
  @method deleteBytesInRange:
  @discussion
    Remove octets at indices in range from the receiver's buffer (shrinking its length in
    the process).
*/
- (void) deleteBytesInRange:(SBRange)range;

/*!
  @method resetBytesInRange:
  @discussion
    Set all octets in the given range of byte indices within the receiver's buffer to
    zero.
*/
- (void) resetBytesInRange:(SBRange)range;

/*!
  @method resetBytesInRange:
  @discussion
    Reset the length of the receiver to match aData and copy aData's content into the
    receiver's buffer.
*/
- (void) setData:(SBData*)aData;

@end
