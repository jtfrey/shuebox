//
// scruffy : maintenance scheduler daemon for SHUEBox
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
+ (SBNumber*) numberWithDouble:(double)value;
+ (SBNumber*) numberWithBool:(BOOL)value;

- (unsigned int) unsignedIntValue;
- (int) intValue;
- (double) doubleValue;
- (BOOL) boolValue;
- (SBString*) stringValue;

@end
