//
// scruffy : maintenance scheduler daemon for SHUEBox
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
#import <limits.h>
#import <float.h>

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

  - (unsigned int) unsignedIntValue
  {
    return (unsigned int)_value;
  }
  - (int) intValue
  {
    return (int)_value;
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
  - (double) doubleValue { return 0.0; }
  - (BOOL) boolValue { return NO; }
  - (SBString*) stringValue
  {
    return [SBString emptyString];
  }

@end
