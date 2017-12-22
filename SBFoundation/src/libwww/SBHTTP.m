//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBHTTP.m
//
// Base inclusions for HTTP support.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBHTTP.h"
#import "SBDictionary.h"
#import "SBRegularExpression.h"

unsigned char __SBHTTPTokenChars[16] = { 0xff, 0xff, 0xff, 0xff, 0x05, 0x93, 0x00, 0xfc, 0x01, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0xa8 };

#define UCHAR(X)  (*((unsigned char*)X))

/*
 * The following table is used for URL encoding and decoding
 * all 256 characters.
 */

struct {
    int   hex;	    /* Valid hex value or -1. */
    int   len;	    /* Length required to encode string. */
    char *str;	    /* String for multibyte encoded character. */
} __urlencode_table[] = {
    {-1, 3, "%00"}, {-1, 3, "%01"}, {-1, 3, "%02"}, {-1, 3, "%03"}, 
    {-1, 3, "%04"}, {-1, 3, "%05"}, {-1, 3, "%06"}, {-1, 3, "%07"}, 
    {-1, 3, "%08"}, {-1, 3, "%09"}, {-1, 3, "%0a"}, {-1, 3, "%0b"}, 
    {-1, 3, "%0c"}, {-1, 3, "%0d"}, {-1, 3, "%0e"}, {-1, 3, "%0f"}, 
    {-1, 3, "%10"}, {-1, 3, "%11"}, {-1, 3, "%12"}, {-1, 3, "%13"}, 
    {-1, 3, "%14"}, {-1, 3, "%15"}, {-1, 3, "%16"}, {-1, 3, "%17"}, 
    {-1, 3, "%18"}, {-1, 3, "%19"}, {-1, 3, "%1a"}, {-1, 3, "%1b"}, 
    {-1, 3, "%1c"}, {-1, 3, "%1d"}, {-1, 3, "%1e"}, {-1, 3, "%1f"}, 
    {-1, 1, "+"},   {-1, 3, "%21"}, {-1, 3, "%22"}, {-1, 3, "%23"}, 
    {-1, 3, "%24"}, {-1, 3, "%25"}, {-1, 3, "%26"}, {-1, 3, "%27"}, 
    {-1, 3, "%28"}, {-1, 3, "%29"}, {-1, 3, "%2a"}, {-1, 3, "%2b"}, 
    {-1, 3, "%2c"}, {-1, 1, NULL}, {-1, 1, NULL}, {-1, 3, "%2f"}, 
    { 0, 1, NULL},  { 1, 1, NULL}, { 2, 1, NULL}, { 3, 1, NULL}, 
    { 4, 1, NULL},  { 5, 1, NULL}, { 6, 1, NULL}, { 7, 1, NULL}, 
    { 8, 1, NULL},  { 9, 1, NULL}, {-1, 3, "%3a"}, {-1, 3, "%3b"}, 
    {-1, 3, "%3c"}, {-1, 3, "%3d"}, {-1, 3, "%3e"}, {-1, 3, "%3f"}, 
    {-1, 3, "%40"}, {10, 1, NULL}, {11, 1, NULL}, {12, 1, NULL}, 
    {13, 1, NULL},  {14, 1, NULL}, {15, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 3, "%5b"}, 
    {-1, 3, "%5c"}, {-1, 3, "%5d"}, {-1, 3, "%5e"}, {-1, 1, NULL}, 
    {-1, 3, "%60"}, {10, 1, NULL}, {11, 1, NULL}, {12, 1, NULL}, 
    {13, 1, NULL},  {14, 1, NULL}, {15, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 1, NULL}, 
    {-1, 1, NULL},  {-1, 1, NULL}, {-1, 1, NULL}, {-1, 3, "%7b"}, 
    {-1, 3, "%7c"}, {-1, 3, "%7d"}, {-1, 3, "%7e"}, {-1, 3, "%7f"}, 
    {-1, 3, "%80"}, {-1, 3, "%81"}, {-1, 3, "%82"}, {-1, 3, "%83"}, 
    {-1, 3, "%84"}, {-1, 3, "%85"}, {-1, 3, "%86"}, {-1, 3, "%87"}, 
    {-1, 3, "%88"}, {-1, 3, "%89"}, {-1, 3, "%8a"}, {-1, 3, "%8b"}, 
    {-1, 3, "%8c"}, {-1, 3, "%8d"}, {-1, 3, "%8e"}, {-1, 3, "%8f"}, 
    {-1, 3, "%90"}, {-1, 3, "%91"}, {-1, 3, "%92"}, {-1, 3, "%93"}, 
    {-1, 3, "%94"}, {-1, 3, "%95"}, {-1, 3, "%96"}, {-1, 3, "%97"}, 
    {-1, 3, "%98"}, {-1, 3, "%99"}, {-1, 3, "%9a"}, {-1, 3, "%9b"}, 
    {-1, 3, "%9c"},  {-1, 3, "%9d"}, {-1, 3, "%9e"}, {-1, 3, "%9f"}, 
    {-1, 3, "%a0"},  {-1, 3, "%a1"}, {-1, 3, "%a2"}, {-1, 3, "%a3"}, 
    {-1, 3, "%a4"},  {-1, 3, "%a5"}, {-1, 3, "%a6"}, {-1, 3, "%a7"}, 
    {-1, 3, "%a8"},  {-1, 3, "%a9"}, {-1, 3, "%aa"}, {-1, 3, "%ab"}, 
    {-1, 3, "%ac"},  {-1, 3, "%ad"}, {-1, 3, "%ae"}, {-1, 3, "%af"}, 
    {-1, 3, "%b0"},  {-1, 3, "%b1"}, {-1, 3, "%b2"}, {-1, 3, "%b3"}, 
    {-1, 3, "%b4"},  {-1, 3, "%b5"}, {-1, 3, "%b6"}, {-1, 3, "%b7"}, 
    {-1, 3, "%b8"},  {-1, 3, "%b9"}, {-1, 3, "%ba"}, {-1, 3, "%bb"}, 
    {-1, 3, "%bc"},  {-1, 3, "%bd"}, {-1, 3, "%be"}, {-1, 3, "%bf"}, 
    {-1, 3, "%c0"},  {-1, 3, "%c1"}, {-1, 3, "%c2"}, {-1, 3, "%c3"}, 
    {-1, 3, "%c4"},  {-1, 3, "%c5"}, {-1, 3, "%c6"}, {-1, 3, "%c7"}, 
    {-1, 3, "%c8"},  {-1, 3, "%c9"}, {-1, 3, "%ca"}, {-1, 3, "%cb"}, 
    {-1, 3, "%cc"},  {-1, 3, "%cd"}, {-1, 3, "%ce"}, {-1, 3, "%cf"}, 
    {-1, 3, "%d0"},  {-1, 3, "%d1"}, {-1, 3, "%d2"}, {-1, 3, "%d3"}, 
    {-1, 3, "%d4"},  {-1, 3, "%d5"}, {-1, 3, "%d6"}, {-1, 3, "%d7"}, 
    {-1, 3, "%d8"},  {-1, 3, "%d9"}, {-1, 3, "%da"}, {-1, 3, "%db"}, 
    {-1, 3, "%dc"},  {-1, 3, "%dd"}, {-1, 3, "%de"}, {-1, 3, "%df"}, 
    {-1, 3, "%e0"},  {-1, 3, "%e1"}, {-1, 3, "%e2"}, {-1, 3, "%e3"}, 
    {-1, 3, "%e4"},  {-1, 3, "%e5"}, {-1, 3, "%e6"}, {-1, 3, "%e7"}, 
    {-1, 3, "%e8"},  {-1, 3, "%e9"}, {-1, 3, "%ea"}, {-1, 3, "%eb"}, 
    {-1, 3, "%ec"},  {-1, 3, "%ed"}, {-1, 3, "%ee"}, {-1, 3, "%ef"}, 
    {-1, 3, "%f0"},  {-1, 3, "%f1"}, {-1, 3, "%f2"}, {-1, 3, "%f3"}, 
    {-1, 3, "%f4"},  {-1, 3, "%f5"}, {-1, 3, "%f6"}, {-1, 3, "%f7"}, 
    {-1, 3, "%f8"},  {-1, 3, "%f9"}, {-1, 3, "%fa"}, {-1, 3, "%fb"}, 
    {-1, 3, "%fc"},  {-1, 3, "%fd"}, {-1, 3, "%fe"}, {-1, 3, "%ff"}
};

