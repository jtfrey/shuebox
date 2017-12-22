//
// SBFoundation : ObjC Class Library for Solaris
// SBString.h
//
// Unicode string class
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#include "unicode/utypes.h"

/*!
  @header SBString.h
  
  SBString represents the public interface to an entire cluster of classes devoted to the
  task of representing and processing textual data.  The size of this class is impressive, due
  mainly to the fact that text processing is a terribly complex beast.
  
  <b>Implementation Details</b>
  <blockquote>
    A little inside info, the actual class cluster under SBString looks like this:
    <ul>
      <li>SBString
        <ul>
          <li>SBStringConst</li>
          <li>SBStringSubString</li>
          <li>SBConcreteString
            <ul>
              <li>SBConcreteStringSubString</li>
            </ul>
          </li>
          <li>SBMutableString
            <ul>
              <li>SBConcreteMutableString</li>
            </ul>
          </li>
        </ul>
      </li>
    </ul>
    The two sub-string classes are present because the content of an immutable string
    cannot change, so a substring can refer directly to the original characters rather
    than making a copy of them in memory.  SBString will return SBStringSubString objects from
    its substring* methods; an SBStringSubString object retains a reference to the parent
    string object and modifies the characterAtIndex: method to call-through to the parent's
    method with a properly-modified offset (according to the range with which the
    SBStringSubString was initialized).  The SBConcreteStringSubString object is a subclass
    of SBConcreteString which also retains a reference to the parent string but sends itself
    the initWithUncopiedCharacters:length:freeWhenDone: message with the applicable region 
    of the parent strings' UTF-16 buffer.
  </blockquote>

  <b>String Compare and Search</b>
  <blockquote>
    String comparison and search operations make use of the ICU comparator and search
    facilities in order to provide locale-dependent, full-featured text analysis
    capabilities.  In particular:
    <ul>
      <li>Case-insensitive OR case-sensitive character testing</li>
      <li>Diacritic-insensitive OR diacritic-sensitive character testing</li>
      <li>Value-sensitive OR character-sensitive numerical sub-string testing</li>
      <li>Literal or canonical character testing</li>
      <li>Anchored searching</li>
      <li>From-end (backwards) searching</li>
    </ul>
    String comparison operations are optimized on a per-encoding basis; compare:
    methods which are invoked with a mix of UTF-8 and UTF-16 encoded string classes
    setup character iterators for the strings' native encodings (rather than
    transcoding to UTF-16 and working directly with full strings).  Searching,
    however, requires the UTF-16 encoding, and thus UTF-8-native string classes
    will transcode to UTF-16 when used in any search-oriented methods.
    
    Future optimizations include introducing a UTF-32-native character iterator for use
    with compare: methods &mdash; right now, the UTF-16 transcoded form is used.  Since none of the
    build-in classes actually use UTF-32 representation, this optimization is somewhat moot,
    though.  At this point, anchored searches are made so only after the actual search has
    been performed through the full string &mdash; ICU does not easily allow for producing a
    fully-anchored search.  I know &mdash; I tried using a break iterator set to mark the start
    and end of the string as the only boundaries, but:
    <ol>
      <li>Despite the break iterator's treating S[0] as the first and only boundary,
          the Search API wouldn't honor a match at that boundary as being a match (it's not
          clear why this is so...bug?)</li>
      <li>For backwards searching, the Search API wants to match the localtion of the beginning
          of the found sub-string to a break iterator boundary.  However, since the boundaries
          being provided were the S[0] and S[len(S)] positions, the Search API would discard
          the match (for reverse search, shouldn't the logical choice be to test the _end_ of
          the found sub-string against the end boundary?)</li>
    </ol>
  </blockquote>
  
  <b>String Constants</b>
  <blockquote>
    The SBStringConst class is used to represent UTF-8 encoded static strings that are
    built-in at compile time; such strings appear in source code using the \@"string" format.
    SBStringConst instances provide all of the SBString methods, so to your code they'll
    look like any other immutable string object.  However, behind the scenes any of the
    more exotic SBString methods may require the SBStringConst to transcode its UTF-8 data
    to UTF-16.
    
    The concrete SBString implementations all will cache their UTF-8 transcoded form the
    first time the utf8Characters method is called, so that subsequent calls will return the
    cached data (though for SBMutableString classes the cache will be dumped when the
    receiver is modified in any way).  SBStringConst objects, being immutable strings,
    likewise optimize this conversion by lazily doing a UTF-16 transcode when necessary, caching
    the UTF-16 form thereafter.
    
    In the future the caching could be further refined by introducing some sort of temporal
    time-out mechanism to automatically discard transcoded forms that have not been needed for
    some time.
  </blockquote>
    
*/

