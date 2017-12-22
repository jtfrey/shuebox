//
// SBFoundation : ObjC Class Library for Solaris
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

/*!
  @class SBRegularExpression
  @discussion
  Class which wraps an ICU Unicode regular expression.  Unicode regular expressions
  behave pretty much just like POSIX extended regular expressions, with some added
  character set support junk.  See:
  
    http://icu-project.org/apiref/icu4c/uregex_8h.html
    
  Instances of SBRegularExpression can be initialized using either an SBString object
  or a UTF8-compliant C string.  Some special flags can be optionally passed to the
  instance; the flags affect case sensitivity, newline treatment, word boundaries,
  etc.  See:
  
    http://icu-project.org/apiref/icu4c/uregex_8h.html#874989dfec4cbeb6baf4d1a51cb529ae
    
  Once an instance has been initialized, it can be used to process one or more
  SBString objects.  The string to be processed -- the "subject string" -- is set
  and (optionally, if ICU version 4 is being used) a sub-range of the full string
  can be selected.  Repeated calls to "findNextMatch" will incrementally locate
  the next sub-string matching the regular expression and return YES; a return value
  of NO indicates no matches remain.  Methods exist to determine the extent of the
  current match (full or partial, relative to the subject string) and to retrieve
  the matched character range and/or any grouped character ranges within the match.
*/
@interface SBRegularExpression : SBObject {
  URegularExpression*     _icuRegex;
  SBString*               _subjectString;
#ifdef ICU_4
  SBRange                 _matchingRange;
#endif
}

/*!
  @method initWithString:
  
  Initialize a newly-allocated instance, attempting to interpret the provided
  SBString as a regular expression.
*/
- (id) initWithString:(SBString*)regexString;
/*!
  @method initWithString:flags:
  
  Initialize a newly-allocated instance, attempting to interpret the provided
  SBString as a regular expression.  Special flags (see the class documentation)
  can also be provided to affect the regular expression's behavior -- pass 0 for
  default behavior.
*/
- (id) initWithString:(SBString*)regexString flags:(int)flags;
/*!
  @method initWithUTF8String:
  
  Initialize a newly-allocated instance, attempting to interpret the provided
  NUL-terminated, UTF8-encoded C string as a regular expression.
*/
- (id) initWithUTF8String:(const char*)cString;
/*!
  @method initWithUTF8String:flags:
  
  Initialize a newly-allocated instance, attempting to interpret the provided
  NUL-terminated, UTF8-encoded C string as a regular expression.  Special flags
  (see the class documentation) can also be provided to affect the regular
  expression's behavior -- pass 0 for default behavior.
*/
- (id) initWithUTF8String:(const char*)cString flags:(int)flags;
/*!
  @method flags
  
  Returns the bit-wise OR of all special flags that were used to initialize
  the receiver.
*/
- (int) flags;
/*!
  @method matchingGroupCount
  
  Returns the number of grouped character ranges that appear in the receiver's
  regular expression.
*/
- (int) matchingGroupCount;
/*!
  @method subjectString
  
  Returns the SBString currently associated with the receiver for regular expressiong
  matching.
*/
- (SBString*) subjectString;
/*!
  @method setSubjectString:
  
  Resets the receiver's regular expression matching state and retains the given subject
  string to use for subsequent matching.
  
  Note that the subject string's characters are NOT copied; if you modify the subject
  string itself while attempting to process matches the behavior is undefined.
*/
- (void) setSubjectString:(SBString*)subject;

#ifdef ICU_4
/*!
  @method matchingRange
  
  Returns the range of characters within the subject string to which the regular expression
  matching operations should be restricted.
*/
- (SBRange) matchingRange;
/*!
  @method setMatchingRange:
  
  Modified the range of characters within the subject string to which the regular expression
  matching operations should be restricted.
*/
- (BOOL) setMatchingRange:(SBRange)range;
#endif

/*!
  @method resetMatching
  
  Reset internal state on the receiver's regular expression; subsequent matching methods
  will search from the beginning of the subject string once again.  Returns YES if the internal
  state was reset properly.
*/
- (BOOL) resetMatching;
/*!
  @method isFullMatch
  
  Returns YES if the entirety of the subject string (or the set matching range on the subject
  string) matches the receiver's regular expression.  If YES, then the stringForMatch and
  stringForMatchingGroup: methods can be used to retrieve matching sub-strings.
*/
- (BOOL) isFullMatch;
/*!
  @method isPartialMatch
  
  Returns YES if at least some portion of the subject string (or the set matching range on the
  subject string) matches the receiver's regular expression.  If YES, then the stringForMatch
  and stringForMatchingGroup: methods can be used to retrieve matching sub-strings.
*/
- (BOOL) isPartialMatch;
/*!
  @method findNextMatch
  
  Repeatedly returns YES if at least some portion of the remaining un-matched portion of the
  subject string (or the set matching range on the subject string) matches the receiver's
  regular expression.  Contrast this method against the isFullMatch and isPartialMatch methods,
  which only ever operate on the subject string in its entirety.
  
  If YES, then the stringForMatch and stringForMatchingGroup: methods can be used to retrieve
  matching sub-strings.
*/
- (BOOL) findNextMatch;
/*!
  @method rangeOfMatch
  
  After a successful matching method has been invoked, the method returns the range of characters
  in the subject string which were matched by the receiver's regular expression.
*/
- (SBRange) rangeOfMatch;
/*!
  @method stringForMatch
  
  After a successful matching method has been invoked, this method returns a string containing
  the full range of characters in the subject string which were matched by the receiver's
  regular expression.
*/
- (SBString*) stringForMatch;
/*!
  @method rangeOfMatchingGroup:
  
  After a successful matching method has been invoked, the method returns the range of characters
  in the subject string which were matched by one of the grouped character ranges in the receiver's
  regular expression.  Groups are indexed from one up to and including the value returned by
  the matchingGroupCount method.
*/
- (SBRange) rangeOfMatchingGroup:(int)groupNum;
/*!
  @method rangesOfMatchingGroups:
  
  After a successful matching method has been invoked, the method copies the array of parenthetical
  sub-matching ranges to groupRanges.  Note that groupRanges must be at least as large as the
  number of parenthetical sub-groups plus one.
*/
- (void) rangesOfMatchingGroups:(SBRange*)groupRanges;
/*!
  @method stringForMatchingGroup:
  
  After a successful matching method has been invoked, this method returns a string containing
  one of the grouped character ranges in the subject string which were matched by the receiver's
  regular expression.  Groups are indexed from one up to and including the value returned by
  the matchingGroupCount method.
*/
- (SBString*) stringForMatchingGroup:(int)groupNum;

@end


/*!
  @category SBMutableString(SBStringRegexAdditions)
  @discussion
  Additional SBString methods which facilitate regular-expression-based find-and-replace
  operations.
*/
@interface SBMutableString(SBStringRegexAdditions)

/*!
  @method replaceFirstMatchForRegex:withString:
  
  Locate the first range of characters in the receiver which match the given regular expression
  and replace that range with the contents of aString.  If the regular expression contains
  grouped ranges then the groups can be references as $1, $2, ... within aString.
*/
- (BOOL) replaceFirstMatchForRegex:(SBRegularExpression*)regex withString:(SBString*)aString;
/*!
  @method replaceAllMatchesForRegex:withString:

  Locate each range of characters in the receiver which matches the given regular expression
  and replace them all with the contents of aString.  If the regular expression contains
  grouped ranges then the groups can be references as $1, $2, ... within aString.
*/
- (BOOL) replaceAllMatchesForRegex:(SBRegularExpression*)regex withString:(SBString*)aString;

@end
