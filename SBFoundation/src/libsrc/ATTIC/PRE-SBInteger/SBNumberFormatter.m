//
// SBFoundation : ObjC Class Library for Solaris
// SBNumberFormatter.m
//
// Numerical format/parse utilities thanks to ICU.
//
// $Id$
//

#import "SBNumberFormatter.h"
#import "SBString.h"
#import "SBValue.h"
#import "SBLocale.h"

enum {
  kSBDateFormatterAttr_MinIntDigits = 0,
  kSBDateFormatterAttr_MaxIntDigits,
  kSBDateFormatterAttr_MinFracDigits,
  kSBDateFormatterAttr_MaxFracDigits,
  kSBDateFormatterAttr_ShowDecSep,
  kSBDateFormatterAttr_UseGroupSep,
  kSBDateFormatterAttr_RoundingMode,
  kSBDateFormatterAttr_PaddingPos,
  kSBDateFormatterAttr_IntOnly,
  
  kSBDateFormatterAttr_Max
};

UNumberFormatAttribute __SBDateFormatterAttrMap[] = {
                              UNUM_MIN_INTEGER_DIGITS,
                              UNUM_MAX_INTEGER_DIGITS,
                              UNUM_MIN_FRACTION_DIGITS,
                              UNUM_MAX_FRACTION_DIGITS,
                              UNUM_DECIMAL_ALWAYS_SHOWN,
                              UNUM_GROUPING_USED,
                              UNUM_ROUNDING_MODE,
                              UNUM_PADDING_POSITION,
                              UNUM_PARSE_INT_ONLY
                            };

@interface SBNumberFormatter(SBNumberFormatterPrivate)

- (BOOL) setupNumberFormatter;

@end

@implementation SBNumberFormatter(SBNumberFormatterPrivate)

  - (BOOL) setupNumberFormatter
  {
    if ( _icuNumberFormat == NULL ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      if ( _pattern ) {
        _icuNumberFormat = unum_open(
                              _numberStyle,
                              [_pattern utf16Characters],
                              [_pattern length],
                              ( _locale ? [_locale localeIdentifier] : NULL ),
                              NULL,
                              &icuErr
                            );
      } else {
        _icuNumberFormat = unum_open(
                              _numberStyle,
                              NULL,
                              0,
                              ( _locale ? [_locale localeIdentifier] : NULL ),
                              NULL,
                              &icuErr
                            );
      }
      
      if ( _icuNumberFormat ) {
        int         i = 0;
        
        // Set all integral attributes:
        while ( i < kSBDateFormatterAttr_Max ) {
          if ( _attributes[i] != SBNumberFormatterDefault )
            unum_setAttribute(_icuNumberFormat, __SBDateFormatterAttrMap[i], _attributes[i]);
          i++;
        }
         
        // Any other attributes:
        unum_setDoubleAttribute(_icuNumberFormat, UNUM_ROUNDING_INCREMENT, ( _roundingIncrement ? [_roundingIncrement doubleValue] : 0.0 ) );
      }
      return U_SUCCESS(icuErr);
    }
    return YES;
  }

@end

//
#pragma mark -
//

@implementation SBNumberFormatter

  - (id) init
  {
    if ( self = [super init] ) {
      int     i = 0;
      
      while ( i < kSBDateFormatterAttr_Max )
        _attributes[i++] = SBNumberFormatterDefault;
        
      [self setPattern:nil];
      [self setLocale:nil];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _icuNumberFormat ) unum_close(_icuNumberFormat);
    if ( _roundingIncrement ) [_roundingIncrement release];
    if ( _pattern ) [_pattern release];
    if ( _locale ) [_locale release];
    [super dealloc];
  }
  
