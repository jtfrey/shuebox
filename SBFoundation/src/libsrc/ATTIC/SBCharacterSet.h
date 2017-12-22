//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBCharacterSet.h
//
// Unicode character sets, thanks to ICU.
//
// $Id$
//

#import "SBObject.h"
#include "unicode/uset.h"

@class SBString, SBData;

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

+ (SBCharacterSet*) characterSetWithRange:(SBRange)aRange;
+ (SBCharacterSet*) characterSetWithCharactersInString:(SBString*)aString;
+ (SBCharacterSet*) characterSetWithBitmapRepresentation:(SBData*)aBitmap;

- (SBCharacterSet*) invertedSet;

- (BOOL) utf16CharacterIsMember:(UChar)aCharacter;
- (BOOL) utf32CharacterIsMember:(UChar32)aCharacter;

- (BOOL) isSupersetOfSet:(SBCharacterSet*)otherCharSet;

- (SBData*) bitmapRepresentation;

@end

@interface SBMutableCharacterSet : SBCharacterSet

- (void) addCharactersInRange:(SBRange)aRange;
- (void) removeCharactersInRange:(SBRange)aRange;

- (void) addCharactersInString:(SBString*)aString;
- (void) removeCharactersInString:(SBString*)aString;

- (void) unionWithCharacterSet:(SBCharacterSet*)otherCharSet;
- (void) intersectionWithCharacterSet:(SBCharacterSet*)otherCharSet;

- (void) invert;

@end
