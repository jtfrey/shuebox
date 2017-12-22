//
// SBFoundation : ObjC Class Library for Solaris
// SBScanner.h
//
// Process string contents.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBCharacterSet;

/*!
  @class SBScanner
  @discussion
    Instances of SBScanner are used to process the textual content of a string.  The
    scanner wraps an SBString object and an index within it; scanning always occurs
    at the index and if successful advances the index past the scanned content.
    
    Simple integer and floating-point values can be parsed by the scanner.  Floating-point
    values are expected to be in simplistic IEEE format with no localization of the
    decimal point, for example.
    
    An SBScanner be default ignores whitespace and newlines between the fields it scans.
    This can be overridden by setting an alternate SBCharacterSet or nil (implying no
    characters are ignored).  An SBScanner can also be made case-insensitive, which affects
    the string-scanning methods -- scanString:intoString: and scanUpToString:intoString:.
*/
@interface SBScanner : SBObject
{
  SBString*         _string;
  SBCharacterSet*   _charactersToBeSkipped;
  BOOL              _caseSensitive;
  SBRange           _scanRange;
  SBUInteger        _fullLength;
}

/*!
  @method scannerWithString:
  @discussion
    Returns a newly-allocated, autorelease SBScanner which can be used to process the
    contents of aString.
*/
+ (id) scannerWithString:(SBString*)aString;

/*!
  @method initWithString:
  @discussion
    Initializes the receiver to process the contents of aString.  The receiver is set to be
    case-sensitive and skip all whitespace and newline characters between the fields it
    scans.
*/
- (id) initWithString:(SBString*)aString;

/*!
  @method string
  @discussion
    Returns the string which the receiver is processing.
*/
- (SBString*) string;

/*!
  @method scanLocation
  @discussion
    Returns the character position at which the receiver will next scan.
*/
- (SBUInteger) scanLocation;

/*!
  @method setScanLocation:
  @discussion
    Alter the character position at which the receiver will next scan.
*/
- (void) setScanLocation:(SBUInteger)index;

/*!
  @method charactersToBeSkipped
  @discussion
    Returns the SBCharacterSet the receiver uses to identify characters which will
    be skipped between fields.
*/
- (SBCharacterSet*) charactersToBeSkipped;

/*!
  @method setCharactersToBeSkipped:
  @discussion
    Sets the receiver to skip all characters in skipSet before scanning a field.
    If skipSet is nil then no characters are skipped.
*/
- (void) setCharactersToBeSkipped:(SBCharacterSet*)skipSet;

/*!
  @method caseSensitive
  @discussion
    Returns YES if the receiver uses case-sensitive string matching in the
    scanString:intoString: and scanUpToString:intoString: methods.
*/
- (BOOL) caseSensitive;

/*!
  @method setCaseSensitive:
  @discussion
    Pass YES if the receiver should use case-sensitive string matching in the
    scanString:intoString: and scanUpToString:intoString: methods; NO if those
    methods should ignore case.
*/
- (void) setCaseSensitive:(BOOL)caseSensitive;

/*!
  @method scanInteger:
  @discussion
    Returns YES if the receiver scans and converts an integer value from the
    string.  If the result would overflow the limits of an SBInteger type it
    is clamped at the extrema and YES is still returned.
*/
- (BOOL) scanInteger:(SBInteger*)value;

/*!
  @method scanInt:
  @discussion
    Returns YES if the receiver scans and converts an integer value from the
    string.  If the result would overflow a 32-bit integer it is clamped at the
    extrema and YES is still returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanInt:(int*)value;

/*!
  @method scanLongLong:
  @discussion
    Returns YES if the receiver scans and converts an integer value from the
    string.  If the result would overflow a 64-bit integer it is clamped at the
    extrema and YES is still returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanLongLong:(long long*)value;

/*!
  @method scanHexInt:
  @discussion
    Returns YES if the receiver scans and converts from the string an integer value
    in hexadecimal format.  If the result would overflow a 32-bit unsigned integer
    it is clamped at the maximul and YES is still returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanHexInt:(unsigned int*)value;

/*!
  @method scanHexLongLong:
  @discussion
    Returns YES if the receiver scans and converts from the string an integer value
    in hexadecimal format.  If the result would overflow a 64-bit unsigned integer
    it is clamped at the maximul and YES is still returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanHexLongLong:(unsigned long long int*)value;

/*!
  @method scanFloat:
  Returns YES if the receiver scans and converts a floating-point value from the
  string.  If the result would overflow a single-precision float, ±Inf is returned;
  if the result would underflow ±0 is returned.  The special values ±Infinity and
  ±NaN are also properly scanned and returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanFloat:(float*)value;

/*!
  @method scanDouble:
  Returns YES if the receiver scans and converts a floating-point value from the
  string.  If the result would overflow a double-precision float, ±Inf is returned;
  if the result would underflow ±0 is returned.  The special values ±Infinity and
  ±NaN are also properly scanned and returned.
    
    Invoke this method with value of NULL to simply scan past a given number.
*/
- (BOOL) scanDouble:(double*)value;

/*!
  @method scanString:intoString:
  @discussion
    If aString is present at the current scan location, then the current scan location
    is advanced to after it; otherwise the scan location does not change.  A copy of the
    matching sub-string is returned in value.
    
    Invoke this method with value of NULL to simply scan past a given string.  Returns
    YES if aString was found.
*/
- (BOOL) scanString:(SBString*)aString intoString:(SBString**)value;

/*!
  @method scanCharactersFromSet:intoString:
  @discussion
    Scans the string as long as characters from a given character set are encountered,
    accumulating characters into a string that’s returned by reference in value.
    
    Invoke this method with value of NULL to simply scan up to a given string.  Returns
    YES if any characters from aSet are found.
*/
- (BOOL) scanCharactersFromSet:(SBCharacterSet*)aSet intoString:(SBString**)value;

/*!
  @method scanUpToString:intoString:
  @discussion
    If aString is present anywhere after the current scan location, then the current scan
    location is advanced to it; otherwise the scan location does not change.  A copy of the
    characters present between the current scan location and the first occurrence of aString
    is returned in value.
    
    Invoke this method with value of NULL to simply scan up to a given string.  Returns
    YES if aString was found.
*/
- (BOOL) scanUpToString:(SBString*)aString intoString:(SBString**)value;

/*!
  @method scanUpToCharactersFromSet:intoString:
  @discussion
    Scans the string until a character from a given character set is encountered, accumulating
    characters into a string that’s returned by reference in value.
    
    If no characters in aSet are present in the receiver's source string, the remainder of the
    source string is put into value, the receiver’s scanLocation is advanced to the end of the
    source string, and the method returns YES.
    
    Invoke this method with value of NULL to simply scan up to a given string.  Returns
    YES if any characters from aSet are found.
*/
- (BOOL) scanUpToCharactersFromSet:(SBCharacterSet*)aSet intoString:(SBString**)value;

/*!
  @method isAtEnd
  @discussion
    Returns YES if the receiver's scan location is at the end of the source string.
*/
- (BOOL) isAtEnd;

@end
