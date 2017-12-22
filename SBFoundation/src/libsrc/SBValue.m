//
// SBFoundation : ObjC Class Library for Solaris
// SBValue.m
//
// Wrap a generic value.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBValue.h"
#import "SBString.h"

#include <float.h>

//

#define SBValueSmallSize   sizeof(void*)
#define SBValueMediumSize  sizeof(void*) * 8

//

@interface SBValue(SBValuePrivate)

+ (id) allocWithSize:(SBUInteger)bytes;

@end

@interface SBConcreteValue : SBValue
{
  SBUInteger        _size;
  const char*       _type;
}

- (const void*) bytes;
- (SBUInteger) size;

@end

@interface SBSmallValue : SBConcreteValue
{
  unsigned char     _bytes[SBValueSmallSize];
}

@end

@interface SBMediumValue : SBConcreteValue
{
  unsigned char     _bytes[SBValueMediumSize];
}

@end

@interface SBLargeValue : SBConcreteValue
{
  void*             _bytes;
}

@end

//
#pragma mark -
//

@implementation SBValue(SBValuePrivate)

  + (id) allocWithSize:(SBUInteger)bytes
  {
    if ( self == [SBValue class] ) {
      if ( bytes <= SBValueSmallSize ) {
        return [SBSmallValue alloc];
      }
      if ( bytes <= SBValueMediumSize ) {
        return [SBMediumValue alloc];
      }
      return [SBLargeValue alloc];
    }
    return [super alloc];
  }

@end

@implementation SBValue

  + (id) alloc
  {
    if ( self == [SBValue class] )
      return [SBLargeValue alloc];
    return [super alloc];
  }

//

  - (void) getValue:(void*)value
  {
  }
  
//

  - (const char*) objCType
  {
    return NULL;
  }

//

@end

@implementation SBValue(SBValueCreation)

  + (SBValue*) valueWithBytes:(const void*)value
    objCType:(const char*)type
  {
    return [[[self allocWithSize:objc_sizeof_type(type)] initWithBytes:value objCType:type] autorelease];
  }
  
//
    
  + (SBValue*) valueWithNonretainedObject:(id)anObject
  {
    return [[[self allocWithSize:sizeof(id)] initWithBytes:&anObject objCType:@encode(id)] autorelease];
  }
  