//

  - (SBString*) stringFromNumber:(SBNumber*)aNumber
  {
    SBString*     result = nil;
    
    if ( [self setupNumberFormatter] ) {
      UErrorCode      icuErr = U_ZERO_ERROR;
      UChar*          buffer = NULL;
      int32_t         bufferLen = 0;
      const char*     nativeType = [aNumber objCType];
      
      if ( strcmp(nativeType, @encode(unsigned int)) == 0 ) {
        bufferLen = unum_formatInt64(
                      _icuNumberFormat,
                      [aNumber int64Value],
                      NULL,
                      0,
                      NULL,
                      &icuErr
                    );
        if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          UChar       buffer[bufferLen + 1];
          
          icuErr = U_ZERO_ERROR;
          bufferLen = unum_formatInt64(
                          _icuNumberFormat,
                          [aNumber int64Value],
                          buffer,
                          bufferLen + 1,
                          NULL,
                          &icuErr
                        );
          if ( U_SUCCESS(icuErr) )
            result = [SBString stringWithCharacters:buffer length:bufferLen];
        }
      }
      else if ( strcmp(nativeType, @encode(int)) == 0 ) {
        bufferLen = unum_format(
                      _icuNumberFormat,
                      [aNumber intValue],
                      NULL,
                      0,
                      NULL,
                      &icuErr
                    );
        if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          UChar       buffer[bufferLen + 1];
          
          icuErr = U_ZERO_ERROR;
          bufferLen = unum_format(
                          _icuNumberFormat,
                          [aNumber intValue],
                          buffer,
                          bufferLen + 1,
                          NULL,
                          &icuErr
                        );
          if ( U_SUCCESS(icuErr) )
            result = [SBString stringWithCharacters:buffer length:bufferLen];
        }
      }
      else if ( strcmp(nativeType, @encode(int64_t)) == 0 ) {
        bufferLen = unum_formatInt64(
                      _icuNumberFormat,
                      [aNumber int64Value],
                      NULL,
                      0,
                      NULL,
                      &icuErr
                    );
        if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          UChar       buffer[bufferLen + 1];
          
          icuErr = U_ZERO_ERROR;
          bufferLen = unum_formatInt64(
                          _icuNumberFormat,
                          [aNumber int64Value],
                          buffer,
                          bufferLen + 1,
                          NULL,
                          &icuErr
                        );
          if ( U_SUCCESS(icuErr) )
            result = [SBString stringWithCharacters:buffer length:bufferLen];
        }
      }
      else if ( strcmp(nativeType, @encode(double)) == 0 ) {
        bufferLen = unum_formatDouble(
                      _icuNumberFormat,
                      [aNumber doubleValue],
                      NULL,
                      0,
                      NULL,
                      &icuErr
                    );
        if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          UChar       buffer[bufferLen + 1];
          
          icuErr = U_ZERO_ERROR;
          bufferLen = unum_formatDouble(
                          _icuNumberFormat,
                          [aNumber doubleValue],
                          buffer,
                          bufferLen + 1,
                          NULL,
                          &icuErr
                        );
          if ( U_SUCCESS(icuErr) )
            result = [SBString stringWithCharacters:buffer length:bufferLen];
        }
      }
      else if ( strcmp(nativeType, @encode(BOOL)) == 0 ) {
        bufferLen = unum_format(
                      _icuNumberFormat,
                      [aNumber intValue],
                      NULL,
                      0,
                      NULL,
                      &icuErr
                    );
        if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          UChar       buffer[bufferLen + 1];
          
          icuErr = U_ZERO_ERROR;
          bufferLen = unum_format(
                          _icuNumberFormat,
                          [aNumber intValue],
                          buffer,
                          bufferLen + 1,
                          NULL,
                          &icuErr
                        );
          if ( U_SUCCESS(icuErr) )
            result = [SBString stringWithCharacters:buffer length:bufferLen];
        }
      }
      
    }
    return result;
  }
  
//

  - (SBNumber*) numberFromString:(SBString*)aString
  {
    SBNumber*       result = nil;
    
    if ( [self setupNumberFormatter] ) {
      UErrorCode  icuErr = U_ZERO_ERROR;
      
      if ( unum_getAttribute(_icuNumberFormat, UNUM_PARSE_INT_ONLY) ) {
        int64_t     value = unum_parseInt64(_icuNumberFormat, [aString utf16Characters], [aString length], NULL, &icuErr);
        
        if ( U_SUCCESS(icuErr) ) {
          if ( value > 0 && value <= UINT_MAX ) {
            result = [SBNumber numberWithUnsignedInt:(unsigned int)value];
          }
          else if ( value >= INT_MIN && value <= INT_MAX ) {
            result = [SBNumber numberWithInt:(int)value];
          }
          else {
            result = [SBNumber numberWithInt64:value];
          }
        }
      } else {
        double      value = unum_parseDouble(_icuNumberFormat, [aString utf16Characters], [aString length], NULL, &icuErr);
        
        if ( U_SUCCESS(icuErr) )
          result = [SBNumber numberWithDouble:value];
      }
    }
    return result;
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
    
    if ( _icuNumberFormat ) {
      unum_close(_icuNumberFormat);
      _icuNumberFormat = NULL;
    }
    
    [self setNumberStyle:( pattern ? UNUM_PATTERN_DECIMAL : UNUM_DEFAULT )];
  }

//

  - (UNumberFormatStyle) numberStyle
  {
    return _numberStyle;
  }
  - (void) setNumberStyle:(UNumberFormatStyle)numberStyle
  {
    if ( numberStyle != _numberStyle ) {
      switch ( numberStyle ) {
        
        case UNUM_DECIMAL:
        case UNUM_CURRENCY:
        case UNUM_PERCENT:
        case UNUM_SCIENTIFIC:
        case UNUM_SPELLOUT: {
          _numberStyle = numberStyle;
          
          if ( _icuNumberFormat ) {
            unum_close(_icuNumberFormat);
            _icuNumberFormat = NULL;
          }
          break;
        }
        
      }
    }
  }

//

  - (UNumberFormatRoundingMode) roundingMode
  {
    return _attributes[kSBDateFormatterAttr_RoundingMode];
  }
  - (void) setRoundingMode:(UNumberFormatRoundingMode)roundingMode
  {
    if ( _attributes[kSBDateFormatterAttr_RoundingMode] != roundingMode ) {
      _attributes[kSBDateFormatterAttr_RoundingMode] = roundingMode;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_ROUNDING_MODE, roundingMode);
    }
  }
  
