//
// SBFoundation : ObjC Class Library for Solaris
// SBDateFormatter.h
//
// Calendar date/time utilities thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/udat.h"

@class SBDate, SBString, SBLocale;

/*!
  @class SBDateFormatter
  @discussion
  An SBDateFormatter is used to generate textual representations of an SBDate's timestamp (formatting)
  and to analyze textual forms, calculating a timestamp from them which can be represented by an
  SBDate object (parsing).
  
  An SBDateFormatter can use an alternate (other than default) localization scheme by sending it the
  setLocale: message with an instance of SBLocale.  This most notably will affect the names of months
  and the days of the week, as well as the ordering of date fields.  For example, the "en_US" locale
  will produce the following formatted date:
  <pre>
    April 24, 2009 2:16:05 PM EDT
  </pre>
  while a British locale like "en_GB" produces:
  <pre>
    24 April 2009 14:16:05 EDT
  </pre>
  Non-English locales (French, German, Spanish) will produce localized month and day names as well as
  altered field ordering/delimiting.
  
  An SBDateFormatter can be configured in one of two ways:
  <ul>
    <li>Simple style directives:  long, medium, and short size</li>
    <li>A template string with place-fillers for the calendar fields</li>
  </ul>
  See the following page for information on the styles and the format of template strings:
  
    http://icu-project.org/apiref/icu4c/udat_8h.html
    
  It's best to avoid template strings since they do not directly provide any localization support
  for field ordering -- e.g. using a template like "yyyy-MM-dd" can be confusing in some locales
  since the numerical month and day may be expected to be in reversed sequence.  That is to say,
  does the following string produced with that template
  <pre>
    2008-01-03
  </pre>
  represent January 3 or March 1, 2008?  In an internationalized application it's impossible to
  tell for sure without knowing the order presented in the template itself.  This may not be a
  big deal for log files, but it becomes a very big deal w.r.t. presenting an intuitive
  internationalized user interface.
*/
@interface SBDateFormatter : SBObject
{
  UDateFormat*        _icuDateFormat;
  UDateFormatStyle    _dateStyle;
  UDateFormatStyle    _timeStyle;
  SBString*           _pattern;
  SBLocale*           _locale;
}
/*!
  @method dateFormatter
  
  Returns an autoreleased SBDateFormatter initialized to default locale and date formatting
  properties.
*/
+ (SBDateFormatter*) dateFormatter;
/*!
  @method init
  
  Initializes an SBDateFormatter to use default locale and date formatting properties.
*/
- (id) init;
/*!
  @method stringFromDate:
  
  Returns a string containing the given SBDate formatted according to the receiver's date-
  and time-formatting properties.
*/
- (SBString*) stringFromDate:(SBDate*)aDate;
/*!
  @method dateFromString:
  
  Attempts to parse aString using the receiver's date- and time-formatting properties.  If
  successful, returns an SBDate object containing the parsed date and time.  Returns nil
  if aString could not be parsed properly.
*/
- (SBDate*) dateFromString:(SBString*)aString;
/*!
  @method dateStyle
  
  Returns the receiver's style for the year/month/day portion of a date.  If a template string
  has been set using the setPattern: method, the returned value is moot since it won't actually
  influence formatting/parsing.
*/
- (UDateFormatStyle) dateStyle;
/*!
  @method setDateStyle:
  
  Modify the receiver's style for the year/month/day portion of a date.
*/
- (void) setDateStyle:(UDateFormatStyle)style;
/*!
  @method timeStyle
  
  Returns the receiver's style for the hour/minute/second/timezone portion of a date.  If a
  template string has been set using the setPattern: method, the returned value is moot since
  it won't actually influence formatting/parsing.
*/
- (UDateFormatStyle) timeStyle;
/*!
  @method setTimeStyle:
  
  Modify the receiver's style for the hour/minute/second/timezone portion of a date.
*/
- (void) setTimeStyle:(UDateFormatStyle)style;
/*!
  @method pattern
  
  Returns the template string that the receiver will use to format/parse dates.  Returns
  nil if none has been set.
*/
- (SBString*) pattern;
/*!
  @method setPattern:
  
  Set the receiver to format/parse dates according to a fixed form specified in a template
  string (pattern).  E.g. \@"yyyy-MM-dd HH:mm:ssZZZ"
  
  See the ICU documentation for full documentation.
*/
- (void) setPattern:(SBString*)pattern;
/*!
  @method locale
  
  Returns the locale which the receiver will use to parse/format dates.
*/
- (SBLocale*) locale;
/*!
  @method setLocale:
  
  Sets the receiver to begin formatting/parsing dates with respect to a specific locale.  Pass
  nil to use the default locale.
*/
- (void) setLocale:(SBLocale*)locale;

@end
