//
// SBFoundation : ObjC Class Library for Solaris
// SBString.m
//
// Unicode string class
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

/*

== On the Implementation of SBString and Friends ===============

Class cluster:

  SBString
    |- SBStringConst
    |- SBStringSubString
    |- SBConcreteString
         |- SBConcreteStringSubString
    |- SBMutableString
         |- SBConcreteMutableString

The two sub-string classes are present because the content of an immutable string
cannot change, so a substring can refer directly to the original characters rather
than making a copy of them.  SBString will return SBStringSubString objects from
its substring* methods; an SBStringSubString object retains a reference to the parent
string object and modifies the characterAtIndex: method to call-through to the parent's
method with a properly-modified offset (according to the range with which the
SBStringSubString was initialized).  The SBConcreteStringSubString object is a subclass
of SBConcreteString which also retains a reference to the parent string but sends itself
the initWithUncopiedCharacters:length:freeWhenDone: message with the applicable region 
of the parent strings' UTF-16 buffer.

Note that SBConcreteMutableString does NOT descend from SBConcreteString; this implies
that many of the UTF-16-optimized methods from SBConcreteString had to be duplicated in
SBConcreteMutableString.  Kinda unfortunate, but it still beats the mess that is
multiple inheritance!


== String Compare and Search ===================================

String comparison and search operations make use of the ICU comparator and search
facilities in order to provide locale-dependent, full-featured text analysis
capabilities.  In particular:

  - Case-insensitive OR case-sensitive character testing
  - Diacritic-insensitive OR diacritic-sensitive character testing
  - Value-sensitive OR character-sensitive numerical sub-string testing
  - Literal or canonical character testing
  - Anchored searching
  - From-end (backwards) searching
  
String comparison operations are optimized on a per-encoding basis; compare:
methods which are invoked with a mix of UTF-8 and UTF-16 encoded string classes
setup character iterators for the strings' native encodings (rather than
transcoding to UTF-16 and working directly with full strings).  Searching,
however, requires the UTF-16 encoding, and thus UTF-8-native string classes
will transcode to UTF-16 when used in any search-oriented methods.

See the declaration and definition of the SBUnicodeSearch class below for
more details on compare/search.

 */

#import "SBString.h"
#import "SBData.h"
#import "SBLocale.h"
#import "SBCharacterSet.h"
#import "SBCharacterSetPrivate.h"
#import "SBDictionary.h"
#import "SBValue.h"
#import "SBArray.h"

#include "SBMemoryPool.h"

#include "unicode/ustring.h"
#include "unicode/ustdio.h"
#include "unicode/uset.h"
#include "unicode/uchar.h"
#include "unicode/ucasemap.h"

//

#include "unicode/ucol.h"
#include "unicode/uiter.h"
#include "unicode/usearch.h"

//

SBComparisonResult
__SBString_BasicComparison(
  SBString*     sPrimary,
  SBRange       rPrimary,
  SBString*     sSecondary,
  BOOL          caseless,
  BOOL          byCodePoint
)
{
  UCharIterator       iPrimary, iSecondary;
  int32_t             lPrimary, lSecondary;
  
  // We may as well short-cut 
  if ( sPrimary == sSecondary )
    return SBOrderSame;
      
  // Setup the iterator for sPrimary:
  switch ( [sPrimary nativeEncoding] ) {
    case kSBStringUTF8NativeEncoding: {
      if ( (lPrimary = [sPrimary utf8Length]) ) {
        unsigned char     *s = (unsigned char*)[sPrimary utf8Characters];
        int32_t           iStart = 0, iEnd;
        UChar32           C;
        
        //
        // We need to skip over the first rPrimary.start UTF16 characters in the UTF8
        // buffer:
        //
        while ( iStart < lPrimary && rPrimary.start) {
          U8_NEXT(s, iStart, lPrimary, C);
          
          if ( C == U_SENTINEL )
            return SBOrderAscending;
            
          rPrimary.start--;
          if ( C > 0x10000 ) {
            // Two UTF16 characters:
            if ( rPrimary.start > 0 ) {
              rPrimary.start--;
            } else {
              // Note that we may actually get two UTF16 entities here, but it makes
              // no sense to stop on the lead surrogate.  So we round down to the start
              // of the surrogate pair:
              s -= 4;
            }
          }
        }
        
        //
        // Now, locate the end of the character range likewise:
        //
        iEnd = iStart;
        while ( iEnd < lPrimary && rPrimary.length ) {
          U8_NEXT(s, iEnd, lPrimary, C);
          
          // End of string reached somehow?
          if ( C == U_SENTINEL )
            break;
            
          rPrimary.length--;
          if ( C > 0x10000 ) {
            // Two UTF16 characters:
            if ( rPrimary.length > 0 ) {
              rPrimary.length--;
            }
            // Note that we may actually get two UTF16 entities here, but it makes
            // no sense to stop on the lead surrogate.  So we round up to the end
            // of the surrogate pair -- actually requires no op
          }
        }
        uiter_setUTF8(&iPrimary, s + iStart, iEnd - iStart);
      }
      break;
    }
    default: {
      if ( (lPrimary = [sPrimary length]) ) {
        if ( rPrimary.start >= lPrimary ) {
          rPrimary.start = lPrimary;
          rPrimary.length = 0;
        } else if ( rPrimary.start + rPrimary.length > lPrimary ) {
          rPrimary.length = lPrimary - rPrimary.start;
        }
        uiter_setString(&iPrimary, [sPrimary utf16Characters] + rPrimary.start, rPrimary.length);
      }
      break;
    }
  }
  
  // Setup the iterator for sSecondary:
  switch ( [sSecondary nativeEncoding] ) {
    case kSBStringUTF8NativeEncoding: {
      if ( (lSecondary = [sSecondary utf8Length]) ) 
        uiter_setUTF8(&iSecondary, [sSecondary utf8Characters], lSecondary);
      break;
    }
    default: {
      if ( (lSecondary = [sSecondary length]) ) 
        uiter_setString(&iSecondary, [sSecondary utf16Characters], lSecondary);
      break;
    }
  }
  
  if ( lPrimary ) {
    if ( lSecondary ) {
      int32_t   cmp;
      
      if ( ! caseless ) {
        cmp = u_strCompareIter(&iPrimary, &iSecondary, ( byCodePoint ? TRUE : FALSE ));
      } else {
        UChar32   C1, C2;
        int32_t   i1, i2;
        
        do {
          C1 = u_tolower(uiter_next32(&iPrimary));
          C2 = u_tolower(uiter_next32(&iSecondary));
          if ( C1 != C2 )
            break;
          if ( C1 == -1 )
            return SBOrderSame;
        } while ( 1 );
        if ( C2 == -1 )
          return SBOrderDescending;
        cmp = C1 - C2;
      }
      
      if ( cmp < 0 )
        return SBOrderAscending;
      if ( cmp > 0 )
        return SBOrderDescending;
      return SBOrderSame;
    }
    return SBOrderDescending;
  } else if ( ! lSecondary ) {
    // BOTH are zero length:
    return SBOrderSame;
  }
  return SBOrderAscending;
}

SBComparisonResult
__SBString_LocalizedCaselessComparison(
  SBString*     sPrimary,
  SBRange       rPrimary,
  SBString*     sSecondary,
  SBLocale*     locale
)
{
  //
  // We can't be as cool at the base literal comparison and use iterators; the ICU
  // APIs for case folding require the full string. :-(
  //
  UCharIterator             iPrimary, iSecondary;
  int32_t                   lPrimary, lSecondary;
  static SBMemoryPoolRef    pool = NULL;
  static UCaseMap*          caseMap = NULL;
  UErrorCode                icuErr = U_ZERO_ERROR;
  int                       cmp;
  
  // We may as well short-cut 
  if ( sPrimary == sSecondary )
    return SBOrderSame;
  
  // Make ourselves a memory pool:
  if ( (pool == NULL) && ((pool = SBMemoryPoolCreate(0)) == NULL) ) {
    return SBOrderSame;
  }
  SBMemoryPoolDrain(pool);
  
  //
  // Setup the case mapper; only neccesary to do UTF-8 strings without a conversion
  // to UTF-16, but we'll keep it on hand no matter what:
  //
  if ( caseMap == NULL ) {
    caseMap = ucasemap_open(
        (const char*)( locale ? [locale localeIdentifier] : NULL ),
        U_COMPARE_CODE_POINT_ORDER,
        &icuErr
      );
  } else {
    ucasemap_setLocale(
        caseMap,
        (const char*)( locale ? [locale localeIdentifier] : NULL ),
        &icuErr
      );
  }
  
  //
  // Setup the iterator for the primary string; automagically convert to caseless:
  //
  switch ( [sPrimary nativeEncoding] ) {
    case kSBStringUTF8NativeEncoding: {
      if ( (lPrimary = [sPrimary utf8Length]) ) {
        unsigned char     *s = (unsigned char*)[sPrimary utf8Characters];
        int32_t           iStart = 0, iEnd;
        UChar32           C;
        
        //
        // We need to skip over the first rPrimary.start UTF16 characters in the UTF8
        // buffer:
        //
        while ( iStart < lPrimary && rPrimary.start) {
          U8_NEXT(s, iStart, lPrimary, C);
          
          if ( C == U_SENTINEL )
            return SBOrderAscending;
            
          rPrimary.start--;
          if ( C > 0x10000 ) {
            // Two UTF16 characters:
            if ( rPrimary.start > 0 ) {
              rPrimary.start--;
            } else {
              // Note that we may actually get two UTF16 entities here, but it makes
              // no sense to stop on the lead surrogate.  So we round down to the start
              // of the surrogate pair:
              s -= 4;
            }
          }
        }
        
        //
        // Now, locate the end of the character range likewise:
        //
        iEnd = iStart;
        while ( iEnd < lPrimary && rPrimary.length ) {
          U8_NEXT(s, iEnd, lPrimary, C);
          
          // End of string reached somehow?
          if ( C == U_SENTINEL )
            break;
            
          rPrimary.length--;
          if ( C > 0x10000 ) {
            // Two UTF16 characters:
            if ( rPrimary.length > 0 ) {
              rPrimary.length--;
            }
            // Note that we may actually get two UTF16 entities here, but it makes
            // no sense to stop on the lead surrogate.  So we round up to the end
            // of the surrogate pair -- actually requires no op
          }
        }
        //
        // Setup the iterator:
        //
        if ( U_SUCCESS(icuErr) && caseMap && (iEnd - iStart) ) {
          int32_t     reqBytes;
          
          icuErr = U_ZERO_ERROR;
          reqBytes = ucasemap_utf8ToLower(
                          caseMap,
                          NULL,
                          0,
                          s + iStart,
                          iEnd - iStart,
                          &icuErr
                        );
          if ( ((icuErr == U_BUFFER_OVERFLOW_ERROR) || U_SUCCESS(icuErr)) && reqBytes ) {
            unsigned char*      p = SBMemoryPoolAlloc(pool, ++reqBytes);
            
            icuErr= U_ZERO_ERROR;
            if ( p ) {
              ucasemap_utf8ToLower(
                  caseMap,
                  p,
                  reqBytes,
                  s + iStart,
                  iEnd - iStart,
                  &icuErr
                );
              uiter_setUTF8(&iPrimary, p, reqBytes);
            } else {
              uiter_setUTF8(&iPrimary, s + iStart, iEnd - iStart);
            }
          } else {
            uiter_setUTF8(&iPrimary, s + iStart, iEnd - iStart);
          }
        } else {
          uiter_setUTF8(&iPrimary, s + iStart, iEnd - iStart);
        }
      }
      break;
    }
    default: {
      if ( (lPrimary = [sPrimary length]) ) {
        UChar*        cPrimary = (UChar*)[sPrimary utf16Characters];
        
        if ( rPrimary.start >= lPrimary ) {
          rPrimary.start = lPrimary;
          rPrimary.length = 0;
        } else if ( rPrimary.start + rPrimary.length > lPrimary ) {
          rPrimary.length = lPrimary - rPrimary.start;
        }
        if ( rPrimary .length ) {
          int32_t       reqChars;
          
          icuErr = U_ZERO_ERROR;
          reqChars = u_strToLower(
                        NULL,
                        0,
                        cPrimary + rPrimary.start,
                        rPrimary.length,
                        ( locale ? [locale localeIdentifier] : NULL ),
                        &icuErr
                      );
          if ( ((icuErr == U_BUFFER_OVERFLOW_ERROR) || U_SUCCESS(icuErr)) && reqChars ) {
            UChar*          p = SBMemoryPoolAlloc(pool, sizeof(UChar) * reqChars);
            
            icuErr= U_ZERO_ERROR;
            if ( p ) {
              u_strToLower(
                  p,
                  reqChars,
                  cPrimary + rPrimary.start,
                  rPrimary.length,
                  ( locale ? [locale localeIdentifier] : NULL ),
                  &icuErr
                );
              uiter_setString(&iPrimary, p, reqChars);
            } else {
              uiter_setString(&iPrimary, cPrimary + rPrimary.start, rPrimary.length);
            }
          } else {
            uiter_setString(&iPrimary, cPrimary + rPrimary.start, rPrimary.length);
          }
        } else {
          uiter_setString(&iPrimary, cPrimary + rPrimary.start, rPrimary.length);
        }
      }
      break;
    }
  }
  
  // Setup the iterator for sSecondary:
  icuErr = U_ZERO_ERROR;
  switch ( [sSecondary nativeEncoding] ) {
    case kSBStringUTF8NativeEncoding: {
      if ( (lSecondary = [sSecondary utf8Length]) ) {
        unsigned char*      cSecondary = (unsigned char*)[sSecondary utf8Characters];
        
        if ( U_SUCCESS(icuErr) && caseMap ) {
          int32_t     reqBytes;
          
          icuErr = U_ZERO_ERROR;
          reqBytes = ucasemap_utf8ToLower(
                          caseMap,
                          NULL,
                          0,
                          cSecondary,
                          lSecondary,
                          &icuErr
                        );
          if ( ((icuErr == U_BUFFER_OVERFLOW_ERROR) || U_SUCCESS(icuErr)) && reqBytes ) {
            unsigned char*      p = SBMemoryPoolAlloc(pool, reqBytes);
            
            icuErr= U_ZERO_ERROR;
            if ( p ) {
              ucasemap_utf8ToLower(
                  caseMap,
                  p,
                  reqBytes,
                  cSecondary,
                  lSecondary,
                  &icuErr
                );
              uiter_setUTF8(&iSecondary, p, reqBytes);
            } else {
              uiter_setUTF8(&iSecondary, cSecondary, lSecondary);
            }
          } else {
            uiter_setUTF8(&iSecondary, cSecondary, lSecondary);
          }
        } else {
          uiter_setUTF8(&iSecondary, cSecondary, lSecondary);
        }
      }
      break;
    }
    default: {
      if ( (lSecondary = [sSecondary length]) ) {
        UChar*        cSecondary = (UChar*)[sSecondary utf16Characters];
        int32_t       reqChars;
          
        icuErr = U_ZERO_ERROR;
        reqChars = u_strToLower(
                      NULL,
                      0,
                      cSecondary,
                      lSecondary,
                      ( locale ? [locale localeIdentifier] : NULL ),
                      &icuErr
                    );
        if ( ((icuErr == U_BUFFER_OVERFLOW_ERROR) || U_SUCCESS(icuErr)) && reqChars ) {
          UChar*          p = SBMemoryPoolAlloc(pool, sizeof(UChar) * reqChars);
          
          icuErr= U_ZERO_ERROR;
          if ( p ) {
            u_strToLower(
                p,
                reqChars,
                cSecondary,
                lSecondary,
                ( locale ? [locale localeIdentifier] : NULL ),
                &icuErr
              );
            uiter_setString(&iSecondary, p, reqChars);
          } else {
            uiter_setString(&iSecondary, cSecondary, lSecondary);
          }
        } else {
          uiter_setString(&iSecondary, cSecondary, lSecondary);
        }
      }
      break;
    }
  }
  if ( lPrimary ) {
    if ( lSecondary ) {
      cmp = u_strCompareIter(&iPrimary, &iSecondary, TRUE);
      if ( cmp < 0 )
        return SBOrderAscending;
      if ( cmp > 0 )
        return SBOrderDescending;
      return SBOrderSame;
    }
    return SBOrderDescending;
  } else if ( ! lSecondary ) {
    // BOTH are zero length:
    return SBOrderSame;
  }
  return SBOrderAscending;
}

