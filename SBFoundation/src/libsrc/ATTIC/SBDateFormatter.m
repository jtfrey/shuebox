//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBDateFormatter.m
//
// Calendar date/time utilities thanks to ICU.
//
// $Id$
//

#import "SBDateFormatter.h"
#import "SBString.h"
#import "SBDate.h"
#import "SBLocale.h"

@interface SBDateFormatter(SBDateFormatterPrivate)

- (BOOL) setupDateFormatter;

@end

@implementation SBDateFormatter(SBDateFormatterPrivate)

  - (BOOL) setupDateFormatter
  {
    if ( _icuDateFormat == NULL ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      if ( _pattern ) {
        _icuDateFormat = udat_open(
                              _timeStyle,
                              _dateStyle,
                              ( _locale ? [_locale localeIdentifier] : NULL ),
                              NULL,
                              -1,
                              [_pattern utf16Characters],
                              [_pattern length],
                              &icuErr
                            );
      } else {
        _icuDateFormat = udat_open(
                              _timeStyle,
                              _dateStyle,
                              ( _locale ? [_locale localeIdentifier] : NULL ),
                              NULL,
                              -1,
                              NULL,
                              -1,
                              &icuErr
                            );
      }
      
      if ( _icuDateFormat )
        udat_setLenient(_icuDateFormat, TRUE);
      
      return U_SUCCESS(icuErr);
    }
    return YES;
  }

@end

//
#pragma mark -
//

@implementation SBDateFormatter

  - (id) init
  {
    if ( self = [super init] ) {
      [self setDateStyle:UDAT_DEFAULT];
      [self setTimeStyle:UDAT_DEFAULT];
      [self setPattern:nil];
      [self setLocale:nil];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _icuDateFormat ) udat_close(_icuDateFormat);
    if ( _pattern ) [_pattern release];
    if ( _locale) [_locale release];
    [super dealloc];
  }

//

  - (SBString*) stringFromDate:(SBDate*)aDate
  {
    SBString*     result = nil;
    
    if ( [self setupDateFormatter] ) {
      UErrorCode  icuErr = U_ZERO_ERROR;
      UChar*      buffer = NULL;
      int32_t     bufferLen = 0;
      
      bufferLen = udat_format(
                    _icuDateFormat,
                    [aDate icuDate],
                    NULL,
                    0,
                    NULL,
                    &icuErr
                  );
      if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
        if ( buffer = (UChar*)malloc(sizeof(UChar) * (bufferLen + 1)) ) {
          icuErr = U_ZERO_ERROR;
          bufferLen = udat_format(
                        _icuDateFormat,
                        [aDate icuDate],
                        buffer,
                        bufferLen,
                        NULL,
                        &icuErr
                      );
          if ( U_SUCCESS(icuErr) ) {
            result = [SBString stringWithCharacters:buffer length:bufferLen];
          }
          free(buffer);
        }
      }
    }
    return result;
  }
  
//

  - (SBDate*) dateFromString:(SBString*)aString
  {
    SBDate*       result = nil;
    
    if ( [self setupDateFormatter] ) {
      UErrorCode  icuErr = U_ZERO_ERROR;
      UDate       icuDate = udat_parse(_icuDateFormat, [aString utf16Characters], [aString length], NULL, &icuErr);
      
      if ( U_SUCCESS(icuErr) ) {
        result = [SBDate dateWithICUDate:icuDate];
      }
    }
    return result;
  }

//

  - (UDateFormatStyle) dateStyle
  {
    return _dateStyle;
  }
  - (void) setDateStyle:(UDateFormatStyle)style
  {
    switch (style) {
      case UDAT_SHORT:
      case UDAT_MEDIUM:
      case UDAT_LONG:
      case UDAT_FULL:
      case UDAT_IGNORE:
      case UDAT_NONE: {
        _dateStyle = style;
        if ( _icuDateFormat ) {
          udat_close(_icuDateFormat);
          _icuDateFormat = NULL;
        }
        break;
      }
    }
  }
  
//

  - (UDateFormatStyle) timeStyle
  {
    return _timeStyle;
  }
  - (void) setTimeStyle:(UDateFormatStyle)style
  {
    switch (style) {
      case UDAT_SHORT:
      case UDAT_MEDIUM:
      case UDAT_LONG:
      case UDAT_FULL:
      case UDAT_IGNORE:
      case UDAT_NONE: {
        _timeStyle = style;
        if ( _icuDateFormat ) {
          udat_close(_icuDateFormat);
          _icuDateFormat = NULL;
        }
        break;
      }
    }
  }
  
//

  - (SBString*) pattern
  {
    return _pattern;
  }
  - (void) setPattern:(SBString*)pattern
  {
    if ( pattern ) pattern = [pattern copy];
    if ( _pattern ) [_pattern release];
    _pattern = pattern;

    if ( _icuDateFormat ) {
      udat_close(_icuDateFormat);
      _icuDateFormat = NULL;
    }
    
    if ( pattern ) {
      [self setDateStyle:UDAT_IGNORE];
      [self setTimeStyle:UDAT_IGNORE];
    }
  }

//

  - (SBLocale*) locale
  {
    return _locale;
  }
  - (void) setLocale:(SBLocale*)locale
  {
    if ( locale ) locale = [locale retain];
    if ( _locale ) [_locale release];
    _locale = locale;
    if ( _icuDateFormat ) {
      udat_close(_icuDateFormat);
      _icuDateFormat = NULL;
    }
  }

@end
