//
// SBFoundation : ObjC Class Library for Solaris
// SBCharacterSet.m
//
// Unicode character sets, thanks to ICU.
//
// $Id$
//

#import "SBCharacterSet.h"
#import "SBString.h"
#import "SBData.h"

#import "SBCharacterSetPrivate.h"

#include "unicode/uversion.h"

#ifdef NEED_USET_ALLCODEPOINTS

void
uset_addAllCodePoints(
  USet*         set,
  const UChar*  str,
  int32_t       strLen	 
)
{
  if ( set && str ) {
    UChar32       c;
    int32_t       i = 0;
    
    if ( strLen < 0 )
      strLen = u_strlen(str);
    while ( i < strLen ) {
      U16_NEXT(str, i, strLen, c);
      uset_add(set, c);
    }
  }
}

UBool
uset_containsAllCodePoints(
  USet*         set,
  const UChar*  str,
  int32_t       strLen	 
)
{
  if ( set && str ) {
    UChar32       c;
    int32_t       i = 0;
    
    if ( strLen < 0 )
      strLen = u_strlen(str);
    while ( i < strLen ) {
      U16_NEXT(str, i, strLen, c);
      if ( ! uset_contains(set, c) )
        return FALSE;
    }
    return TRUE;
  }
  return FALSE;
}

#endif

//

#ifdef NEED_USET_FREEZE

void
uset_freeze(
  USet*   set
)
{
  uset_compact(set);
}

UBool
uset_isFrozen(
  const USet* set
)
{
  return FALSE;
}

#endif

//

#ifdef NEED_USET_CLONE

USet*
uset_cloneAsThawed(
  const USet*   set
)
{
  USet*     result = NULL;
  
  if ( set ) {
    result = uset_open(1,0);
    if ( result )
      uset_addAll(result, set);
  }
  return result;
}

USet*
uset_clone(
  const USet*   set
)
{
  USet*     result = uset_cloneAsThawed(set);
  
  if ( result )
    uset_freeze(result);
  return result;
}

#endif

//

@implementation SBCharacterSet(SBCharacterSetPrivate)

  - (id) initWithICUCharacterSet:(USet*)icuCharSet
  {
    if ( self = [super init] ) {
      if ( (_icuCharSet = icuCharSet) && ! uset_isFrozen(_icuCharSet) )
        uset_freeze(_icuCharSet);
    }
    return self;
  }

//

  - (id) initWithPattern:(UChar*)pattern
  {
    UErrorCode      uErr = U_ZERO_ERROR;
    USet*           newSet = NULL;
    
    newSet = uset_openPattern(pattern, -1, &uErr);
    if ( U_SUCCESS(uErr) )
      return [self initWithICUCharacterSet:newSet];
    
    [self release];
    return nil;
  }

//

  - (id) initWithRange:(SBRange)aRange
  {
    USet*           newSet = NULL;
    
    newSet = uset_open(aRange.start, aRange.start + aRange.length - 1);
    return [self initWithICUCharacterSet:newSet];
  }

//

  - (id) initWithCharactersInString:(SBString*)aString
  {
    USet*           newSet = NULL;
    
    newSet = uset_open(1, 0);
    if ( newSet ) {
      uset_addAllCodePoints(newSet, [aString utf16Characters], [aString length]);
      return [self initWithICUCharacterSet:newSet];
    }
    
    [self release];
    return nil;
  }

//

  - (id) initWithBitmapRepresentation:(SBData*)aBitmap
  {
    USerializedSet    serialSet;
    
    if ( uset_getSerializedSet(&serialSet, [aBitmap bytes], [aBitmap length] / sizeof(uint16_t)) ) {
      USet*           newSet = uset_open(1, 0);
      
      if ( newSet ) {
        int32_t       i = 0, iMax = uset_getSerializedRangeCount(&serialSet);
        
        while ( i < iMax ) {
          int32_t     low,high;
          
          if ( uset_getSerializedRange(&serialSet, i++, &low, &high) )
            uset_addRange(newSet, low, high);
        }
        return [self initWithICUCharacterSet:newSet];
      }
    }
    
    [self release];
    return nil;
  }

//

  - (USet*) icuCharSet
  {
    return _icuCharSet;
  }

@end

//
#pragma mark -
//