SBUInteger
__urlencode_preflight(
  SBString*   aString
)
{
  SBUInteger        altSize = 0;
  SBUInteger        i = 0, iMax = [aString length];
  UChar             c;
  
  /* Determine the required length for the encoded form: */
  while ( i < iMax ) {
    c = [aString characterAtIndex:i++];
    if ( c < 256 )
      altSize += __urlencode_table[c].len;
  }
  return altSize;
}

void
__urlencode(
  SBString*   aString,
  UChar*      buffer,
  SBUInteger  bufferLen
)
{
  SBUInteger        i = 0, iMax = [aString length];
  UChar             c;
  
  /* Go over the incoming string and write it into the buffer
     making substitutions as we go: */
  while ( bufferLen && (i < iMax) ) {
    c = [aString characterAtIndex:i++];
    if ( c < 256 ) {
      if ( __urlencode_table[c].str == NULL ) {
        *buffer++ = c;
        bufferLen--;
      } else {
        int         j = 0, jMax = __urlencode_table[c].len;
        char*       s = __urlencode_table[c].str;
        
        while ( j++ < jMax ) {
          *buffer++ = (UChar)*s++;
          bufferLen--;
        }
      }
    }
  }
}

SBUInteger
__urldecode_preflight(
  char*             cString,
  SBUInteger        cStringLen
)
{
  SBUInteger        altSize = 0;
  unsigned char     c;
  
  /* Determine the required length for the decoded form: */
  if ( cStringLen > 0 ) {
    while ( cStringLen && (c = UCHAR(cString)) != 0 ) {
      altSize++;
      cString++;
      cStringLen--;
      if ( c == '%' ) {
        /* We want a two-nibble hex value next: */
        if ( *cString && isxdigit(*cString) && *(cString + 1) && isxdigit(*(cString + 1)) ) {
          cString += 2;
          cStringLen -= 2;
        } else {
          return (SBUInteger)-1;
        }
      }
    }
  } else {
    while ( (c = UCHAR(cString)) != 0 ) {
      altSize++;
      cString++;
      if ( c == '%' ) {
        /* We want a two-nibble hex value next: */
        if ( *cString && isxdigit(*cString) && *(cString + 1) && isxdigit(*(cString + 1)) ) {
          cString += 2;
        } else {
          return (SBUInteger)-1;
        }
      }
    }
  }
  return altSize;
}