//
  
  + (SBValue*) valueWithPointer:(const void*)pointer
  {
    return [[[self allocWithSize:sizeof(const void*)] initWithBytes:&pointer objCType:@encode(void*)] autorelease];
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    objCType:(const char*)type
  {
    return [self init];
  }
  
@end

@implementation SBValue(SBExtendedValue)

  - (id) nonretainedObjectValue
  {
    id              theObj = nil;
    const char*     myType = [self objCType];
    
    if ( myType && (strcmp(@encode(id), myType) == 0) )
      [self getValue:&theObj];
    return theObj;
  }
  
//

  - (void*) pointerValue
  {
    void*           thePtr = NULL;
    const char*     myType = [self objCType];
    
    if ( myType && (strcmp(@encode(void*), myType) == 0) )
      [self getValue:&thePtr];
    return thePtr;
  }
  
//

  - (BOOL) isEqual:(id)anObject
  {
    if ( self == anObject )
      return YES;
    else if ( ! anObject )
      return NO;
    
    // Both SBValue objects?
    if ( [anObject isKindOf:[SBValue class]] ) {
      return [self isEqualToValue:(SBValue*)anObject];
    }
    return NO;
  }

//

  - (BOOL) isEqualToValue:(SBValue*)value
  {
    if ( self == value )
      return YES;
    else if ( ! value )
      return NO;
   
    const char*     myType = [self objCType];
    const char*     hisType = [value objCType];
    SBUInteger      size;
    
    if ( myType && hisType && (strcmp(myType, hisType) == 0 ) ) {
      if ( (size = objc_sizeof_type(myType)) == objc_sizeof_type(hisType) ) {
        unsigned char   myData[size];
        unsigned char   hisData[size];
        
        [self getValue:myData];
        [value getValue:hisData];
        
        if ( memcmp(myData, hisData, size) == 0 )
          return YES;
      }
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBConcreteValue

  - (id) initWithBytes:(const void*)bytes
    objCType:(const char*)type
  {
    if ( self = [self init] ) {
      _size = objc_sizeof_type(type);
      _type = type;
    }
    return self;
  }
  
//

  - (id) copy
  {
    return [self retain];
  }

//

  - (SBUInteger) hash
  {
    void*     bytes = (void*)[self bytes];
    
    if ( bytes && _size )
      return [self hashForData:bytes byteLength:_size];
    return [super hash];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    const char*   type = [self objCType];
    
    [super summarizeToStream:stream];
    fprintf(stream, " { size: %ld | type: %s }\n",
        _size,
        ( type ? type : "" )
      );
  }

//

  - (const void*) bytes
  {
    return NULL;
  }
  
//

  - (SBUInteger) size
  {
    return _size;
  }

//

  - (void) getValue:(void*)value
  {
    const void*   bytes = [self bytes];
    
    if ( bytes && _size )
      memcpy(value, bytes, _size);
  }
  - (const char*) objCType
  {
    return _type;
  }

//

  - (BOOL) isEqualToValue:(SBValue*)value
  {
    if ( self == value )
      return YES;
    else if ( ! value )
      return NO;
    
    const char*     hisType = [value objCType];
    
    if ( _type && hisType && (strcmp(_type, hisType) == 0 ) ) {
      const void*   bytes = [self bytes];
      
      if ( [value isKindOf:[SBConcreteValue class]] ) {
        if ( _size == [(SBConcreteValue*)value size] ) {
          if ( bytes && (memcmp(bytes, [(SBConcreteValue*)value bytes], _size) == 0) ) {
            return YES;
          }
        }
      } else if ( _size == objc_sizeof_type(hisType) ) {
        unsigned char   hisData[_size];
        
        [value getValue:hisData];
        
        if ( bytes && (memcmp(bytes, hisData, _size) == 0) )
          return YES;
      }
    }
    return NO;
  }

@end

@implementation SBSmallValue

  - (id) initWithBytes:(const void*)bytes
    objCType:(const char*)type
  {
    if ( self = [super initWithBytes:bytes objCType:type] ) {
      memcpy(_bytes, bytes, [self size]);
    }
    return self;
  }
  
//

  - (const void*) bytes
  {
    return _bytes;
  }
  
@end

@implementation SBMediumValue

  - (id) initWithBytes:(const void*)bytes
    objCType:(const char*)type
  {
    if ( self = [super initWithBytes:bytes objCType:type] ) {
      memcpy(_bytes, bytes, [self size]);
    }
    return self;
  }
  
//

  - (const void*) bytes
  {
    return _bytes;
  }
  
@end

@implementation SBLargeValue

  - (id) initWithBytes:(const void*)bytes
    objCType:(const char*)type
  {
    if ( self = [super initWithBytes:bytes objCType:type] ) {
      if ( [self size] ) {
        _bytes = objc_malloc([self size]);
        if ( _bytes ) {
          memcpy(_bytes, bytes, [self size]);
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
    
    
    if ( self = [self init] ) {
      SBUInteger        byteSize = objc_sizeof_type(type);
      SBUInteger        allocSize = byteSize;
      
      if ( byteSize && type ) {
        byteSize += strlen(type) + 1;
        
        _bytes = objc_malloc(byteSize);
        if ( _bytes ) {
          memcpy((void*)_bytes, bytes, byteSize);
          _type = (void*)_bytes + byteSize;
          strcpy((char*)_type, type);
          _size = allocSize;
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _bytes ) objc_free((void*)_bytes);
    [super dealloc];
  }

//

  - (const void*) bytes
  {
    return _bytes;
  }

@end

//
#pragma mark -
//

@interface SBNumber_UI : SBNumber
{
  unsigned int  _value;
}
- (id) initWithUnsignedIntValue:(unsigned int)value;
@end

@implementation SBNumber_UI

  - (id) initWithUnsignedIntValue:(unsigned int)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject unsignedIntValue] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %u }\n", _value);
  }

//

  - (unsigned int) unsignedIntValue
  {
    return _value;
  }

  - (uint64_t) unsignedInt64Value
  {
    return (uint64_t)_value;
  }
  - (int) intValue
  {
    if ( _value > INT_MAX )
      return INT_MAX;
    return (int)_value;
  }
  - (int64_t) int64Value
  {
    return (int64_t)_value;
  }
  - (double) doubleValue
  {
    return (double)_value;
  }
  - (BOOL) boolValue
  {
    return ( _value ? YES : NO );
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[32];
    
    snprintf(tmpBuffer, 32, "%u", _value);
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((unsigned int*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(unsigned int);
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%u", _value);
  }
  
@end

//
#pragma mark -
//

@interface SBNumber_SI : SBNumber
{
  int         _value;
}
- (id) initWithSignedIntValue:(int)value;
@end

@implementation SBNumber_SI

  - (id) initWithSignedIntValue:(int)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject intValue] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %d }\n", _value);
  }

//

  - (unsigned int) unsignedIntValue
  {
    if ( _value < 0 )
      return 0;
    return (unsigned int)_value;
  }
  - (uint64_t) unsignedInt64Value
  {
    if ( _value < 0 )
      return 0;
    return (uint64_t)_value;
  }
  - (int) intValue
  {
    return _value;
  }
  - (int64_t) int64Value
  {
    return (int64_t)_value;
  }
  - (double) doubleValue
  {
    return (double)_value;
  }
  - (BOOL) boolValue
  {
    return ( _value ? YES : NO );
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[32];
    
    snprintf(tmpBuffer, 32, "%d", _value);
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((int*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(int);
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%d", _value);
  }

@end

//
#pragma mark -
//

@interface SBNumber_SI64 : SBNumber
{
  int64_t     _value;
}
- (id) initWithInt64Value:(int64_t)value;
@end

@implementation SBNumber_SI64

  - (id) initWithInt64Value:(int64_t)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject int64Value] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %lld }\n", _value);
  }

//

  - (unsigned int) unsignedIntValue
  {
    if ( _value < 0 )
      return 0;
    if ( _value > UINT_MAX )
      return UINT_MAX;
    return (unsigned int)_value;
  }
  - (uint64_t) unsignedInt64Value
  {
    if ( _value < 0 )
      return 0;
    return (uint64_t)_value;
  }
  - (int) intValue
  {
    if ( _value < INT_MIN )
      return INT_MIN;
    if ( _value > INT_MAX )
      return INT_MAX;
    return (int)_value;
  }
  - (int64_t) int64Value
  {
    return _value;
  }
  - (double) doubleValue
  {
    return (double)_value;
  }
  - (BOOL) boolValue
  {
    return ( _value ? YES : NO );
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[128];
    
    snprintf(tmpBuffer, 128, "%lld", _value);
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((int64_t*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(int64_t);
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%lld", _value);
  }

@end

//
#pragma mark -
//

@interface SBNumber_UI64 : SBNumber
{
  uint64_t    _value;
}
- (id) initWithUnsignedInt64Value:(uint64_t)value;
@end

@implementation SBNumber_UI64

  - (id) initWithUnsignedInt64Value:(uint64_t)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject unsignedInt64Value] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %llu }\n", _value);
  }

//

  - (unsigned int) unsignedIntValue
  {
    if ( _value < 0 )
      return 0;
    if ( _value > UINT_MAX )
      return UINT_MAX;
    return (unsigned int)_value;
  }
  - (uint64_t) unsignedInt64Value
  {
    return _value;
  }
  - (int) intValue
  {
    if ( _value < INT_MIN )
      return INT_MIN;
    if ( _value > INT_MAX )
      return INT_MAX;
    return (int)_value;
  }
  - (int64_t) int64Value
  {
    if ( _value < INT64_MIN )
      return INT64_MIN;
    if ( _value > INT64_MAX )
      return INT64_MAX;
    return (int)_value;
  }
  - (double) doubleValue
  {
    return (double)_value;
  }
  - (BOOL) boolValue
  {
    return ( _value ? YES : NO );
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[128];
    
    snprintf(tmpBuffer, 128, "%llu", _value);
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((uint64_t*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(uint64_t);
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%llu", _value);
  }

@end

//
#pragma mark -
//

@interface SBNumber_DOUBLE : SBNumber
{
  double      _value;
}
- (id) initWithDoubleValue:(double)value;
@end

@implementation SBNumber_DOUBLE

  - (id) initWithDoubleValue:(double)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject doubleValue] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %lg }\n", _value);
  }

//

  - (unsigned int) unsignedIntValue
  {
    double      tval = trunc(_value);
    
    if ( tval > (double)UINT_MAX )
      return UINT_MAX;
    if ( tval < 0.0 )
      return 0;
    return (unsigned int)tval;
  }
  - (uint64_t) unsignedInt64Value
  {
    double      tval = trunc(_value);
    
    if ( tval > (double)UINT64_MAX )
      return UINT64_MAX;
    if ( tval < 0.0 )
      return 0;
    return (uint64_t)tval;
  }
  - (int) intValue
  {
    double      tval = trunc(_value);
    
    if ( tval > (double)INT_MAX )
      return INT_MAX;
    if ( tval < INT_MIN )
      return INT_MIN;
    return (int)tval;
  }
  - (int64_t) int64Value
  {
    double      tval = trunc(_value);
    
    if ( tval > (double)INT64_MAX )
      return INT64_MAX;
    if ( tval < INT64_MIN )
      return INT64_MIN;
    return (int64_t)tval;
  }
  - (double) doubleValue
  {
    return _value;
  }
  - (BOOL) boolValue
  {
    return ( (fabs(_value) > DBL_EPSILON) ? YES : NO );
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[128];
    
    snprintf(tmpBuffer, 128, "%lg", _value);
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((double*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(double);
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%lg", _value);
  }

@end

//
#pragma mark -
//

@interface SBNumber_BOOL : SBNumber
{
  BOOL        _value;
}
- (id) initWithBooleanValue:(BOOL)value;
@end

@implementation SBNumber_BOOL

  - (id) initWithBooleanValue:(BOOL)value
  {
    if ( self = [super init] ) {
      _value = value;
    }
    return self;
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBNumber class]] )
      if ( _value == [otherObject boolValue] )
        return YES;
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream," { %s }\n", ( _value ? "true" : "false" ));
  }

