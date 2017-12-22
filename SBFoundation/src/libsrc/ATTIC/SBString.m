//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBString.m
//
// Unicode string class
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBString.h"
#import "SBData.h"
#import "SBLocale.h"
#import "SBCharacterSet.h"
#import "SBCharacterSetPrivate.h"

#include "unicode/ustring.h"
#include "unicode/ustdio.h"
#include "unicode/uset.h"

//

#include "unicode/ucnv.h"

@interface SBUnicodeConverter : SBObject
{
  UConverter*     _icuConverter;
}

- (id) initWithCharacterSetName:(const char*)charSetName;
- (id) initWithCCSID:(int)codepage platform:(UConverterPlatform)platform;

- (const char*) converterName;
- (int) converterCCSID;
- (UConverterPlatform) converterPlatform;
- (UConverterType) converterType;

- (BOOL) preflightConvertFromBytes:(const void*)bytes byteCount:(int)byteCount charCount:(int*)charCount;
- (BOOL) preflightConvertFromChars:(const UChar*)chars charCount:(int)charCount byteCount:(int*)byteCount;

- (BOOL) convertToChars:(UChar*)chars charCount:(int)charCount fromBytes:(const void*)bytes byteCount:(int)byteCount;
- (BOOL) convertToBytes:(void*)bytes byteCount:(int)byteCount fromChars:(const UChar*)chars charCount:(int)charCount actualByteCount:(int*)actualByteCount;

@end

//
#pragma mark -
//

@implementation SBUnicodeConverter

  - (id) initWithCharacterSetName:(const char*)charSetName
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _icuConverter = ucnv_open(charSetName, &icuErr);
      if ( icuErr ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithCCSID:(int)codepage
    platform:(UConverterPlatform)platform
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _icuConverter = ucnv_openCCSID(codepage, platform, &icuErr);
      if ( icuErr ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _icuConverter ) ucnv_close(_icuConverter);
    [super dealloc];
  }

//

  - (const char*) converterName
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return ucnv_getName(_icuConverter, &icuErr);
  }
  
//

  - (int) converterCCSID
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return (int)ucnv_getCCSID(_icuConverter, &icuErr);
  }
  
//

  - (UConverterPlatform) converterPlatform
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    return ucnv_getPlatform(_icuConverter, &icuErr);
  }
  
//
  - (UConverterType) converterType
  {
    return ucnv_getType(_icuConverter);
  }

//

  - (BOOL) preflightConvertFromBytes:(const void*)bytes
    byteCount:(int)byteCount
    charCount:(int*)charCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           count;
    
    ucnv_resetToUnicode(_icuConverter);
    
    count = ucnv_toUChars(_icuConverter, NULL, 0, bytes, byteCount, &icuErr);
    if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
      *charCount = count;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) preflightConvertFromChars:(const UChar*)chars
    charCount:(int)charCount
    byteCount:(int*)byteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           count;
    
    ucnv_resetFromUnicode(_icuConverter);
    
    count = ucnv_fromUChars(_icuConverter, NULL, 0, chars, charCount, &icuErr);
    if ( icuErr == U_BUFFER_OVERFLOW_ERROR ) {
      *byteCount = count;
      return YES;
    }
    return NO;
  }

//

  - (BOOL) convertToChars:(UChar*)chars
    charCount:(int)charCount
    fromBytes:(const void*)bytes
    byteCount:(int)byteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    
    ucnv_resetToUnicode(_icuConverter);
    ucnv_toUChars(_icuConverter, chars, charCount, bytes, byteCount, &icuErr);
    return ( (icuErr == 0) ? YES : NO );
  }
  
