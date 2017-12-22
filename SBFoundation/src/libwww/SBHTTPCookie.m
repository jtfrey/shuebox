//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBHTTPCookie.m
//
// Base class for HTTP cookie handling.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBHTTPCookie.h"

#import "SBString.h"
#import "SBDate.h"

@implementation SBHTTPCookie

  + (SBDictionary*) cookiesFromEnv
  {
    static SBDictionary* __cookiesFromEnv = nil;
    
    if ( __cookiesFromEnv == nil )
      __cookiesFromEnv = [[SBDictionary dictionaryWithCookiesFromEnv] retain];
    return __cookiesFromEnv;
  }

//

  - (id) initWithCookieName:(SBString*)name
    andValue:(SBString*)value
  {
    if ( self = [self init] ) {
      [self setCookieName:name];
      [self setCookieValue:value];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _cookieName ) [_cookieName release];
    if ( _cookieValue ) [_cookieValue release];
    if ( _basePath ) [_basePath release];
    if ( _baseDomain ) [_baseDomain release];
    
    [super dealloc];
  }

//

  - (SBString*) cookieName
  {
    return _cookieName;
  }
  - (void) setCookieName:(SBString*)aString
  {
    if ( aString ) aString = [aString retain];
    if ( _cookieName ) [_cookieName release];
    _cookieName = aString;
  }
  
//

  - (SBString*) cookieValue
  {
    return _cookieName;
  }
  - (void) setCookieValue:(SBString*)aString
  {
    if ( aString ) aString = [aString retain];
    if ( _cookieValue ) [_cookieValue release];
    _cookieValue = aString;
  }
  
//

  - (SBInteger) timeToLive
  {
    return _timeToLive;
  }
  - (void) setTimeToLive:(SBInteger)ttl
  {
    _timeToLive = ttl;
  }
  
//

  - (SBDate*) expirationDate
  {
    return [SBDate dateWithSecondsSinceNow:_timeToLive];
  }
  - (void) setExpirationDate:(SBDate*)expirationDate
  {
    SBTimeInterval*   timeDiff = [expirationDate timeIntervalSinceDate:[SBDate dateWhichIsAlwaysNow]];
    
    if ( timeDiff )
      [self setTimeToLive:[timeDiff totalSecondsInTimeInterval]];
  }

//

  - (SBString*) basePath
  {
    return _basePath;
  }
  - (void) setBasePath:(SBString*)aString
  {
    if ( aString ) aString = [aString retain];
    if ( _basePath ) [_basePath release];
    _basePath = aString;
  }
  
//

  - (SBString*) baseDomain
  {
    return _baseDomain;
  }
  - (void) setBaseDomain:(SBString*)aString
  {
    if ( aString ) aString = [aString retain];
    if ( _baseDomain ) [_baseDomain release];
    _baseDomain = aString;
  }

//

  - (BOOL) secureConnectionRequired
  {
    return _secureConnectionRequired;
  }
  - (void) setSecureConnectionRequired:(BOOL)secureConnectionRequired
  {
    _secureConnectionRequired = secureConnectionRequired;
  }

//

  - (SBString*) asString
  {
    SBString*   result = nil;
    
    if ( _cookieName ) {
      SBMutableString*    content = [[SBMutableString alloc] init];
      
      if ( content ) {
        [content appendFormat:"%S=", [_cookieName utf16Characters]];
        
        if ( _cookieValue )
          [content urlEncodeAndAppendString:_cookieValue];
        
        if ( _timeToLive ) {
          time_t      then = time(NULL) + _timeToLive;
          struct tm   thenTm;
          char        timeStr[32];
          
          strftime(timeStr, 32, "%a, %d-%b-%Y %H:%M:%S %Z", localtime_r(&then, &thenTm));
          
          [content appendFormat:"; expires=%s", timeStr];
        }
        
        if ( _basePath )
          [content appendFormat:"; path=%S", [_basePath utf16Characters]];
        
        if ( _baseDomain )
          [content appendFormat:"; domain=%S", [_baseDomain utf16Characters]];
        
        if ( _secureConnectionRequired )
          [content appendFormat:"; secure"];
        
        result = [content copy];
        [content release];
      }
    }
    return result;
  }
  
//
#pragma mark SBHTTPHeaderSupport protocol
//

  - (void) appendHTTPHeaders:(SBMutableString*)content
  {
    if ( _cookieName ) {
      [content appendFormat:"Set-Cookie: %S=", [_cookieName utf16Characters]];
      
      if ( _cookieValue )
        [content urlEncodeAndAppendString:_cookieValue];
      
      if ( _timeToLive ) {
        time_t      then = time(NULL) + _timeToLive;
        struct tm   thenTm;
        char        timeStr[32];
        
        strftime(timeStr, 32, "%a, %d-%b-%Y %H:%M:%S %Z", gmtime_r(&then, &thenTm));
        
        [content appendFormat:"; expires=%s", timeStr];
      }
      
      if ( _basePath )
        [content appendFormat:"; path=%S", [_basePath utf16Characters]];
      
      if ( _baseDomain )
        [content appendFormat:"; domain=%S", [_baseDomain utf16Characters]];
        
      [content appendString:@"\r\n"];
    }
  }

@end

//
#pragma mark -
//