@class SBData, SBLocale, SBCharacterSet, SBRegularExpression, SBArray;

/*!
  @enum String searching options
  
  Flags that control how string comparison/search behaves.  Combine multiple
  flags by bitwise OR'ing the flags together.
*/
enum {
  SBStringCaseInsensitiveSearch       = 1,
  SBStringLiteralSearch               = 2,
  SBStringBackwardsSearch             = 4,
  SBStringAnchoredSearch              = 8,
  SBStringNumericSearch               = 16,
  SBStringDiacriticInsensitiveSearch  = 32,
  SBStringForcedOrderingSearch        = 64
};

/*!
  @typedef SBStringSearchOptions
  
  Type used to pass bitwise-OR'ed string search flags to SBString methods.  A
  value of 0 implies no special options.
*/
typedef unsigned int SBStringSearchOptions;

/*!
  @typedef SBStringNativeEncoding
  
  All SBString-descendent classes define a class and instance method which return a value
  from this enumeration as a hint w.r.t. how they natively represent their character data.
  
  Used internally by the class cluster to optimize operations that require specific UTF
  encoding formats (e.g. most of the ICU functions work with UTF16 characters only).
  
  See the SBString nativeEncoding methods for more information.
*/
typedef enum {
  kSBStringUTF16NativeEncoding,
  kSBStringUTF8NativeEncoding,
  kSBStringUTF32NativeEncoding,
  kSBStringUnknownNativeEncoding
} SBStringNativeEncoding;

/*!
  @class SBString
  @discussion
  Instances of SBString wrap textual data.  This class is constructed to be very similar to the
  Cocoa NSString class:  behind the scenes there are several kinds of SBString.  Rest assured,
  you'll never actually get an SBString, but an instance of a concrete subclass which is
  optimized for the text in question.
  
  Internally, all of the SBString concrete subclasses represent their text payload as UTF-16
  character arrays.  This may not be true of any subclasses defined outside the context of this
  header file, though.  Any subclass of SBString must at least implement:
  <ul>
    <li>- (int) length</li>
    <li>- (UChar) characterAtIndex:(int)index</li>
  </ul>
  With these two methods, any subclass will automatically work with all of the methods defined in
  the SBStringExtensions category.  Of course, further optimization can be accomplished by
  overriding those methods with methods that are optimized to the particular context of the
  subclass.
  
  Subclasses are responsible for implementing their own factory and init methods; they should
  not rely on the SBString methods since only concrete subclasses of SBString <i>actually</i> allocate
  space for character arrays, etc.
*/
@interface SBString : SBObject <SBStringValue>

/*!
  @method length
  
  Returns the number of UTF-16 characters in the receiver.
*/
- (int) length;
/*!
  @method characterAtIndex:
  
  Returns the UTF-16 character/surrogate at the specified offset from the beginning of the receiver's
  character array.
*/
- (UChar) characterAtIndex:(int)index;

@end

/*!
  @category SBString(SBStringCreation)
  
  Category of SBString which contains all methods that create and initialize SBString instances.
*/
@interface SBString(SBStringCreation)