@implementation SBCharacterSet

  + (SBCharacterSet*) controlCharacterSet
  {
    static SBCharacterSet*   __SBControlCharacterSet = nil;
    static UChar             __SBControlCharacterSetPattern[] = { '[' , ':' , 'C' , ':' , ']' , 0 };
    
    if ( __SBControlCharacterSet == nil )
      __SBControlCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBControlCharacterSetPattern];
    
    return __SBControlCharacterSet;
  }
  
//

  + (SBCharacterSet*) whitespaceCharacterSet
  {
    static SBCharacterSet*   __SBWhitespaceCharacterSet = nil;
    static UChar             __SBWhitespaceCharacterSetPattern[] = { '[' , \
                                      '[' , ':' , 'Z' , 's' , ':' , ']' , \
                                      '[' , '\\' , '\t' , ']' , \
                                      ']', 0 };
    
    if ( __SBWhitespaceCharacterSet == nil )
      __SBWhitespaceCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBWhitespaceCharacterSetPattern];
    
    return __SBWhitespaceCharacterSet;
  }
  
//

  + (SBCharacterSet*) whitespaceAndNewlineCharacterSet
  {
    static SBCharacterSet*   __SBWhitespaceAndNewlineCharacterSet = nil;
    static UChar             __SBWhitespaceAndNewlineCharacterSetPattern[] = { '[' , \
                                      '[' , ':' , 'Z' , ':' , ']' , \
                                      '[' , '\\' , '\n' , '\\' , '\r' , '\\' , '\t' , ']' , \
                                      ']', 0 };
    
    if ( __SBWhitespaceAndNewlineCharacterSet == nil )
      __SBWhitespaceAndNewlineCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBWhitespaceAndNewlineCharacterSetPattern];
    
    return __SBWhitespaceAndNewlineCharacterSet;
  }
  
//

  + (SBCharacterSet*) newlineCharacterSet
  {
    static SBCharacterSet*   __SBNewlineCharacterSet = nil;
    static UChar             __SBNewlineCharacterSetPattern[] = { '[' , \
                                      '[' , ':' , 'Z' , 'l' , ':' , ']' , \
                                      '[' , '\\' , '\n' , '\\' , '\r', ']' , \
                                      ']', 0 };
    
    if ( __SBNewlineCharacterSet == nil )
      __SBNewlineCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBNewlineCharacterSetPattern];
    
    return __SBNewlineCharacterSet;
  }
  
//

  + (SBCharacterSet*) decimalDigitCharacterSet
  {
    static SBCharacterSet*   __SBDecimalDigitCharacterSet = nil;
    static UChar             __SBDecimalDigitCharacterSetPattern[] = { '[' , ':' , 'N' , 'd' , ':' , ']' , 0 };
    
    if ( __SBDecimalDigitCharacterSet == nil )
      __SBDecimalDigitCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBDecimalDigitCharacterSetPattern];
    
    return __SBDecimalDigitCharacterSet;
  }
  
//

  + (SBCharacterSet*) letterCharacterSet
  {
    static SBCharacterSet*   __SBLetterCharacterSet = nil;
    static UChar             __SBLetterCharacterSetPattern[] = { '[' , ':' , 'L' , ':' , ']' , 0 };
    
    if ( __SBLetterCharacterSet == nil )
      __SBLetterCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBLetterCharacterSetPattern];
    
    return __SBLetterCharacterSet;
  }
  
//

  + (SBCharacterSet*) lowercaseLetterCharacterSet
  {
    static SBCharacterSet*   __SBLowercaseLetterCharacterSet = nil;
    static UChar             __SBLowercaseLetterCharacterSetPattern[] = { '[' , ':' , 'L' , 'l' , ':' , ']' , 0 };
    
    if ( __SBLowercaseLetterCharacterSet == nil )
      __SBLowercaseLetterCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBLowercaseLetterCharacterSetPattern];
    
    return __SBLowercaseLetterCharacterSet;
  }
  
//

  + (SBCharacterSet*) uppercaseLetterCharacterSet
  {
    static SBCharacterSet*   __SBUppercaseLetterCharacterSet = nil;
    static UChar             __SBUppercaseLetterCharacterSetPattern[] = { '[' , ':' , 'L' , 'u' , ':' , ']' , 0 };
    
    if ( __SBUppercaseLetterCharacterSet == nil )
      __SBUppercaseLetterCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBUppercaseLetterCharacterSetPattern];
    
    return __SBUppercaseLetterCharacterSet;
  }
  
