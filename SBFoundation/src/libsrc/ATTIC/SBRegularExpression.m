//
// scruffy : maintenance scheduler daemon for SHUEBox
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


@implementation SBRegularExpression

  - (id) initWithString:(SBString*)regexString
  {
    return [self initWithString:regexString flags:0];
  }
  
//

  - (id) initWithString:(SBString*)regexString
    flags:(int)flags
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
    flags:(int)flags
  {
    if ( self = [super init] ) {
      UErrorCode      icuErr = 0;
      
      _icuRegex = uregex_openC(
                    cString,
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

  - (void) dealloc
  {
    if ( _subjectString ) [_subjectString release];
    if ( _icuRegex ) uregex_close(_icuRegex);
    [super dealloc];
  }
  
//

  - (int) flags
  {
    int           result = 0;
    UErrorCode    icuErr = 0;
    
    result = (int)uregex_flags(_icuRegex, &icuErr);
    if ( icuErr )
      result = 0;
    return result;
  }
  
//

  - (int) matchingGroupCount
  {
    int           result = 0;
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
    
    uregex_setRegion(
        _icuRegex,
        range.start,
        SBRangeMax(range) - 1,
        &icuErr
      );
    return ( (icuErr == 0) ? YES : NO );
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
    return ( (icuErr == 0) ? YES : NO );
  }
  
//

  - (BOOL) isFullMatch
  {
    if ( _subjectString ) {
      UErrorCode    icuErr = 0;
      
      if ( uregex_matches(_icuRegex, 0, &icuErr) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) isPartialMatch
  {
    if ( _subjectString ) {
      UErrorCode    icuErr = 0;
      
      if ( uregex_lookingAt(_icuRegex, 0, &icuErr) )
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

  - (SBString*) stringForMatch
  {
    return [self stringForMatchingGroup:0];
  }
  
//
  
  - (SBString*) stringForMatchingGroup:(int)groupNum
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