//
#pragma mark -
//

@interface SBUnicodeSearch : SBObject
{
  UCollator*              _icuCollator;
  SBLocale*               _searchLocale;
  SBStringSearchOptions   _searchOptions;
}

+ (SBUnicodeSearch*) defaultUnicodeSearch;

- (id) init;
- (id) initWithSearchOptions:(SBStringSearchOptions)searchOptions;
- (id) initWithSearchOptions:(SBStringSearchOptions)searchOptions locale:(SBLocale*)locale;

- (SBStringSearchOptions) searchOptions;
- (void) setSearchOptions:(SBStringSearchOptions)searchOptions;

- (SBLocale*) searchLocale;
- (void) setSearchLocale:(SBLocale*)searchLocale;

- (SBComparisonResult) compareRange:(SBRange)range ofString:(SBString*)s1 toString:(SBString*)s2;

@end

static SBStringSearchOptions __SBStringSearchOptionsMask =  SBStringCaseInsensitiveSearch | \
                                                            SBStringLiteralSearch | \
                                                            SBStringBackwardsSearch | \
                                                            SBStringAnchoredSearch | \
                                                            SBStringNumericSearch | \
                                                            SBStringDiacriticInsensitiveSearch | \
                                                            SBStringForcedOrderingSearch;

@implementation SBUnicodeSearch

  + (SBUnicodeSearch*) defaultUnicodeSearch
  {
    static SBUnicodeSearch*   __SBDefaultUnicodeSearch = nil;
    
    if ( __SBDefaultUnicodeSearch == nil ) {
      __SBDefaultUnicodeSearch = [[SBUnicodeSearch alloc] init];
    }
    return __SBDefaultUnicodeSearch;
  }

//

  - (id) init
  {
    return [self initWithSearchOptions:0 locale:nil];
  }
  
//

  - (id) initWithSearchOptions:(SBStringSearchOptions)searchOptions
  {
    return [self initWithSearchOptions:searchOptions locale:nil];
  }
  
//

  - (id) initWithSearchOptions:(SBStringSearchOptions)searchOptions
    locale:(SBLocale*)locale
  {
    if ( self = [super init] ) {
      _searchOptions = searchOptions & __SBStringSearchOptionsMask;
      [self setSearchLocale:locale];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _icuCollator ) ucol_close(_icuCollator);
    if ( _searchLocale ) [_searchLocale release];
    [super dealloc];
  }
  
//

  - (SBStringSearchOptions) searchOptions
  {
    return _searchOptions;
  }
  - (void) setSearchOptions:(SBStringSearchOptions)searchOptions
  {
    searchOptions &= __SBStringSearchOptionsMask;
    
    //
    // Implicitly add the case-insensitive flag if forced-ordering was chosen:
    //
    if ( searchOptions & SBStringForcedOrderingSearch )
      searchOptions |= SBStringCaseInsensitiveSearch;
      
    //
    // No collator yet?  Hang onto the option word and return, waiting
    // for a setLocale: before we actually do anything:
    //
    if ( ! _icuCollator ) {
      _searchOptions = searchOptions;
      return;
    }
    
    if ( searchOptions != _searchOptions ) {
      UErrorCode              icuErr = U_ZERO_ERROR;
      SBStringSearchOptions   mask = (SBStringCaseInsensitiveSearch | SBStringForcedOrderingSearch);
      
      //
      // Forced ordering:  Case insensitive searches should still predictably
      //                   order strings which vary only by case.
      //
      ucol_setAttribute(
          _icuCollator,
          UCOL_CASE_FIRST,
          ( (searchOptions & mask) == mask ? UCOL_UPPER_FIRST : UCOL_OFF ),
          &icuErr
        );
      icuErr = U_ZERO_ERROR;
      
      //
      // Diacritic insensitive?
      //
      if ( searchOptions & SBStringDiacriticInsensitiveSearch ) {
        //
        // Case insensitive?
        //
        ucol_setAttribute(
            _icuCollator,
            UCOL_CASE_LEVEL,
            ( ( searchOptions & SBStringCaseInsensitiveSearch ) ? UCOL_OFF : UCOL_ON ),
            &icuErr
          );
        icuErr = U_ZERO_ERROR;
        
        ucol_setStrength(_icuCollator, UCOL_PRIMARY);
      } else if ( searchOptions & SBStringCaseInsensitiveSearch ) {
        //
        // Case insensitive?
        //
        ucol_setAttribute(
            _icuCollator,
            UCOL_CASE_LEVEL,
            ( ( (searchOptions & mask) == mask ) ? UCOL_ON : UCOL_OFF ),
            &icuErr
          );
        icuErr = U_ZERO_ERROR;
        ucol_setStrength(_icuCollator, UCOL_SECONDARY);
      } else {
        //
        // Default search strength:
        //
        ucol_setAttribute(
            _icuCollator,
            UCOL_CASE_LEVEL,
            UCOL_DEFAULT,
            &icuErr
          );
        icuErr = U_ZERO_ERROR;
        ucol_setAttribute(
            _icuCollator,
            UCOL_CASE_FIRST,
            UCOL_DEFAULT,
            &icuErr
          );
        icuErr = U_ZERO_ERROR;
        ucol_setStrength(_icuCollator, UCOL_TERTIARY);
      }
      
      //
      // Numeric by-value ordering?
      //
      ucol_setAttribute(
          _icuCollator,
          UCOL_NUMERIC_COLLATION,
          ( (searchOptions & SBStringNumericSearch) ? UCOL_ON : UCOL_OFF ),
          &icuErr
        );
      icuErr = U_ZERO_ERROR;
      
      _searchOptions = searchOptions;
    }
  }

//

  - (SBLocale*) searchLocale
  {
    return _searchLocale;
  }
  - (void) setSearchLocale:(SBLocale*)searchLocale
  {
    UErrorCode              icuErr = U_ZERO_ERROR;
    SBStringSearchOptions   options = _searchOptions;
    
    if ( ! _icuCollator || ( searchLocale != _searchLocale ) ) {
      if ( searchLocale ) searchLocale = [searchLocale retain];
      if ( _searchLocale ) [_searchLocale release];
      _searchLocale = searchLocale;
      
      if ( _icuCollator ) {
        // Drop the old collator and any search helper attached to it:
        ucol_close(_icuCollator);
        _icuCollator = NULL;
      }
      
      // Create the collator:
      _icuCollator = ucol_open(
                        ( _searchLocale ? [_searchLocale localeIdentifier] : "" ),
                        &icuErr
                      );
      if ( U_SUCCESS(icuErr) ) {
        _searchOptions = 0;
        [self setSearchOptions:options];
      }
    }
  }

//

  - (SBComparisonResult) compareRange:(SBRange)range
    ofString:(SBString*)s1
    toString:(SBString*)s2
  {
    if ( _icuCollator ) {
      UCharIterator     i1,i2;
      UCollationResult  cmp;
      UErrorCode        icuErr = U_ZERO_ERROR;
      int               l1,l2;
      
      // Setup the iterator for s1:
      switch ( [s1 nativeEncoding] ) {
        case kSBStringUTF8NativeEncoding: {
          if ( (l1 = [s1 utf8Length]) ) {
            unsigned char     *s = (unsigned char*)[s1 utf8Characters];
            int32_t           iStart = 0, iEnd;
            UChar32           C;
            
            //
            // We need to skip over the first range.start UTF16 characters in the UTF8
            // buffer:
            //
            while ( iStart < l1 && range.start) {
              U8_NEXT(s, iStart, l1, C);
              
              if ( C == U_SENTINEL )
                return SBOrderAscending;
                
              range.start--;
              if ( C > 0x10000 ) {
                // Two UTF16 characters:
                if ( range.start > 0 ) {
                  range.start--;
                } else {
                  // Note that we may actually get two UTF16 entities here, but it makes
                  // no sense to stop on the lead surrogate.  So we round down to the start
                  // of the surrogate pair:
                  s -= 4;
                }
              }
            }
            
            //
            // Now, locate the end of the character range likewise:
            //
            iEnd = iStart;
            while ( iEnd < l1 && range.length ) {
              U8_NEXT(s, iEnd, l1, C);
              
              // End of string reached somehow?
              if ( C == U_SENTINEL )
                break;
                
              range.length--;
              if ( C > 0x10000 ) {
                // Two UTF16 characters:
                if ( range.length > 0 ) {
                  range.length--;
                }
                // Note that we may actually get two UTF16 entities here, but it makes
                // no sense to stop on the lead surrogate.  So we round up to the end
                // of the surrogate pair -- actually requires no op
              }
            }
            uiter_setUTF8(&i1, s + iStart, iEnd - iStart);
          }
          break;
        }
        default: {
          if ( (l1 = [s1 length]) ) {
            if ( range.start >= l1 ) {
              range.start = l1;
              range.length = 0;
            } else if ( range.start + range.length > l1 ) {
              range.length = l1 - range.start;
            }
            uiter_setString(&i1, [s1 utf16Characters] + range.start, range.length);
          }
          break;
        }
      }
      
      // Setup the iterator for s2:
      switch ( [s2 nativeEncoding] ) {
        case kSBStringUTF8NativeEncoding: {
          if ( (l2 = [s2 utf8Length]) ) 
            uiter_setUTF8(&i2, [s2 utf8Characters], l2);
          break;
        }
        default: {
          if ( (l2 = [s2 length]) ) 
            uiter_setString(&i2, [s2 utf16Characters], l2);
          break;
        }
      }
      
      // Check for zero-length:
      if ( l1 == 0 ) {
        if ( l2 == 0 )
          return SBOrderSame;
        return SBOrderAscending;
      } else if ( l2 == 0 ) {
        return SBOrderDescending;
      }
      
      // Do the collation:
      cmp = ucol_strcollIter(_icuCollator, &i1, &i2, &icuErr);
      if ( U_SUCCESS(icuErr) ) {
        switch ( cmp ) {
          case UCOL_EQUAL:
            return SBOrderSame;
          case UCOL_LESS:
            return SBOrderAscending;
          case UCOL_GREATER:
            return SBOrderDescending;
        }
      }
    }
    return SBOrderSame;
  }