//

  - (UNumberFormatPadPosition) paddingPosition
  {
    return _attributes[kSBDateFormatterAttr_PaddingPos];
  }
  - (void) setPaddingPosition:(UNumberFormatPadPosition)paddingPosition
  {
    if ( _attributes[kSBDateFormatterAttr_PaddingPos] != paddingPosition ) {
      _attributes[kSBDateFormatterAttr_PaddingPos] = paddingPosition;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_PADDING_POSITION, paddingPosition);
    }
  }
  
//

  - (SBNumber*) roundingIncrement
  {
    return _roundingIncrement;
  }
  - (void) setRoundingIncrement:(SBNumber*)number
  {
    if ( number ) number = [number copy];
    if ( _roundingIncrement ) [_roundingIncrement release];
    _roundingIncrement = number;
    
    if ( _icuNumberFormat )
      unum_setDoubleAttribute(_icuNumberFormat, UNUM_ROUNDING_INCREMENT, ( _roundingIncrement ? [_roundingIncrement doubleValue] : 0.0 ));
  }
  
//

  - (unsigned int) minimumIntegerDigits
  {
    return _attributes[kSBDateFormatterAttr_MinIntDigits];
  }
  - (void) setMinimumIntegerDigits:(unsigned int)digits
  {
    if ( _attributes[kSBDateFormatterAttr_MinIntDigits] != digits ) {
      _attributes[kSBDateFormatterAttr_MinIntDigits] = digits;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_MIN_INTEGER_DIGITS, digits);
    }
  }
  
//

  - (unsigned int) maximumIntegerDigits
  {
    return _attributes[kSBDateFormatterAttr_MaxIntDigits];  
  }
  - (void) setMaximumIntegerDigits:(unsigned int)digits
  {
    if ( _attributes[kSBDateFormatterAttr_MaxIntDigits] != digits ) {
      _attributes[kSBDateFormatterAttr_MaxIntDigits] = digits;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_MAX_INTEGER_DIGITS, digits);
    }
  }
  
//

  - (unsigned int) minimumFractionDigits
  {
    return _attributes[kSBDateFormatterAttr_MinFracDigits];
  }
  - (void) setMinimumFractionDigits:(unsigned int)digits
  {
    if ( _attributes[kSBDateFormatterAttr_MinFracDigits] != digits ) {
      _attributes[kSBDateFormatterAttr_MinFracDigits] = digits;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_MIN_FRACTION_DIGITS, digits);
    
      [self setParseIntegerOnly:( _attributes[kSBDateFormatterAttr_MinFracDigits] == 0 && _attributes[kSBDateFormatterAttr_MaxFracDigits] == 0 )];
    }
  }
  
//

  - (unsigned int) maximumFractionDigits
  {
    return _attributes[kSBDateFormatterAttr_MaxFracDigits];
  }
  - (void) setMaximumFractionDigits:(unsigned int)digits
  {
    if ( _attributes[kSBDateFormatterAttr_MaxFracDigits] != digits ) {
      _attributes[kSBDateFormatterAttr_MaxFracDigits] = digits;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_MAX_FRACTION_DIGITS, digits);
    
      [self setParseIntegerOnly:( _attributes[kSBDateFormatterAttr_MinFracDigits] == 0 && _attributes[kSBDateFormatterAttr_MaxFracDigits] == 0 )];
    }
  }
  
//

  - (BOOL) parseIntegerOnly
  {
    return _attributes[kSBDateFormatterAttr_IntOnly];
  }
  - (void) setParseIntegerOnly:(BOOL)parseIntOnly
  {
    if ( _attributes[kSBDateFormatterAttr_IntOnly] != parseIntOnly ) {
      _attributes[kSBDateFormatterAttr_IntOnly] = parseIntOnly;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_PARSE_INT_ONLY, _attributes[kSBDateFormatterAttr_IntOnly]);
    }
  }

//

  - (BOOL) alwaysShowsDecimalSeparator
  {
    return _attributes[kSBDateFormatterAttr_ShowDecSep];
  }
  - (void) setAlwaysShowsDecimalSeparator:(BOOL)state
  {
    if ( _attributes[kSBDateFormatterAttr_ShowDecSep] != state ) {
      _attributes[kSBDateFormatterAttr_ShowDecSep] = state;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_DECIMAL_ALWAYS_SHOWN, state);
    }
  }
  
//

  - (BOOL) usesGroupingSeparator
  {
    return _attributes[kSBDateFormatterAttr_UseGroupSep];
  }
  - (void) setUsesGroupingSeparator:(BOOL)state
  {
    if ( _attributes[kSBDateFormatterAttr_UseGroupSep] != state ) {
      _attributes[kSBDateFormatterAttr_UseGroupSep] = state;
      if ( _icuNumberFormat )
        unum_setAttribute(_icuNumberFormat, UNUM_GROUPING_USED, state);
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
    if ( _icuNumberFormat ) {
      unum_close(_icuNumberFormat);
      _icuNumberFormat = NULL;
    }
  }

@end