//

  - (unsigned int) unsignedIntValue
  {
    return (unsigned int)_value;
  }
  - (uint64_t) unsignedInt64Value
  {
    return (uint64_t)_value;
  }
  - (int) intValue
  {
    return (int)_value;
  }
  - (int64_t) int64Value
  {
    return (int64_t)_value;
  }
  - (double) doubleValue
  {
    return (double)_value;
  }
  - (BOOL) boolValue
  {
    return _value;
  }
  - (SBString*) stringValue
  {
    char      tmpBuffer[2];
    
    snprintf(tmpBuffer, 2, "%d", ( _value ? 1 : 0 ));
    return [SBString stringWithUTF8String:tmpBuffer];
  }
  - (void) getValue:(void*)value
  {
    *((BOOL*)value) = _value;
  }
  - (const char*) objCType
  {
    return @encode(BOOL);
  }
  - (SBComparisonResult) compare:(SBNumber*)otherNumber
  {
    BOOL      otherValue = [otherNumber boolValue];
    
    if ( _value == otherValue )
      return SBOrderSame;
    if ( _value < otherValue )
      return SBOrderAscending;
    return SBOrderDescending;
  }
  - (void) writeToStream:(FILE*)stream
  {
    fprintf(stream, "%s", ( _value ? "yes" : "no" ));
  }