//

  + (SBCharacterSet*) marksCharacterSet
  {
    static SBCharacterSet*   __SBMarksCharacterSet = nil;
    static UChar             __SBMarksCharacterSetPattern[] = { '[' , ':' , 'M' , ':' , ']' , 0 };
    
    if ( __SBMarksCharacterSet == nil )
      __SBMarksCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBMarksCharacterSetPattern];
    
    return __SBMarksCharacterSet;
  }
  
//

  + (SBCharacterSet*) alphanumericCharacterSet
  {
    static SBCharacterSet*   __SBAlphanumericCharacterSet = nil;
    static UChar             __SBAlphanumericCharacterSetPattern[] = { '[' , \
                                                                             '[' , ':' , 'L' , ':' , ']' , \
                                                                             '[' , ':' , 'M' , ':' , ']' , \
                                                                             '[' , ':' , 'N' , ':' , ']' , \
                                                                       ']' , 0 };
    
    if ( __SBAlphanumericCharacterSet == nil )
      __SBAlphanumericCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBAlphanumericCharacterSetPattern];
    
    return __SBAlphanumericCharacterSet;
  }
  
//

  + (SBCharacterSet*) illegalCharacterSet
  {
    static SBCharacterSet*   __SBIllegalCharacterSet = nil;
    static UChar             __SBIllegalCharacterSetPattern[] = { '[' , ':' , 'C' , 'n' , ':' , ']' , 0 };
    
    if ( __SBIllegalCharacterSet == nil )
      __SBIllegalCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBIllegalCharacterSetPattern];
    
    return __SBIllegalCharacterSet;
  }
  
//

  + (SBCharacterSet*) punctuationCharacterSet
  {
    static SBCharacterSet*   __SBPunctuationCharacterSet = nil;
    static UChar             __SBPunctuationCharacterSetPattern[] = { '[' , ':' , 'P' , ':' , ']' , 0 };
    
    if ( __SBPunctuationCharacterSet == nil )
      __SBPunctuationCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBPunctuationCharacterSetPattern];
    
    return __SBPunctuationCharacterSet;
  }
  
//

  + (SBCharacterSet*) capitalizedLetterCharacterSet
  {
    static SBCharacterSet*   __SBCapitalizedLetterCharacterSet = nil;
    static UChar             __SBCapitalizedLetterCharacterSetPattern[] = { '[' , ':' , 'L' , 't' , ':' , ']' , 0 };
    
    if ( __SBCapitalizedLetterCharacterSet == nil )
      __SBCapitalizedLetterCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBCapitalizedLetterCharacterSetPattern];
    
    return __SBCapitalizedLetterCharacterSet;
  }
  
//

  + (SBCharacterSet*) symbolCharacterSet
  {
    static SBCharacterSet*   __SBSymbolCharacterSet = nil;
    static UChar             __SBSymbolCharacterSetPattern[] = { '[' , ':' , 'S' , ':' , ']' , 0 };
    
    if ( __SBSymbolCharacterSet == nil )
      __SBSymbolCharacterSet = [[SBCharacterSet alloc] initWithPattern:__SBSymbolCharacterSetPattern];
    
    return __SBSymbolCharacterSet;
  }

//

  + (SBCharacterSet*) characterSetWithRange:(SBRange)aRange
  {
    return [[[SBCharacterSet alloc] initWithRange:aRange] autorelease];
  }
  
//

  + (SBCharacterSet*) characterSetWithCharactersInString:(SBString*)aString
  {
    return [[[SBCharacterSet alloc] initWithCharactersInString:aString] autorelease];
  }

//

  + (SBCharacterSet*) characterSetWithBitmapRepresentation:(SBData*)aBitmap
  {
    return [[[SBCharacterSet alloc] initWithBitmapRepresentation:aBitmap] autorelease];
  }

//

  - (void) dealloc
  {
    if ( _icuCharSet ) uset_close(_icuCharSet);
    [super dealloc];
  }
  
//

  - (id) mutableCopy
  {
    USet*     setCopy = NULL;
    
    if ( _icuCharSet )
      setCopy = uset_cloneAsThawed((const USet*)_icuCharSet);
    
    return [[SBMutableCharacterSet alloc] initWithICUCharacterSet:setCopy];
  }

