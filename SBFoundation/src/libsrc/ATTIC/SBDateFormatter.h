//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBDateFormatter.h
//
// Calendar date/time utilities thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/udat.h"

@class SBDate, SBString, SBLocale;

@interface SBDateFormatter : SBObject
{
  UDateFormat*        _icuDateFormat;
  UDateFormatStyle    _dateStyle;
  UDateFormatStyle    _timeStyle;
  SBString*           _pattern;
  SBLocale*           _locale;
}

- (id) init;

- (SBString*) stringFromDate:(SBDate*)aDate;
- (SBDate*) dateFromString:(SBString*)aString;

- (UDateFormatStyle) dateStyle;
- (void) setDateStyle:(UDateFormatStyle)style;

- (UDateFormatStyle) timeStyle;
- (void) setTimeStyle:(UDateFormatStyle)style;

- (SBString*) pattern;
- (void) setPattern:(SBString*)pattern;

- (SBLocale*) locale;
- (void) setLocale:(SBLocale*)locale;

@end
