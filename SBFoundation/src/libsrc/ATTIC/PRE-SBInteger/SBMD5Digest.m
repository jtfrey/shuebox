//
// SBFoundation : ObjC Class Library for Solaris
// SBMD5Digest.m
//
// Compute MD5 digests.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBMD5Digest.h"
#import "SBData.h"

@implementation SBMD5Digest

  + (SBMD5Digest*) md5Digest
  {
    return [[[SBMD5Digest alloc] init] autorelease];
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
      MD5Init(&_context);
      _digestString[0] = '\0';
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( ! _isDigestFinished )
      MD5Final(_digestString, &_context);
    [super dealloc];
  }

//

  - (BOOL) isDigestFinished
  {
    return _isDigestFinished;
  }
  
//

  - (void) resetForNewDigest
  {
    if ( ! _isDigestFinished ) {
      MD5Final(_digestString, &_context);
      _digestString[0] = '\0';
      _isDigestFinished = NO;
    }
    MD5Init(&_context);
  }

//

  - (const char*) digestString
  {
    if ( ! _isDigestFinished ) {
      MD5Final(_digestString, &_context);
      _isDigestFinished = YES;
    }
    return (const char*)_digestString;
  }

//

  - (BOOL) appendBytesToDigest:(const void*)bytes
    length:(size_t)length
  {
    if ( ! _isDigestFinished )
      MD5Update(&_context, (unsigned char*)bytes, (unsigned int)length);
    return NO;
  }
  
//

  - (BOOL) appendStringToDigest:(SBString*)aString
  {
    if ( ! _isDigestFinished )
      MD5Update(&_context, (unsigned char*)[aString utf16Characters], (unsigned int)(sizeof(UChar) * [aString length]));
    return NO;
  }
  
//

  - (BOOL) appendDataToDigest:(SBData*)aData
  {
    if ( ! _isDigestFinished )
      MD5Update(&_context, (unsigned char*)[aData bytes], (unsigned int)[aData length]);
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBString(SBMD5DigestAdditions)

  - (BOOL) md5DigestForUTF8:(const char*)digestString
  {
    SBSTRING_AS_UTF8_BEGIN(self)
    
#ifdef SOLARIS
      md5_calc(
          (char*)digestString,
          (unsigned char*)self_utf8,
          (unsigned int)[self utf8Length]
        );
      return YES;
#else
      if ( MD5((unsigned char*)self_utf8, (unsigned int)[self utf8Length], (unsigned char*)digestString) == digestString )
        return YES;
#endif
    
    SBSTRING_AS_UTF8_END
    return NO;
  }

//

  - (BOOL) md5Digest:(const char*)digestString
  {
#ifdef SOLARIS
    md5_calc(
        (char*)digestString,
        (unsigned char*)[self utf16Characters],
        (unsigned int)(sizeof(UChar) * [self length])
      );
    return YES;
#else
      if ( MD5((unsigned char*)[self utf16Characters], (unsigned int)(sizeof(UChar) * [self length]), (unsigned char*)digestString) == digestString )
        return YES;
#endif
    return NO;
  }

@end
