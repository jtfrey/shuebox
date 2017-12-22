//
// SBFoundation : ObjC Class Library for Solaris
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

/*!
  @class SBNumberFormatter
  @discussion
  An SBNumberFormatter is used to generate textual representations of an SBNumber's value (formatting)
  and to analyze textual forms, calculating a value from them which can be represented by an
  SBNumber object (parsing).
  
  An SBNumberFormatter can use an alternate (other than default) localization scheme by sending it the
  setLocale: message with an instance of SBLocale.  This most notably will affect decimal separators
  and currency symbols.
  
  See the following page for information on the options which influence the behavior of an SBNumberFormatter
  object:
  
    http://icu-project.org/apiref/icu4c/unum_8h.html

*/
@interface SBNumberFormatter : SBObject
{
  UNumberFormat*              _icuNumberFormat;
  UNumberFormatStyle          _numberStyle;
  SBNumber*                   _roundingIncrement;
  unsigned int                _attributes[9];
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

- (BOOL) parseIntegerOnly;
- (void) setParseIntegerOnly:(BOOL)parseIntOnly;

- (BOOL) alwaysShowsDecimalSeparator;
- (void) setAlwaysShowsDecimalSeparator:(BOOL)state;

- (BOOL) usesGroupingSeparator;
- (void) setUsesGroupingSeparator:(BOOL)state;

- (SBLocale*) locale;
- (void) setLocale:(SBLocale*)locale;

@end
