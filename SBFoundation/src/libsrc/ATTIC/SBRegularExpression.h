//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBRegularExpression.h
//
// Unicode regular expressions
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"

#include "unicode/uregex.h"


@interface SBRegularExpression : SBObject {
  URegularExpression*     _icuRegex;
  SBString*               _subjectString;
}

- (id) initWithString:(SBString*)regexString;
- (id) initWithString:(SBString*)regexString flags:(int)flags;
- (id) initWithUTF8String:(const char*)cString;
- (id) initWithUTF8String:(const char*)cString flags:(int)flags;

- (int) flags;
- (int) matchingGroupCount;

- (SBString*) subjectString;
- (void) setSubjectString:(SBString*)subject;

#ifdef ICU_4
- (SBRange) matchingRange;
- (BOOL) setMatchingRange:(SBRange)range;
#endif

- (BOOL) resetMatching;
- (BOOL) isFullMatch;
- (BOOL) isPartialMatch;
- (BOOL) findNextMatch;

- (SBString*) stringForMatch;
- (SBString*) stringForMatchingGroup:(int)groupNum;

@end