/*!
  @method string
  
  Returns an autoreleased SBString instance containing an empty string.
*/
+ (id) string;
/*!
  @method stringWithUTF8String:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the UTF-8 encoded
  cString passed to it.
*/
+ (id) stringWithUTF8String:(const char*)cString;
/*!
  @method stringWithUTF8String:length:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the UTF-8 encoded
  cString passed to it.  Only the first length UTF8 code points are used.
*/
+ (id) stringWithUTF8String:(const char*)cString length:(int)length;
/*!
  @method stringWithCharacters:length:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the UTF-16 characters
  passed to it (as a buffer pointer and number of UTF-16 characters in the buffer).
*/
+ (id) stringWithCharacters:(UChar*)characters length:(int)length;
/*!
  @method stringWithUncopiedCharacters:length:freeWhenDone:
  
  Returns a newly-initialized, autoreleased instance wrapping the string of UTF-16 characters
  passed to it.
*/
+ (id) stringWithUncopiedCharacters:(UChar*)characters length:(int)length freeWhenDone:(BOOL)freeWhenDone;
/*!
  @method stringWithString:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the SBString passed
  to it.
*/
+ (id) stringWithString:(SBString*)aString;
/*!
  @method stringWithFormat:
  
  Returns a newly-initialized, autoreleased instance containing the string that results from
  the sprintf-like conversion of the format string using the additional (variable) arguments
  passed to the method.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types.
*/
+ (id) stringWithFormat:(const char*)format,...;
/*!
  @method stringWithBytes:count:encoding:
  
  Returns a newly-initialized, autoreleased instance containing the string that results from
  converting the provided byte stream (at bytes) FROM the given character encoding TO
  Unicode.
*/
+ (id) stringWithBytes:(const void*)bytes count:(int)count encoding:(const char*)encoding;

/*!
  @method initWithUTF8String:
  
  Initialize the receiver to contain a copy of the UTF-8 encoded cString passed to it.
*/
- (id) initWithUTF8String:(const char*)cString;
/*!
  @method initWithUTF8String:length:
  
  Initialize the receiver to contain a copy of the UTF-8 encoded cString passed to it.  Only
  the first length UTF8 code points are used.
*/
- (id) initWithUTF8String:(const char*)cString length:(int)length;
/*!
  @method initWithCharacters:length:
  
  Initialize the receiver to contain a copy of the UTF-16 characters passed to it (as a
  buffer pointer and number of UTF-16 characters in the buffer).
*/
- (id) initWithCharacters:(UChar*)characters length:(int)length;
/*!
  @method initWithString:
  
  Initialize the receiver to contain a copy of the SBString passed to it.
*/
- (id) initWithString:(SBString*)aString;
/*!
  @method initWithFormat:,...
  
  Initialize the receiver to contain the string that results from the sprintf-like conversion
  of the format string using the additional (variable) arguments passed to the method.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types.
*/
- (id) initWithFormat:(const char*)format,...;
/*!
  @method initWithFormat:arguments:
  
  Initialize the receiver to contain the string that results from the sprintf-like conversion
  of the format string using the variable argument list passed to the method.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types.
*/
- (id) initWithFormat:(const char*)format arguments:(va_list)argList;
/*!
  @method initWithBytes:count:encoding:
  
  Attempts to initialize the receiver to contain the string that results from converting the
  byte stream (at bytes) FROM the given character encoding TO Unicode.
*/
- (id) initWithBytes:(const void*)bytes count:(int)count encoding:(const char*)encoding;

@end

/*!
  @category SBString(SBStringExtensions)
  
  Category of SBString which contains all additional functionality beyond the accessors for
  string length and single-character retrieval.  At the level of SBString itself, these
  methods are implemented using those two basic accessors; subclasses can (and should!)
  provide their own implementations for more optimal processing where applicable.
*/
@interface SBString(SBStringExtensions)

/*!
  @method nativeEncoding
  
  Returns the default encoding that the class will use to represent instances' character
  data.
*/
+ (SBStringNativeEncoding) nativeEncoding;
/*!
  @method nativeEncoding
  
  Returns the encoding that the receiver is currently using to represent its character data.
*/
- (SBStringNativeEncoding) nativeEncoding;