//

  - (SBRange) searchRange:(SBRange)range
    ofString:(SBString*)s1
    forString:(SBString*)s2
  {
    SBRange             foundRange = SBEmptyRange;
    int32_t             l1 = [s1 length];
    
    if ( range.start >= l1 ) {
      return foundRange;
    } else if ( range.start + range.length > l1 ) {
      range.length = l1 - range.start;
    }
    
    if ( _icuCollator ) {
      UErrorCode        icuErr = U_ZERO_ERROR;
      int32_t           foundIdx;
      UStringSearch*    search;
      
      search = usearch_openFromCollator(
                    [s2 utf16Characters],
                    [s2 length],
                    [s1 utf16Characters] + range.start,
                    range.length,
                    _icuCollator,
                    NULL,
                    &icuErr
                  );
      if ( U_SUCCESS(icuErr) ) {
        if ( _searchOptions & SBStringBackwardsSearch ) {
          foundIdx = usearch_last(search, &icuErr);
        } else {
          foundIdx = usearch_first(search, &icuErr);
        }
        if ( U_SUCCESS(icuErr) && (foundIdx != USEARCH_DONE) ) {
          if ( _searchOptions & SBStringAnchoredSearch ) {
            if ( _searchOptions & SBStringBackwardsSearch ) {
              if ( foundIdx + usearch_getMatchedLength(search) == range.length ) {
                foundRange = SBRangeCreate( range.start + foundIdx, usearch_getMatchedLength(search) );
              }
            } else if ( foundIdx == 0 ) {
              foundRange = SBRangeCreate( range.start, usearch_getMatchedLength(search) );
            }
          } else {
            foundRange = SBRangeCreate( range.start + foundIdx, usearch_getMatchedLength(search) );
          }
        }
        usearch_close(search);
      }
    }
    return foundRange;
  }

@end

//
#pragma mark -
//

#include "unicode/ucnv.h"

@interface SBUnicodeConverter : SBObject
{
  UConverter*     _icuConverter;
}

- (id) initWithCharacterSetName:(const char*)charSetName;
- (id) initWithCCSID:(int)codepage platform:(UConverterPlatform)platform;

- (const char*) converterName;
- (int) converterCCSID;
- (UConverterPlatform) converterPlatform;
- (UConverterType) converterType;

- (BOOL) preflightConvertFromBytes:(const void*)bytes byteCount:(int)byteCount charCount:(int*)charCount;
- (BOOL) preflightConvertFromChars:(const UChar*)chars charCount:(int)charCount byteCount:(int*)byteCount;

- (BOOL) convertToChars:(UChar*)chars charCount:(int)charCount fromBytes:(const void*)bytes byteCount:(int)byteCount;
- (BOOL) convertToBytes:(void*)bytes byteCount:(int)byteCount fromChars:(const UChar*)chars charCount:(int)charCount actualByteCount:(int*)actualByteCount;

@end

//
#pragma mark -
//

@implementation SBUnicodeConverter

  - (id) initWithCharacterSetName:(const char*)charSetName
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _icuConverter = ucnv_open(charSetName, &icuErr);
      if ( icuErr ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithCCSID:(int)codepage
    platform:(UConverterPlatform)platform
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _icuConverter = ucnv_openCCSID(codepage, platform, &icuErr);
      if ( icuErr ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _icuConverter ) ucnv_close(_icuConverter);
    [super dealloc];
  }

//

  - (const char*) converterName
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return ucnv_getName(_icuConverter, &icuErr);
  }
  
//

  - (int) converterCCSID
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return (int)ucnv_getCCSID(_icuConverter, &icuErr);
  }
  
//

  - (UConverterPlatform) converterPlatform
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return ucnv_getPlatform(_icuConverter, &icuErr);
  }
  
//
  - (UConverterType) converterType
  {
    return ucnv_getType(_icuConverter);
  }

//

  - (BOOL) preflightConvertFromBytes:(const void*)bytes
    byteCount:(int)byteCount
    charCount:(int*)charCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           count;
    
    ucnv_resetToUnicode(_icuConverter);
    
    count = ucnv_toUChars(_icuConverter, NULL, 0, bytes, byteCount, &icuErr);
    if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
      *charCount = count;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) preflightConvertFromChars:(const UChar*)chars
    charCount:(int)charCount
    byteCount:(int*)byteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           count;
    
    ucnv_resetFromUnicode(_icuConverter);
    
    count = ucnv_fromUChars(_icuConverter, NULL, 0, chars, charCount, &icuErr);
    if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
      *byteCount = count;
      return YES;
    }
    return NO;
  }

//

  - (BOOL) convertToChars:(UChar*)chars
    charCount:(int)charCount
    fromBytes:(const void*)bytes
    byteCount:(int)byteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    
    ucnv_resetToUnicode(_icuConverter);
    ucnv_toUChars(_icuConverter, chars, charCount, bytes, byteCount, &icuErr);
    return ( (icuErr == 0) ? YES : NO );
  }
  
//

  - (BOOL) convertToBytes:(void*)bytes
    byteCount:(int)byteCount
    fromChars:(const UChar*)chars
    charCount:(int)charCount
    actualByteCount:(int*)actualByteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           outByteCount;
    
    ucnv_resetFromUnicode(_icuConverter);
    outByteCount = (int)ucnv_fromUChars(_icuConverter, bytes, byteCount, chars, charCount, &icuErr);
    if ( U_SUCCESS(icuErr) ) {
      *actualByteCount = outByteCount;
      return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

/*!
  @class SBStringSubString
  @discussion
  Used by SBString and its (public) descendents to represent a sub-range of
  an immutable string.  Avoids duplicating storage by referencing the parent
  string and the index range within it.
  
  SBMutableString handles sub-arrays by allocating a new SBString containing
  the characters in the sub-range.
*/
@interface SBStringSubString : SBString
{
  SBString*       _parentString;
  int             _base;
  int             _length;
}

+ (id) subStringWithParentString:(SBString*)parentString range:(SBRange)range;
- (id) initWithParentString:(SBString*)parentString range:(SBRange)range;

@end

@interface SBString(SBStringPrivate)

- (id) initWithCapacity:(int32_t)charCount;
- (id) initWithUncopiedCharacters:(UChar*)characters length:(int)length freeWhenDone:(BOOL)freeWhenDone;

@end

@interface SBMutableString(SBMutableStringPrivate)

@end

/*!
  @class SBConcreteString
  @discussion
  Concrete implementation of SBString which uses a C array of UChar (UTF-16
  character type from ICU).
*/
@interface SBConcreteString : SBString
{
  const UChar*    _u16Chars;
  int32_t         _length;
  SBData*         _u8Chars;
  unsigned int    _hash;
  struct {
    unsigned int  hashCalculated : 1;
    unsigned int  noFreeWhenDone : 1;
  } _flags;
}

@end

/*!
  @class SBConcreteStringSubString
  @discussion
  Class which handles sub-strings of the immutable SBConcreteString class.
  Very similar to SBStringSubString, but adds an SBData field which will wrap
  a NUL-terminated UChar array when requested by the utf16Characters method.
*/
@interface SBConcreteStringSubString : SBConcreteString
{
  SBString*       _parentString;
  SBMutableData*  _nulTerminatedU16Chars;
}

+ (id) subStringWithParentString:(SBString*)parentString range:(SBRange)range;
- (id) initWithParentString:(SBString*)parentString range:(SBRange)range;

@end

/*!
  @class SBConcreteMutableString
  @discussion
  Concrete implementation of SBMutableString.
*/
@interface SBConcreteMutableString : SBMutableString
{
  UChar*          _u16Chars;
  int32_t         _length;
  int32_t         _capacity;
  SBData*         _u8Chars;
  unsigned int    _hash;
  struct {
    unsigned int  hashCalculated : 1;
    unsigned int  flexCapacity : 1;
  } _flags;
}

- (BOOL) growToSize:(int32_t)charCapacity;

@end

//
#pragma mark -
//

static uint8_t*
__SBStringAppendUTF8(
  uint8_t*    pDest,
  UChar32     c
)
{
  /* it is 0<=c<=0x10ffff and not a surrogate if called by a validating function */
  if((c)<=0x7f) {
      *pDest++=(uint8_t)c;
  } else if(c<=0x7ff) {
      *pDest++=(uint8_t)((c>>6)|0xc0);
      *pDest++=(uint8_t)((c&0x3f)|0x80);
  } else if(c<=0xffff) {
      *pDest++=(uint8_t)((c>>12)|0xe0);
      *pDest++=(uint8_t)(((c>>6)&0x3f)|0x80);
      *pDest++=(uint8_t)(((c)&0x3f)|0x80);
  } else /* if((uint32_t)(c)<=0x10ffff) */ {
      *pDest++=(uint8_t)(((c)>>18)|0xf0);
      *pDest++=(uint8_t)((((c)>>12)&0x3f)|0x80);
      *pDest++=(uint8_t)((((c)>>6)&0x3f)|0x80);
      *pDest++=(uint8_t)(((c)&0x3f)|0x80);
  }
  return pDest;
}

static UFILE* __SBStringStdout = NULL;
static UFILE* __SBStringStderr = NULL;

static SBConcreteString* __SBNullString = nil;

@implementation SBString

  + initialize
  {
    if ( ! __SBStringStdout )
      __SBStringStdout = u_finit(stdout, NULL, "UTF-8");
    if ( ! __SBStringStderr )
      __SBStringStderr = u_finit(stderr, NULL, "UTF-8");
    if ( ! __SBNullString )
      __SBNullString = [[SBConcreteString alloc] initWithCharacters:(UChar*)"\0\0" length:0];
  }

//

  + (id) alloc
  {
    /* If SBString is being asked to alloc, then alloc an SBConcreteString;
       otherwise, pass along the usual object alloc: */
    if ( self == [SBString class] )
      return [SBConcreteString alloc];
    return [super alloc];
  }

//

  - (id) copy
  {
    return [self retain];
  }

//

  - (id) mutableCopy
  {
    return [[SBConcreteMutableString alloc] initWithString:self];
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBString class]] )
      return [self isEqualToString:(SBString*)otherObject];
    return NO;
  }

//

/*
 * Adapted from
 *
 *   http://www.azillionmonkeys.com/qed/hash.html
 *
 */

  - (unsigned int) hash
  {
    unsigned int    hash = 0;
    UChar           charBuffer[2];
    int32_t         charInBuffer = 0;
    int             charFromIndex = 0;
    int             charRemain = [self length];
      
    hash = ( charRemain ? [self length] * sizeof(UChar) : 0 );
    
    while ( charRemain > 0 ) {
      /* Next two 16-bit characters, please: */
      charInBuffer = 0;
      charBuffer[charInBuffer++] = [self characterAtIndex:charFromIndex++]; charRemain--;
      if ( charRemain > 0 ) {
        unsigned int  tmp;
        
        charBuffer[charInBuffer++] = [self characterAtIndex:charFromIndex++]; charRemain--;
        
        hash += charBuffer[0];
        tmp   = (charBuffer[1] << 11) ^ hash;
        hash  = (hash << 16) ^ tmp;
        hash += hash >> 11;
      } else {
        /* Terminal case, only one character remained: */
        hash += charBuffer[0];
        hash ^= hash << 11;
        hash += hash >> 17;
      }
    }

    /* Force "avalanching" of final 127 bits */
    hash ^= hash << 3;
    hash += hash >> 5;
    hash ^= hash << 4;
    hash += hash >> 17;
    hash ^= hash << 25;
    hash += hash >> 6;
    
    return hash;
  }

//

  - (int) length
  {
    return 0;
  }

//

  - (UChar) characterAtIndex:(int)index
  {
    return (UChar)0;
  }

//

  - (SBString*) stringValue
  {
    return self;
  }

@end

@implementation SBString(SBStringPrivate)

  - (id) initWithCapacity:(int32_t)charCount
  {
    return [self init];
  }
  
//

  - (id) initWithUncopiedCharacters:(UChar*)characters
    length:(int)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [self init];
  }

@end

@implementation SBString(SBStringCreation)

  + (id) string
  {
    return __SBNullString;
  }
  
//

  + (id) stringWithUTF8String:(const char*)cString
  {
    return [[[self alloc] initWithUTF8String:cString] autorelease];
  }
  
//

  + (id) stringWithUTF8String:(const char*)cString
    length:(int)length
  {
    return [[[self alloc] initWithUTF8String:cString length:length] autorelease];
  }
  
//

  + (id) stringWithCharacters:(UChar*)characters
    length:(int)length
  {
    return [[[self alloc] initWithCharacters:characters length:length] autorelease];
  }
  
//

  + (id) stringWithUncopiedCharacters:(UChar*)characters
    length:(int)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [[[self alloc] initWithUncopiedCharacters:characters length:length freeWhenDone:freeWhenDone] autorelease];
  }
  
//

  + (id) stringWithString:(SBString*)aString
  {
    return [[[self alloc] initWithString:aString] autorelease];
  }
  
//

  + (id) stringWithFormat:(const char*)format,...
  {
    SBString*   newString = nil;
    va_list     varg;
    
    va_start(varg, format);
    newString = [[[self alloc] initWithFormat:format arguments:varg] autorelease];
    va_end(varg);
    
    return newString;
  }
  
//

  + (id) stringWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    return [[[self alloc] initWithBytes:bytes count:count encoding:encoding] autorelease];
  }

//

  - (id) initWithUTF8String:(const char*)cString
  {
    return [self initWithUTF8String:cString length:-1];
  }
  
//

  - (id) initWithUTF8String:(const char*)cString
    length:(int)length
  {
    return [self init];
  }
  
//

  - (id) initWithCharacters:(UChar*)characters
    length:(int)length
  {
    return [self init];
  }
  
