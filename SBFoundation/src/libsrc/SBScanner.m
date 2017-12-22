//
// SBFoundation : ObjC Class Library for Solaris
// SBScanner.m
//
// Process string contents.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBScanner.h"
#import "SBString.h"
#import "SBCharacterSet.h"


unsigned char __SBScannerFloatCharset[16] = {
    0x00,
    0x00,
    0x00,
    0x00,
    0x00,
    0x68,  /*  (   )   *   +   ,   -   .   /   */
    0xFF,  /*  0   1   2   3   4   5   6   7   */
    0x03,  /*  8   9   :   ;   <   =   >   ?   */
    0x20,  /*  @   A   B   C   D   E   F   G   */
    0x00,
    0x00,
    0x00,
    0x20,  /*  `   a   b   c   d   e   f   g   */
    0x00,
    0x00,
    0x00
  };


@interface SBScanner(SBScannerPrivate)

- (void) skipUnusedCharacters;
- (BOOL) scanBase10Integer:(unsigned long long int*)magnitude sign:(int*)sign overflow:(BOOL*)overflow;
- (BOOL) scanBase16Integer:(unsigned long long int*)magnitude overflow:(BOOL*)overflow;

@end

@implementation SBScanner(SBScannerPrivate)

  - (void) skipUnusedCharacters
  {
    if ( _charactersToBeSkipped ) {
      UChar       c;
      
      while ( _scanRange.start < _fullLength ) {
        c = [_string characterAtIndex:_scanRange.start];
        if ( ! [_charactersToBeSkipped utf16CharacterIsMember:c] )
          break;
        _scanRange.start++;
        _scanRange.length--;
      }
    }
  }

//

  - (BOOL) scanBase10Integer:(unsigned long long int*)magnitude
    sign:(int*)sign
    overflow:(BOOL*)overflow
  {
    unsigned long long int  digits = 0ULL;
    BOOL                    isNegative = NO;
    BOOL                    foundDigits = NO;
    SBRange                 range = _scanRange;
    
    *overflow = NO;
    
    // Leading +/- character?
    switch ( [_string characterAtIndex:range.start] ) {
      case '-':
        isNegative = YES;
      case '+':
        range.start++;
        range.length--;
        break;
    }
    
    // Process digits:
    while ( range.length ) {
      UChar                   digit = [_string characterAtIndex:range.start];
      unsigned long long int  newValue;
      
      if ( (digit < '0') || (digit > '9') )
        break;
      else
        foundDigits = YES;
      
      if ( ! *overflow ) {
        newValue = (digits * 10) + (digit - '0');
        if ( newValue < digits ) {
          *overflow = YES;
          digits = LONG_LONG_MAX;
        } else {
          digits = newValue;
        }
      }
      range.start++;
      range.length--;
    }
    if ( foundDigits ) {
      _scanRange = range;
      *sign = ( isNegative ? -1 : 1 );
      *magnitude = digits;
      return YES;
    }
    return NO;
  }

