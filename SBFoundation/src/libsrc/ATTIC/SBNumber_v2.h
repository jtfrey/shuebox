//
// SBFoundation : ObjC Class Library for Solaris
// SBNumber.h
//
// Wrap a number.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString;

@interface SBNumber : SBObject

+ (SBNumber*) numberWithUnsignedInt:(unsigned int)value;
+ (SBNumber*) numberWithInt:(int)value;
+ (SBNumber*) numberWithInt64:(int64_t)value;
+ (SBNumber*) numberWithDouble:(double)value;
+ (SBNumber*) numberWithBool:(BOOL)value;

- (unsigned int) unsignedIntValue;
- (int) intValue;
- (int64_t) int64Value;
- (double) doubleValue;
- (BOOL) boolValue;
- (SBString*) stringValue;

- (const char*) atomicTypeEncoding;

@end