static inline int
__urldecode_charToInt(
  char      c
)
{
  return __urlencode_table[c].hex;
}

void
__urldecode(
  char*             cString,
  SBUInteger        cStringLen,
  char*             buffer,
  SBUInteger        bufferLen,
  BOOL              fromFormData
)
{
  unsigned char     c;
  
  /* Determine the required length for the decoded form: */
  if ( cStringLen > 0 ) {
    while ( cStringLen && bufferLen && ((c = UCHAR(cString)) != 0) ) {
      cString++;
      cStringLen--;
      if ( fromFormData && (c == '+') ) {
        c = ' ';
      }
      else if ( c == '%' ) {
        /* We only get called if the preflight was successful, so no
           reason to re-check whether what follows is a hex code or not! */
        c = __urldecode_charToInt(*cString) << 4 | __urldecode_charToInt(*(cString + 1));
        cString += 2;
        cStringLen -= 2;
      }
      *buffer++ = c;
      bufferLen--;
    }
  } else {
    while ( bufferLen && ((c = UCHAR(cString)) != 0) ) {
      cString++;
      if ( fromFormData && (c == '+') ) {
        c = ' ';
      }
      else if ( c == '%' ) {
        /* We only get called if the preflight was successful, so no
           reason to re-check whether what follows is a hex code or not! */
        c = __urldecode_charToInt(*cString) << 4 | __urldecode_charToInt(*(cString + 1));
        cString += 2;
      }
      *buffer++ = c;
      bufferLen--;
    }
  }
  *buffer = '\0';
}

