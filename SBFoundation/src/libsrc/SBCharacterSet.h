//
// SBFoundation : ObjC Class Library for Solaris
// SBCharacterSet.h
//
// Unicode character sets, thanks to ICU.
//
// $Id$
//

#import "SBObject.h"
#include "unicode/uset.h"

#if SB64BitIntegers
#  error SBCharacterSet is not 64-bit clean.
#endif

@class SBString, SBData;

/*!
  @class SBCharacterSet
  @discussion
  Class which wraps an immutable ICU Unicode character set.  See the ICU documentation at:
  
    http://icu-project.org/apiref/icu4c/uset_8h.html
  
  A character set thus created has a fixed membership; see SBMutableCharacterSet if you need
  to dynamically add/remove characters from a character set.
*/
@interface SBCharacterSet : SBObject <SBMutableCopying>
{
  USet*       _icuCharSet;
}

+ (SBCharacterSet*) controlCharacterSet;
+ (SBCharacterSet*) whitespaceCharacterSet;
+ (SBCharacterSet*) whitespaceAndNewlineCharacterSet;
+ (SBCharacterSet*) newlineCharacterSet;
+ (SBCharacterSet*) decimalDigitCharacterSet;
+ (SBCharacterSet*) letterCharacterSet;
+ (SBCharacterSet*) lowercaseLetterCharacterSet;
+ (SBCharacterSet*) uppercaseLetterCharacterSet;
+ (SBCharacterSet*) marksCharacterSet;
+ (SBCharacterSet*) alphanumericCharacterSet;
+ (SBCharacterSet*) illegalCharacterSet;
+ (SBCharacterSet*) punctuationCharacterSet;
+ (SBCharacterSet*) capitalizedLetterCharacterSet;
+ (SBCharacterSet*) symbolCharacterSet;

/*!
  @method characterSetWithRange:
  
  Returns an autoreleased character set which contains all Unicode code points
  in the given range.
*/
+ (SBCharacterSet*) characterSetWithRange:(SBRange)aRange;
/*!
  @method characterSetWithCharactersInString:
  
  Returns an autoreleased character set which contains all unique Unicode code
  points in the given string.
*/
+ (SBCharacterSet*) characterSetWithCharactersInString:(SBString*)aString;
/*!
  @method characterSetWithBitmapRepresentation:
  
  Returns an autoreleased character set initialized from the given binary
  representation (wrapped by an SBData object).
*/
+ (SBCharacterSet*) characterSetWithBitmapRepresentation:(SBData*)aBitmap;
/*!
  @method invertedSet
  
  Returns an autoreleased copy of the receiver which has had its Unicode code point
  membership inverted.
*/
- (SBCharacterSet*) invertedSet;
/*!
  @method utf16CharacterIsMember:
  
  Returns YES if the given UTF-16 character is contained in the receiver's set.
*/
- (BOOL) utf16CharacterIsMember:(UChar)aCharacter;
/*!
  @method utf32CharacterIsMember:
  
  Returns YES if the given UTF-32 character is contained in the receiver's set.
*/
- (BOOL) utf32CharacterIsMember:(UChar32)aCharacter;
/*!
  @method isSupersetOfSet:
  
  Returns YES if the receiver contains all Unicode code points also present in
  otherCharSet.
*/
- (BOOL) isSupersetOfSet:(SBCharacterSet*)otherCharSet;
/*!
  @method bitmapRepresentation
  
  Returns an SBData object which contains a binary represenation of the character
  set.
*/
- (SBData*) bitmapRepresentation;

@end

/*!
  @class SBMutableCharacterSet
  @discussion
  A mutable character set contains a set of Unicode characters which can be
  dynamically altered.
*/
@interface SBMutableCharacterSet : SBCharacterSet

/*!
  @method addCharactersInRange:
  
  Add the given range of Unicode code points to the receiver's set.
*/
- (void) addCharactersInRange:(SBRange)aRange;
/*!
  @method removeCharactersInRange:
  
  Remove the given range of Unicode code points to the receiver's set.
*/
- (void) removeCharactersInRange:(SBRange)aRange;
/*!
  @method addCharactersInString:
  
  Add every unique Unicode code point in aString to the receiver's set.
*/
- (void) addCharactersInString:(SBString*)aString;
/*!
  @method removeCharactersInString:
  
  Remove every unique Unicode code point in aString to the receiver's set.
*/
- (void) removeCharactersInString:(SBString*)aString;
/*!
  @method unionWithCharacterSet:
  
  Add every Unicode code point contained in otherCharSet to the receiver's
  set.
*/
- (void) unionWithCharacterSet:(SBCharacterSet*)otherCharSet;
/*!
  @method intersectionWithCharacterSet:
  
  Remove any Unicode code points which the reciever's set does not have in
  common with otherCharSet.
*/
- (void) intersectionWithCharacterSet:(SBCharacterSet*)otherCharSet;
/*!
  @method invert
  
  Invert the receiver's set such that all Unicode code points that were not
  in it now are, and all code points that were not are.
*/
- (void) invert;

@end