//

  - (id) initWithString:(SBString*)aString
  {
    return [self initWithCharacters:(UChar*)[aString utf16Characters] length:[aString length]];
  }
  
//

  - (id) initWithFormat:(const char*)format,...
  {
    va_list     varg;
    
    va_start(varg, format);
    self = [self initWithFormat:format arguments:varg];
    va_end(varg);
    
    return self;
  }
  
//

  - (id) initWithFormat:(const char*)format
    arguments:(va_list)argList
  {
    return [self init];
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    return [self init];
  }

@end

@implementation SBString(SBStringExtensions)

  + (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUnknownNativeEncoding;
  }
  - (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUnknownNativeEncoding;
  }

//

  - (SBString*) substringFromIndex:(int)from
  {
    return [self substringWithRange:SBRangeCreate(from, [self length] - from)];
  }
  - (SBString*) substringToIndex:(int)to
  {
    return [self substringWithRange:SBRangeCreate(0, to + 1)];
  }
  - (SBString*) substringWithRange:(SBRange)range
  {
    SBString*     result = nil;
    
    if ( [self length] )
      result = [SBStringSubString subStringWithParentString:self range:range];
    return result;
  }

//

  - (const UChar*) utf16Characters
  {
    static UChar*   nulResult = (UChar*)"\0\0";
    UChar*          result = nulResult;
    
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      SBMutableData*  u16Buffer = [SBMutableData dataWithCapacity:(iMax + 1) * sizeof(UChar)];
      
      if ( u16Buffer ) {
        UChar   c;
        
        while ( i < iMax ) {
          c = [self characterAtIndex:i++];
          [u16Buffer appendBytes:&c length:sizeof(UChar)];
        }
        c = (UChar)0;
        [u16Buffer appendBytes:&c length:sizeof(UChar)];
        
        result = (UChar*)[u16Buffer bytes];
      } else 
        result = NULL;
    }
    return result;
  }
  
//

  - (int) utf8Length
  {
    int         length = 0;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar32   c, c2;
      
      while ( i < iMax ) {
        c = [self characterAtIndex:i++];
        if ( c <= 0x7f ) {
          length++;
        } else if( c <= 0x7ff ) {
          length += 2;
        } else if ( ! UTF_IS_SURROGATE(c) ) {
          length += 3;
        } else if ( UTF_IS_SURROGATE_FIRST(c) && UTF_IS_TRAIL( c2 = [self characterAtIndex:i] ) ) {
          i++;
          length += 4;
        } else {
          /* Unicode 3.2 forbids surrogate code points in UTF-8 */
        }
      }
    }
    return length;
  }
  
//

  - (int) utf32Length
  {
    int         length = 0;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar32   c, c2;
      
      while ( i < iMax ) {
        c = [self characterAtIndex:i++];
        length++;
        if ( U16_IS_LEAD(c) && U16_IS_TRAIL( c2 = [self characterAtIndex:i] ) ) {
          i++;
        }
      }
    }
    return length;
  }
  
//

  - (const UChar32*) utf32Characters
  {
    UChar32*      result = NULL;
    int           utf32Len = [self utf32Length];
    
    if ( ( result = objc_calloc(utf32Len + 1, sizeof(UChar32)) ) ) {
      [self copyUTF32CharactersToBuffer:result length:utf32Len];
      [SBData dataWithBytesNoCopy:result length:((utf32Len + 1) * sizeof(UChar32))];
    }
    return result;
  }

//

  - (UChar32) utf32CharacterAtIndex:(int)index
  {
    UChar32     c = 0xFFFFFFFF;
    int         length = 0;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar32   c2;
      
      while ( i < iMax && length <= index ) {
        c = [self characterAtIndex:i++];
        if ( U16_IS_LEAD(c) && U16_IS_TRAIL( c2 = [self characterAtIndex:i] ) ) {
          i++;
          c = UTF16_GET_PAIR_VALUE(c, c2);
        }
        length++;
      }
      if ( length != index + 1 ) {
        c = 0xFFFFFFFF;
      }
    }
    return c;
  }
  
//

  - (SBString*) uppercaseString
  {
    return [self uppercaseStringWithLocale:nil];
  }
  - (SBString*) lowercaseString;
  {
    return [self lowercaseStringWithLocale:nil];
  }
  - (SBString*) titlecaseString;
  {
    return [self titlecaseStringWithLocale:nil];
  }
  - (SBString*) uppercaseStringWithLocale:(SBLocale*)locale;
  {
    return nil;
  }
  - (SBString*) lowercaseStringWithLocale:(SBLocale*)locale;
  {
    return nil;
  }
  - (SBString*) titlecaseStringWithLocale:(SBLocale*)locale;
  {
    return nil;
  }

//

  - (BOOL) copyCharactersToBuffer:(UChar*)buffer
    length:(int)length
  {
    BOOL        result = NO;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar     c;
      
      while ( i < iMax && length ) {
        *buffer++ = [self characterAtIndex:i++];
        length--;
      }
      result = YES;
    }
    return result;
  }
  
//

  - (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer
    length:(int)length
  {
    BOOL        result = YES;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar32   c, c2;
      
      while ( result && (i < iMax) && length ) {
        c = [self characterAtIndex:i++];
        if ( c <= 0x7f ) {
          length--;
          *buffer++ = c;
        } else if( c <= 0x7ff ) {
          if ( length >= 2 ) {
            length -= 2;
            *buffer++ = (uint8_t)((c >> 6) | 0xc0);
            *buffer++ = (uint8_t)((c & 0x3f ) | 0x80);
          } else {
            break;
          }
        } else if ( c <= 0xd7ff || c >= 0xe000 ) {
          if ( length >= 3 ) {
            length -= 3;
            *buffer++ = (uint8_t)((c >> 12) | 0xe0);
            *buffer++ = (uint8_t)(((c >> 6) & 0x3f) | 0x80);
            *buffer++ = (uint8_t)((c & 0x3f) | 0x80);
          } else {
            break;
          }
        } else {
          int32_t     clen;
          
          /* need not check for NUL because NUL fails UTF_IS_TRAIL() anyway */
          if( UTF_IS_SURROGATE_FIRST(c) && UTF_IS_TRAIL( c2 = [self characterAtIndex:i] ) ) {
            i++;
            c = UTF16_GET_PAIR_VALUE(c, c2);
          } else {
            /* Unicode 3.2 forbids surrogate code points in UTF-8 */
            result = NO;
          }
          
          if ( length >= ( clen = U8_LENGTH(c) ) ) {
            buffer = __SBStringAppendUTF8(buffer, c);
            length -= clen;
          } else {
            break;
          }
        }
      }
      if ( length ) {
        *buffer = (int8_t)0;
      }
    }
    return result;
  }
  
//

  - (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer
    length:(int)length
  {
    BOOL        result = YES;
    int         i = 0, iMax = [self length];
    
    if ( iMax ) {
      UChar     c, c2;
      UChar32   C;
      
      while ( i < iMax && length ) {
        c = [self characterAtIndex:i++];
        if ( U16_IS_LEAD(c) && U16_IS_TRAIL( c2 = [self characterAtIndex:i] ) ) {
          i++;
          *buffer++ = UTF16_GET_PAIR_VALUE(c, c2);
        } else {
          *buffer++ = c;
        }
        length--;
      }
      if ( length ) {
        *buffer = (UChar32)0;
      }
    }
    return result;
  }
  
//

  - (SBData*) dataUsingEncoding:(const char*)encoding
  {
    SBData*                 byteStream = nil;
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    
    if ( converter ) {
      int             requiredBytes;
      const UChar*    u16Chars = [self utf16Characters];
      
      if ( u16Chars && [converter preflightConvertFromChars:u16Chars charCount:[self length] byteCount:&requiredBytes] ) {
        void*   bytes = NULL;
        
        // Allow a little bit of wiggle room on the buffer size:
        requiredBytes += 4;
        bytes = objc_malloc(requiredBytes);
        
        if ( bytes ) {
          if ( [converter convertToBytes:bytes byteCount:requiredBytes fromChars:u16Chars charCount:[self length] actualByteCount:&requiredBytes] ) {
            byteStream = [SBData dataWithBytesNoCopy:bytes length:requiredBytes];
          } else {
            objc_free(bytes);
          }
        }
      }
      [converter release];
    }
    return byteStream;
  }
  
//

  - (const unsigned char*) utf8Characters
  {
    const unsigned char*    result = NULL;
    int                     utf8Len = [self utf8Length];
      
    if ( ( result = objc_malloc(utf8Len + 1) ) ) {
      [self copyUTF8CharactersToBuffer:(unsigned char*)result length:utf8Len];
      [SBData dataWithBytesNoCopy:result length:utf8Len + 1];
    }
    return result;
  }
  
//

  - (BOOL) isEqualToString:(SBString*)otherString
  {
    UCharIterator       iPrimary, iSecondary;
    int32_t             lPrimary, lSecondary;
    BOOL                result = NO;
    
    // We may as well short-cut 
    if ( self == otherString ) {
      result = YES;
    } else {
      BOOL        gotResult = NO;
      
      switch ( [self nativeEncoding] ) {
      
        case kSBStringUTF8NativeEncoding: {
          unsigned char*      primary = (unsigned char*)[self utf8Characters];
          
          lPrimary = [self utf8Length];
          
          switch ( [otherString nativeEncoding] ) {
          
            case kSBStringUTF8NativeEncoding: {
              unsigned char*  secondary = (unsigned char*)[otherString utf8Characters];
              
              lSecondary = [otherString utf8Length];
              if ( (lPrimary == lSecondary) && (memcmp(primary, secondary, lSecondary) == 0 ) )
                result = YES;
              else
                result = NO;
              gotResult = YES;
            }
            
            case kSBStringUTF16NativeEncoding:
            default: {
              // Gotta resort to using an iterator:
              if ( (lSecondary = [otherString length]) )
                uiter_setString(&iSecondary, [otherString utf16Characters], lSecondary);
              break;
            }
            
          }
          // Setup my iterator:
          if ( ! gotResult && lPrimary )
            uiter_setUTF8(&iPrimary, primary, lPrimary);
          break;
        }
        
        case kSBStringUTF16NativeEncoding:
        default: {
          UChar*              primary = (UChar*)[self utf16Characters];
          
          lPrimary = [self length];
          
          switch ( [otherString nativeEncoding] ) {
          
            case kSBStringUTF8NativeEncoding: {
              if ( (lSecondary = [otherString utf8Length]) ) {
                uiter_setUTF8(&iSecondary, [otherString utf8Characters], lSecondary);
              }
              break;
            }
            
            case kSBStringUTF16NativeEncoding:
            default: {
              UChar*          secondary = (UChar*)[otherString utf16Characters];
              
              lSecondary = [otherString length];
              if ( (lPrimary == lSecondary) && (u_strCompare(primary, lSecondary, secondary, lSecondary, TRUE) == 0) )
                result = YES;
              else
                result = NO;
              gotResult = YES;
            }
            
          }
          // Setup my iterator:
          if ( ! gotResult && lPrimary )
            uiter_setString(&iPrimary, primary, lPrimary);
          break;
        }
      
      }
      if ( ! gotResult ) {
        if ( lPrimary ) {
          if ( lSecondary && (u_strCompareIter(&iPrimary, &iSecondary, TRUE) == 0) ) {
            result = YES;
          }
        } else if ( ! lSecondary ) {
          // BOTH are zero length:
          result = YES;
        }
      }
    }
    
    return result;
  }

//

  - (SBComparisonResult) compare:(SBString*)otherString
  {
    return [self compare:otherString options:0 range:SBRangeCreate(0,[self length]) locale:nil];
  }
  - (SBComparisonResult) compare:(SBString*)otherString
    options:(SBStringSearchOptions)options
  {
    return [self compare:otherString options:options range:SBRangeCreate(0,[self length]) locale:nil];
  }
  - (SBComparisonResult) compare:(SBString*)otherString
    options:(SBStringSearchOptions)options
    range:(SBRange)compareRange
  {
    return [self compare:otherString options:options range:compareRange locale:nil];
  }
  - (SBComparisonResult) compare:(SBString*)otherString
    options:(SBStringSearchOptions)options
    range:(SBRange)compareRange
    locale:(SBLocale*)locale
  {
    SBComparisonResult  result = SBOrderSame;
    
    //
    // We'll first handle all the special options combos -- non-localized, per-character comparisons
    // that don't require an SBUnicodeSearcher to help them.
    //
    if ( ! locale ) {
      switch ( options ) {
        
        case 0:
          result = __SBString_BasicComparison(self, compareRange, otherString, NO, YES);
          break;
        case SBStringLiteralSearch:
          result = __SBString_BasicComparison(self, compareRange, otherString, NO, NO);
          break;
        case SBStringCaseInsensitiveSearch:
        case SBStringCaseInsensitiveSearch | SBStringLiteralSearch: {
          if ( locale )
            result = __SBString_LocalizedCaselessComparison(self, compareRange, otherString, locale);
          else
            result = __SBString_BasicComparison(self, compareRange, otherString, YES, YES);
          break;
        }
      
      }
    } else {
      switch ( options ) {
        
        case SBStringCaseInsensitiveSearch:
        case SBStringCaseInsensitiveSearch | SBStringLiteralSearch: {
          result = __SBString_LocalizedCaselessComparison(self, compareRange, otherString, locale);
          break;
        }
      
        default: {
          SBUnicodeSearch*    searcher = [SBUnicodeSearch defaultUnicodeSearch];
          
          if ( searcher ) {
            // Mask out any options compare doesn't accept:
            options &= (SBStringCaseInsensitiveSearch | SBStringNumericSearch | SBStringDiacriticInsensitiveSearch | SBStringForcedOrderingSearch);
            
            [searcher setSearchLocale:locale];
            [searcher setSearchOptions:options];
            
            result = [searcher compareRange:compareRange ofString:self toString:otherString];
          }
          break;
        }
        
      }
    }
    
    return result;
  }

//

  - (SBComparisonResult) caseInsensitiveCompare:(SBString*)otherString
  {
    return [self compare:otherString options:SBStringCaseInsensitiveSearch];
  }
  - (SBComparisonResult) localizedCompare:(SBString*)otherString
  {
    return [self compare:otherString options:0 range:SBRangeCreate(0,[self length]) locale:[SBLocale defaultLocale]];
  }
  - (SBComparisonResult) localizedCaseInsensitiveCompare:(SBString*)otherString
  {
    return [self compare:otherString options:(SBStringForcedOrderingSearch | SBStringCaseInsensitiveSearch) range:SBRangeCreate(0,[self length]) locale:[SBLocale defaultLocale]];
  }
 
//

  - (SBRange) rangeOfString:(SBString*)otherString
  {
    return [self rangeOfString:otherString options:0 range:SBRangeCreate(0,[self length]) locale:nil];
  }
  - (SBRange) rangeOfString:(SBString*)otherString
    options:(SBStringSearchOptions)options
  {
    return [self rangeOfString:otherString options:options range:SBRangeCreate(0,[self length]) locale:nil];
  }
  - (SBRange) rangeOfString:(SBString*)otherString
    options:(SBStringSearchOptions)options
    range:(SBRange)searchRange
  {
    return [self rangeOfString:otherString options:options range:searchRange locale:nil];
  }
  - (SBRange) rangeOfString:(SBString*)otherString
    options:(SBStringSearchOptions)options
    range:(SBRange)searchRange
    locale:(SBLocale*)locale
  {
    SBRange             foundRange = SBEmptyRange;
    
    if ( ! SBRangeEmpty(searchRange) ) {
      SBUnicodeSearch*    searcher = [SBUnicodeSearch defaultUnicodeSearch];
    
      if ( searcher ) {
        // Mask out any options compare doesn't accept:
        options &= (SBStringCaseInsensitiveSearch | SBStringDiacriticInsensitiveSearch | SBStringAnchoredSearch | SBStringBackwardsSearch);
        
        [searcher setSearchOptions:options];
        [searcher setSearchLocale:locale];
        
        foundRange = [searcher searchRange:searchRange ofString:self forString:otherString];
      }
    }
    
    return foundRange;
  }
  
//

  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
  {
    return [self rangeOfCharacterFromSet:aSet options:0 range:SBRangeCreate(0,[self length])]; 
  }
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(SBStringSearchOptions)options
  {
    return [self rangeOfCharacterFromSet:aSet options:options range:SBRangeCreate(0,[self length])];
  }
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(SBStringSearchOptions)options
    range:(SBRange)searchRange
  {
    SBRange             foundRange = SBEmptyRange;
    const UChar*        myChars = [self utf16Characters];
    int                 myLen = [self length];
    
    if ( ! SBRangeEmpty(searchRange) && myChars && myLen && aSet ) {
      USet*               charSet = [aSet icuCharSet];
      
      if ( charSet ) {
        USetSpanCondition cond = ( (options & SBStringAnchoredSearch) ? USET_SPAN_CONTAINED : USET_SPAN_NOT_CONTAINED );
        int32_t           idx;
        
        if ( (options & SBStringBackwardsSearch) ) {
          idx = uset_spanBack(
                    charSet,
                    myChars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx != searchRange.length )
              foundRange = SBRangeCreate(SBRangeMax(searchRange) - 1 - idx, 1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx - 1, 1);
          }
        } else {
          idx = uset_span(
                    charSet,
                    myChars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx )
              foundRange = SBRangeCreate(searchRange.start,1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx, 1);
          }
        }
      }
    }
    
    return foundRange;
  }
  