//

SBUInteger
__urldecode_sbstring_preflight(
  SBString*         s
)
{
  SBUInteger        altSize = 0;
  SBUInteger        i = 0, iMax = [s length];
  
  /* Determine the required length for the decoded form: */
  while ( i < iMax ) {
    UChar           C = [s characterAtIndex:i++];
    
    altSize++;
    if ( C == '%' ) {
      UChar         H1, H2;
      
      if ( (iMax - i) < 2 )
        return (SBUInteger)-1;
      
      /* We want a two-nibble hex value next: */
      H1 = [s characterAtIndex:i++];
      H2 = [s characterAtIndex:i++];
      if ( ! isxdigit(H1) || ! isxdigit(H2) )
        return (SBUInteger)-1;
    } else if ( C > 127 ) {
      return (SBUInteger)-1;
    }
  }
  return altSize;
}

SBUInteger
__urldecode_sbstring(
  SBString*         s,
  char*             buffer,
  SBUInteger        bufferLen,
  BOOL              fromFormData
)
{
  SBUInteger        altLen = 0;
  SBUInteger        i = 0, iMax = [s length];

  while ( bufferLen && (i < iMax) ) {
    UChar           C = [s characterAtIndex:i++];
    
    if ( fromFormData && (C == '+') ) {
      C = ' ';
    }
    else if ( C == '%' ) {
      UChar         H1, H2;
      
      /* We only get called if the preflight was successful, so no
         reason to re-check whether what follows is a hex code or not! */
      H1 = [s characterAtIndex:i++];
      H2 = [s characterAtIndex:i++];
      C = __urldecode_charToInt(H1) << 4 | __urldecode_charToInt(H2);
    }
    *buffer++ = C;
    bufferLen--;
    altLen++;
  }
  return altLen;
}

//

struct {
  UChar       character;
  const char* substitute;
} __xmlsafe_table[] = {
  { (UChar)'"',  "&quot;" },
  { (UChar)'&',  "&amp;"   },
  { (UChar)'\'', "&apos;"  },
  { (UChar)'<',  "&lt;"    },
  { (UChar)'>',  "&gt;"    },
  { (UChar)0,    NULL      }
};

SBUInteger
__xmlsafe_preflight(
  SBString*   aString
)
{
  SBUInteger  i = 0, iMax = [aString length];
  SBUInteger  altLen = 0;
  
  while ( i < iMax ) {
    UChar     C = [aString characterAtIndex:i++];
    int       j = 0;
    int       addLen = 1;
    
    if ( C < 128 ) {
      while ( __xmlsafe_table[j].character ) {
        if (  __xmlsafe_table[j].character == C ) {
          addLen = strlen(__xmlsafe_table[j].substitute);
          break;
        }
        j++;
      }
    }
    altLen += addLen;
  }
  return altLen;
}

void
__xmlsafe(
  SBString*   aString,
  UChar*      buffer,
  SBUInteger  bufferLen
)
{
  SBUInteger        i = 0, iMax = [aString length];
  
  /* Go over the incoming string and write it into the buffer
     making substitutions as we go: */
  while ( bufferLen && (i < iMax) ) {
    UChar           C = [aString characterAtIndex:i++];
    BOOL            skip = NO;
    
    if ( C < 128 ) {
      int           j = 0;
      
      while ( __xmlsafe_table[j].character ) {
        if (  __xmlsafe_table[j].character == C ) {
          char*     s = (char*)__xmlsafe_table[j].substitute;
          
          while ( bufferLen && *s ) {
            *buffer++ = (UChar)*s;
            bufferLen--;
            s++;
          }
          skip = YES;
          break;
        }
        j++;
      }
    }
    if ( ! skip ) {
      *buffer++ = C;
      bufferLen--;
    }
  }
}

//