//

  - (SBCharacterSet*) invertedSet
  {
    SBCharacterSet*   result = nil;
    
    if ( _icuCharSet ) {
      USet*       newSet = uset_cloneAsThawed((const USet*)_icuCharSet);
      
      if ( newSet ) {
        uset_complement(newSet);
        result = [[[[self class] alloc] initWithICUCharacterSet:newSet] autorelease];
      }
    }
    return result;
  }

//

  - (BOOL) utf16CharacterIsMember:(UChar)aCharacter
  {
    if ( _icuCharSet ) {
      if ( uset_containsAllCodePoints(_icuCharSet, &aCharacter, 1) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) utf32CharacterIsMember:(UChar32)aCharacter
  {
    if ( _icuCharSet ) {
      if ( uset_contains(_icuCharSet, aCharacter) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) isSupersetOfSet:(SBCharacterSet*)otherCharSet
  {
    BOOL      result = NO;
    
    if ( _icuCharSet ) {
      USet*   other = ( otherCharSet ? [otherCharSet icuCharSet] : NULL );
      
      result = YES;
      if ( other && ! uset_containsAll(_icuCharSet, other) )
        result = NO;
    }
    return result;
  }

//

  - (SBData*) bitmapRepresentation
  {
    SBData*     result = nil;
    
    if ( _icuCharSet ) {
      int32_t       actLen;
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      actLen = uset_serialize(
                    _icuCharSet,
                    NULL,
                    0,
                    &icuErr
                  );
      if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
        uint16_t*   buffer = (uint16_t*)objc_malloc(actLen * sizeof(uint16_t));
        if ( buffer ) {
          icuErr = U_ZERO_ERROR;
          uset_serialize(
              _icuCharSet,
              buffer,
              actLen,
              &icuErr
            );
          if ( U_FAILURE(icuErr) ) {
            objc_free(buffer);
            [result release];
            result = nil;
          } else {
            result = [SBData dataWithBytesNoCopy:buffer length:actLen * sizeof(uint16_t)];
          }
        }
      }
    }
    return result;
  }

@end

//
#pragma mark -
//

@implementation SBMutableCharacterSet

  - (id) init
  {
    return [self initWithRange:SBEmptyRange];
  }

//

  - (id) copy
  {
    USet*     setCopy = NULL;
    
    if ( _icuCharSet )
      setCopy = (USet*)uset_clone(_icuCharSet);
    
    return [[SBCharacterSet alloc] initWithICUCharacterSet:setCopy];
  }
  
//

  - (id) initWithICUCharacterSet:(USet*)icuCharSet
  {
    if ( self = [super init] ) {
      _icuCharSet = icuCharSet;
    }
    return self;
  }

//

  - (void) addCharactersInRange:(SBRange)aRange
  {
    if ( _icuCharSet )
      uset_addRange(_icuCharSet, aRange.start, aRange.start + aRange.length - 1);
  }
  
//

  - (void) removeCharactersInRange:(SBRange)aRange
  {
    if ( _icuCharSet )
      uset_removeRange(_icuCharSet, aRange.start, aRange.start + aRange.length - 1);
  }
  
//

  - (void) addCharactersInString:(SBString*)aString
  {
    if ( _icuCharSet )
      uset_addAllCodePoints(_icuCharSet, [aString utf16Characters], [aString length]);
  }
  
//

  - (void) removeCharactersInString:(SBString*)aString
  {
    if ( _icuCharSet && aString && [aString length] ) {
      USet*     removeSet = uset_open(1, 0);
      
      if ( removeSet ) {
        uset_addAllCodePoints(removeSet, [aString utf16Characters], [aString length]);
        uset_removeAll(_icuCharSet, removeSet);
        uset_close(removeSet);
      }
    }
  }
  
//

  - (void) unionWithCharacterSet:(SBCharacterSet*)otherCharSet
  {
    if ( _icuCharSet && otherCharSet ) {
      USet*     otherSet = [otherCharSet icuCharSet];
      
      if ( otherSet )
        uset_addAll(_icuCharSet, otherSet);
    }
  }
  
//

  - (void) intersectionWithCharacterSet:(SBCharacterSet*)otherCharSet
  {
    if ( _icuCharSet && otherCharSet ) {
      USet*     otherSet = [otherCharSet icuCharSet];
      
      if ( otherSet )
        uset_retainAll(_icuCharSet, otherSet);
    }
  }

//

  - (void) invert
  {
    if ( _icuCharSet )
      uset_complement(_icuCharSet);
  }

@end