//

  - (BOOL) hasPrefix:(SBString*)prefixString
  {
    return ( ([self rangeOfString:prefixString options:SBStringAnchoredSearch]).length != 0 );
  }
  
//

  - (BOOL) hasSuffix:(SBString*)suffixString
  {
    return ( ([self rangeOfString:suffixString options:SBStringAnchoredSearch | SBStringBackwardsSearch]).length != 0 );
  }
  
//

  - (SBString*) stringByAppendingString:(SBString *)aString
  {
    SBString*         result = nil;
    int32_t           myLength = [self length];
    int32_t           itsLength = [aString length];
    
    if ( itsLength ) {
      UChar*      concatBuffer = objc_calloc(myLength + itsLength + 1, sizeof(UChar));
      
      if ( concatBuffer ) {
        [self copyCharactersToBuffer:concatBuffer length:myLength];
        [aString copyCharactersToBuffer:concatBuffer + myLength length:itsLength];
        result = [[[SBConcreteString alloc] initWithUncopiedCharacters:concatBuffer length:myLength + itsLength + 1 freeWhenDone:YES] autorelease];
      }
    } else
     result = self;
    return result;
  }
  
//

  - (SBString*) stringByAppendingFormat:(const char*)format, ...
  {
    SBString*         result = nil;
    int32_t           myLength = [self length];
    int32_t           charLen;
    
    if ( format && (charLen = strlen(format)) ) {
      va_list       vargs;
      UChar*        u16Chars = objc_malloc((++charLen + myLength) * sizeof(UChar));
      
      va_start(vargs, format);
      
      if ( u16Chars ) {
        [self copyCharactersToBuffer:u16Chars length:myLength];
        while ( u16Chars ) {
          int32_t     actLen;
          va_list     argList;
          
          va_copy(argList, vargs);
          actLen = u_vsnprintf(
                      u16Chars + myLength,
                      charLen,
                      format,
                      argList
                    );
          if ( (actLen < 0) || (actLen >= charLen) ) {
            UChar*    altU16Chars = objc_realloc(u16Chars, (myLength + charLen + 8) * sizeof(UChar));
            
            if ( altU16Chars ) {
              charLen += 8;
              u16Chars = altU16Chars;
            } else {
              objc_free(u16Chars);
              u16Chars = NULL;
            }
          } else {
            break;
          }
        }
        if ( u16Chars )
          result = [[[SBConcreteString alloc] initWithUncopiedCharacters:u16Chars length:myLength + charLen freeWhenDone:YES] autorelease];
      }
      va_end(vargs);
    } else
      result = self;
    return result;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, "[ hash = %08x | length = %d ] {\n  ", [self hash], [self length] );
    [self writeToStream:stream];
    fprintf(stream,"\n}\n");
  }

//

  - (SBArray*) componentsSeparatedByString:(SBString*)separator
  {
    SBArray*            result = nil;
    unsigned int        length = [self length];
    SBRange             searchRange = SBRangeCreate(0, length);
    unsigned int        pieces = 0;
    
    if ( length > 0 ) {
      while ( 1 ) {
        SBRange     foundRange = [self rangeOfString:separator options:0 range:searchRange];
        
        if ( SBRangeEmpty(foundRange) )
          break;
        
        pieces++;
        
        searchRange.start = SBRangeMax(foundRange);
        searchRange.length = length - searchRange.start;
      }
      if ( searchRange.length )
        pieces++;
      
      if ( pieces ) {
        SBString*       subStrings[pieces];
        unsigned int    i = 0;
        
        searchRange = SBRangeCreate(0, [self length]);
        while ( i < pieces ) {
          SBRange     foundRange = [self rangeOfString:separator options:0 range:searchRange];
          
          if ( SBRangeEmpty(foundRange) )
            break;
          
          subStrings[i++] = [self substringWithRange:SBRangeCreate(searchRange.start, foundRange.start - searchRange.start)];
          
          searchRange.start = SBRangeMax(foundRange);
          searchRange.length = length - searchRange.start;
        }
        if ( searchRange.length )
          subStrings[i] = [self substringWithRange:searchRange];
        
        result = [SBArray arrayWithObjects:subStrings count:pieces];
      }
    }
    return result;
  }

//

  - (double) doubleValue
  {
    SBSTRING_AS_UTF8_BEGIN(self)
    
      char*     endptr;
      double    result = strtod(self_utf8, &endptr);
      
      if ( endptr > self_utf8 )
        return result;
      
    SBSTRING_AS_UTF8_END
    return 0.0;
  }
  - (float) floatValue
  {
    SBSTRING_AS_UTF8_BEGIN(self)
    
      char*     endptr;
      float     result = strtof(self_utf8, &endptr);
      
      if ( endptr > self_utf8 )
        return result;
      
    SBSTRING_AS_UTF8_END
    return 0.0f;
  }
  - (int) intValue
  {
    SBSTRING_AS_UTF8_BEGIN(self)
    
      char*     endptr;
      long int  result = strtol(self_utf8, &endptr, 10);
      
      if ( endptr > self_utf8 ) {
        if ( result > INT_MAX )
          return INT_MAX;
        if ( result < INT_MIN )
          return INT_MIN;
        return result;
      }
    
    SBSTRING_AS_UTF8_END
    return 0;
  }

//

  - (void) writeToStream:(FILE*)stream
  {
    int           iMax = [self length];
    
    if ( iMax ) {
      int         i = 0;
      UFILE*      tmpFile;
      BOOL        closeWhenDone = NO;
      
      if ( stream == stdout ) {
        tmpFile = __SBStringStdout;
      }
      else if ( stream == stderr ) {
        tmpFile = __SBStringStderr;
      }
      else {
        tmpFile = u_finit(stream, NULL, "UTF-8");
        closeWhenDone = YES;
      }
      if ( tmpFile ) {
        while ( i < iMax ) {
          UChar     c = [self characterAtIndex:i++];
          
          if ( c ) {
            u_fprintf(tmpFile, "%C", c);
          } else {
            break;
          }
        }
        if ( closeWhenDone )
          u_fclose(tmpFile);
      } else {
        unsigned char* asUTF8 = (unsigned char*)[self utf8Characters];
        
        i = [self utf8Length];
        while ( i-- )
          fputc(*asUTF8++, stream);
      }
    }
  }

@end

//
#pragma mark -
//



@implementation SBMutableString

  + (id) alloc
  {
    /* If SBString is being asked to alloc, then alloc an SBConcreteString;
       otherwise, pass along the usual object alloc: */
    if ( self == [SBMutableString class] )
      return [SBConcreteMutableString alloc];
    return [super alloc];
  }

//

  + (id) string
  {
    return [[[self alloc] init] autorelease];
  }
  
//

  - (void) replaceCharactersInRange:(SBRange)range
    withCharacters:(UChar*)characters
    length:(int)length
  {
  }

@end

@implementation SBMutableString(SBMutableStringCreation)

  + (id) stringWithFixedCapacity:(int)maxCharacters
  {
    return [[[self alloc] initWithFixedCapacity:maxCharacters] autorelease];
  }

//

  - (id) initWithFixedCapacity:(int)maxCharacters
  {
    return [super init];
  }    

@end

@implementation SBMutableString(SBMutableStringExtensions)

  - (SBString*) substringWithRange:(SBRange)range
  {
    if ( [self length] ) {
      UChar*      u16Chars = (UChar*)[self utf16Characters];
      
      return [SBString stringWithCharacters:u16Chars + range.start length:range.length];
    }
    return nil;
  }

//

  - (void) deleteAllCharacters
  {
    [self replaceCharactersInRange:SBRangeCreate(0, [self length]) withCharacters:(UChar*)"\0\0" length:0];
  }

//

  - (void) replaceCharactersInRange:(SBRange)range
    withString:(SBString*)aString
  {
    [self replaceCharactersInRange:range withCharacters:(UChar*)[aString utf16Characters] length:[aString length]];
  }

//

  - (void) appendString:(SBString*)aString
  {
    [self replaceCharactersInRange:SBRangeCreate([self length],0) withString:aString];
  }
  
//

  - (void) appendCharacters:(const UChar*)characters
    length:(int)length
  {
    [self replaceCharactersInRange:SBRangeCreate([self length],0) withCharacters:(UChar*)characters length:length];
  }

//

  - (void) appendFormat:(const char*)format, ...
  {
    //
    // Save some time and effort rather than allowing appendCharacters: to catch this:
    //
    int32_t       charLen = strlen(format);
    va_list       vargs, vargsCopy;
    
    if ( charLen ) {
      UChar*        appendThis = NULL;
      
      va_start(vargs, format);      
      do {
        int32_t     actLen;
        
        if ( appendThis ) {
          UChar*    rAppendThis = objc_realloc(appendThis, sizeof(UChar) * charLen);
          
          if ( rAppendThis ) {
            appendThis = rAppendThis;
          } else {
            objc_free(appendThis);
            return;
          }
        } else {
          if ( ! (appendThis = objc_malloc( sizeof(UChar) * charLen )) ) { 
            objc_free(appendThis);
            return;
          }
        }
        va_copy(vargsCopy, vargs);
        actLen = u_vsnprintf(
                    appendThis,
                    charLen,
                    format,
                    vargsCopy
                  );
        if ( (actLen < 0) || ( actLen >= charLen) ) {
          charLen += 8;
        } else {
          charLen = actLen;
          break;
        }
      } while (1);
      
      if ( appendThis ) {
        if ( charLen )
          [self appendCharacters:appendThis length:charLen];
        objc_free(appendThis);
      }
      
      va_end(vargs);
    }
  }

