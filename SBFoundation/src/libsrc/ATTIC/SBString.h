//
// scruffy : maintenance scheduler daemon for SHUEBox
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

@class SBData, SBLocale, SBCharacterSet;

/*!
  @enum SBString Search Options
  
  Options affecting string searches.
*/
enum {
  SBBackwardsSearch       = 1 << 0,
  SBAnchoredSearch        = 1 << 1
};

/*!
  @class SBString
  
  Instances of SBString wrap textual data.  Internally, the string is stored as a UTF-16 encoded array of
  Unicode characters.  The IBM ICU library is used for all Unicode processing operations, with this class
  primarily acting as house-keeper and simplified interface to said library.
*/
@interface SBString : SBObject
{
  UChar*            _u16Chars;
  size_t            _byteLength;
  int32_t           _charLength;
  unsigned int      _storedHash;
  id                _u8Chars;
  struct {
    unsigned int    hashCalculated      : 1;
  } _flags;
}

/*!
  @method emptyString
  
  Returns a shared instance of the NUL string.
*/
+ (SBString*) emptyString;

/*!
  @method string
  
  Returns an empty, newly-initialized, autoreleased instance.
*/
+ (SBString*) string;

/*!
  @method stringWithUTF8String:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the UTF-8 encoded
  cString passed to it.
*/
+ (SBString*) stringWithUTF8String:(const char*)cString;

/*!
  @method stringWithCharacters:length:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the UTF-16 characters
  passed to it (as a buffer pointer and number of UTF-16 characters in the buffer).
*/
+ (SBString*) stringWithCharacters:(UChar*)characters length:(int)length;

/*!
  @method stringWithString:
  
  Returns a newly-initialized, autoreleased instance containing a copy of the SBString passed
  to it.
*/
+ (SBString*) stringWithString:(SBString*)aString;

/*!
  @method stringWithFormat:
  
  Returns a newly-initialized, autoreleased instance containing the string that results from
  the sprintf-like conversion of the format string using the additional (variable) arguments
  passed to the method.
  
  See the ICU ustdio.h header for a description of the format string.  Basically the same as
  the C printf format, with %C/%S added to convert UChar/UChar* types.
*/
+ (SBString*) stringWithFormat:(const char*)format,...;

/*!
  @method stringWithBytes:count:encoding:
  
  Returns a newly-initialized, autoreleased instance containing the string that results from
  converting the provided byte stream (at bytes) FROM the given character encoding TO
  Unicode.
*/
+ (SBString*) stringWithBytes:(const void*)bytes count:(int)count encoding:(const char*)encoding;

/*!
  @method initWithUTF8String:
  
  Initialize the receiver to contain a copy of the UTF-8 encoded cString passed to it.
*/
- (id) initWithUTF8String:(const char*)cString;

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
  @method initWithFormat:
  
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

/*!
  @method utf16Characters
  
  This method mainly gets used when passing SBString's to one of the formatting methods;
  shouldn't really use it otherwise!
*/
- (const UChar*) utf16Characters;

/*!
  @method length
  
  Returns the number of UTF-16 entities in the string (not truly character count, since surrogate
  pairs count as two entities).
*/
- (size_t) length;

/*!
  @method utf8Length
  
  Returns the length of the receiver when re-encoded as UTF-8.
*/
- (size_t) utf8Length;

/*!
  @method utf32Length
  
  Returns the length of the receiver when re-encoded as UTF-32.
*/
- (size_t) utf32Length;

/*!
  @method characterAtIndex:
  
  Returns the UTF-16 entity at the specified index.  This may be an actual representable character
  or a part of a surrogate pair, so use this method with care.
*/
- (UChar) characterAtIndex:(int)index;

/*!
  @method utf32CharacterAtIndex:
  
  Returns the UTF-32 character which occurs at the specified position in the UTF-16 entity vector.
*/
- (UChar32) utf32CharacterAtIndex:(int)index;

/*!
  @method uppercaseString
  
  Return the receiver's string with all characters converted to their uppercase equivalents.
*/
- (SBString*) uppercaseString;

/*!
  @method lowercaseString
  
  Return the receiver's string with all characters converted to their lowercase equivalents.
*/
- (SBString*) lowercaseString;

/*!
  @method titlecase
  
  Return the receiver's string with all characters converted to their titlecase equivalents.
*/
- (SBString*) titlecaseString;

/*!
  @method uppercaseStringWithLocale:
  
  Return the receiver's string with all characters converted to their uppercase equivalents
  according to the passed-in locale.
*/
- (SBString*) uppercaseStringWithLocale:(SBLocale*)locale;