SBUInteger
__xmlsafe_preflight_cstring(
  const char*     aCString,
  SBUInteger      length
)
{
  unsigned char*  s = (unsigned char*)aCString;
  SBUInteger      i = 0, iMax = length;
  SBUInteger      altLen = 0;
  
  while ( i < iMax ) {
    unsigned char   c = aCString[i++];
    int             j = 0;
    int             addLen = 1;
    
    if ( c < 128 ) {
      while ( __xmlsafe_table[j].character ) {
        if (  __xmlsafe_table[j].character == c ) {
          addLen = strlen(__xmlsafe_table[j].substitute);
          break;
        }
        j++;
      }
    }
    altLen += addLen;
  }
  return altLen;
}

void
__xmlsafe_cstring(
  const char*   aCString,
  SBUInteger    length,
  char*         buffer,
  SBUInteger    bufferLen
)
{
  unsigned char*    s = (unsigned char*)aCString;
  SBUInteger        i = 0, iMax = length;
  
  /* Go over the incoming string and write it into the buffer
     making substitutions as we go: */
  while ( bufferLen && (i < iMax) ) {
    unsigned char   c = aCString[i++];
    BOOL            skip = NO;
    
    if ( c < 128 ) {
      int           j = 0;
      
      while ( __xmlsafe_table[j].character ) {
        if (  __xmlsafe_table[j].character == c ) {
          char*     s = (char*)__xmlsafe_table[j].substitute;
          
          while ( bufferLen && *s ) {
            *buffer++ = *s++;
            bufferLen--;
          }
          skip = YES;
          break;
        }
        j++;
      }
    }
    if ( ! skip ) {
      *buffer++ = c;
      bufferLen--;
    }
  }
}

//

@implementation SBString(SBHTTPAdditions)

  + (id) stringWithURLEncodedString:(SBString*)aString
  {
    return [self stringWithURLEncodedString:aString fromFormData:NO];
  }
  + (id) stringWithURLEncodedString:(SBString*)aString
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_sbstring_preflight(aString);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize];
      
      decodeSize = __urldecode_sbstring(aString, decoded, decodeSize, fromFormData);
      if ( decodeSize != (SBUInteger)-1 )
        return [SBString stringWithUTF8String:decoded length:decodeSize];
    }
    return nil;
  }

//

  + (id) stringWithURLEncodedUTF8String:(const char*)cString
  {
    return [self stringWithURLEncodedUTF8String:cString fromFormData:NO];
  }
  + (id) stringWithURLEncodedUTF8String:(const char*)cString
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_preflight((char*)cString, 0);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __urldecode((char*)cString, 0, decoded, decodeSize, fromFormData);
      return [SBString stringWithUTF8String:decoded];
    }
    return nil;
  }

//

  + (id) stringWithURLEncodedUTF8String:(const char*)cString
    length:(SBUInteger)length
  {
    return [self stringWithURLEncodedUTF8String:cString length:length fromFormData:NO];
  }
  + (id) stringWithURLEncodedUTF8String:(const char*)cString
    length:(SBUInteger)length
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_preflight((char*)cString, length);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __urldecode((char*)cString, length, decoded, decodeSize, fromFormData);
      return [SBString stringWithUTF8String:decoded];
    }
    return nil;
  }
  
//
  
  - (id) initWithURLEncodedString:(SBString*)aString
  {
    return [self initWithURLEncodedString:aString fromFormData:NO];
  }
  - (id) initWithURLEncodedString:(SBString*)aString
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_sbstring_preflight(aString);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize];
      
      decodeSize = __urldecode_sbstring(aString, decoded, decodeSize, fromFormData);
      if ( decodeSize != (SBUInteger)-1 )
        return [self initWithUTF8String:decoded length:decodeSize];
    }
    [self release];
    return nil;
  }
  
//
    
  - (id) initWithURLEncodedUTF8String:(const char*)cString
  {
    return [self initWithURLEncodedUTF8String:cString fromFormData:NO];
  }
  - (id) initWithURLEncodedUTF8String:(const char*)cString
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_preflight((char*)cString, 0);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __urldecode((char*)cString, 0, decoded, decodeSize, fromFormData);
      return [self initWithUTF8String:decoded];
    }
    [self release];
    return nil;
  }
  