//

  - (BOOL) scanBase16Integer:(unsigned long long int*)value
     overflow:(BOOL*)overflow
  {
    unsigned long long int  digits = 0ULL;
    UChar                   digit;
    BOOL                    foundDigits = NO;
    SBRange                 range = _scanRange;
    
    *overflow = NO;
    
    // Leading 0x or 0X?
    digit = [_string characterAtIndex:range.start];
    if ( digit == '0' && (range.length > 1) ) {
      switch ( [_string characterAtIndex:range.start + 1] ) {
        case 'x':
        case 'X':
          range.start += 2;
          range.length -= 2;
          break;
      }
    }
    
    // Process digits:
    while ( range.length ) {
      unsigned long long int  newValue;
      unsigned                digitValue = 32;
      
      switch ( (digit = [_string characterAtIndex:range.start]) ) {
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
          digitValue = digit - '0';
          break;
        case 'a':
        case 'b':
        case 'c':
        case 'd':
        case 'e':
        case 'f':
          digitValue = 10 + digit - 'a';
          break;
        case 'A':
        case 'B':
        case 'C':
        case 'D':
        case 'E':
        case 'F':
          digitValue = 10 + digit - 'A';
          break;
      }
      if ( digitValue == 32 )
        break;
      else
        foundDigits = YES;
      
      if ( ! *overflow ) {
        newValue = (digits * 16) + digitValue;
        if ( newValue < digits ) {
          *overflow = YES;
          digits = LONG_LONG_MAX;
        } else {
          digits = newValue;
        }
      }
      range.start++;
      range.length--;
    }
    if ( foundDigits ) {
      _scanRange = range;
      *value = digits;
      return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBScanner

  + (id) scannerWithString:(SBString*)aString
  {
    return [[[SBScanner alloc] initWithString:aString] autorelease];
  }
  
//

  - (id) initWithString:(SBString*)aString
  {
    if ( (self = [super init]) ) {
      _string = ( aString ? [aString copy] : [[SBString alloc] init] );
      _charactersToBeSkipped = [[SBCharacterSet whitespaceAndNewlineCharacterSet] retain];
      _caseSensitive = YES;
      _scanRange = SBRangeCreate(0, (_fullLength = [_string length]));
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _string ) [_string release];
    if ( _charactersToBeSkipped ) [_charactersToBeSkipped release];
    [super dealloc];
  }

//

  - (SBString*) string
  {
    return _string;
  }
  
//

  - (SBUInteger) scanLocation
  {
    return _scanRange.start;
  }
  - (void) setScanLocation:(SBUInteger)index
  {
    if ( index < _fullLength )
      _scanRange = SBRangeCreate(index, _fullLength - index);
  }
  
//

  - (SBCharacterSet*) charactersToBeSkipped
  {
    return _charactersToBeSkipped;
  }
  - (void) setCharactersToBeSkipped:(SBCharacterSet*)skipSet
  {
    if ( skipSet ) skipSet = [skipSet copy];
    if ( _charactersToBeSkipped ) [_charactersToBeSkipped release];
    _charactersToBeSkipped = skipSet;
  }
  
//

  - (BOOL) caseSensitive
  {
    return _caseSensitive;
  }
  - (void) setCaseSensitive:(BOOL)caseSensitive
  {
    _caseSensitive = caseSensitive;
  }
  
//

  - (BOOL) scanInteger:(SBInteger*)value
  {
    unsigned long long int  magnitude;
    int                     sign;
    BOOL                    overflow;
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length && [self scanBase10Integer:&magnitude sign:&sign overflow:&overflow] ) {
      if ( sign == -1 ) {
        if ( overflow || (magnitude > -((unsigned long long int)SBIntegerMin)) )
          magnitude = SBIntegerMin;
      } else {
        if ( overflow || (magnitude > ((unsigned long long int)SBIntegerMax)) )
          magnitude = SBIntegerMax;
      }
      if ( value )
        *value = sign * ((SBInteger)magnitude);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) scanInt:(int*)value
  {
    unsigned long long int  magnitude;
    int                     sign;
    BOOL                    overflow;
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length && [self scanBase10Integer:&magnitude sign:&sign overflow:&overflow] ) {
      if ( sign == -1 ) {
        if ( overflow || (magnitude > -((unsigned long long int)INT_MIN)) )
          magnitude = INT_MIN;
      } else {
        if ( overflow || (magnitude > ((unsigned long long int)INT_MAX)) )
          magnitude = INT_MAX;
      }
      if ( value )
        *value = sign * ((int)magnitude);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) scanLongLong:(long long*)value
  {
    unsigned long long int  magnitude;
    int                     sign;
    BOOL                    overflow;
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length && [self scanBase10Integer:&magnitude sign:&sign overflow:&overflow] ) {
      if ( sign == -1 ) {
        if ( overflow || (magnitude > -((unsigned long long int)LONG_LONG_MIN)) )
          magnitude = LONG_LONG_MIN;
      } else {
        if ( overflow || (magnitude > ((unsigned long long int)LONG_LONG_MAX)) )
          magnitude = LONG_LONG_MAX;
      }
      if ( value )
        *value = sign * ((long long)magnitude);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) scanHexInt:(unsigned int*)value
  {
    unsigned long long int  magnitude;
    BOOL                    overflow;
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length && [self scanBase16Integer:&magnitude overflow:&overflow] ) {
      if ( value )
        *value = ( ( overflow || (magnitude > ((unsigned long long int)UINT_MAX)) ) ? UINT_MAX : (unsigned int)magnitude );
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) scanHexLongLong:(unsigned long long int*)value
  {
    unsigned long long int  magnitude;
    BOOL                    overflow;
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length && [self scanBase16Integer:&magnitude overflow:&overflow] ) {
      if ( value )
        *value = ( ( overflow || (magnitude > ((unsigned long long int)ULONG_LONG_MAX)) ) ? ULONG_LONG_MAX : (unsigned long long int)magnitude );
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) scanFloat:(float*)value
  {
    char          stackBuffer[64];
    char*         buffer = stackBuffer;
    SBUInteger    length = 0, capacity = 64;
    BOOL          isNegative = NO;
    BOOL          foundDigits = NO;
    BOOL          rc = NO;
    SBRange       range = _scanRange;
    
    [self skipUnusedCharacters];
    
    // Leading +/- character?
    switch ( [_string characterAtIndex:range.start] ) {
      case '-':
        isNegative = YES;
        buffer[length++] = '-';
      case '+':
        range.start++;
        range.length--;
        break;
    }
    
    // Check for special cases:
    if ( [_string compare:@"infinity" options:SBStringCaseInsensitiveSearch range:range] == SBOrderSame ) {
      *((uint32_t*)value) = ( isNegative ? 0xff00000ULL : 0x7f00000ULL );
      _scanRange.start = range.start + 8;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    if ( [_string compare:@"inf" options:SBStringCaseInsensitiveSearch range:range] == SBOrderSame ) {
      *((uint32_t*)value) = ( isNegative ? 0xff00000ULL : 0x7f00000ULL );
      _scanRange.start = range.start + 3;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    if ( [_string compare:@"nan" options:SBStringCaseInsensitiveSearch range:range] == SBOrderSame ) {
      *((uint32_t*)value) = 0x7f800000U;
      _scanRange.start = range.start + 3;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    
    // Move all applicable characters to a temp buffer:
    while ( range.length ) {
      UChar       nextChar = [_string characterAtIndex:range.start];
      
      if ( (nextChar < 128) && (__SBScannerFloatCharset[nextChar / 8] & (1 << (nextChar % 8))) ) {
        // Push this character into our buffer:
        if ( length == capacity ) {
          char*       largerBuffer = NULL;
          
          if ( buffer == stackBuffer ) {
            // Need to go off the heap now:
            largerBuffer = malloc( capacity + 64 );
            if ( largerBuffer ) {
              memcpy(largerBuffer, stackBuffer, capacity);
              capacity += 64;
            }
          } else {
            largerBuffer = realloc(buffer, capacity + 64);
            if ( largerBuffer )
              capacity += 64;
          }
          if ( ! largerBuffer ) {
            // Out of memory...this is the best we can do:
            foundDigits = NO;
            break;
          }
          buffer = largerBuffer;
        }
        foundDigits = YES;
        buffer[length++] = (char)nextChar;
      } else {
        break;
      }
      range.start++;
      range.length--;
    }
    
    if ( foundDigits ) {
      char*       s = NULL;
      double      v = strtof(buffer, &s);
      
      if ( s > buffer ) {
        if ( value )
          *value = v;
        _scanRange = range;
        rc = YES;
      }
    }
    
    if ( buffer != stackBuffer )
      objc_free(buffer);
    return rc;
  }
  
//

  - (BOOL) scanDouble:(double*)value
  {
    char          stackBuffer[64];
    char*         buffer = stackBuffer;
    SBUInteger    length = 0, capacity = 64;
    BOOL          isNegative = NO;
    BOOL          foundDigits = NO;
    BOOL          rc = NO;
    SBRange       range;
    
    [self skipUnusedCharacters];
    range = _scanRange;
    
    // Leading +/- character?
    switch ( [_string characterAtIndex:range.start] ) {
      case '-':
        isNegative = YES;
        buffer[length++] = '-';
      case '+':
        range.start++;
        range.length--;
        break;
    }
    
    // Check for special cases:
    if ( [_string compare:@"infinity" options:SBStringCaseInsensitiveSearch range:SBRangeCreate(range.start, 8)] == SBOrderSame ) {
      *((uint64_t*)value) = ( isNegative ? 0xfff0000000000000ULL : 0x7ff0000000000000ULL );
      _scanRange.start = range.start + 8;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    if ( [_string compare:@"inf" options:SBStringCaseInsensitiveSearch range:SBRangeCreate(range.start, 3)] == SBOrderSame ) {
      *((uint64_t*)value) = ( isNegative ? 0xfff0000000000000ULL : 0x7ff0000000000000ULL );
      _scanRange.start = range.start + 3;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    if ( [_string compare:@"nan" options:SBStringCaseInsensitiveSearch range:SBRangeCreate(range.start, 3)] == SBOrderSame ) {
      *((uint64_t*)value) = 0x7ff8000000000000ULL;
      _scanRange.start = range.start + 3;
      _scanRange.length = _fullLength - _scanRange.start;
      return YES;
    }
    
    // Move all applicable characters to a temp buffer:
    while ( range.length ) {
      UChar       nextChar = [_string characterAtIndex:range.start];
      
      if ( (nextChar < 128) && (__SBScannerFloatCharset[nextChar / 8] & (1 << (nextChar % 8))) ) {
        // Push this character into our buffer:
        if ( length == capacity ) {
          char*       largerBuffer = NULL;
          
          if ( buffer == stackBuffer ) {
            // Need to go off the heap now:
            largerBuffer = malloc( capacity + 64 );
            if ( largerBuffer ) {
              memcpy(largerBuffer, stackBuffer, capacity);
              capacity += 64;
            }
          } else {
            largerBuffer = realloc(buffer, capacity + 64);
            if ( largerBuffer )
              capacity += 64;
          }
          if ( ! largerBuffer ) {
            // Out of memory...this is the best we can do:
            foundDigits = NO;
            break;
          }
          buffer = largerBuffer;
        }
        foundDigits = YES;
        buffer[length++] = (char)nextChar;
      } else {
        break;
      }
      range.start++;
      range.length--;
    }
    
    if ( foundDigits ) {
      char*       s = NULL;
      double      v = strtod(buffer, &s);
      
      if ( s > buffer ) {
        if ( value )
          *value = v;
        _scanRange = range;
        rc = YES;
      }
    }
    
    if ( buffer != stackBuffer )
      objc_free(buffer);
    return rc;
  }

//

  - (BOOL) scanString:(SBString*)string
    intoString:(SBString**)value
  {
    SBStringSearchOptions     searchOpts = SBStringAnchoredSearch | ( _caseSensitive ? 0 : SBStringCaseInsensitiveSearch );
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length ) {
      SBRange       found = [_string rangeOfString:string options:searchOpts range:_scanRange];
      
      if ( found.length ) {
        if ( value )
          *value = [_string substringWithRange:found];
        _scanRange.start = SBRangeMax(found);
        _scanRange.length = _fullLength - _scanRange.start;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) scanCharactersFromSet:(SBCharacterSet*)set
    intoString:(SBString**)value
  {
    [self skipUnusedCharacters];
    
    if ( _scanRange.length ) {
      SBRange       found = [_string rangeOfCharacterFromSet:set options:SBStringAnchoredSearch range:_scanRange];
      
      if ( found.length ) {
        if ( value )
          *value = [_string substringWithRange:found];
        _scanRange.start = SBRangeMax(found);
        _scanRange.length = _fullLength - _scanRange.start;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) scanUpToString:(SBString*)string
    intoString:(SBString**)value
  {
    SBStringSearchOptions     searchOpts = ( _caseSensitive ? 0 : SBStringCaseInsensitiveSearch );
    
    [self skipUnusedCharacters];
    
    if ( _scanRange.length ) {
      SBRange       found = [_string rangeOfString:string options:searchOpts range:_scanRange];
      
      if ( found.length ) {
        if ( value )
          *value = [_string substringWithRange:SBRangeCreate(_scanRange.start, found.start - _scanRange.start)];
        _scanRange.start = found.start;
        _scanRange.length = _fullLength - found.start;
        return YES;
      }
    }
    return NO;
    
  }
  
//

  - (BOOL) scanUpToCharactersFromSet:(SBCharacterSet*)set
    intoString:(SBString**)value
  {
    [self skipUnusedCharacters];
    
    if ( _scanRange.length ) {
      SBRange       found = [_string rangeOfCharacterFromSet:set options:0 range:_scanRange];
      
      if ( found.length ) {
        if ( value )
          *value = [_string substringWithRange:SBRangeCreate(_scanRange.start, found.start - _scanRange.start)];
        _scanRange.start = found.start;
        _scanRange.length = _fullLength - found.start;
        return YES;
      }
    }
    return NO;
  }

//

  - (BOOL) isAtEnd
  {
    return ( _scanRange.length ? NO : YES );
  }

@end