/*!
  @method lowercaseStringWithLocale:
  
  Return the receiver's string with all characters converted to their lowercase equivalents
  according to the passed-in locale.
*/
- (SBString*) lowercaseStringWithLocale:(SBLocale*)locale;

/*!
  @method titlecaseWithLocale:
  
  Return the receiver's string with all characters converted to their titlecase equivalents
  according to the passed-in locale.
*/
- (SBString*) titlecaseStringWithLocale:(SBLocale*)locale;

/*!
  @method copyUTF8CharactersToBuffer:length:
  
  Fill the provided buffer with the receiver's characters re-encoded as UTF-8.  If the buffer
  is long enough, a trailing NUL character will be appended.
*/
- (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer length:(size_t)length;

/*!
  @method copyUTF32CharactersToBuffer:length:
  
  Fill the provided buffer with the receiver's characters re-encoded as UTF-32.  If the buffer
  is long enough, a trailing NUL character will be appended.
*/
- (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer length:(size_t)length;

/*!
  @method dataUsingEncoding
  
  Convert the receiver FROM its native Unicode encoding TO the given character encoding and return
  the resulting byte stream as an SBData object.
*/
- (SBData*) dataUsingEncoding:(const char*)encoding;

/*!
  @method utf8Characters
  
  Returns the string in UTF-8 encoding; the characters are backed by a SBData object held internally
  by the receiver and remains valid through the lifetime of the receiver.
*/
- (const unsigned char*) utf8Characters;

/*!
  @method compareToString:
  
  Compare two strings in code point order.
*/
- (SBComparisonResult) compareToString:(SBString*)aString;

/*!
  @method compareToString:
  
  Caseless comparison of two strings in code point order.
*/
- (SBComparisonResult) caselessCompareToString:(SBString*)aString;

/*!
  @method writeToStream:
  
  Write the receiver to the stdio stream as UTF-8 characters.
*/
- (void) writeToStream:(FILE*)stream;

/*!
  @method rangeOfString:
  
  Locate the first occurence of aString in the receiver and return a range corresponding to the
  found position and entity range.
  
  Returns an empty range if aString is not found.
*/
- (SBRange) rangeOfString:(SBString*)aString;

/*!
  @method rangeOfString:range:
  
  Locate the first occurence of aString in the given searchRange of the receiver and return a range
  corresponding to the found position and entity range.
  
  The searchRange is a range of UTF-16 entities to search, not strictly a character range.
  
  Returns an empty range if aString is not found.
*/
- (SBRange) rangeOfString:(SBString*)aString range:(SBRange)searchRange;

/*!
  @method rangeOfCharacterFromSet:
  
  Returns the position of the first character in the receiver which is in aSet.
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet;

/*!
  @method rangeOfCharacterFromSet:options:range:
  
  Returns the position of the first character in the receiver which is in aSet.
  
  The options argument is an OR of search modifiers; pass zero for no options.
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet options:(unsigned int)options;

/*!
  @method rangeOfCharacterFromSet:options:range:
  
  Returns the position of the first character in the receiver which is in aSet.  The search
  is limited to the given sub-range of the receiver (searchRange).
  
  The options argument is an OR of search modifiers; pass zero for no options.
*/
- (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet options:(unsigned int)options range:(SBRange)searchRange;

/*!
  @method replaceCharactersInRange:withString:
  
  Cuts the UTF-16 entities in range out of the receiver and replaces them with the UTF-16 entities
  contained in aString.
  
  This routine acts as a driver for all of the string modification methods: appending is a replacement
  of zero characters at the end of the receiver; insertion is a replacement of zero characters at an
  arbitrary index; and deletion is a replacement with an empty string.
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
- (void) appendCharacters:(const UChar*)characters length:(size_t)length;

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
- (void) insertCharacters:(const UChar*)characters length:(size_t)length atIndex:(unsigned int)index;

/*!
  @method deleteCharactersInRange:
  
  Remove the UTF-16 entities at indices in range from the receiver.
*/
- (void) deleteCharactersInRange:(SBRange)range;

@end

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
  @method pathExists
  
  Returns YES if the receiver represents an extant UNIX file path.
*/
- (BOOL) pathExists;

/*!
  @method pathIsDirectory
  
  Returns YES if the receiver represents an extant UNIX file path and
  the object at that path is a directory.
*/
- (BOOL) pathIsDirectory;

/*!
  @method pathIsFile
  
  Returns YES if the receiver represents an extant UNIX file path and
  the object at that path is a file.
*/
- (BOOL) pathIsFile;

/*!
  @method setWorkingDirectory
  
  Attempts to set the current working directory to the UNIX file path contained
  in the receiver.  Returns YES if successful.
*/
- (BOOL) setWorkingDirectory;

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