unsigned int
__SBDictionary_countCookiesInCString(
  const char*   cookieString
)
{
  unsigned int    count = 0;
  BOOL            foundEqual = NO;
  char*           s = (char*)cookieString;
  
  while ( *s ) {
    switch ( *s ) {
    
      case '=':
        foundEqual = YES;
        break;
        
      case ';':
        if ( foundEqual ) {
          foundEqual = NO;
          count++;
        }
        break;
    
    }
    s++;
  }
  if ( foundEqual )
    count++;
  return count;
}

//

unsigned int
__SBDictionary_parseCookiesFromCString(
  const char*   cookieString,
  SBString*     keys[],
  SBString*     values[],
  unsigned int  maxCookies
)
{
  unsigned int    count = 0;
  BOOL            foundEqual = NO;
  char*           keyStart = (char*)cookieString;
  char*           keyEnd = keyStart;
  char*           valStart;
  char*           end = keyEnd;
  
  while ( *end && (count < maxCookies) ) {
    switch ( *end ) {
    
      case ' ':
        if ( ! foundEqual )
          keyStart++;
        break;
        
      case '=':
        if ( ! foundEqual ) {
          foundEqual = YES;
          keyEnd = end;
          valStart = end + 1;
        }
        break;
        
      case ';':
        if ( foundEqual ) {
          // keyStart,keyEnd provide the start of the key and the '=' character pointers, respectively
          if ( (keyEnd - keyStart) > 0 ) {
            keys[count] = [SBString stringWithURLEncodedUTF8String:keyStart length:(keyEnd - keyStart)];
            
            // valStart,end provide the start of the value and the ';' character pointers, respectively
            if ( (end - valStart) > 0 )
              values[count] = [SBString stringWithURLEncodedUTF8String:valStart length:(end - valStart)];
            else
              values[count] = [SBString string];
            count++;
          }
          foundEqual = NO;
          keyStart = keyEnd = end + 1;
        }
        break;
    
    }
    end++;
  }
  if ( foundEqual && (count < maxCookies) ) {
    // keyStart,keyEnd provide the start of the key and the '=' character pointers, respectively
    keys[count] = [SBString stringWithURLEncodedUTF8String:keyStart length:(keyEnd - keyStart)];
    
    // valStart,end provide the start of the value and the ';' character pointers, respectively
    values[count] = [SBString stringWithURLEncodedUTF8String:valStart length:(end - valStart)];
    
    count++;
  }
  return count;
}

//

@implementation SBDictionary(SBHTTPCookieAdditions)

  + (SBDictionary*) dictionaryWithCookiesFromEnv
  {
    const char*       HTTP_COOKIE = getenv("HTTP_COOKIE");
    unsigned int      cookieCount = 0;
    
    if ( HTTP_COOKIE && (cookieCount = __SBDictionary_countCookiesInCString(HTTP_COOKIE)) ) {
      SBString*       keys[cookieCount];
      SBString*       values[cookieCount];
      
      cookieCount = __SBDictionary_parseCookiesFromCString(HTTP_COOKIE, keys, values, cookieCount);
      if ( cookieCount )
        return [SBDictionary dictionaryWithObjects:values forKeys:keys count:cookieCount];
    }
    return nil;
  }
  + (SBDictionary*) dictionaryWithCookieString:(SBString*)cookieString
  {
    SBSTRING_AS_UTF8_BEGIN(cookieString)
    
      unsigned int      cookieCount = 0;
    
      if ( (cookieCount = __SBDictionary_countCookiesInCString(cookieString_utf8)) ) {
        SBString*       keys[cookieCount];
        SBString*       values[cookieCount];
        
        cookieCount = __SBDictionary_parseCookiesFromCString(cookieString_utf8, keys, values, cookieCount);
        if ( cookieCount )
          return [SBDictionary dictionaryWithObjects:values forKeys:keys count:cookieCount];
      }
    
    SBSTRING_AS_UTF8_END
    return nil;
  }
  
//

  - (id) initWithCookiesFromEnv
  {
    const char*       HTTP_COOKIE = getenv("HTTP_COOKIE");
    unsigned int      cookieCount = 0;
    
    if ( HTTP_COOKIE && (cookieCount = __SBDictionary_countCookiesInCString(HTTP_COOKIE)) ) {
      SBString*       keys[cookieCount];
      SBString*       values[cookieCount];
      
      cookieCount = __SBDictionary_parseCookiesFromCString(HTTP_COOKIE, keys, values, cookieCount);
      if ( cookieCount )
        return [self initWithObjects:values forKeys:keys count:cookieCount];
    }
    return [self init];
  }
  - (id) initWithCookieString:(SBString*)cookieString
  {
    SBSTRING_AS_UTF8_BEGIN(cookieString)
    
      unsigned int      cookieCount = 0;
    
      if ( (cookieCount = __SBDictionary_countCookiesInCString(cookieString_utf8)) ) {
        SBString*       keys[cookieCount];
        SBString*       values[cookieCount];
        
        cookieCount = __SBDictionary_parseCookiesFromCString(cookieString_utf8, keys, values, cookieCount);
        if ( cookieCount )
          return [self initWithObjects:values forKeys:keys count:cookieCount];
      }
    
    SBSTRING_AS_UTF8_END
    return [self init];
  }

@end