//

  - (void) insertString:(SBString*)aString
    atIndex:(unsigned int)index
  {
    [self replaceCharactersInRange:SBRangeCreate(index,0) withString:aString];
  }

//

  - (void) insertCharacters:(const UChar*)characters
    length:(int)length
    atIndex:(unsigned int)index
  {
    [self replaceCharactersInRange:SBRangeCreate(index,0) withCharacters:(UChar*)characters length:length];
  }
    
//

  - (void) deleteCharactersInRange:(SBRange)range
  {
    [self replaceCharactersInRange:range withCharacters:(UChar*)"\0\0" length:0];
  }
  
//

  - (void) setString:(SBString*)aString
  {
    [self deleteCharactersInRange:SBRangeCreate(0,[self length])];
    [self appendString:aString];
  }
  
//

  - (void) setWithUTF8String:(const char*)cString
  {
    [self setWithUTF8String:cString length:-1];
  }
  - (void) setWithUTF8String:(const char*)cString
    length:(int)length
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int32_t       u16Count = 0;
    
    // Count the UTF16 characters in the string:
    u_strFromUTF8(NULL, 0, &u16Count, cString, ( (length == -1) ? -1 : length ), &icuErr);
    if ( U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR) ) {
      if ( u16Count ) {
        UChar     u16Chars[u16Count];
        
        icuErr = 0;
        u_strFromUTF8(
            u16Chars,
            u16Count,
            NULL,
            cString,
            ( (length == -1) ? -1 : length ),
            &icuErr
          );
        if ( U_SUCCESS(icuErr) ) {
          [self deleteCharactersInRange:SBRangeCreate(0,[self length])];
          [self appendCharacters:u16Chars length:u16Count];
        }
      }
    }
  }

@end

//
#pragma mark -
//

@implementation SBConcreteString

  + (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF16NativeEncoding;
  }
  - (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF16NativeEncoding;
  }

//

  - (id) initWithCapacity:(int32_t)charCount
  {
    if ( self = [super init] ) {
      if ( charCount ) {
        if ( (_u16Chars = (UChar*)objc_calloc(charCount + 1, sizeof(UChar))) ) {
          _length = charCount;
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
  }

//

  - (id) initWithUTF8String:(const char*)cString
    length:(int)length
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int32_t       u16Count = 0;
    
    // Count the UTF16 characters in the string:
    u_strFromUTF8(NULL, 0, &u16Count, cString, ( (length == -1) ? -1 : length ), &icuErr);
    if ( U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR) ) {
      if ( u16Count ) {
        // Grow to the required capacity:
        if ( ! [self initWithCapacity:u16Count] ) {
          [self release];
          self = nil;
        } else {
          icuErr = 0;
          u_strFromUTF8(
              (UChar*)_u16Chars,
              u16Count,
              NULL,
              cString,
              ( (length == -1) ? -1 : length ),
              &icuErr
            );
          if ( ! U_SUCCESS(icuErr) ) {
            [self release];
            self = nil;
          } else {
            _length = u16Count;
          }
        }
      } else {
        self = [self init];
      }
    } else {
      [self release];
      self = nil;
    }
    return self;
  }
  
//

  - (id) initWithCharacters:(UChar*)characters
    length:(int)length
  {
    if ( characters && length ) {
      if ( self = [self initWithCapacity:length] ) {
        u_strncpy((UChar*)_u16Chars, characters, length);
        _length = length;
      } else {
        [self release];
        self = nil;
      }
    } else {
      self = [self init];
    }
    return self;
  }
  
//

  - (id) initWithUncopiedCharacters:(UChar*)characters
    length:(int)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    if ( self = [self init] ) {
      if ( characters && length ) {
        _u16Chars = characters;
        _length = length;
        _flags.noFreeWhenDone = ! freeWhenDone;
      }
    }
    return self;
  }
  
