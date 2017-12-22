//
// SBFoundation : ObjC Class Library for Solaris
// SBNumber.m
//
// Wrap a number.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBNumber.h"
#import "SBString.h"

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
  - (const char*) atomicTypeEncoding
  {
    return @encode(unsigned int);
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
  - (const char*) atomicTypeEncoding
  {
    return @encode(int);
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
  - (const char*) atomicTypeEncoding
  {
    return @encode(int64_t);
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
  - (const char*) atomicTypeEncoding
  {
    return @encode(double);
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
  - (const char*) atomicTypeEncoding
  {
    return @encode(BOOL);
  }

@end

//
#pragma mark -
//

@implementation SBNumber

  + (SBNumber*) numberWithUnsignedInt:(unsigned int)value
  {
    return [[[SBNumber_UI alloc] initWithUnsignedIntValue:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithInt:(int)value
  {
    return [[[SBNumber_SI alloc] initWithSignedIntValue:value] autorelease];
  }
  
//

  + (SBNumber*) numberWithInt64:(int64_t)value
  {
    return [[[SBNumber_SI alloc] initWithInt64Value:value] autorelease];
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

  - (unsigned int) hash
  {
    return [self unsignedIntValue];
  }

//

  - (unsigned int) unsignedIntValue { return 0; }
  - (int) intValue { return 0; }
  - (int64_t) int64Value { return 0; }
  - (double) doubleValue { return 0.0; }
  - (BOOL) boolValue { return NO; }
  - (SBString*) stringValue
  {
    return [SBString string];
  }
  - (const char*) atomicTypeEncoding
  {
    return NULL;
  }

@end
