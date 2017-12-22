//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBNumberFormatter.h
//
// Numerical format/parse utilities thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/unum.h"

#define SBNumberFormatterDefault ((unsigned int)-1)

@class SBString, SBNumber, SBLocale;

@interface SBNumberFormatter : SBObject
{
  UNumberFormat*              _icuNumberFormat;
  UNumberFormatStyle          _numberStyle;
  SBNumber*                   _roundingIncrement;
  unsigned int                _attributes[8];
  SBString*                   _pattern;
  SBLocale*                   _locale;
}

- (id) init;

- (SBString*) stringFromNumber:(SBNumber*)aNumber;
- (SBNumber*) numberFromString:(SBString*)aString;

- (SBString*) pattern;
- (void) setPattern:(SBString*)pattern;

- (UNumberFormatStyle) numberStyle;
- (void) setNumberStyle:(UNumberFormatStyle)numberStyle;

- (UNumberFormatRoundingMode) roundingMode;
- (void) setRoundingMode:(UNumberFormatRoundingMode)roundingMode;

- (UNumberFormatPadPosition) paddingPosition;
- (void) setPaddingPosition:(UNumberFormatPadPosition)paddingPosition;

- (SBNumber*) roundingIncrement;
- (void) setRoundingIncrement:(SBNumber*)number;

- (unsigned int) minimumIntegerDigits;
- (void) setMinimumIntegerDigits:(unsigned int)digits;

- (unsigned int) maximumIntegerDigits;
- (void) setMaximumIntegerDigits:(unsigned int)digits;

- (unsigned int) minimumFractionDigits;
- (void) setMinimumFractionDigits:(unsigned int)digits;

- (unsigned int) maximumFractionDigits;
- (void) setMaximumFractionDigits:(unsigned int)digits;

- (BOOL) alwaysShowsDecimalSeparator;
- (void) setAlwaysShowsDecimalSeparator:(BOOL)state;

- (BOOL) usesGroupingSeparator;
- (void) setUsesGroupingSeparator:(BOOL)state;

- (SBLocale*) locale;
- (void) setLocale:(SBLocale*)locale;

@end