//

  - (id) initWithFormat:(const char*)format
    arguments:(va_list)argList
  {
    if ( self = [self init] ) {
      int32_t         charLen;
      
      if ( format && (charLen = 1 + strlen(format)) ) {
        va_list       vargs;
        UChar*        u16Chars = objc_malloc(charLen * sizeof(UChar));
        
        while ( u16Chars ) {
          int32_t     actLen;
          
          va_copy(vargs, argList);
          actLen = u_vsnprintf(
                      u16Chars,
                      charLen,
                      format,
                      vargs
                    );
          if ( (actLen < 0) || (actLen >= charLen) ) {
            UChar*    altU16Chars = objc_realloc(u16Chars, (charLen + 8) * sizeof(UChar));
            
            if ( altU16Chars ) {
              charLen += 8;
              u16Chars = altU16Chars;
            } else {
              objc_free(u16Chars);
              u16Chars = NULL;
              [self release];
              self = nil;
            }
          } else {
            _u16Chars = u16Chars;
            _length = actLen;
            break;
          }
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    
    if ( converter ) {
      int       requiredChars;
        
      if ( [converter preflightConvertFromBytes:bytes byteCount:count charCount:&requiredChars] && 
              ( self = [self initWithCapacity:requiredChars] ) )
      {
        if ( [converter convertToChars:(UChar*)_u16Chars charCount:requiredChars + 1 fromBytes:bytes byteCount:count] ) {
          _length = requiredChars;
        } else {
          [self release];
          self = nil;
        }
      } else {
        [self release];
        self = nil;
      }
      [converter release];
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( ! _flags.noFreeWhenDone && _u16Chars ) objc_free((void*)_u16Chars);
    if ( _u8Chars ) [_u8Chars release];
    [super dealloc];
  }

//

  - (unsigned int) hash
  {
    if ( ! _flags.hashCalculated ) {
      if ( (_length > 0) && _u16Chars )
        _hash = [self hashForData:_u16Chars byteLength:sizeof(UChar) * _length];
      else
        _hash = 0x80808080;
      _flags.hashCalculated = YES;
    }
    return _hash;
  }

//

  - (int) length
  {
    return _length;
  }

//

  - (UChar) characterAtIndex:(int)index
  {
    if ( _u16Chars )
      return _u16Chars[index];
    return (UChar)0;
  }
  
//

  - (SBString*) substringWithRange:(SBRange)range
  {
    return [SBConcreteStringSubString subStringWithParentString:self range:range];
  }

//

  - (const UChar*) utf16Characters
  {
    return _u16Chars;
  }

//

  - (int) utf8Length
  {
    if ( _u16Chars && _length ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF8WithSub(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _length,
          (UChar32)0xFFFD,
          NULL,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return reqLength;
    }
    return 0;
  }

//

  - (int) utf32Length
  {
    if ( _u16Chars && _length ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF32(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _length,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return reqLength;
    }
    return 0;
  }

//

  - (UChar32) utf32CharacterAtIndex:(int)index
  {
    UChar32     c = 0xFFFFFFFF;
    
    if ( _u16Chars ) {
      UChar*    s = (UChar*)_u16Chars;
      int32_t   i = 0,j = 0;
      
      while ( i < _length ) {
        U16_NEXT(s, i, _length, c);
        if ( j == index )
          break;
        j++;
      }
      if ( j != index )
        c = 0xFFFFFFFF;
    }
    return c;
  }

//

  - (SBString*) uppercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToUpper(
                    NULL,
                    0,
                    _u16Chars,
                    _length,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToUpper(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _length,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (SBString*) lowercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToLower(
                    NULL,
                    0,
                    _u16Chars,
                    _length,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToLower(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _length,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (SBString*) titlecaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToTitle(
                    NULL,
                    0,
                    (UChar*)_u16Chars,
                    _length,
                    NULL,
                    (char*)( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToTitle(
              (UChar*)[result utf16Characters],
              actLen + 1,
              (UChar*)_u16Chars,
              _length,
              NULL,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }
  
//

  - (const unsigned char*) utf8Characters
  {
    unsigned char*      buffer = "";
    
    if ( ! _u8Chars ) {      
      if ( _u16Chars && _length ) {
        UErrorCode              uerr = U_ZERO_ERROR;
        int32_t                 reqLength = 0;
        
        u_strToUTF8(
            NULL,
            0,
            &reqLength,
            (UChar*)_u16Chars,
            _length,
            &uerr
          );
        if ( reqLength && (buffer = objc_malloc(++reqLength)) ) {
          _u8Chars = [[SBData alloc] initWithBytesNoCopy:buffer length:reqLength freeWhenDone:YES];
          if ( _u8Chars ) {
            uerr = 0;
            u_strToUTF8(
                buffer,
                reqLength,
                &reqLength,
                (UChar*)_u16Chars,
                _length,
                &uerr
              );
          }
        }
      }
    } else {
      buffer = (unsigned char*)[_u8Chars bytes];
    }
    return buffer;
  }

//

  - (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer
    length:(int)length
  {
    if ( _u16Chars && _length ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF8WithSub(
        (char*)buffer,
        length,
        NULL,
        (UChar*)_u16Chars,
        _length,
        (UChar32)0xFFFD,
        NULL,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return YES;
    }
    return NO;
  }

//


  - (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer
    length:(int)length
  {
    if ( _u16Chars && _length ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF32(
        (UChar32*)buffer,
        length,
        NULL,
        (UChar*)_u16Chars,
        _length,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return YES;
    }
    return NO;
  }

//

  - (SBData*) dataUsingEncoding:(const char*)encoding
  {
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    SBData*                 byteStream = nil;
    
    if ( converter ) {
      int       requiredBytes;
      
      if ( [converter preflightConvertFromChars:_u16Chars charCount:_length byteCount:&requiredBytes] ) {
        void*   bytes = NULL;
        
        // Allow a little bit of wiggle room on the buffer size:
        requiredBytes += 4;
        bytes = objc_malloc(requiredBytes);
        
        if ( bytes ) {
          if ( [converter convertToBytes:bytes byteCount:requiredBytes fromChars:_u16Chars charCount:_length actualByteCount:&requiredBytes] ) {
            byteStream = [SBData dataWithBytesNoCopy:bytes length:requiredBytes];
          } else {
            objc_free(bytes);
          }
        }
      }
      [converter release];
    }
    return byteStream;
  }

//

  - (SBRange) rangeOfString:(SBString*)aString
    range:(SBRange)searchRange
  {
    SBRange           foundRange = SBEmptyRange;
    const UChar*      searchChars = [aString utf16Characters];
    int               searchLen = [aString length];
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _length && searchChars && searchLen ) {
      UChar*          foundPtr = NULL;
      
      foundPtr = u_strFindFirst(
                      _u16Chars + searchRange.start,
                      searchRange.length,
                      searchChars,
                      searchLen
                    );
      if ( foundPtr ) {
        foundRange.start = foundPtr - _u16Chars;
        foundRange.length = searchLen;
      }
    }
    return foundRange;
  }
  
//
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(unsigned int)options
    range:(SBRange)searchRange
  {
    SBRange               foundRange = SBEmptyRange;
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _length && aSet ) {
      USet*               charSet = [aSet icuCharSet];
      
      if ( charSet ) {
        USetSpanCondition cond = ( (options & SBStringAnchoredSearch) ? USET_SPAN_CONTAINED : USET_SPAN_NOT_CONTAINED );
        int32_t           idx;
        
        if ( (options & SBStringBackwardsSearch) ) {
          idx = uset_spanBack(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx != searchRange.length )
              foundRange = SBRangeCreate(SBRangeMax(searchRange) - 1 - idx, 1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx - 1, 1);
          }
        } else {
          idx = uset_span(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx )
              foundRange = SBRangeCreate(searchRange.start,1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx, 1);
          }
        }
      }
    }
    return foundRange;
  }

@end

//
#pragma mark -
//

@implementation SBConcreteMutableString

  + (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF16NativeEncoding;
  }
  - (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF16NativeEncoding;
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
      _flags.flexCapacity = YES;
    }
    return self;
  }

//

  - (id) initWithCapacity:(int32_t)charCount
  {
    if ( self = [super init] ) {
      if ( charCount ) {
        if ( (_u16Chars = (UChar*)objc_calloc(charCount + 1, sizeof(UChar))) ) {
          _capacity = charCount;
          _flags.flexCapacity = YES;
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
  }

//

  - (id) initWithFixedCapacity:(int)maxCharacters
  {
    if ( self = [super init] ) {
      if ( maxCharacters ) {
        if ( (_u16Chars = (UChar*)objc_calloc(maxCharacters + 1, sizeof(UChar))) ) {
          _capacity = maxCharacters;
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
  }    
  
//

  - (id) initWithUTF8String:(const char*)cString
    length:(int)length
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int32_t       u16Count = 0;
    
    // Count the UTF16 characters in the string:
    u_strFromUTF8(NULL, 0, &u16Count, cString, ( (length == -1) ? -1 : length ), &icuErr);
    if ( U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR) ) {
      if ( u16Count ) {
        // Grow to the required capacity:
        if ( ! [self initWithCapacity:u16Count] ) {
          [self release];
          self = nil;
        } else {
          icuErr = 0;
          u_strFromUTF8(
              (UChar*)_u16Chars,
              u16Count,
              NULL,
              cString,
              ( (length == -1) ? -1 : length ),
              &icuErr
            );
          if ( ! U_SUCCESS(icuErr) ) {
            [self release];
            self = nil;
          } else {
            _length = u16Count;
          }
        }
      } else {
        self = [self init];
      }
    } else {
      [self release];
      self = nil;
    }
    return self;
  }
  
//

  - (id) initWithCharacters:(UChar*)characters
    length:(int)length
  {
    if ( characters && length ) {
      if ( self = [self initWithCapacity:length] ) {
        u_strncpy((UChar*)_u16Chars, characters, length);
        _length = length;
      } else {
        [self release];
        self = nil;
      }
    } else {
      self = [self init];
    }
    return self;
  }
  
//

  - (id) initWithUncopiedCharacters:(UChar*)characters
    length:(int)length
    freeWhenDone:(BOOL)freeWhenDone
  {
    return [self initWithCharacters:characters length:length];
  }

//

  - (id) initWithFormat:(const char*)format
    arguments:(va_list)argList
  {
    if ( self = [self init] ) {
      int32_t         charLen;
      
      if ( format && (charLen = 1 + strlen(format)) ) {
        va_list       vargs;
        UChar*        u16Chars = objc_malloc(charLen * sizeof(UChar));
        
        while ( u16Chars ) {
          int32_t     actLen;
          
          va_copy(vargs, argList);
          actLen = u_vsnprintf(
                      u16Chars,
                      charLen,
                      format,
                      vargs
                    );
          if ( (actLen < 0) || (actLen >= charLen) ) {
            UChar*    altU16Chars = objc_realloc(u16Chars, (charLen + 8) * sizeof(UChar));
            
            if ( altU16Chars ) {
              charLen += 8;
              u16Chars = altU16Chars;
            } else {
              objc_free(u16Chars);
              u16Chars = NULL;
              [self release];
              self = nil;
            }
          } else {
            _u16Chars = u16Chars;
            _length = actLen;
            break;
          }
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    
    if ( converter ) {
      int       requiredChars;
        
      if ( [converter preflightConvertFromBytes:bytes byteCount:count charCount:&requiredChars] && 
              ( self = [self initWithCapacity:requiredChars] ) )
      {
        if ( [converter convertToChars:(UChar*)_u16Chars charCount:requiredChars + 1 fromBytes:bytes byteCount:count] ) {
          _length = requiredChars;
        } else {
          [self release];
          self = nil;
        }
      } else {
        [self release];
        self = nil;
      }
      [converter release];
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _u16Chars ) objc_free(_u16Chars);
    if ( _u8Chars ) [_u8Chars release];
    [super dealloc];
  }

//

  - (unsigned int) hash
  {
    if ( ! _flags.hashCalculated ) {
      if ( (_length > 0) && _u16Chars )
        _hash = [self hashForData:_u16Chars byteLength:sizeof(UChar) * _length];
      else
        _hash = 0x80808080;
      _flags.hashCalculated = YES;
    }
    return _hash;
  }

//

  - (id) copy
  {
    return [[SBConcreteString alloc] initWithString:self];
  }

//

  - (int) length
  {
    return _length;
  }

//

  - (UChar) characterAtIndex:(int)index
  {
    UChar   result = (UChar)0;
    
    if ( _u16Chars )
      result = _u16Chars[index];
    return result;
  }
  
//

  - (SBString*) substringWithRange:(SBRange)range
  {
    SBString*     result = nil;
    
    if ( _u16Chars )
      result = [SBString stringWithCharacters:_u16Chars + range.start length:range.length];
    return result;
  }

//

  - (const UChar*) utf16Characters
  {
    return (const UChar*)_u16Chars;
  }

//

  - (int) utf8Length
  {
    int         result = 0;
  
    if ( _u16Chars && _length ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF8WithSub(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _length,
          (UChar32)0xFFFD,
          NULL,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        result = reqLength;
    }
    return result;
  }

//

  - (int) utf32Length
  {
    int       result = 0;
    
    if ( _u16Chars && _length ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF32(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _length,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        result = reqLength;
    }
    return result;
  }

//

  - (UChar32) utf32CharacterAtIndex:(int)index
  {
    UChar32     c = 0xFFFFFFFF;
    
    if ( _u16Chars ) {
      UChar*    s = (UChar*)_u16Chars;
      int32_t   i = 0,j = 0;
      
      while ( i < _length ) {
        U16_NEXT(s, i, _length, c);
        if ( j == index )
          break;
        j++;
      }
      if ( j != index )
        c = 0xFFFFFFFF;
    }
    return c;
  }

//

  - (SBString*) uppercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToUpper(
                    NULL,
                    0,
                    _u16Chars,
                    _length,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToUpper(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _length,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (SBString*) lowercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToLower(
                    NULL,
                    0,
                    _u16Chars,
                    _length,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToLower(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _length,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (SBString*) titlecaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _length ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToTitle(
                    NULL,
                    0,
                    (UChar*)_u16Chars,
                    _length,
                    NULL,
                    (char*)( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBConcreteString alloc] initWithCapacity:actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToTitle(
              (UChar*)[result utf16Characters],
              actLen + 1,
              (UChar*)_u16Chars,
              _length,
              NULL,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }
  
//

  - (const unsigned char*) utf8Characters
  {
    unsigned char*      buffer = "";
    
    if ( ! _u8Chars ) {      
      if ( _u16Chars && _length ) {
        UErrorCode              uerr = U_ZERO_ERROR;
        int32_t                 reqLength = 0;
        
        u_strToUTF8(
            NULL,
            0,
            &reqLength,
            (UChar*)_u16Chars,
            _length,
            &uerr
          );
        if ( reqLength && (buffer = objc_malloc(++reqLength)) ) {
          _u8Chars = [[SBData alloc] initWithBytesNoCopy:buffer length:reqLength freeWhenDone:YES];
          
          if ( _u8Chars ) {
            uerr = 0;
            u_strToUTF8(
                buffer,
                reqLength,
                &reqLength,
                (UChar*)_u16Chars,
                _length,
                &uerr
              );
          }
        }
      }
    } else {
      buffer = (unsigned char*)[_u8Chars bytes];
    }
    return buffer;
  }

//

  - (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer
    length:(int)length
  {
    BOOL          result = NO;
    
    if ( _u16Chars && _length ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF8WithSub(
        (char*)buffer,
        length,
        NULL,
        (UChar*)_u16Chars,
        _length,
        (UChar32)0xFFFD,
        NULL,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        result = YES;
    }
    return result;
  }

//

  - (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer
    length:(int)length
  {
    BOOL          result = NO;
    
    if ( _u16Chars && _length ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF32(
        (UChar32*)buffer,
        length,
        NULL,
        (UChar*)_u16Chars,
        _length,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        result = YES;
    }
    return result;
  }

//

  - (SBData*) dataUsingEncoding:(const char*)encoding
  {
    SBData*                   byteStream = nil;
    SBUnicodeConverter*       converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
      
    if ( converter ) {
      int       requiredBytes;
      
      if ( [converter preflightConvertFromChars:_u16Chars charCount:_length byteCount:&requiredBytes] ) {
        void*   bytes = NULL;
        
        // Allow a little bit of wiggle room on the buffer size:
        requiredBytes += 4;
        bytes = objc_malloc(requiredBytes);
        
        if ( bytes ) {
          if ( [converter convertToBytes:bytes byteCount:requiredBytes fromChars:_u16Chars charCount:_length actualByteCount:&requiredBytes] ) {
            byteStream = [SBData dataWithBytesNoCopy:bytes length:requiredBytes];
          } else {
            objc_free(bytes);
          }
        }
      }
      [converter release];
    }
    return byteStream;
  }
  
//

  - (SBRange) rangeOfString:(SBString*)aString
    range:(SBRange)searchRange
  {
    SBRange           foundRange = SBEmptyRange;
    const UChar*      searchChars = [aString utf16Characters];
    int               searchLen = [aString length];
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _length && searchChars && searchLen ) {
      UChar*          foundPtr = NULL;
      
      foundPtr = u_strFindFirst(
                      _u16Chars + searchRange.start,
                      searchRange.length,
                      searchChars,
                      searchLen
                    );
      if ( foundPtr ) {
        foundRange.start = foundPtr - _u16Chars;
        foundRange.length = searchLen;
      }
    }
    return foundRange;
  }
  
//
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(unsigned int)options
    range:(SBRange)searchRange
  {
    SBRange               foundRange = SBEmptyRange;
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _length && aSet ) {
      USet*               charSet = [aSet icuCharSet];
      
      if ( charSet ) {
        USetSpanCondition cond = ( (options & SBStringAnchoredSearch) ? USET_SPAN_CONTAINED : USET_SPAN_NOT_CONTAINED );
        int32_t           idx;
        
        if ( (options & SBStringBackwardsSearch) ) {
          idx = uset_spanBack(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx != searchRange.length )
              foundRange = SBRangeCreate(SBRangeMax(searchRange) - 1 - idx, 1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx - 1, 1);
          }
        } else {
          idx = uset_span(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBStringAnchoredSearch) ) {
            if ( idx )
              foundRange = SBRangeCreate(searchRange.start,1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx, 1);
          }
        }
      }
    }
    return foundRange;
  }
  
//

  - (BOOL) growToSize:(int32_t)charCapacity
  {
    BOOL        result = NO;
    
    if ( _flags.flexCapacity && (charCapacity > _capacity) ) {
      //
      // We account for the possible need for the NUL character (for using u_sprintf, e.g.) by
      // always over-allocating by a single UChar.
      //
      UChar*      p = NULL;
      
      if ( _u16Chars ) {
        if ( ( p = (UChar*) objc_realloc(_u16Chars, (charCapacity + 1 ) * sizeof(UChar)) ) ) {
          // Make sure we zero-out the added bytes:
          bzero(p + _capacity, charCapacity - _capacity + 1);
        }
      } else {
        p = (UChar*) objc_calloc(charCapacity + 1, sizeof(UChar));
      }
      if ( p ) {
        _u16Chars = p;
        _capacity = charCapacity;
        result = YES;
      }
    }
    return result;
  }

//

  - (void) deleteAllCharacters
  {
    _length = 0;
    _flags.hashCalculated = NO;
    if ( _u8Chars ) {
      [_u8Chars release];
      _u8Chars = nil;
    }
  }

//

  - (void) replaceCharactersInRange:(SBRange)range
    withCharacters:(UChar*)characters
    length:(int)length
  {
    // Validate the start of the replacement range:
    if ( _length && (range.start > _length) )
    return;
    
    // Validate the replacement range in the receiver:
    if ( SBRangeMax(range) > _length )
      range.length = _length - range.start;
    
    // Drop any nul characters off the replacement:
    UChar*        sTerm = characters + length - 1;
    while ( length && (*sTerm == 0) ) {
      sTerm--;
      length--;
    }
    
    // Adjust for fixed capacity:
    if ( ! _flags.flexCapacity ) {
      if ( _length - range.length + length > _capacity ) {
        length = _capacity - (_length - range.length);
        if ( length <= 0 )
          return;
      }
    }
    
    if ( _u16Chars ) {
      UChar*          c = 0;
      size_t          newLen = _length - (ssize_t)(range.length - length);
      unsigned int    end = SBRangeMax(range);
      
      //
      // If we're replacing with MORE characters than the buffer will hold,
      // then we need to resize the buffer.  Otherwise, we're merely doing
      // a memmove and (possibly) a memcpy.
      //
      if ( (range.length  >= length) || (_capacity >= newLen) ) {
        // Shift some data:
        if ( range.length > length )
          u_memmove(_u16Chars + range.start + length, _u16Chars + end, _length - end + 1);
        
        // Copy-in the new characters:
        if ( length )
          u_memcpy(_u16Chars + range.start, characters, length);
        
        // Done, reset flags accordingly:
        _length = newLen;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      } else if ( [self growToSize:newLen] ) {
        // Move data up off the original end to make room for the incoming
        // chars:
        u_memmove(_u16Chars + range.start + length, _u16Chars + end, _length - end + 1);
        
        // Insert the new chars:
        if ( length )
          u_memcpy(_u16Chars + range.start, characters, length);
        
        // Done, reset flags accordingly:
        _length = newLen;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      }
      
    } else if ( characters && length ) {
      //
      // We don't yet have a buffer, so just make a duplicate copy of aString
      // and reset all flags accordingly:
      //
      if ( [self growToSize:length] ) {
        u_memcpy(_u16Chars, characters, length);
        _length = length;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      }
    }
  }

//

  - (void) setString:(SBString*)aString
  {
    _length = 0;
    _flags.hashCalculated = NO;
    if ( _u8Chars ) {
      [_u8Chars release];
      _u8Chars = nil;
    }
    [self appendString:aString];
  }
  
//

  - (void) setWithUTF8String:(const char*)cString
    length:(int)length
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int32_t       u16Count = 0;
    
    // Count the UTF16 characters in the string:
    u_strFromUTF8(NULL, 0, &u16Count, cString, ( (length == -1) ? -1 : length ), &icuErr);
    if ( U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR) ) {
      if ( u16Count ) {
        UChar     u16Chars[u16Count];
        
        icuErr = 0;
        u_strFromUTF8(
            u16Chars,
            u16Count,
            NULL,
            cString,
            ( (length == -1) ? -1 : length ),
            &icuErr
          );
        if ( U_SUCCESS(icuErr) ) {
          if ( _length )
            _length = 0;
          [self appendCharacters:u16Chars length:u16Count];
        }
      }
    }
  }

@end

//
#pragma mark -
//

@implementation SBStringSubString

  + (id) subStringWithParentString:(SBString*)parentString
    range:(SBRange)range
  {
    return [[[SBStringSubString alloc] initWithParentString:parentString range:range] autorelease];
  }
  
//

  - (id) initWithParentString:(SBString*)parentString
    range:(SBRange)range
  {
    if ( self = [super initWithUncopiedCharacters:(UChar*)[parentString utf16Characters] + range.start length:range.length freeWhenDone:NO] ) {
      _length = [parentString length];
      _parentString = [parentString retain];
      if ( range.start >= _length ) {
        _base = 0;
        _length = 0;
      } else {
        _base = range.start;
        _length -= range.start;
        if ( range.length < _length )
          _length = range.length;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parentString ) [_parentString release];
    [super dealloc];
  }
  
//

  - (int) length
  {
    return _length;
  }
  
//

  - (UChar) characterAtIndex:(int)index
  {
    if ( (index >= 0) && (index < _length) )
      return [_parentString characterAtIndex:_base + index];
    return (UChar)0;
  }

@end

@implementation SBConcreteStringSubString

  + (id) subStringWithParentString:(SBString*)parentString
    range:(SBRange)range
  {
    return [[[SBConcreteStringSubString alloc] initWithParentString:parentString range:range] autorelease];
  }
  
//

  - (id) initWithParentString:(SBString*)parentString
    range:(SBRange)range
  {
    if ( self = [super initWithUncopiedCharacters:(UChar*)[parentString utf16Characters] + range.start length:range.length freeWhenDone:NO] ) {
      _parentString = [parentString retain];
    }
    return self;
  }

//

  - (UChar*) utf16Characters
  {
    unsigned int      length = [self length];
    
    if ( ! _nulTerminatedU16Chars && length ) {
      _nulTerminatedU16Chars = [SBMutableData dataWithCapacity:(length + 1) * sizeof(UChar)];
      
      if ( _nulTerminatedU16Chars ) {
        int8_t        nul = 0;
        
        [_nulTerminatedU16Chars appendBytes:[super utf16Characters] length:(length * sizeof(UChar))];
        [_nulTerminatedU16Chars appendBytes:&nul length:1];
      }
    }
    if ( _nulTerminatedU16Chars )
      return (UChar*)[_nulTerminatedU16Chars bytes];
    return (UChar*)"\0\0";
  }

//

  - (void) dealloc
  {
    if ( _parentString ) [_parentString release];
    if ( _nulTerminatedU16Chars ) [_nulTerminatedU16Chars release];
    [super dealloc];
  }

@end

//
#pragma mark -
//

typedef struct {
  @defs(SBStringConst)
} SBStringConstAsStruct;

typedef union {
  struct {
    unsigned int    l;
    const char*     s;
  } byDef;
  struct {
    const char*     s;
    unsigned int    l;
  } byGCC;
} SBStringConstInstanceData;


static SBMutableDictionary* __SBStringConst_U16Forms = nil;

@implementation SBStringConst

  + initialize
  {
    if ( __SBStringConst_U16Forms == nil ) {
      __SBStringConst_U16Forms = [[SBMutableDictionary alloc] init];
    }
  }

//

  + (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF8NativeEncoding;
  }
  - (SBStringNativeEncoding) nativeEncoding
  {
    return kSBStringUTF8NativeEncoding;
  }

//

  - (id) mutableCopy
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    return [[SBConcreteMutableString alloc] initWithUTF8String:iData->byGCC.s length:iData->byGCC.l];
  }

//

  - (id) retain
  {
    // We're a string _constant_, do nothing!
    return self;
  }
  - (void) release
  {
    // We're a string _constant_, do nothing!
  }
  - (id) autorelease
  {
    // We're a string _constant_, do nothing!
    return self;
  }
  - (void) dealloc
  {
    // We're a string _constant_, do nothing!
    return;
    
    [super dealloc];
  }

//

  - (unsigned int) constCStringLength
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    return iData->byGCC.l;
  }
  
//

  - (const char*) constCString
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    return iData->byGCC.s;
  }

//

  - (int) length
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    if ( iData->byGCC.s ) {
      UErrorCode  icuErr = 0;
      int32_t     actLen = 0;
      
      u_strFromUTF8(
          NULL,
          0,
          &actLen,
          iData->byGCC.s,
          iData->byGCC.l,
          &icuErr
        );
      return actLen;
    }
    return 0;
  }
  
//

  - (UChar) characterAtIndex:(int)index
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    const char*                   s = iData->byGCC.s;
    UChar                         c = 0;
    
    if ( s ) {
      UChar32       C;
      int           i = 0, iMax = iData->byGCC.l;
      
      while ( i < iMax && index >= 0 ) {
        U8_NEXT(s, i, iMax, C);
        if ( C < 0 )
          break;
        switch ( U16_LENGTH(C) ) {
          case 2:
            if ( index == 0 ) {
              c = U16_LEAD(C);
              index = -1;
            } else if ( index == 1 ) {
              c = U16_TRAIL(C);
              index = -1;
            } else {
              index -= 2;
            }
            break;
          case 1:
            c = C;
            index--;
            break;
          default:
            index = -2;
            break;
        }
      }
      if ( index != -1 )
        c = 0;
    }
    return c;
  }

//

  //
  // ObjC string constants see a LOT of use, period.  A lot of the methods in the generalized SBString method
  // implementations will need to pull a full UTF16-encoded form for string constants.  We could re-generate
  // an autoreleased SBData each time -- but they're string CONSTANTS, so why not lazily cache the UTF16 forms
  // for later re-use when the utf16Characters message is again sent to the SBStringConst object!
  //
  // The caching uses an SBMutableDictionary, with key-value pairs of
  //
  //    SBValue{SBStringConst} => SBData{UChar[]}
  //
  - (const UChar*) utf16Characters
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    SBValue*                      valueOfSelf = [[SBValue alloc] initWithBytes:&self objCType:@encode(id)];
    UChar*                        u16Chars = NULL;
    
    if ( valueOfSelf ) {
      SBData*     u16Data = [__SBStringConst_U16Forms objectForKey:valueOfSelf];
            
      if ( ! u16Data ) {
        int32_t     u16CharLen;
        UErrorCode  icuErr = U_ZERO_ERROR;
        
        u_strFromUTF8(
            NULL,
            0,
            &u16CharLen,
            (char*)iData->byGCC.s,
            iData->byGCC.l,
            &icuErr
          );
        if ( U_SUCCESS(icuErr) || icuErr == U_BUFFER_OVERFLOW_ERROR ) {
          u16Chars = objc_calloc(++u16CharLen, sizeof(UChar));
          
          if ( u16Chars ) {
            icuErr = 0;
            u_strFromUTF8(
                u16Chars,
                u16CharLen,
                &u16CharLen,
                (char*)iData->byGCC.s,
                iData->byGCC.l,
                &icuErr
              );
            u16Data = [[SBData alloc] initWithBytesNoCopy:u16Chars length:u16CharLen];
            if ( u16Data ) {
              [__SBStringConst_U16Forms setObject:u16Data forKey:valueOfSelf];
              [u16Data release];
            } else {
              objc_free(u16Chars);
              u16Chars = NULL;
            }
          }
        }
      } else {
        u16Chars = (UChar*)[u16Data bytes];
      }
      [valueOfSelf release];
    }
    return u16Chars;
  }

//

  - (const unsigned char*) utf8Characters
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    return (const unsigned char*)iData->byGCC.s;
  }

//

  - (SBString*) substringWithRange:(SBRange)range
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    if ( iData->byGCC.s && iData->byGCC.l )
      return [SBConcreteString stringWithUTF8String:iData->byGCC.s + range.start length:range.length];
    return nil;
  }

//

  - (void) writeToStream:(FILE*)stream
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    fprintf(stream, "%s", iData->byGCC.s);
  }
  
//

  - (double) doubleValue
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    char*     endptr;
    double    result = strtod(iData->byGCC.s, &endptr);
    
    if ( endptr > iData->byGCC.s )
      return result;
    return 0.0;
  }
  - (float) floatValue
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    char*     endptr;
    float     result = strtof(iData->byGCC.s, &endptr);
    
    if ( endptr > iData->byGCC.s )
      return result;
    return 0.0f;
  }
  - (int) intValue
  {
    SBStringConstInstanceData*    iData = (SBStringConstInstanceData*)(&((SBStringConstAsStruct*)self)->_references);
    
    char*     endptr;
    long int  result = strtol(iData->byGCC.s, &endptr, 10);
    
    if ( endptr > iData->byGCC.s ) {
      if ( result > INT_MAX )
        return INT_MAX;
      if ( result < INT_MIN )
        return INT_MIN;
      return result;
    }
    return 0;
  }

@end

//
#pragma mark -
//

#define UCHAR_PERIOD ((UChar)0x002e)
#define UCHAR_SLASH ((UChar)0x002f)
#define UCHAR_BACKSLASH ((UChar)0x005c)

static UChar __UChar_Period = UCHAR_PERIOD;
static UChar __UChar_Slash = UCHAR_SLASH;
static UChar __UChar_Backslash = UCHAR_BACKSLASH;

@implementation SBString(SBStringPathExtensions)

  - (BOOL) isAbsolutePath
  {
    if ( [self length] && ([self characterAtIndex:0] == __UChar_Slash) )
      return YES;
    return NO;
  }
  
//

  - (BOOL) isRelativePath
  {
    if ( [self length] && ([self characterAtIndex:0] != __UChar_Slash) )
      return YES;
    return NO;
  }

//

  - (SBString*) lastPathComponent
  {
    int       length = [self length], start = length;
    
    if ( length ) {
      while ( start-- ) {
        UChar c = [self characterAtIndex:start];
        
        if ( c == UCHAR_SLASH ) {
          if ( (--start > 0) && ([self characterAtIndex:start] == __UChar_Backslash) ) {
            start--;
          } else {
            start++;
            break;
          }
        }
      }
      if ( start == 0 )
        return self;
      return [self substringFromIndex:start + 1];
    }
    return nil;
  }

//

  - (SBString*) stringByDeletingLastPathComponent
  {
    int       length = [self length], start = length;
    
    if ( length ) {
      while ( start-- ) {
        UChar c = [self characterAtIndex:start];
        
        if ( c == UCHAR_SLASH ) {
          if ( (--start > 0) && ([self characterAtIndex:start] == __UChar_Backslash) ) {
            start--;
          } else {
            start++;
            break;
          }
        }
      }
      if ( start == 0 )
        return nil;
      return [self substringToIndex:start - 1];
    }
    return nil;
  }
  
//

  - (SBString*) stringByAppendingPathComponent:(SBString*)aString
  {
    SBMutableString*   result = [SBMutableString stringWithString:self];
    
    if ( result ) {
      [result appendCharacters:&__UChar_Slash length:1];
      [result appendString:aString];
    }
    return result;
  }
  
//

  - (SBString*) stringByAppendingPathComponents:(SBString*)aString,
    ...
  {
    SBMutableString*   result = [SBMutableString stringWithString:self];
    
    if ( result ) {
      va_list         vargs;
      
      va_start(vargs, aString);
      while ( aString ) {
        [result appendCharacters:&__UChar_Slash length:1];
        [result appendString:aString];
        aString = va_arg(vargs, id);
      }
      va_end(vargs);
    }
    return result;
  }
  
//

  - (SBString*) pathExtension
  {
    int       length = [self length], start = length;
    
    if ( length ) {
      while ( start-- ) {
        switch ( [self characterAtIndex:start] ) {
        
          case UCHAR_PERIOD:
            return [self substringFromIndex:start + 1];
          
          case UCHAR_SLASH:
            if ( (--start > 0) && ([self characterAtIndex:start] == __UChar_Backslash) ) {
              start--;
              continue;
            }
            return nil;
            
        }
      }
    }
    return nil;
  }

//

  - (SBString*) stringByDeletingPathExtension
  {
    int       length = [self length], start = length;
    
    if ( length ) {
      while ( start-- ) {
        switch ( [self characterAtIndex:start] ) {
        
          case UCHAR_PERIOD:
            if ( start > 0 )
              return [self substringToIndex:start - 1];
            return self;
            
          case UCHAR_SLASH:
            if ( (--start > 0) && ([self characterAtIndex:start] == __UChar_Backslash) ) {
              start--;
              continue;
            }
            return nil;
            
        }
      }
    }
    return nil;
  }
  
//

  - (SBString*) stringByAppendingPathExtension:(SBString*)aString
  {
    SBMutableString*   result = [SBMutableString stringWithString:self];
    
    if ( result ) {
      [result appendCharacters:&__UChar_Period length:1];
      [result appendString:aString];
    }
    return result;
  }
  
@end

//
#pragma mark -
//

SBString* SBUserName()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_name )
    return [SBConcreteString stringWithUTF8String:passwdForUser->pw_name];
  return nil;
}

//

SBString* SBFullUserName()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_gecos )
    return [SBConcreteString stringWithUTF8String:passwdForUser->pw_gecos];
  return nil;
}

//

SBString* SBHomeDirectory()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_dir )
    return [SBConcreteString stringWithUTF8String:passwdForUser->pw_dir];
  return nil;
}

//

SBString* SBHomeDirectoryForUser(
  SBString*   userName
)
{
  SBSTRING_AS_UTF8_BEGIN(userName)
    struct passwd*    passwdForUser = getpwnam(userName_utf8);
    
    if ( passwdForUser && passwdForUser->pw_dir )
      return [SBConcreteString stringWithUTF8String:passwdForUser->pw_dir];
  SBSTRING_AS_UTF8_END
  
  return nil;
}
