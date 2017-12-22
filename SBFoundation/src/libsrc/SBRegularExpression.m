//
// SBFoundation : ObjC Class Library for Solaris
// SBRegularExpression.m
//
// Unicode regular expressions
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBRegularExpression.h"

@interface SBRegularExpression(SBRegularExpressionPrivate)

- (URegularExpression*) icuRegexPointer;

@end

@implementation SBRegularExpression(SBRegularExpressionPrivate)

  - (URegularExpression*) icuRegexPointer
  {
    return _icuRegex;
  }

@end

//
#pragma mark -
//

@implementation SBRegularExpression

  - (id) initWithString:(SBString*)regexString
  {
    return [self initWithString:regexString flags:0];
  }
  
//

  - (id) initWithString:(SBString*)regexString
    flags:(SBUInteger)flags
  {
    if ( self = [super init] ) {
      UErrorCode      icuErr = 0;
      
      _icuRegex = uregex_open(
                    [regexString utf16Characters],
                    [regexString length],
                    flags,
                    NULL,
                    &icuErr
                  );
      if ( ! _icuRegex ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithUTF8String:(const char*)cString
  {
    return [self initWithUTF8String:cString flags:0];
  }
  
//

  - (id) initWithUTF8String:(const char*)cString
    flags:(SBUInteger)flags
  {
    if ( self = [super init] ) {
      UErrorCode      icuErr = 0;
      
      _icuRegex = uregex_openC(
                    cString,
                    (int)flags,
                    NULL,
                    &icuErr
                  );
      if ( ! _icuRegex ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _subjectString ) [_subjectString release];
    if ( _icuRegex ) uregex_close(_icuRegex);
    [super dealloc];
  }
  
//

  - (SBUInteger) flags
  {
    SBUInteger    result = 0;
    UErrorCode    icuErr = 0;
    
    result = (SBUInteger)uregex_flags(_icuRegex, &icuErr);
    if ( icuErr )
      result = 0;
    return result;
  }
  
//

  - (SBUInteger) matchingGroupCount
  {
    SBUInteger    result = 0;
    UErrorCode    icuErr = 0;
      
    result = uregex_groupCount(_icuRegex, &icuErr);
    if ( icuErr )
      result = 0;
    return result;
  }

//

  - (SBString*) subjectString
  {
    return _subjectString;
  }
  - (void) setSubjectString:(SBString*)subject
  {
    UErrorCode      icuErr = 0;
    
    if ( subject ) subject = [subject retain];
    if ( _subjectString ) [_subjectString release];
    if ( (_subjectString = subject) ) {
      uregex_setText(
          _icuRegex,
          [subject utf16Characters],
          [subject length],
          &icuErr
        );
    } else {
      UChar     nul = 0;
      
      uregex_setText(_icuRegex, &nul, 0, &icuErr);
    }
#ifdef ICU_4
    [self setMatchingRange:SBEmptyRange];
#endif
  }

//

#ifdef ICU_4

  - (SBRange) matchingRange
  {
    SBRange       result = SBEmptyRange;
    int32_t       start,end;
    UErrorCode    icuErr = 0;
    
    start = uregex_regionStart(_icuRegex, &icuErr);
    if ( icuErr == 0 ) {
      end = uregex_regionEnd(_icuRegex, &icuErr);
      if ( icuErr == 0 ) {
        result = SBRangeCreate(start, end - start + 1);
      }
    }
    return result;
  }
  - (BOOL) setMatchingRange:(SBRange)range
  {
    UErrorCode    icuErr = 0;
    
    if ( SBRangeEmpty(range) ) {
      uregex_setRegion(
          _icuRegex,
          0,
          [_subjectString length],
          &icuErr
        );
    } else {
      uregex_setRegion(
          _icuRegex,
          range.start,
          SBRangeMax(range) - 1,
          &icuErr
        );
    }
    if ( U_SUCCESS(icuErr) ) {
      _matchingRange = range;
      return YES;
    }
    return NO;
  }

#endif /* ICU_4 */

//

  - (BOOL) resetMatching
  {
    UErrorCode    icuErr = 0;
    
    uregex_reset(
        _icuRegex,
        0,
        &icuErr
      );
    if ( U_SUCCESS(icuErr) ) {
#ifdef ICU_4
      return [self setMatchingRange:_matchingRange];
#else
      return YES;
#endif
    }
    return NO;
  }
  
//

  - (BOOL) isFullMatch
  {
    if ( _subjectString ) {
      UErrorCode    icuErr = 0;
      
      if ( uregex_matches(_icuRegex, -1, &icuErr) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) isPartialMatch
  {
    if ( _subjectString ) {
      UErrorCode    icuErr = 0;
      
      if ( uregex_lookingAt(_icuRegex, -1, &icuErr) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) findNextMatch
  {
    if ( _subjectString ) {
      UErrorCode    icuErr = 0;
      
      if ( uregex_findNext(_icuRegex, &icuErr) )
        return YES;
    }
    return NO;
  }

//

  - (SBRange) rangeOfMatch
  {
    return [self rangeOfMatchingGroup:0];
  }

//

  - (SBString*) stringForMatch
  {
    return [self stringForMatchingGroup:0];
  }
  
//

  - (SBRange) rangeOfMatchingGroup:(SBUInteger)groupNum
  {
    SBRange   aRange = SBEmptyRange;
    
    if ( _subjectString ) {
      int32_t     start,endPlus1;
      UErrorCode  icuErr = 0;
      
      start = uregex_start(_icuRegex, groupNum, &icuErr);
      if ( icuErr == 0 ) {
        endPlus1 = uregex_end(_icuRegex, groupNum, &icuErr);
        if ( icuErr == 0 ) {
          aRange.start = start;
          aRange.length = endPlus1 - start;
        }
      }
    }
    return aRange;
  }
  
//

  - (void) rangesOfMatchingGroups:(SBRange*)groupRanges
  {
    if ( _subjectString ) {
      SBUInteger    i = 0, iMax = [self matchingGroupCount];
      
      while ( i <= iMax ) {
        int32_t     start,endPlus1;
        UErrorCode  icuErr = 0;
        
        *groupRanges = SBEmptyRange;
        start = uregex_start(_icuRegex, i, &icuErr);
        if ( icuErr == 0 ) {
          endPlus1 = uregex_end(_icuRegex, i, &icuErr);
          if ( icuErr == 0 ) {
            groupRanges->start = start;
            groupRanges->length = endPlus1 - start;
          }
        }
        groupRanges++;
        i++;
      }
    }
  }

//
  
  - (SBString*) stringForMatchingGroup:(SBUInteger)groupNum
  {
    if ( _subjectString ) {
      int32_t     start,endPlus1;
      UErrorCode  icuErr = 0;
      
      start = uregex_start(_icuRegex, groupNum, &icuErr);
      if ( icuErr == 0 ) {
        endPlus1 = uregex_end(_icuRegex, groupNum, &icuErr);
        if ( icuErr == 0 ) {
          return [SBString stringWithCharacters:((UChar*)[_subjectString utf16Characters]) + start length:endPlus1 - start];
        }
      }
    }
    return nil;
  }

@end

//
#pragma mark -
//

@implementation SBMutableString(SBStringRegexAdditions)

  - (BOOL) replaceFirstMatchForRegex:(SBRegularExpression*)regex
    withString:(SBString*)aString
  {
    URegularExpression*   regexPtr = [regex icuRegexPointer];
    UChar*                repChars = (UChar*)[aString utf16Characters];
    int                   repCharsLen = [aString length];
    SBString*             oldSubjectString = [regex subjectString];
    int                   newCharsLen = 0;
    UErrorCode            icuErr = 0;
    BOOL                  rc = NO;

#ifdef ICU_4
    SBRange               oldMatchingRange = [regex matchingRange];
#endif
    
    if ( regexPtr == NULL )
      return YES;
    
    if ( (repChars == NULL) || (repCharsLen == 0) ) {
      repChars = (UChar*)"\0\0";
      repCharsLen = 0;
    }
    
    if ( oldSubjectString ){
      // Hang onto a reference in case the regex held the only one -- otherwise,
      // it could get released!
      oldSubjectString = [oldSubjectString retain];
    }
    [regex setSubjectString:self];
    
    // Initial guess at the size of the product:
    newCharsLen = uregex_replaceFirst(
                          regexPtr,
                          repChars,
                          repCharsLen,
                          NULL,
                          0,
                          &icuErr
                        );
    if ( (U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR)) && (newCharsLen > 0) ) {
      UChar*          newChars = objc_malloc(++newCharsLen * sizeof(UChar));
      
      while ( newChars && ! rc ) {
        int32_t       actLen;
        
        icuErr = 0;
        actLen = uregex_replaceFirst(
                          regexPtr,
                          repChars,
                          repCharsLen,
                          newChars,
                          newCharsLen,
                          &icuErr
                        );
        if ( (U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR)) && (actLen > 0) && (actLen < newCharsLen) ) {
          [self replaceCharactersInRange:SBRangeCreate(0,[self length]) withCharacters:newChars length:actLen];
          rc = YES;
        } else {
          UChar*        rNewChars = (UChar*)objc_realloc(newChars, newCharsLen + 32);
          
          if ( rNewChars ) {
            newCharsLen += 32;
            newChars = rNewChars;
          } else {
            break;
          }
        }
      }
      if ( newChars )
        objc_free(newChars);
    }
    
    // Restore the regex's state:
    [regex setSubjectString:oldSubjectString];
#ifdef ICU_4
    [regex setMatchingRange:oldMatchingRange];
#endif
    if ( oldSubjectString )
      [oldSubjectString release];

    return rc;
  }

//

  - (BOOL) replaceAllMatchesForRegex:(SBRegularExpression*)regex
    withString:(SBString*)aString
  {
    URegularExpression*   regexPtr = [regex icuRegexPointer];
    UChar*                repChars = (UChar*)[aString utf16Characters];
    int                   repCharsLen = [aString length];
    SBString*             oldSubjectString = [regex subjectString];
    int                   newCharsLen = 0;
    UErrorCode            icuErr = 0;
    BOOL                  rc = NO;

#ifdef ICU_4
    SBRange               oldMatchingRange = [regex matchingRange];
#endif
    
    if ( regexPtr == NULL )
      return YES;
    
    if ( (repChars == NULL) || (repCharsLen == 0) ) {
      repChars = (UChar*)"\0\0";
      repCharsLen = 0;
    }
    
    if ( oldSubjectString ){
      // Hang onto a reference in case the regex held the only one -- otherwise,
      // it could get released!
      oldSubjectString = [oldSubjectString retain];
    }
    [regex setSubjectString:self];
    
    // Initial guess at the size of the product:
    newCharsLen = uregex_replaceAll(
                          regexPtr,
                          repChars,
                          repCharsLen,
                          NULL,
                          0,
                          &icuErr
                        );
    if ( (U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR)) && (newCharsLen > 0) ) {
      UChar*          newChars = objc_malloc(++newCharsLen * sizeof(UChar));
      
      while ( newChars && ! rc ) {
        int32_t       actLen;
        
        icuErr = 0;
        actLen = uregex_replaceAll(
                          regexPtr,
                          repChars,
                          repCharsLen,
                          newChars,
                          newCharsLen,
                          &icuErr
                        );
        if ( (U_SUCCESS(icuErr) || (icuErr == U_BUFFER_OVERFLOW_ERROR)) && (actLen > 0) && (actLen < newCharsLen) ) {
          [self replaceCharactersInRange:SBRangeCreate(0,[self length]) withCharacters:newChars length:actLen];
          rc = YES;
        } else {
          UChar*        rNewChars = (UChar*)objc_realloc(newChars, newCharsLen + 32);
          
          if ( rNewChars ) {
            newCharsLen += 32;
            newChars = rNewChars;
          } else {
            break;
          }
        }
      }
      if ( newChars )
        objc_free(newChars);
    }
    
    // Restore the regex's state:
    [regex setSubjectString:oldSubjectString];
#ifdef ICU_4
    [regex setMatchingRange:oldMatchingRange];
#endif
    if ( oldSubjectString )
      [oldSubjectString release];
    
    return rc;
  }

@end