/*!
  @method substringFromIndex:
  
  Return a string which contains (inclusive) all characters from an arbitrary index to the end
  of the string.
  
  This is a convenience method that calls-through to substringWithRange:.
*/
- (SBString*) substringFromIndex:(int)from;
/*!
  @method substringToIndex:
  
  Return a string which contains (inclusive) all characters up to an arbitrary index in the
  string.
  
  This is a convenience method that calls-through to substringWithRange:.
*/
- (SBString*) substringToIndex:(int)to;
/*!
  @method substringWithRange:
  
  Return a string which contains all characters in the receiver which lie inside the
  provided range (end-points are inclusive).
*/
- (SBString*) substringWithRange:(SBRange)range;
/*!
  @method utf16Characters
  
  Return a pointer to a buffer containing the receiver's character data in UTF-16 encoding.
  In some instances this is a constant-time operation with no additional memory cost; in
  some cases it may trigger a re-encoding into an autoreleased SBData instance.
  
  It is never okay to hold onto the returned pointer for very long &mdash; the next flush of the
  autorelease pool may cause the SBData object backing the character data to be deallocated,
  in which case the pointer will cause your program to SEGFAULT.  If you need a copy of
  the UTF-16 character data, use the copyCharactersToBuffer:length: method with a chunk of
  memory you've allocated.
*/
- (const UChar*) utf16Characters;
/*!
  @method utf8Length
  
  Return the number of UTF-8 coding entities (bytes) required by the receiver's string.
*/
- (int) utf8Length;
/*!
  @method utf8Characters
  
  Return a pointer to a buffer containing the receiver's character data in UTF-8 encoding.
  In some instances this is a constant-time operation with no additional memory cost; in
  most cases it will trigger a re-encoding into an autoreleased SBData instance.
  
  It is never okay to hold onto the returned pointer for very long &mdash; the next flush of the
  autorelease pool may cause the SBData object backing the character data to be deallocated,
  in which case the pointer will cause your program to SEGFAULT.  If you need a copy of
  the UTF-8 character data, use the copyUTF8CharactersToBuffer:length: method with a chunk of
  memory you've allocated.
*/
- (const unsigned char*) utf8Characters;
/*!
  @method utf32Length
  
  Return the number of UTF-32 coding entities (4-byte words) required by the receiver's string.
*/
- (int) utf32Length;
/*!
  @method utf32Characters
  
  Return a pointer to a buffer containing the receiver's character data in UTF-32 encoding.
  This will most likely _always_ trigger a re-encoding into an autoreleased SBData instance,
  since none of the internal bits of this class cluster natively treat their strings as
  UTF-32 characters.
  
  It is never okay to hold onto the returned pointer for very long &mdash; the next flush of the
  autorelease pool may cause the SBData object backing the character data to be deallocated,
  in which case the pointer will cause your program to SEGFAULT.  If you need a copy of
  the UTF-32 character data, use the copyUTF32CharactersToBuffer:length: method with a chunk of
  memory you've allocated.
*/
- (const UChar32*) utf32Characters;
/*!
  @method utf32CharacterAtIndex:
  
  Returns the index-th UTF-32 character from the receiver's string.
*/
- (UChar32) utf32CharacterAtIndex:(int)index;
/*!
  @method uppercaseString
  
  Convenience method which calls through to uppercaseStringWithLocale: with the default locale.
*/
- (SBString*) uppercaseString;
/*!
  @method lowercaseString
  
  Convenience method which calls through to uppercaseStringWithLocale: with the default locale.
*/
- (SBString*) lowercaseString;
/*!
  @method titlecaseString
  
  Convenience method which calls through to uppercaseStringWithLocale: with the default locale.
*/
- (SBString*) titlecaseString;
/*!
  @method uppercaseStringWithLocale:
  
  Return a string which contains the receiver's string transformed to upper case according to
  the provided locale's case-folding rules.
*/
- (SBString*) uppercaseStringWithLocale:(SBLocale*)locale;
/*!
  @method lowercaseStringWithLocale:
  
  Return a string which contains the receiver's string transformed to lower case according to
  the provided locale's case-folding rules.
*/
- (SBString*) lowercaseStringWithLocale:(SBLocale*)locale;
/*!
  @method titlecaseStringWithLocale:
  
  Return a string which contains the receiver's string transformed to title case according to
  the provided locale's case-folding rules.
*/
- (SBString*) titlecaseStringWithLocale:(SBLocale*)locale;
/*!
  @method copyCharactersToBuffer:length:
  
  Fill the provided buffer with the receiver's string as UTF-16 characters/surrogates.  If the
  buffer is long enough, a trailing NUL character will be included.
*/
- (BOOL) copyCharactersToBuffer:(UChar*)buffer length:(int)length;
/*!
  @method copyUTF8CharactersToBuffer:length:
  
  Fill the provided buffer with the receiver's string as UTF-8 characters/surrogates.  If the
  buffer is long enough, a trailing NUL character will be included.
*/
- (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer length:(int)length;
/*!
  @method copyUTF32CharactersToBuffer:length:
  
  Fill the provided buffer with the receiver's string as UTF-32 characters.  If the buffer is long
  enough, a trailing NUL character will be included.
*/
- (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer length:(int)length;
/*!
  @method dataUsingEncoding
  
  Attempt to convert the receiver _from_ its native encoding _to_ the given character encoding and
  return the resulting byte stream as an SBData object.
*/
- (SBData*) dataUsingEncoding:(const char*)encoding;
/*!
  @method isEqualToString:
  
  Simple binary comparison of the receiver against another string.
*/
- (BOOL) isEqualToString:(SBString*)otherString;
/*!
  @method compare:
  
  Compare the full range of characters in the receiver's string against otherString.  The comparison
  uses the basic UCA algorithms and tables (no locale-specific tailoring) and tertiary strength
  (case and diacritics are significant). 
*/
- (SBComparisonResult) compare:(SBString*)otherString;
/*!
  @method compare:options:
  
  Compare the full range of characters in the receiver's string against otherString.  The comparison
  uses the basic UCA algorithms and tables (no locale-specific tailoring).  The options argument
  can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringNumericSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringForcedOrderingSearch
  
*/
- (SBComparisonResult) compare:(SBString*)otherString options:(SBStringSearchOptions)options;
/*!
  @method compare:options:range:
  
  Compare the given range of characters in the receiver's string against otherString.  The comparison
  uses the basic UCA algorithms and tables (no locale-specific tailoring).  The options argument
  can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringNumericSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringForcedOrderingSearch
  
*/
- (SBComparisonResult) compare:(SBString*)otherString options:(SBStringSearchOptions)options range:(SBRange)compareRange;
/*!
  @method compare:options:range:locale:
  
  Compare the given range of characters in the receiver's string against otherString.  The comparison
  uses the basic UCA algorithms and tables unless a non-nil SBLocale is provided.  The options argument
  can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringNumericSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringForcedOrderingSearch
  
*/
- (SBComparisonResult) compare:(SBString*)otherString options:(SBStringSearchOptions)options range:(SBRange)compareRange locale:(SBLocale*)locale;
/*!
  @method caseInsensitiveCompare:
  
  Convenience method which invokes compare:options: with the SBStringCaseInsensitiveSearch option.
*/
- (SBComparisonResult) caseInsensitiveCompare:(SBString*)otherString;
/*!
  @method localizedCompare:
  
  Convenience method which invokes compare:options:range:locale: with the default locale.
*/
- (SBComparisonResult) localizedCompare:(SBString*)otherString;
/*!
  @method localizedCaseInsensitiveCompare:
  
  Convenience method which invokes compare:options:range:locale: with the default locale and the
  case-insensitive, forced-ordering option.
*/
- (SBComparisonResult) localizedCaseInsensitiveCompare:(SBString*)otherString;
/*!
  @method rangeOfString:
  
  Locate the first occurence of otherString in the receiver and return a range corresponding to the
  found position and entity range.
  
  Returns an empty range if otherString is not found.
*/
- (SBRange) rangeOfString:(SBString*)otherString;
/*!
  @method rangeOfString:options:
  
  Locate the first occurence of otherString in the receiver and return a range corresponding to the found
  position and entity range.
  
  The options argument can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringAnchoredSearch
    - SBStringBackwardsSearch
  
  Returns an empty range if otherString is not found.
*/
- (SBRange) rangeOfString:(SBString*)otherString options:(SBStringSearchOptions)options;
/*!
  @method rangeOfString:options:range:
  
  Locate the first occurence of otherString in the given searchRange of the receiver and return a range
  corresponding to the found position and entity range.
  
  The searchRange is a range of UTF-16 entities to search, not strictly a character range.
  
  The options argument can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringAnchoredSearch
    - SBStringBackwardsSearch
  
  Returns an empty range if otherString is not found.
*/
- (SBRange) rangeOfString:(SBString*)otherString options:(SBStringSearchOptions)options range:(SBRange)searchRange;
/*!
  @method rangeOfString:options:range:locale:
  
  Locate the first occurence of otherString in the given searchRange of the receiver and return a range
  corresponding to the found position and entity range.  The search uses the basic UCA algorithms and tables
  unless a non-nil SBLocale is provided.
  
  The searchRange is a range of UTF-16 entities to search, not strictly a character range.
  
  The options argument can contain any of the following flags OR'ed together:
  
    - SBStringCaseInsensitiveSearch
    - SBStringLiteralSearch
    - SBStringDiacriticInsensitiveSearch
    - SBStringAnchoredSearch
    - SBStringBackwardsSearch
  
  Returns an empty range if otherString is not found.
*/
- (SBRange) rangeOfString:(SBString*)otherString options:(SBStringSearchOptions)options range:(SBRange)searchRange locale:(SBLocale*)locale;
/*!
  @method rangeOfCharacterFromSet:
  
  Returns the position of the first character in the receiver which is in aSet.
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet;
/*!
  @method rangeOfCharacterFromSet:options:range:
  
  Returns the position of the first character in the receiver which is in aSet.
  
  The options argument can contain any of the following flags OR'ed together:
  
    - SBStringAnchoredSearch
    - SBStringBackwardsSearch
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet options:(SBStringSearchOptions)options;
/*!
  @method rangeOfCharacterFromSet:options:range:
  
  Returns the position of the first character in the receiver which is in aSet.  The search
  is limited to the given sub-range of the receiver (searchRange).
  
  The options argument can contain any of the following flags OR'ed together:
  
    - SBStringAnchoredSearch
    - SBStringBackwardsSearch
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet options:(SBStringSearchOptions)options range:(SBRange)searchRange;
/*!
  @method hasPrefix:
  
  Returns YES if the receiver begins with the specified prefixString.
*/
- (BOOL) hasPrefix:(SBString*)prefixString;
/*!
  @method hasSuffix:
  
  Returns YES if the receiver ends with the specified suffixString.
*/
- (BOOL) hasSuffix:(SBString*)suffixString;
/*!
  @method stringByAppendingString:
  
  Return a new string that contains the receiver's string with aString concatenated.
*/
- (SBString*) stringByAppendingString:(SBString*)aString;
/*!
  @method stringByAppendingFormat:
  
  Return a new string that contains the receiver's string with the string that results from
  the sprintf-like conversion of the format string using the additional (variable) arguments
  passed to the method concatenated to it.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types
*/
- (SBString*) stringByAppendingFormat:(const char*)format, ...;
/*!
  @method componentsSeparatedByString:
  
  Attempts to carve-up the receiver using the given separator string as a boundary between
  values.
*/
- (SBArray*) componentsSeparatedByString:(SBString*)separator;
/*!
  @method doubleValue
  
  Attempts to parse the receiver as a double-precision floating-point value.  Returns
  NAN if unable to parse.
*/
- (double) doubleValue;
/*!
  @method floatValue
  
  Attempts to parse the receiver as a single-precision floating-point value.  Returns
  NAN if unable to parse.
*/
- (float) floatValue;
/*!
  @method intValue
  
  Attempts to parse the receiver as an integer value.  Returns 0 if unable to parse.
*/
- (int) intValue;
/*!
  @method writeToStream:
  
  Write the receiver's string to the provided stdio stream as UTF-8 characters.
*/
- (void) writeToStream:(FILE*)stream;

@end

/*!
  @class SBMutableString
  @discussion
  Instances of SBMutableString augment SBString with methods which modify instances' character
  strings.  This class is constructed to be very similar to the Cocoa NSMutableString class; just like
  SBString, there are concrete subclasses implemented behind the scenes.
  
  Internally, all of the SBMutableString concrete subclasses represent their text payload as UTF-16
  character arrays.  This may not be true of any subclasses defined outside the context of this
  header file, though.  Any subclass of SBMutableString must at least implement:
  <ul>
    <li>- (int) length</li>
    <li>- (UChar) characterAtIndex:(int)index</li>
    <li>- (void) replaceCharactersInRange:(SBRange)range withCharacters:(UChar*)characters length:(int)length</li>
  </ul>
  With these three methods, any subclass will automatically work with all of the methods defined in
  the SBMutableStringExtensions category.  Of course, further optimization can be accomplished by
  overriding those methods with methods that are optimized to the particular context of the
  subclass.
  
  Subclasses are responsible for implementing their own factory and init methods; they should
  not rely on the SBString/SBMutableString methods since only concrete subclasses of SBMutableString
  <i>actually</i> allocate space for character arrays, etc.
*/
@interface SBMutableString : SBString

/*!
  @method replaceCharactersInRange:withCharacters:length:
  
  Cuts the UTF-16 entities in range out of the receiver and replaces them with the UTF-16 entities
  contained in aString; at most length UTF-16 entities are copied into the receiver.
  
  For mutable strings allocated with a fixed capacity, this method should not fail if the resulting
  string will exceed the capacity; rather, the resulting string should be truncated to fit the
  fixed capacity.
*/
- (void) replaceCharactersInRange:(SBRange)range withCharacters:(UChar*)characters length:(int)length;

@end

/*!
  @category SBMutableString(SBMutableStringCreation)
  
  Category of SBMutableString which groups all methods (in addition to those defined for SBString)
  which create or initialize an instance of SBMutableString.
*/
@interface SBMutableString(SBMutableStringCreation)

/*!
  @method stringWithFixedCapacity:
  
  Returns a newly-initialized, autoreleased instance which can accomodate at most maxCharacters
  UTF-16 entities.
*/
+ (id) stringWithFixedCapacity:(int)maxCharacters;
/*!
  @method initWithFixedCapacity:
  
  Initialize the receiver to accomodate at most maxCharacters UTF-16 entities.
*/
- (id) initWithFixedCapacity:(int)maxCharacters;

@end

/*!
  @category SBMutableString(SBMutableStringExtensions)
  
  Category of SBMutableString which contains all additional functionality beyond the simple
  character replacement method.  At the level of SBMutableString itself, these methods are
  implemented using the replaceCharactersInRange:withCharacters:length method; subclasses
  can provide their own implementations for more optimal processing where applicable.
*/
@interface SBMutableString(SBMutableStringExtensions)

/*!
  @method deleteAllCharacters
  
  Null-out the string.
*/
- (void) deleteAllCharacters;
/*!
  @method replaceCharactersInRange:withString:
  
  Cuts the UTF-16 entities in range out of the receiver and replaces them with the characters
  contained in aString.
*/
- (void) replaceCharactersInRange:(SBRange)range withString:(SBString*)aString;
/*!
  @method appendString:
  
  Append the contents of aString to the receiver.
*/
- (void) appendString:(SBString*)aString;
/*!
  @method appendCharacters:length:
  
  Append length UTF-16 entities from the characters buffer to the receiver.
*/
- (void) appendCharacters:(const UChar*)characters length:(int)length;
/*!
  @method appendFormat:...
  
  Append characters produced by the sprintf-like conversion of the format string using the
  additional (variable) arguments passed to the method.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types.
*/
- (void) appendFormat:(const char*)format,...;
/*!
  @method insertString:atIndex:
  
  Insert the contents of aString in the receiver at the specified offset within the receiver.
*/
- (void) insertString:(SBString*)aString atIndex:(unsigned int)index;
/*!
  @method insertCharacters:length:atIndex:
  
  Insert length UTF-16 entities from the characters buffer to the receiver at the specified offset
  within the receiver.
*/
- (void) insertCharacters:(const UChar*)characters length:(int)length atIndex:(unsigned int)index;
/*!
  @method deleteCharactersInRange:
  
  Remove the UTF-16 entities at indices in range (end-points inclusive) from the receiver.
*/
- (void) deleteCharactersInRange:(SBRange)range;
/*!
  @method setString:
  
  Clears the receiver and sets it to contain the same string present in aString.
*/
- (void) setString:(SBString*)aString;
/*!
  @method setWithUTF8String:
  
  Clears the receiver and sets it to contain the characters in cString.
*/
- (void) setWithUTF8String:(const char*)cString;
/*!
  @method setWithUTF8String:length:
  
  Clears the receiver and sets it to contain the characters in the first "length" bytes
  of cString.
*/
- (void) setWithUTF8String:(const char*)cString length:(int)length;

@end

/*!
  @category SBString(SBStringPathExtensions)
  
  Category which groups a set of convenience methods for working with UNIX file paths.
*/
@interface SBString(SBStringPathExtensions)

/*!
  @method isAbsolutePath
  
  Returns YES if the receiver represents an absolute UNIX file path.
*/
- (BOOL) isAbsolutePath;

/*!
  @method isRelativePath
  
  Returns YES if the receiver represents a relative UNIX file path.
*/
- (BOOL) isRelativePath;

/*!
  @method lastPathComponent
  
  Returns a string which contains the last component of the UNIX file path
  contained in the receiver.  E.g.
  
    ["/opt/etc/ipf.conf" lastPathComponent] => "ipf.conf"
*/
- (SBString*) lastPathComponent;

/*!
  @method stringByDeletingLastPathComponent
  
  Returns a string which contains all but the last component of the UNIX file path
  contained in the receiver.  E.g.
  
    ["/opt/etc/ipf.conf" stringByDeletingLastPathComponent] => "/opt/etc"
*/
- (SBString*) stringByDeletingLastPathComponent;

/*!
  @method stringByAppendingPathComponent:
  
  Returns a string which contains the reciever with a "/" and aString appended to it.
  E.g.
  
    ["/opt/etc" stringByAppendingPathComponent:"ipf.conf"] => "/opt/etc/ipf.conf"
*/
- (SBString*) stringByAppendingPathComponent:(SBString*)aString;

/*!
  @method stringByAppendingPathComponents:
  
  Returns a string which contains the reciever with one or more strings suffixed
  using a "/" prefix on each.  E.g.
  
    ["/opt/etc" stringByAppendingPathComponent:"ipf","ipf.conf",nil] => "/opt/etc/ipf/ipf.conf"
  
  The list of arguments must be terminated by nil.
*/
- (SBString*) stringByAppendingPathComponents:(SBString*)aString,...;

/*!
  @method pathExtension
  
  Returns a string which contains the filename extension of the UNIX file path
  contained in the receiver.  E.g.
  
    ["/opt/etc/ipf.conf" pathExtension] => "conf"
*/
- (SBString*) pathExtension;

/*!
  @method stringByDeletingPathExtension
  
  Returns a string which contains all but the filename extension of the UNIX file path
  contained in the receiver.  E.g.
  
    ["/opt/etc/ipf.conf" stringByDeletingPathExtension] => "/opt/etc/ipf"
*/
- (SBString*) stringByDeletingPathExtension;

/*!
  @method stringByAppendingPathExtension
  
  Returns a string which contains the receiver with a "." and aString appended to it.
  E.g.
  
    ["/opt/etc/ipf.conf" stringByAppendingPathExtension:"bak"] => "/opt/etc/ipf.conf.bak"
*/
- (SBString*) stringByAppendingPathExtension:(SBString*)aString;

@end

/*!
  @function SBUserName
  
  Returns an SBString containing the username of the current user.
*/
SBString* SBUserName();

/*!
  @function SBFullUserName
  
  Returns an SBString containing the full name (GECOS) of the current user.
*/
SBString* SBFullUserName();

/*!
  @function SBHomeDirectory
  
  Returns an SBString containing the path to the current user's home
  directory.
*/
SBString* SBHomeDirectory();

/*!
  @function SBHomeDirectoryForUser
  
  Returns an SBString containging the path to the specified user's home
  directory.
*/
SBString* SBHomeDirectoryForUser(SBString* userName);


/*!
  @class SBStringConst
  @discussion
  This is the class which gcc will use for any string constant objects it finds.  This class
  definition is placed here primarily to make it clear what class should be used when
  compiling (with the -fconstant-string-class flag to gcc).  Do NOT attempt to allocate
  instances of it, etc.  It's useless for anything _but_ string constants.
*/
@interface SBStringConst : SBString
{
  /*
    Instances will have the same size as NXConstStr but will have the
    char* and uint length in reverse order structurally -- we'll
    worry about that internally, though:
   */
  const char*     _reserved;
}

- (unsigned int) constCStringLength;
- (const char*) constCString;

@end

/*
  Since we're using the GNU compiler collection we can get away with variable-length stack-based
  allocations (a'la Fortran).  This means that for standard C APIs which are expecting ASCII
  argument strings we could do:
  
    SBString*   aPath = [SBString stringWithUTF8String:"/etc/passwd"];
    
    SBSTRING_AS_UTF8_BEGIN(aPath)
      struct stat   info;
      
      stat(aPath_utf8, &info);
        :
    SBSTRING_AS_UTF8_END
    
  The UTF8 version of the string is named by appending "_utf8" to the SBString object's name.
*/
#define SBSTRING_AS_UTF8_BEGIN(S) if ( S && ([S utf8Length] > 0) ) { char S ## _utf8[[S utf8Length] + 1]; if ( [S copyUTF8CharactersToBuffer:S ## _utf8 length:[S utf8Length] + 1] ) {
#define SBSTRING_AS_UTF8_END } }