//

  - (BOOL) convertToBytes:(void*)bytes
    byteCount:(int)byteCount
    fromChars:(const UChar*)chars
    charCount:(int)charCount
    actualByteCount:(int*)actualByteCount
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int           outByteCount;
    
    ucnv_resetFromUnicode(_icuConverter);
    outByteCount = (int)ucnv_fromUChars(_icuConverter, bytes, byteCount, chars, charCount, &icuErr);
    if ( U_SUCCESS(icuErr) ) {
      *actualByteCount = outByteCount;
      return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

@interface SBString(SBStringPrivate)

- (id) initWithByteCapacity:(size_t)byteCapacity;
- (size_t) byteLength;
- (BOOL) growToByteLength:(size_t)newSize;

- (void) replaceCharactersInRange:(SBRange)range withCharacters:(UChar*)altChars length:(size_t)altLen;

@end

@implementation SBString(SBStringPrivate)

  - (id) initWithByteCapacity:(size_t)byteCapacity
  {
    if ( self = [super init] ) {
      if ( ! [self growToByteLength:byteCapacity] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (size_t) byteLength
  {
    return _byteLength;
  }
  
//

  - (BOOL) growToByteLength:(size_t)newSize
  {
    UChar*      p = NULL;
    
    //
    // We account for the possible need for the NUL character (for using u_sprintf, e.g.) by
    // always over-allocating by a single UChar.
    // 
    if ( _u16Chars ) {
      if ( ( p = (UChar*) realloc(_u16Chars, newSize + sizeof(UChar)) ) ) {
        // Make sure we zero-out the added bytes:
        memset(p + _byteLength, 0, (newSize + sizeof(UChar)) - _byteLength);
      }
    } else {
      p = (UChar*) calloc(1, newSize + sizeof(UChar));
    }
    if ( p ) {
      _u16Chars = p;
      _byteLength = newSize;
      return YES;
    }
    return NO;
  }

//

  - (void) replaceCharactersInRange:(SBRange)range
    withCharacters:(UChar*)altChars
    length:(size_t)altLen
  {
    if ( _u16Chars ) {
      size_t          newLen = _charLength - (range.length - altLen);
      unsigned int    end = SBRangeMax(range);
      
      //
      // If we're replacing with MORE characters than the buffer will hold,
      // then we need to resize the buffer.  Otherwise, we're merely doing
      // a memmove and (possibly) a memcpy.
      //
      if ( (range.length  >= altLen) || (_byteLength >= newLen * sizeof(UChar)) ) {
        // Shift some data:
        if ( range.length > altLen )
          u_memmove(_u16Chars + range.start + altLen, _u16Chars + end, _charLength - end + 1);
        
        // Copy-in the new characters:
        if ( altLen )
          u_memcpy(_u16Chars + range.start, altChars, altLen);
        
        // Done, reset flags accordingly:
        _charLength = newLen;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      } else if ( [self growToByteLength:newLen * sizeof(UChar)] ) {
        // Move data up off the original end to make room for the incoming
        // chars:
        u_memmove(_u16Chars + range.start + altLen, _u16Chars + end, _charLength - end + 1);
        
        // Insert the new chars:
        if ( altLen )
          u_memcpy(_u16Chars + range.start, altChars, altLen);
        
        // Done, reset flags accordingly:
        _charLength = newLen;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      }
      
    } else if ( altChars && altLen ) {
      //
      // We don't yet have a buffer, so just make a duplicate copy of aString
      // and reset all flags accordingly:
      //
      if ( [self growToByteLength:altLen * sizeof(UChar)] ) {
        u_memcpy(_u16Chars, altChars, altLen);
        _charLength = altLen;
        if ( _u8Chars ) {
          [_u8Chars release];
          _u8Chars = nil;
        }
        _flags.hashCalculated = NO;
      }
    }
  }

@end

//
#pragma mark -
//

static UFILE* __SBStringStdout = NULL;

@implementation SBString

  + initialize
  {
    if ( ! __SBStringStdout ) {
      __SBStringStdout = u_finit(stdout, NULL, "UTF-8");
    }
  }

//

  + (SBString*) emptyString
  {
    static SBString* sharedEmptyInstance = nil;
    
    if ( sharedEmptyInstance == nil )
      sharedEmptyInstance = [[SBString alloc] initWithUTF8String:""];
    return sharedEmptyInstance;
  }
  
//

  + (SBString*) string
  {
    return [[[SBString alloc] init] autorelease];
  }
  
//

  + (SBString*) stringWithUTF8String:(const char*)cString
  {
    return [[[SBString alloc] initWithUTF8String:cString] autorelease];
  }
  
//

  + (SBString*) stringWithCharacters:(UChar*)characters
    length:(int)length
  {
    return [[[SBString alloc] initWithCharacters:characters length:length] autorelease];
  }
  
//

  + (SBString*) stringWithString:(SBString*)aString
  {
    return [[[SBString alloc] initWithString:aString] autorelease];
  }

//

  + (SBString*) stringWithFormat:(const char*)format,...
  {
    SBString*   newObj = nil;
    va_list     vargs;
    
    va_start(vargs, format);
    newObj = [[[SBString alloc] initWithFormat:format arguments:vargs] autorelease];
    va_end(vargs);
    
    return newObj;
  }

//

  + (SBString*) stringWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    return [[[SBString alloc] initWithBytes:bytes count:count encoding:encoding] autorelease];
  }

//

  - (id) initWithUTF8String:(const char*)cString
  {
    if ( self = [super init] ) {
      UErrorCode    uerr = U_ZERO_ERROR;
      int32_t       u16Count = 0;
      
      // Count the UTF16 characters in the string:
      u_strFromUTF8(NULL, 0, &u16Count, cString, -1, &uerr);
      if ( u16Count ) {
        // Grow to the required capacity:
        if ( ! [self growToByteLength:u16Count * sizeof(UChar)] ) {
          [self release];
          self = nil;
        } else {
          uerr = 0;
          u_strFromUTF8(
              _u16Chars,
              u16Count,
              NULL,
              cString,
              -1,
              &uerr
            );
          if ( ! U_SUCCESS(uerr) ) {
            [self release];
            self = nil;
          } else {
            _charLength = u16Count;
          }
        }
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithCharacters:(UChar*)characters
    length:(int)length
  {
    if ( self = [super init] ) {
      if ( characters && length ) {
        if ( ! [self growToByteLength:length * sizeof(UChar)] ) {
          [self release];
          self = nil;
        } else {
          u_strncpy(_u16Chars, characters, length);
          _charLength = length;
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithString:(SBString*)aString
  {
    return [self initWithCharacters:(UChar*)[aString utf16Characters] length:[aString length]];
  }

//

  - (id) initWithFormat:(const char*)format,...
  {
    va_list     vargs;
    
    va_start(vargs, format);
    self = [self initWithFormat:format arguments:vargs];
    va_end(vargs);
    return self;
  }
  
//

  - (id) initWithFormat:(const char*)format
    arguments:(va_list)argList
  {
    if ( self = [super init] ) {
      int32_t         charLen;
      
      if ( format && (charLen = strlen(format)) ) {
        va_list       vargs;
        
        do {
          int32_t     actLen;
          
          if ( ! [self growToByteLength:sizeof(UChar) * charLen] ) {
            [self release];
            return nil;
          }
          va_copy(vargs, argList);
          actLen = u_vsnprintf(
                      _u16Chars,
                      charLen,
                      format,
                      vargs
                    );
          if ( (actLen < 0) || (actLen == charLen) ) {
            charLen += 8;
          } else {
            _charLength = actLen;
            break;
          }
        } while (1);
      }
    }
    return self;
  }
  
//

  - (id) initWithBytes:(const void*)bytes
    count:(int)count
    encoding:(const char*)encoding
  {
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    
    if ( converter ) {
      if ( self = [super init] ) {
        int       requiredChars;
        
        if ( [converter preflightConvertFromBytes:bytes byteCount:count charCount:&requiredChars] && [self growToByteLength:requiredChars * sizeof(UChar)] ) {
          if ( [converter convertToChars:_u16Chars charCount:requiredChars + 1 fromBytes:bytes byteCount:count] ) {
            _charLength = requiredChars;
          } else {
            [self release];
            self = nil;
          }
        } else {
          [self release];
          self = nil;
        }
      }
      [converter release];
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _u8Chars )
      [_u8Chars release];
    if ( _u16Chars )
      free(_u16Chars);
    [super dealloc];
  }

//

  - (unsigned int) hash
  {
    if ( ! _flags.hashCalculated ) {
      if ( (_charLength > 0) && _u16Chars )
        _storedHash = [self hashForData:_u16Chars byteLength:sizeof(UChar) * _charLength];
      else
        _storedHash = 0x80808080;
      _flags.hashCalculated = YES;
    }
    return _storedHash;
  }

//

  - (id) copy
  {
    return [[SBString alloc] initWithString:self];
  }

//

  - (const UChar*) utf16Characters
  {
    return _u16Chars;
  }

//

  - (size_t) length
  {
    return _charLength;
  }

//

  - (size_t) utf8Length
  {
    if ( _u16Chars && _charLength ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF8WithSub(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _charLength,
          (UChar32)0xFFFD,
          NULL,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr = U_BUFFER_OVERFLOW_ERROR) )
        return reqLength;
    }
    return 0;
  }

//

  - (size_t) utf32Length
  {
    if ( _u16Chars && _charLength ) {
      UErrorCode              uerr = U_ZERO_ERROR;
      int32_t                 reqLength = 0;
      
      u_strToUTF32(
          NULL,
          0,
          &reqLength,
          _u16Chars,
          _charLength,
          &uerr
        );
      if ( U_SUCCESS(uerr) || (uerr = U_BUFFER_OVERFLOW_ERROR) )
        return reqLength;
    }
    return 0;
  }

//

  - (UChar) characterAtIndex:(int)index
  {
    if ( _u16Chars )
      return _u16Chars[index];
    return (UChar)0;
  }

//

  - (UChar32) utf32CharacterAtIndex:(int)index
  {
    UChar32     c = 0xFFFFFFFF;
    
    if ( _u16Chars ) {
      UChar*    s = _u16Chars;
      int32_t   i = 0,j = 0;
      
      while ( i < _charLength ) {
        U16_NEXT(s, i, _charLength, c);
        if ( j == index )
          break;
        j++;
      }
      if ( j != index )
        c = 0xFFFFFFFF;
    }
    return c;
  }

//


  - (SBString*) uppercaseString
  {
    return [self uppercaseStringWithLocale:nil];
  }
  - (SBString*) uppercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _charLength ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToUpper(
                    NULL,
                    0,
                    _u16Chars,
                    _charLength,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBString alloc] initWithByteCapacity:sizeof(UChar) * actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToUpper(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _charLength,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//


  - (SBString*) lowercaseString
  {
    return [self lowercaseStringWithLocale:nil];
  }
  - (SBString*) lowercaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _charLength ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToLower(
                    NULL,
                    0,
                    _u16Chars,
                    _charLength,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBString alloc] initWithByteCapacity:sizeof(UChar) * actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToLower(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _charLength,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (SBString*) titlecaseString
  {
    return [self titlecaseStringWithLocale:nil];
  }
  - (SBString*) titlecaseStringWithLocale:(SBLocale*)locale
  {
    SBString*   result = nil;
    
    if ( _u16Chars && _charLength ) {
      int32_t     actLen = 0;
      UErrorCode  uerr = U_ZERO_ERROR;
      
      actLen = u_strToTitle(
                    NULL,
                    0,
                    _u16Chars,
                    _charLength,
                    NULL,
                    ( locale ? [locale localeIdentifier] : NULL ),
                    &uerr
                  );
      if ( actLen && (uerr == U_BUFFER_OVERFLOW_ERROR) ) {
        result = [[SBString alloc] initWithByteCapacity:sizeof(UChar) * actLen];
        if ( result ) {
          uerr = U_ZERO_ERROR;
          u_strToTitle(
              (UChar*)[result utf16Characters],
              actLen + 1,
              _u16Chars,
              _charLength,
              NULL,
              ( locale ? [locale localeIdentifier] : NULL ),
              &uerr
            );
          if ( U_SUCCESS(uerr) ) {
            result = [result autorelease];
          } else {
            [result release];
            result = nil;
          }
        }
      }
    }
    return result;
  }

//

  - (const unsigned char*) utf8Characters
  {
    unsigned char*      buffer = "";
    
    if ( ! _u8Chars ) {      
      if ( _u16Chars && _charLength ) {
        UErrorCode              uerr = U_ZERO_ERROR;
        int32_t                 reqLength = 0;
        
        u_strToUTF8(
            NULL,
            0,
            &reqLength,
            _u16Chars,
            _charLength,
            &uerr
          );
        if ( reqLength ) {
          _u8Chars = [[SBData alloc] initWithCapacity:++reqLength];
          
          if ( _u8Chars ) {
            uerr = 0;
            u_strToUTF8(
                buffer = (unsigned char*)[_u8Chars bytes],
                reqLength,
                &reqLength,
                _u16Chars,
                _charLength,
                &uerr
              );
          }
        }
      }
    } else {
      buffer = (unsigned char*)[_u8Chars bytes];
    }
    return buffer;
  }

//

  - (BOOL) copyUTF8CharactersToBuffer:(unsigned char*)buffer
    length:(size_t)length
  {
    if ( _u16Chars && _charLength ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF8WithSub(
        (char*)buffer,
        length,
        NULL,
        _u16Chars,
        _charLength,
        (UChar32)0xFFFD,
        NULL,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return YES;
    }
    return NO;
  }

//


  - (BOOL) copyUTF32CharactersToBuffer:(UChar32*)buffer
    length:(size_t)length
  {
    if ( _u16Chars && _charLength ) {
      UErrorCode        uerr = U_ZERO_ERROR;
      
      u_strToUTF32(
        (UChar32*)buffer,
        length,
        NULL,
        _u16Chars,
        _charLength,
        &uerr
      );
      if ( U_SUCCESS(uerr) || (uerr == U_BUFFER_OVERFLOW_ERROR) )
        return YES;
    }
    return NO;
  }

//

  - (SBData*) dataUsingEncoding:(const char*)encoding
  {
    SBUnicodeConverter*     converter = [[SBUnicodeConverter alloc] initWithCharacterSetName:encoding];
    SBData*                 byteStream = nil;
    
    if ( converter ) {
      int       requiredBytes;
      
      if ( [converter preflightConvertFromChars:_u16Chars charCount:_charLength byteCount:&requiredBytes] ) {
        void*   bytes = NULL;
        
        // Allow a little bit of wiggle room on the buffer size:
        requiredBytes += 4;
        bytes = malloc(requiredBytes);
        
        if ( bytes ) {
          if ( [converter convertToBytes:bytes byteCount:requiredBytes fromChars:_u16Chars charCount:_charLength actualByteCount:&requiredBytes] ) {
            byteStream = [SBData dataWithBytesNoCopy:bytes length:requiredBytes];
          } else {
            free(bytes);
          }
        }
      }
      [converter release];
    }
    return byteStream;
  }

//

  - (SBComparisonResult) compareToString:(SBString*)aString
  {
    const UChar*      altCharacters = [aString utf16Characters];
    int               altLength = [aString length];
    int32_t           cmp;
    
    if ( (altCharacters == NULL) || (altLength == 0) ) {
      if ( (_u16Chars == NULL) || (_charLength == 0) )
        return SBOrderSame;
      else
        return SBOrderDescending;
    }
    if ( (_u16Chars == NULL) || (_charLength == 0) )
      return SBOrderAscending;
    
    if ( altLength > _charLength ) {
      return SBOrderAscending;
    }
    if ( altLength < _charLength ) {
      return SBOrderDescending;
    }
    cmp = u_strncmpCodePointOrder(
              _u16Chars,
              altCharacters,
              _charLength
            );
    if ( cmp == 0 )
      return SBOrderSame;
    if ( cmp < 0 )
      return SBOrderDescending;
    return SBOrderAscending;
  }

//

  - (SBComparisonResult) caselessCompareToString:(SBString*)aString
  {
    const UChar*      altCharacters = [aString utf16Characters];
    int               altLength = [aString length];
    int32_t           cmp;
    
    if ( (altCharacters == NULL) || (altLength == 0) ) {
      if ( (_u16Chars == NULL) || (_charLength == 0) )
        return SBOrderSame;
      else
        return SBOrderDescending;
    }
    if ( (_u16Chars == NULL) || (_charLength == 0) )
      return SBOrderAscending;
    
    if ( altLength > _charLength ) {
      return SBOrderAscending;
    }
    if ( altLength < _charLength ) {
      return SBOrderDescending;
    }
    cmp = u_strncasecmp(
              _u16Chars,
              altCharacters,
              _charLength,
              U_COMPARE_CODE_POINT_ORDER
            );
    if ( cmp == 0 )
      return SBOrderSame;
    if ( cmp < 0 )
      return SBOrderDescending;
    return SBOrderAscending;
  }

//

  - (void) describe
  {
    if ( _u16Chars )
      u_fprintf(__SBStringStdout, "SBString@%p {\n  hash: %08X\n  `%S`\n}\n", self, [self hash], _u16Chars);
  }

//

  - (void) writeToStream:(FILE*)stream
  {
    if ( _u16Chars && _charLength ) {
      if ( stream == stdout ) {
        u_fprintf(__SBStringStdout, "%S", _u16Chars);
      } else {
        UFILE*    tmpFile = u_finit(stream, NULL, "UTF-8");
        
        u_fprintf(tmpFile, "%S", _u16Chars);
        u_fclose(tmpFile);
      }
    }
  }

//

  - (SBRange) rangeOfString:(SBString*)aString
  {
    return [self rangeOfString:aString range:SBRangeCreate(0,[self length])];
  }
  
//

  - (SBRange) rangeOfString:(SBString*)aString
    range:(SBRange)searchRange
  {
    SBRange           foundRange = SBEmptyRange;
    const UChar*      searchChars = [aString utf16Characters];
    size_t            searchLen = [aString length];
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _charLength && searchChars && searchLen ) {
      UChar*          foundPtr = NULL;
      
      foundPtr = u_strFindFirst(
                      _u16Chars + searchRange.start,
                      searchRange.length,
                      searchChars,
                      searchLen
                    );
      if ( foundPtr ) {
        foundRange.start = foundPtr - _u16Chars;
        foundRange.length = searchLen;
      }
    }
    return foundRange;
  }
  
//

  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
  {
    return [self rangeOfCharacterFromSet:aSet options:0 range:SBRangeCreate(0,_charLength)];  
  }
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(unsigned int)options
  {
    return [self rangeOfCharacterFromSet:aSet options:options range:SBRangeCreate(0,_charLength)];
  }
  - (SBRange) rangeOfCharacterFromSet:(SBCharacterSet*)aSet
    options:(unsigned int)options
    range:(SBRange)searchRange
  {
    SBRange               foundRange = SBEmptyRange;
    
    if ( ! SBRangeEmpty(searchRange) && _u16Chars && _charLength && aSet ) {
      USet*               charSet = [aSet icuCharSet];
      
      if ( charSet ) {
        USetSpanCondition cond = ( (options & SBAnchoredSearch) ? USET_SPAN_CONTAINED : USET_SPAN_NOT_CONTAINED );
        int32_t           idx;
        
        if ( (options & SBBackwardsSearch) ) {
          idx = uset_spanBack(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBAnchoredSearch) ) {
            if ( idx != searchRange.length )
              foundRange = SBRangeCreate(SBRangeMax(searchRange) - 1 - idx, 1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx - 1, 1);
          }
        } else {
          idx = uset_span(
                    charSet,
                    _u16Chars + searchRange.start,
                    searchRange.length,
                    cond
                  );
          if ( (options & SBAnchoredSearch) ) {
            if ( idx )
              foundRange = SBRangeCreate(searchRange.start,1);
          } else {
            foundRange = SBRangeCreate(searchRange.start + idx, 1);
          }
        }
      }
    }
    return foundRange;
  }

//

  - (void) replaceCharactersInRange:(SBRange)range
    withString:(SBString*)aString
  {
    [self replaceCharactersInRange:range withCharacters:(UChar*)[aString utf16Characters] length:[aString length]];
  }

//

  - (void) appendString:(SBString*)aString
  {
    [self replaceCharactersInRange:SBRangeCreate([self length],0) withString:aString];
  }
  
//

  - (void) appendCharacters:(const UChar*)characters
    length:(size_t)length
  {
    [self replaceCharactersInRange:SBRangeCreate([self length],0) withCharacters:(UChar*)characters length:length];
  }

//

  - (void) insertString:(SBString*)aString
    atIndex:(unsigned int)index
  {
    [self replaceCharactersInRange:SBRangeCreate(index,0) withString:aString];
  }

//

  - (void) insertCharacters:(const UChar*)characters
    length:(size_t)length
    atIndex:(unsigned int)index
  {
    [self replaceCharactersInRange:SBRangeCreate(index,0) withCharacters:(UChar*)characters length:length];
  }
    
//

  - (void) deleteCharactersInRange:(SBRange)range
  {
    [self replaceCharactersInRange:range withString:[SBString emptyString]];
  }

@end

//
#pragma mark -
//

#define UCHAR_PERIOD ((UChar)0x002e)
#define UCHAR_SLASH ((UChar)0x002f)
#define UCHAR_BACKSLASH ((UChar)0x005c)

static UChar __UChar_Period = UCHAR_PERIOD;
static UChar __UChar_Slash = UCHAR_SLASH;
static UChar __UChar_Backslash = UCHAR_BACKSLASH;

@implementation SBString(SBStringPathExtensions)

  - (BOOL) isAbsolutePath
  {
    if ( _u16Chars && _charLength && (*_u16Chars == __UChar_Slash) )
      return YES;
    return NO;
  }
  
//

  - (BOOL) isRelativePath
  {
    if ( _u16Chars && _charLength && (*_u16Chars != __UChar_Slash) )
      return YES;
    return NO;
  }

//

  - (SBString*) lastPathComponent
  {
    if ( _u16Chars && _charLength ) {
      UChar*          end = _u16Chars + _charLength;
      size_t          charLen = 0;
      
      while ( end-- > _u16Chars ) {
        if ( *end == __UChar_Slash ) {
          end--;
          if ( (end >= _u16Chars) && (*end == __UChar_Backslash) ) {
            charLen += 2;
            continue;
          }
          return [SBString stringWithCharacters:end + 2 length:charLen];
        }
        charLen++;
      }
      return [SBString stringWithString:self];
    }
    return nil;
  }

//

  - (SBString*) stringByDeletingLastPathComponent
  {
    if ( _u16Chars && _charLength ) {
      UChar*          end = _u16Chars + _charLength;
      size_t          charLen = 0;
      
      while ( end-- > _u16Chars ) {
        if ( *end == __UChar_Slash ) {
          end--;
          if ( (end >= _u16Chars) && (*end == __UChar_Backslash) ) {
            charLen += 2;
            continue;
          }
          return [SBString stringWithCharacters:_u16Chars length:(_charLength - charLen)];
        }
        charLen++;
      }
      return [SBString stringWithString:self];
    }
    return nil;
  }
  
//

  - (SBString*) stringByAppendingPathComponent:(SBString*)aString
  {
    SBString*   result = [SBString stringWithString:self];
    
    if ( result ) {
      [result appendCharacters:&__UChar_Slash length:1];
      [result appendString:aString];
    }
    return result;
  }
  
//

  - (SBString*) stringByAppendingPathComponents:(SBString*)aString,
    ...
  {
    SBString*   result = [SBString stringWithString:self];
    
    if ( result ) {
      va_list         vargs;
      
      va_start(vargs, aString);
      while ( aString ) {
        [result appendCharacters:&__UChar_Slash length:1];
        [result appendString:aString];
        aString = va_arg(vargs, id);
      }
      va_end(vargs);
    }
    return result;
  }
  
//

  - (SBString*) pathExtension
  {
    if ( _u16Chars && _charLength ) {
      UChar*          end = _u16Chars + _charLength;
      size_t          charLen = 0;
      
      while ( end-- > _u16Chars ) {
        switch ( *end ) {
        
          case UCHAR_PERIOD:
            return [SBString stringWithCharacters:end + 1 length:charLen];
          
          case UCHAR_SLASH:
            end--;
            if ( (end >= _u16Chars) && (*end == __UChar_Backslash) ) {
              charLen += 2;
              continue;
            }
            return nil;
          
        }
        charLen++;
      }
    }
    return nil;
  }

//

  - (SBString*) stringByDeletingPathExtension
  {
    if ( _u16Chars && _charLength ) {
      UChar*          end = _u16Chars + _charLength;
      size_t          charLen = 0;
      
      while ( end-- > _u16Chars ) {
        switch ( *end ) {
        
          case UCHAR_PERIOD:
            return [SBString stringWithCharacters:_u16Chars length:(_charLength - charLen)];
          
          case UCHAR_SLASH:
            end--;
            if ( (end >= _u16Chars) && (*end == __UChar_Backslash) ) {
              charLen += 2;
              continue;
            }
            return nil;
          
        }
        charLen++;
      }
    }
    return nil;
  }
  
//

  - (SBString*) stringByAppendingPathExtension:(SBString*)aString
  {
    SBString*   result = [SBString stringWithString:self];
    
    if ( result ) {
      [result appendCharacters:&__UChar_Period length:1];
      [result appendString:aString];
    }
    return result;
  }

//

  - (BOOL) pathExists
  {
    return ( [self pathIsFile] || [self pathIsDirectory] );
  }
  
//

  - (BOOL) pathIsDirectory
  {
    SBSTRING_AS_UTF8_BEGIN(self)
      return directoryExists( self_utf8 );
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (BOOL) pathIsFile
  {
    SBSTRING_AS_UTF8_BEGIN(self)
      return fileExists( self_utf8 );
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

//

  - (BOOL) setWorkingDirectory
  {
    SBSTRING_AS_UTF8_BEGIN(self)
      return ( chdir((const char*)self_utf8) == 0 );
    SBSTRING_AS_UTF8_END
    
    return NO;
  }

@end

//
#pragma mark -
//

SBString* SBUserName()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_name )
    return [SBString stringWithUTF8String:passwdForUser->pw_name];
  return nil;
}

//

SBString* SBFullUserName()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_gecos )
    return [SBString stringWithUTF8String:passwdForUser->pw_gecos];
  return nil;
}

//

SBString* SBHomeDirectory()
{
  struct passwd*    passwdForUser = getpwuid(getuid());
  
  if ( passwdForUser && passwdForUser->pw_dir )
    return [SBString stringWithUTF8String:passwdForUser->pw_dir];
  return nil;
}

//

SBString* SBHomeDirectoryForUser(
  SBString*   userName
)
{
  SBSTRING_AS_UTF8_BEGIN(userName)
    struct passwd*    passwdForUser = getpwnam(userName_utf8);
    
    if ( passwdForUser && passwdForUser->pw_dir )
      return [SBString stringWithUTF8String:passwdForUser->pw_dir];
  SBSTRING_AS_UTF8_END
  
  return nil;
}