@end

//
#pragma mark -
//

@implementation SBNumber

  + (SBNumber*) numberWithInteger:(SBInteger)value
  {
#if SB64BitIntegers
    return [[[SBNumber_SI64 alloc] initWithSignedInt64Value:value] autorelease];
#else
    return [[[SBNumber_SI alloc] initWithSignedIntValue:value] autorelease];
#endif
  }

//

  + (SBNumber*) numberWithUnsignedInteger:(SBUInteger)value
  {
#if SB64BitIntegers
    return [[[SBNumber_UI64 alloc] initWithUnsignedInt64Value:value] autorelease];
#else
    return [[[SBNumber_UI alloc] initWithUnsignedIntValue:value] autorelease];
#endif
  }

//

  + (SBNumber*) numberWithUnsignedInt:(unsigned int)value
  {
    return [[[SBNumber_UI alloc] initWithUnsignedIntValue:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithUnsignedInt64:(uint64_t)value
  {
    return [[[SBNumber_UI64 alloc] initWithUnsignedInt64Value:value] autorelease];
  }

//

  + (SBNumber*) numberWithInt:(int)value
  {
    return [[[SBNumber_SI alloc] initWithSignedIntValue:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithInt64:(int64_t)value
  {
    return [[[SBNumber_SI64 alloc] initWithInt64Value:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithDouble:(double)value
  {
    return [[[SBNumber_DOUBLE alloc] initWithDoubleValue:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithBool:(BOOL)value
  {
    return [[[SBNumber_BOOL alloc] initWithBooleanValue:value] autorelease];
  }
  
//

  - (SBUInteger) hash
  {
    return [self unsignedIntegerValue];
  }

//

  - (SBInteger) integerValue
  {
#if SB64BitIntegers
    return [self int64Value];
#else
    return [self intValue];
#endif
  }
  
//

  - (SBUInteger) unsignedIntegerValue
  {
#if SB64BitIntegers
    return [self unsignedInt64Value];
#else
    return [self unsignedIntValue];
#endif
  }

//

  - (unsigned int) unsignedIntValue { return 0; }
  - (uint64_t) unsignedInt64Value { return 0; }
  - (int) intValue { return 0; }
  - (int64_t) int64Value { return 0; }
  - (double) doubleValue { return 0.0; }
  - (BOOL) boolValue { return NO; }
  - (SBString*) stringValue
  {
    return [SBString string];
  }
  
//

  - (SBComparisonResult) compare:(SBNumber*)otherNumber
  {
    double      cmp = [self doubleValue] - [otherNumber doubleValue];
    
    if ( cmp <= __DBL_EPSILON__ )
      return SBOrderSame;
    if ( cmp < 0.0 )
      return SBOrderAscending;
    return SBOrderDescending;
  }
  
//

  - (BOOL) isEqualToNumber:(SBNumber*)number
  {
    return ( [self compare:number] == SBOrderSame ? YES : NO );
  }

//

  - (void) writeToStream:(FILE*)stream
  {
  }

@end

