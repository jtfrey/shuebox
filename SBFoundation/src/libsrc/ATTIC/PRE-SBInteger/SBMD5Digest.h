//
// SBFoundation : ObjC Class Library for Solaris
// SBMD5Digest.h
//
// Compute MD5 digests.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"

#ifdef SOLARIS
# include <md5.h>
#endif

@class SBData;

/*!
  @class SBMD5Digest
  @discussion
    Instances of this class are used to generate an MD5 digest for a stream
    of bytes.
*/
@interface SBMD5Digest : SBObject
{
  MD5_CTX     _context;
  BOOL        _isDigestFinished;
  char        _digestString[16];
}

/*!
  @method md5Digest
  @discussion
    Returns a singleton, shared instance of this class.
*/
+ (SBMD5Digest*) md5Digest;

/*!
  @method isDigestFinished
  @discussion
    Returns YES if the receiver's digest action is complete.
*/
- (BOOL) isDigestFinished;

/*!
  @method resetForNewDigest
  @discussion
    Returns the receiver to its initial state, making it ready to
    perform another digest action.
*/
- (void) resetForNewDigest;

/*!
  @method digestString
  @discussion
    Marks the receiver as having completed its current digest
    action and returns a pointer to the 16-character MD5 digest
    string which was produced.
*/
- (const char*) digestString;

/*!
  @method appendBytesToDigest:length:
  @discussion
    Process the given byte stream (length octets at bytes) into the
    receiver's current digest hash.
*/
- (BOOL) appendBytesToDigest:(const void*)bytes length:(size_t)length;

/*!
  @method appendStringToDigest:
  @discussion
    Process the bytes of aString into the receiver's current digest hash.
    The string is processed as UTF-16 character data.
*/
- (BOOL) appendStringToDigest:(SBString*)aString;

/*!
  @method appendDataToDigest:
  @discussion
    Process the binary contents of aData into the receiver's current digest
    hash.
*/
- (BOOL) appendDataToDigest:(SBData*)aData;

@end

//

@interface SBString(SBMD5DigestAdditions)

/*!
  @method md5DigestForUTF8:
  @discussion
    Fills-in the 16-byte buffer at digestString with the MD5 digest hash
    corresponding with the UTF-8 representation of the receiver.
*/
- (BOOL) md5DigestForUTF8:(const char*)digestString;

/*!
  @method md5Digest:
  @discussion
    Fills-in the 16-byte buffer at digestString with the MD5 digest hash
    corresponding with the UTF-16 representation of the receiver.
*/
- (BOOL) md5Digest:(const char*)digestString;

@end
