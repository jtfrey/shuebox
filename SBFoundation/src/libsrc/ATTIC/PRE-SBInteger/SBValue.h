//
// SBFoundation : ObjC Class Library for Solaris
// SBValue.h
//
// Wrap a generic value.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @class SBValue
  @discussion
  Instances of SBValue are used to wrap atomic types, pointers, structs, etc. in
  an object that can be used in SBFoundation collections (arrays, dictionaries).
  SBValue is used internally and you'll probably never need to use it in any
  code written to use SBFoundation.
  
  Behind the scenes there are several concrete subclasses that implement value
  objects; as long as any subclass of SBValue implements the getValue: and
  objCType methods, the extended SBValue methods will also work.
*/
@interface SBValue : SBObject

/*!
  @method getValue:
  
  Based on the byte-size, N, of the type wrapped by the receiver, copy N bytes
  to the provided buffer (value).
*/
- (void) getValue:(void*)value;
/*!
  @method objCType
  
  Returns the encoded type for the value wrapped by the receiver.
*/
- (const char*) objCType;

@end

/*!
  @category SBValue(SBValueCreation)
  @discussion
  Groups methods that create SBValue object.
*/
@interface SBValue(SBValueCreation)

/*!
  @method valueWithBytes:objCType:
  
  Returns a newly-initialized, autoreleased instance which wraps the given
  data and type.
  
  The type can be computed using the \@encode() compiler directive.  For example,
  to create an SBValue which wraps a 2D point:
  <pre>
typedef struct {
  float   x,y;
} point2d_t;

point2d_t   aPoint = { 1.0 , -1.0 };
SBValue*    asValue = [SBValue valueWithBytes:&aPoint objCType:\@encode(point2d_t)];
  </pre>
*/
+ (SBValue*) valueWithBytes:(const void*)value objCType:(const char*)type;
/*!
  @method valueWithNonretainedObject:
  
  Convenience method which returns a newly-initialized, autoreleased instance
  which wraps the given object without increasing that object's reference
  count.  Of course, one needs to be extremely careful with this, since the
  contents of the SBValue may or may not become invalid if anObject is
  released!
*/
+ (SBValue*) valueWithNonretainedObject:(id)anObject;
/*!
  @method valueWithPointer:
  
  Convenience method which returns a newly-initialized, autoreleased instance
  which wraps the given pointer.  Of course, one needs to be extremely careful
  with this:  if the wrapped pointer were on the stack then eventually the
  references pointer would go out of scope.  Likewise, if the wrapped pointer
  is a malloc()'ed buffer, that buffer could be free()'d and the SBValue
  would be left with an invalid pointer!
*/
+ (SBValue*) valueWithPointer:(const void*)pointer;
/*!
  @method initWithBytes:objCType:
  
  Initialize the receiver to wrap the specified data type.  The type is
  analyzed to determine the size of the type (in bytes); a size-appropriate
  buffer is allocated and filled with that much data from "bytes".
*/
- (id) initWithBytes:(const void*)bytes objCType:(const char*)type;

@end

/*!
  @category SBValue(SBExtendedValue)
  @discussion
  Groups additional extensions to the basic SBValue methods.
*/
@interface SBValue(SBExtendedValue)

/*!
  @method nonretainedObjectValue
  
  If the receiver can be interpreted as containing an object pointer, return
  that value.  Otherwise, return nil.
*/
- (id) nonretainedObjectValue;
/*!
  @method pointerValue
  
  If the receiver can be interpreted as containing a pointer, return that
  value.  Otherwise, return NULL.
*/
- (void*) pointerValue;
/*!
  @method isEqualToValue:
  
  If the receiver and "value" are of the same type and contain the same byte
  sequence, return YES.  Otherwise, return NO.
*/
- (BOOL) isEqualToValue:(SBValue*)value;

@end

@class SBString;

/*!
  @class SBNumber
  @discussion
  Instances of SBNumber wrap atomic numerical values -- integers, floats, etc.
*/
@interface SBNumber : SBValue <SBStringValue>

/*!
  @method numberWithUnsignedInt:
  
  Returns a newly-initialized, autorelease instance that wraps the given
  unsigned integer value.
*/
+ (SBNumber*) numberWithUnsignedInt:(unsigned int)value;
/*!
  @method numberWithInt:
  
  Returns a newly-initialized, autorelease instance that wraps the given
  signed integer value.
*/
+ (SBNumber*) numberWithInt:(int)value;
/*!
  @method numberWithInt64:
  
  Returns a newly-initialized, autorelease instance that wraps the given
  signed 64-bit integer value.
*/
+ (SBNumber*) numberWithInt64:(int64_t)value;
/*!
  @method numberWithDouble:
  
  Returns a newly-initialized, autorelease instance that wraps the given
  double-precision floating-point value.
*/
+ (SBNumber*) numberWithDouble:(double)value;
/*!
  @method numberWithBool:
  
  Returns a newly-initialized, autorelease instance that wraps the given
  boolean value.
*/
+ (SBNumber*) numberWithBool:(BOOL)value;
/*!
  @method unsignedIntValue
  
  Returns the value of the receiver as an unsigned integer.  Values outside
  the range of an unsigned int are truncated to the min/max value.
*/
- (unsigned int) unsignedIntValue;
/*!
  @method intValue
  
  Returns the value of the receiver as a signed integer.  Values outside
  the range of an int are truncated to the min/max value.
*/
- (int) intValue;
/*!
  @method int64Value
  
  Returns the value of the receiver as a signed 64-bit integer.  Values outside
  the range of an int64_t are truncated to the min/max value.
*/
- (int64_t) int64Value;
/*!
  @method doubleValue
  
  Returns the value of the receiver as a double-precision floating-point value.
*/
- (double) doubleValue;
/*!
  @method boolValue
  
  Returns the value of the receiver as a boolean -- zero equates to NO, non-zero
  equates to YES.
*/
- (BOOL) boolValue;

- (void) writeToStream:(FILE*)stream;

@end
