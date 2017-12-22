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

static inline int
__SBMD5HexDigitToInt(
  UChar   c
)
{
  switch ( c ) {
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      return ( c - '0' );
    case 'a':
    case 'b':
    case 'c':
    case 'd':
    case 'e':
    case 'f':
      return ( 10 + c - 'a' );
    case 'A':
    case 'B':
    case 'C':
    case 'D':
    case 'E':
    case 'F':
      return ( 10 + c - 'A' );
  }
  return -1;
}

//

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
    length:(SBUInteger)length
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
  
//

  - (BOOL) md5DigestForUTF8MatchesString:(SBString*)digestAsString
  {
    unsigned char   digestHash[16];
    
    if ( [digestAsString length] != 32 )
      return NO;
    
    if ( [self md5DigestForUTF8:digestHash] ) {
      SBUInteger    i = 0, j = 0;
      
      while ( i < 32 ) {
        int           c1 = __SBMD5HexDigitToInt([digestAsString characterAtIndex:i++]);
        int           c2 = __SBMD5HexDigitToInt([digestAsString characterAtIndex:i++]);
        unsigned char byte;
        
        if ( c1 < 0 || c2 < 0 )
          return NO;
        
        byte = c1 * 16 + c2;
        if ( byte != digestHash[j++] )
          return NO;
      }
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) md5DigestMatchesString:(SBString*)digestAsString
  {
    unsigned char   digestHash[16];
    
    if ( [digestAsString length] != 32 )
      return NO;
    
    if ( [self md5Digest:digestHash] ) {
      SBUInteger    i = 0, j = 0;
      
      while ( i < 32 ) {
        int           c1 = __SBMD5HexDigitToInt([digestAsString characterAtIndex:i++]);
        int           c2 = __SBMD5HexDigitToInt([digestAsString characterAtIndex:i++]);
        unsigned char byte;
        
        if ( c1 < 0 || c2 < 0 )
          return NO;
        
        byte = c1 * 16 + c2;
        if ( byte != digestHash[j++] )
          return NO;
      }
      return YES;
    }
    return NO;
  }

@end