//
    
  - (id) initWithURLEncodedUTF8String:(const char*)cString
    length:(SBUInteger)length
  {
    return [self initWithURLEncodedUTF8String:cString length:length fromFormData:NO];
  }
  - (id) initWithURLEncodedUTF8String:(const char*)cString
    length:(SBUInteger)length
    fromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_preflight((char*)cString, length);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __urldecode((char*)cString, length, decoded, decodeSize, fromFormData);
      return [self initWithUTF8String:decoded];
    }
    [self release];
    return nil;
  }
  
//

  + (id) stringWithXMLSafeUTF8String:(const char*)cString
  {
    return [self stringWithXMLSafeUTF8String:cString length:(cString ? strlen(cString) : 0)];
  }
  
//

  + (id) stringWithXMLSafeUTF8String:(const char*)cString
    length:(SBUInteger)length
  {
    SBUInteger  decodeSize = __xmlsafe_preflight_cstring((char*)cString, length);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __xmlsafe_cstring((const char*)cString, length, decoded, decodeSize);
      return [SBString stringWithUTF8String:decoded];
    }
    return nil;
  }
  
//

  - (id) initWithXMLSafeUTF8String:(const char*)cString
  {
    return [self initWithXMLSafeUTF8String:cString length:(cString ? strlen(cString) : 0)];
  }
  
//

  - (id) initWithXMLSafeUTF8String:(const char*)cString
    length:(SBUInteger)length
  {
    SBUInteger  decodeSize = __xmlsafe_preflight_cstring((char*)cString, length);
    
    if ( decodeSize != (SBUInteger)-1 ) {
      char      decoded[decodeSize + 1];
      
      __xmlsafe_cstring((const char*)cString, length, decoded, decodeSize);
      return [self initWithUTF8String:decoded];
    }
    return [self init];
  }

//

  - (SBString*) decodeURLEncodedString
  {
    return [self decodeURLEncodedStringFromFormData:NO];
  }
  - (SBString*) decodeURLEncodedStringFromFormData:(BOOL)fromFormData
  {
    SBUInteger  decodeSize = __urldecode_sbstring_preflight(self);
    
    if ( decodeSize == (SBUInteger)-1 )
      return nil;
    
    if ( decodeSize < [self length] ) {
      char      decoded[decodeSize];
      
      decodeSize = __urldecode_sbstring(self, decoded, decodeSize, fromFormData);
      if ( decodeSize != (SBUInteger)-1 )
        return [SBString stringWithUTF8String:decoded length:decodeSize];
    } else {
      return self;
    }
    return nil;
  }

//

  - (SBString*) urlEncodedString
  {
    SBUInteger  encodeSize = __urlencode_preflight(self);
    
    if ( encodeSize > 0 ) {
      if ( encodeSize == [self utf8Length] ) {
        return [[self copy] autorelease];
      } else {
        UChar     encoded[encodeSize];
        
        __urlencode(self, encoded, encodeSize);
        return [SBString stringWithCharacters:encoded length:encodeSize];
      }
    }
    return nil;
  }

//

  - (SBString*) xmlSafeString
  {
    SBUInteger  origSize = [self length];
    SBUInteger  encodeSize = __xmlsafe_preflight(self);
    
    if ( encodeSize > 0 ) {
      if ( encodeSize == origSize ) {
        return [[self copy] autorelease];
      } else {
        UChar     encoded[encodeSize];
        
        __xmlsafe(self, encoded, encodeSize);
        return [SBString stringWithCharacters:encoded length:encodeSize];
      }
    }
    return nil;
  }
  
//

  - (SBString*) normalizedHTTPToken
  {
    SBUInteger    i = 0, iMax = [self length];
    
    if ( iMax ) {
      SBUInteger  j = 0;
      BOOL        isModified = NO;
      BOOL        needCaps = YES;
      char        normalized[iMax + 1];
      
      while ( i < iMax ) {
        UChar     c = [self characterAtIndex:i++];
        
        if ( c < 128 ) {
          if ( __SBHTTPTokenChars[ c / 8 ] & (1 << (c % 8)) ) {
            isModified = YES;
          } else {
            if ( needCaps ) {
              if ( c >= 'a' && c <= 'z' ) {
                c -= 'a' - 'A';
                isModified = YES;
              }
              needCaps = NO;
            } else if ( c == '-' ) {
              needCaps = YES;
            } else if ( c >= 'A' && c <= 'Z' ) {
              c += 'a' - 'A';
              isModified = YES;
            }
            normalized[j++] = c;
          }
        } else {
          isModified = YES;
        }
      }
      if ( ! isModified )
        return self;
      if ( j ) {
        normalized[j++] = '\0';
        return [SBString stringWithUTF8String:normalized];
      }
    }
    return nil;
  }

@end

@implementation SBMutableString(SBHTTPAdditions)

  - (void) urlEncodeAndAppendString:(SBString*)aString
  {
    SBUInteger  encodeSize = __urlencode_preflight(aString);
    
    if ( encodeSize > 0 ) {
      UChar     encoded[encodeSize];
      
      __urlencode(aString, encoded, encodeSize);
      [self appendCharacters:encoded length:encodeSize];
    }
  }

//

  - (void) makeXMLSafeAndAppendString:(SBString*)aString
  {
    SBUInteger  origSize = [aString length];
    SBUInteger  encodeSize = __xmlsafe_preflight(aString);
    
    if ( encodeSize > 0 ) {
      if ( encodeSize == origSize ) {
        return [self appendString:aString];
      } else {
        UChar     encoded[encodeSize];
        
        __xmlsafe(self, encoded, encodeSize);
        [self appendCharacters:encoded length:encodeSize];
      }
    }
  }

@end

//
#pragma mark -
//

static SBRegularExpression*
__SBMIMETypeGetPrimaryRegex(void)
{
  static SBRegularExpression* mimePrimaryRegex = nil;
  
  if ( ! mimePrimaryRegex ) {
    mimePrimaryRegex = [[SBRegularExpression alloc] initWithString:@"^\\s*([^/]+)/([^\t\n\f\r\\p{Z};]+)"];
  }
  return mimePrimaryRegex;
}

static SBRegularExpression*
__SBMIMETypeGetParameterRegex(void)
{
  static SBRegularExpression* mimeParameterRegex = nil;
  
  if ( ! mimeParameterRegex ) {
    mimeParameterRegex = [[SBRegularExpression alloc] initWithString:@"\\s*([^\x01-\x1A ()<>@,;:\\\"/\\[\\]?=]+)="];
  }
  return mimeParameterRegex;
}

//

@implementation SBMIMEType

  + (SBMIMEType*) mimeTypeWithString:(SBString*)mimeString
  {
    return [[[SBMIMEType alloc] initWithString:mimeString] autorelease];
  }
  
//

  - (id) initWithString:(SBString*)mimeString
  {
    if ( (self = [super init]) ) {
      BOOL      okay = NO;
      
      if ( mimeString ) {
        SBRegularExpression*    primary = __SBMIMETypeGetPrimaryRegex();
        
        if ( primary ) {
          [primary setSubjectString:mimeString];
          if ( [primary isPartialMatch] ) {
            _mediaType = [[[primary stringForMatchingGroup:1] lowercaseString] retain];
            _mediaSubType = [[[primary stringForMatchingGroup:2] lowercaseString] retain];
            if ( _mediaType && _mediaSubType ) {
              SBRegularExpression*  param = __SBMIMETypeGetParameterRegex();
              SBRange               match = [primary rangeOfMatch];
              SBUInteger            iMax = [mimeString length];
              SBMutableDictionary*  params = nil;
              
              // Type and subtype were at least okay:
              okay = YES;
              
              // Now try processing parameters:
              [param setSubjectString:mimeString];
              [param setMatchingRange:SBRangeCreate(SBRangeMax(match), [mimeString length] - SBRangeMax(match))];
              while ( [param findNextMatch] ) {
                SBString*           key = [[mimeString substringWithRange:[param rangeOfMatchingGroup:1]] normalizedHTTPToken];
                SBUInteger          i;
                SBString*           value = nil;
                
                SBRange  r = [param rangeOfMatch];
                
                // Full range includes the "=" sign; we need to isolate the value thereafter:
                if ( (i = SBRangeMax([param rangeOfMatch])) < iMax ) {
                  UChar             C = [mimeString characterAtIndex:i];
                  
                  if ( C == '"' ) {
                    BOOL              sawSlash = NO;
                    SBMutableString*  accum = [[SBMutableString alloc] init];
                    
                    // Quoted string:
                    i++;
                    while ( i < iMax ) {
                      C = [mimeString characterAtIndex:i++];
                      if ( C > 127 || C == '\r' )
                        break;
                      if ( C == '"' && ! sawSlash )
                        break;
                      if ( C == '\\' && ! sawSlash ) {
                        sawSlash = YES;
                      } else {
                        sawSlash = NO;
                        [accum appendCharacters:&C length:1];
                      }
                    }
                    value = [accum copy];
                    [accum release];
                  } else {
                    // Scan-in all token characters:
                    SBCharacterSet*   tokenChars = [SBCharacterSet httpTokenCharacterSet];
                    SBUInteger        start = i;
                    
                    if ( [tokenChars utf16CharacterIsMember:C] ) {
                      while ( ++i < iMax ) {
                        C = [mimeString characterAtIndex:i];
                        if ( ! [tokenChars utf16CharacterIsMember:C] )
                          break;
                      }
                      value = [mimeString substringWithRange:SBRangeCreate(start, i - start)];
                    }
                  }
                }
                if ( ! params )
                  params = [[SBMutableDictionary alloc] init];
                if ( params ) {
                  // Add a NULL for a non-valued key:
                  [params setObject:( value ? (id)value : (id)[SBNull null] ) forKey:key];
                }
                if ( i >= iMax )
                  break;
                  
                [param setMatchingRange:SBRangeCreate(i, iMax - i)];
              }
              if ( params ) {
                _parameters = [params copy];
                [params release];
              }
              [param setSubjectString:nil];
            }
          }
          [primary setSubjectString:nil];
        }
      }
      if ( ! okay ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _mediaType ) [_mediaType release];
    if ( _mediaSubType ) [_mediaSubType release];
    if ( _parameters ) [_parameters release];
    
    [super dealloc];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, "{ ");
    if ( _mediaType && _mediaSubType ) {
      [_mediaType writeToStream:stream];
      fputc('/', stream);
      [_mediaSubType writeToStream:stream];
    }
    if ( _parameters ) {
      fprintf(stream, "\n  parameters = ");
      [_parameters summarizeToStream:stream];
      fputc('\n', stream);
    }
    fprintf(stream, " }");
  }

//

  - (SBString*) mediaType
  {
    return _mediaType;
  }

//

  - (SBString*) mediaSubType
  {
    return _mediaSubType;
  }

//

  - (SBDictionary*) parameters
  {
    return _parameters;
  }
  - (SBString*) parameterForName:(SBString*)parameterName
  {
    if ( _parameters )
      return [_parameters objectForKey:[parameterName normalizedHTTPToken]];
    return nil;
  }

@end

//

@implementation SBCharacterSet(SBHTTPAdditions)

  + (SBCharacterSet*) httpTokenCharacterSet
  {
    static SBCharacterSet* __httpTokenCharacterSet = nil;
    
    if ( ! __httpTokenCharacterSet ) {
      SBMutableCharacterSet*    tmpSet = [[SBMutableCharacterSet alloc] init];
      int                       i = 0;
      
      while ( i < 128 ) {
        if ( ! (__SBHTTPTokenChars[i / 8] & (1 << (i % 8))) )
          [tmpSet addCharactersInRange:SBRangeCreate(i, 1)];
        i++;
      }
      __httpTokenCharacterSet = [tmpSet copy];
      [tmpSet release];
    }
    return __httpTokenCharacterSet;
  }

@end
