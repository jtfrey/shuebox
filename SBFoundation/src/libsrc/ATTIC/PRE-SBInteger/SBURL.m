//
// SBFoundation : ObjC Class Library for Solaris
// SBURL.m
//
// Wrap a generic URL.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBURL.h"
#import "SBValue.h"
#import "SBError.h"
#import "SBRegularExpression.h"

//

SBRegularExpression*    __SBURLRegex = nil;

SBString* SBURLLoadErrorDomain = @"url-load";
SBString* SBURLFileScheme = @"file";

//

#include <curl/curl.h>

static size_t
__SBURLLoader_curlDataCallback(
  void*     ptr,
  size_t    size,
  size_t    nmemb,
  void*     data
)
{
  SBMutableData*  buffer = (SBMutableData*)data;
  size_t          totalSize = size * nmemb;
  
  [buffer appendBytes:ptr length:totalSize];
  
  return totalSize;
}

//

static size_t
__SBURLLoader_curlHeaderCallback(
  void*     ptr,
  size_t    size,
  size_t    nmemb,
  void*     data
)
{
  SBMutableDictionary*    headers = (SBMutableDictionary*)data;
  size_t                  length, totalSize = size * nmemb;
  char*                   P = ptr;
  int                     shouldCap = 1;
  char                    *hStart, *hEnd;
  char                    *vStart, *vEnd;
  
  // Isolate the header name:
  length = totalSize;
  while ( *P && length && isspace(*P) ) {
    P++;
    length--;
  }
  hStart = hEnd = P;
  while ( *P && length && (*P != ':') && (*P != '\r') && (*P != '\n') ) {
    // We titlecase the header names:
    if ( *P == '-' ) {
      shouldCap = 1;
    } else if ( shouldCap ) {
      *P = toupper(*P);
      shouldCap = 0;
    } else {
      *P = tolower(*P);
    }
    P++;
    hEnd++;
    length--;
  }
  // Skip any whitespace:
  if ( *P == ':' ) P++;
  while ( *P && length && isspace(*P) ) {
    P++;
    length--;
  }
  // Isolate the header value:
  vStart = vEnd = P;
  while ( *P && length && (*P != '\r') && (*P != '\n') ) {
    P++;
    vEnd++;
    length--;
  }
  
  if ( (hEnd > hStart) && (vEnd > vStart) ) {
    SBString*     headerName = [SBString stringWithUTF8String:hStart length:(hEnd - hStart)];
    
    if ( headerName ) {
      SBString*   headerValue = [SBString stringWithUTF8String:vStart length:(vEnd - vStart)];
      
      if ( headerValue )
        [headers setObject:headerValue forKey:headerName];
    }
  }
  return totalSize;
}

//

SBError*
__SBURLLoader(
  const char*           url,
  SBMutableData*        data,
  SBMutableDictionary*  headers
)
{
  CURL*         curlHandle = curl_easy_init();
  CURLcode      status;
  SBString*     explanation = nil;
  char          error[1024];
  
  if ( curlHandle ) {
    curl_easy_setopt(curlHandle, CURLOPT_URL, url);
    if ( data ) {
      curl_easy_setopt(curlHandle, CURLOPT_WRITEFUNCTION, __SBURLLoader_curlDataCallback);
      curl_easy_setopt(curlHandle, CURLOPT_WRITEDATA, (void *)data);
    } else {
      curl_easy_setopt(curlHandle, CURLOPT_NOBODY, 1);
    }
    if ( headers ) {
      curl_easy_setopt(curlHandle, CURLOPT_HEADERFUNCTION, __SBURLLoader_curlHeaderCallback);
      curl_easy_setopt(curlHandle, CURLOPT_HEADERDATA, (void *)headers);
    }
    curl_easy_setopt(curlHandle, CURLOPT_USERAGENT, "SBURL/1.0");
    curl_easy_setopt(curlHandle, CURLOPT_ERRORBUFFER, error);
    
    status = curl_easy_perform(curlHandle);
    if ( status ) {
      explanation = [SBString stringWithFormat:"cURL encountered an error while fetching `%s` (code: %d)", url, status];
    }
    curl_easy_cleanup(curlHandle);
  } else {
    explanation = @"Unable to allocate a cURL agent.";
  }
  
  if ( explanation )
    return [SBError errorWithDomain:SBURLLoadErrorDomain code:kSBURLLoadSystemError
                      supportingData:[SBDictionary dictionaryWithObject:explanation forKey:SBErrorExplanationKey]
                    ];
  return nil;
}

//
#pragma mark -
//

enum {
  kSBURLSchemaPart                          = 1,
  kSBURLResourceSpecifierPart               = 2,
  kSBURLInternetSchemePart                  = 3,
  kSBURLInternetUsernamePart                = 5,
  kSBURLInternetPasswordPart                = 7,
  kSBURLInternetHostPart                    = 8,
  kSBURLInternetPortPart                    = 10,
  kSBURLURIPart                             = 12
};

enum {
  kSBURLSchemaIndex                         = 0,
  kSBURLResourceSpecifierIndex,
  kSBURLInternetSchemeIndex,
  kSBURLInternetUsernameIndex,
  kSBURLInternetPasswordIndex,
  kSBURLInternetHostIndex,
  kSBURLInternetPortIndex,
  kSBURLURIIndex,
  kSBURLMaxIndex
};

//

@interface SBURL(SBURLPrivate)

- (BOOL) isolateURLPiecesInString:(SBString*)urlString;

@end

@implementation SBURL(SBURLPrivate)

  - (BOOL) isolateURLPiecesInString:(SBString*)urlString
  {
    if ( __SBURLRegex && urlString ) {
      [__SBURLRegex setSubjectString:urlString];
      if ( [__SBURLRegex isFullMatch] ) {
        [__SBURLRegex rangesOfMatchingGroups:_parts];
        return YES;
      }
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBURL

  + initialize
  {
    if ( __SBURLRegex == nil ) {
      __SBURLRegex = [[SBRegularExpression alloc] initWithUTF8String:
                          "^([a-z0-9+.-]*):(//((([^:@]*)(:([^@]*))?@)?([^:/]+)(:([0-9]+))?)?(/(.*))?)?$"
                          flags:UREGEX_CASE_INSENSITIVE
                        ];
    }
  }

//

  + (id) urlWithScheme:(SBString*)scheme
    host:(SBString*)host
    uri:(SBString*)uri
  {
    return [[[SBURL alloc] initWithScheme:scheme host:host uri:uri] autorelease];
  }
  
//

  + (id) urlWithFilePath:(SBString*)filepath
  {
    return [[[SBURL alloc] initWithFilePath:filepath] autorelease];
  }
  
//

  + (id) urlWithString:(SBString*)urlString
  {
    return [[[SBURL alloc] initWithString:urlString] autorelease];
  }

//

  - (id) initWithScheme:(SBString*)scheme
    host:(SBString*)host
    uri:(SBString*)uri
  {
    if ( self = [super init] ) {
      // At least need the scheme:
      if ( scheme ) {
        _urlString = [[SBString alloc] initWithFormat:"%s://%S/%S",
                          [scheme utf8Characters],
                          ( host ? [host utf16Characters] : (const UChar*)"\0\0" ),
                          ( uri ? [uri utf16Characters] : (const UChar*)"\0\0" )
                        ];
        if ( ! [self isolateURLPiecesInString:_urlString] ) {
          [self release];
          self = nil;
        }
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithFilePath:(SBString*)filepath
  {
    return [self initWithScheme:SBURLFileScheme host:nil uri:filepath];
  }
  
//

  - (id) initWithString:(SBString*)urlString
  {
    if ( self = [super init] ) {
      if ( ! [self isolateURLPiecesInString:urlString] ) {
        [self release];
        self = nil;
      } else {
        _urlString = [urlString copy];
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    unsigned int    i = 0;
    
    while ( i < kSBURLMaxIndex ) {
      if ( _cache[i] && ! [_cache[i] isNull] )
        [_cache[i] release];
      i++;
    }
    if ( _urlString ) [_urlString release];
    [super dealloc];
  }

//

  - (unsigned int) hash
  {
    return [_urlString hash];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    id      value;
    
    [super summarizeToStream:stream];
    fprintf(stream, " ( scheme = `"); [[self scheme] writeToStream:stream];
    fprintf(stream, "`) {\n");
    if ( value = [self user] ) {
      fprintf(stream, "  Internet.username:    "); [value writeToStream:stream]; fputc('\n', stream);
    }
    if ( value = [self password] ) {
      fprintf(stream, "  Internet.password:    "); [value writeToStream:stream]; fputc('\n', stream);
    }
    if ( value = [self host] ) {
      fprintf(stream, "  Internet.host:        "); [value writeToStream:stream]; fputc('\n', stream);
    }
    if ( value = [self port] ) {
      fprintf(stream, "  Internet.port:        %u\n", [value unsignedIntValue]);
    }
    if ( value = [self uri] ) {
      fprintf(stream, "  URI:                  "); [value writeToStream:stream]; fputc('\n', stream);
    }
    fprintf(stream, "}\n");
  }

//

  - (SBString*) scheme
  {
    if ( ! _cache[kSBURLSchemaIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLSchemaPart]) ) {
        _cache[kSBURLSchemaIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLSchemaIndex] = [[_urlString substringWithRange:_parts[kSBURLSchemaPart]] retain] );
      }
    }
    return ( [_cache[kSBURLSchemaIndex] isNull] ? nil : _cache[kSBURLSchemaIndex] );
  }
  
//

  - (SBString*) resourceSpecifier
  {
    if ( ! _cache[kSBURLResourceSpecifierIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLResourceSpecifierPart]) ) {
        _cache[kSBURLResourceSpecifierIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLResourceSpecifierIndex] = [[_urlString substringWithRange:_parts[kSBURLResourceSpecifierPart]] retain] );
      }
    }
    return ( [_cache[kSBURLResourceSpecifierIndex] isNull] ? nil : _cache[kSBURLResourceSpecifierIndex] );
  }
  
//

  - (SBString*) user
  {
    if ( ! _cache[kSBURLInternetUsernameIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLInternetUsernamePart]) ) {
        _cache[kSBURLInternetUsernameIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLInternetUsernameIndex] = [[_urlString substringWithRange:_parts[kSBURLInternetUsernamePart]] retain] );
      }
    }
    return ( [_cache[kSBURLInternetUsernameIndex] isNull] ? nil : _cache[kSBURLInternetUsernameIndex] );
  }
  
//

  - (SBString*) password
  {
    if ( ! _cache[kSBURLInternetPasswordIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLInternetPasswordPart]) ) {
        _cache[kSBURLInternetPasswordIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLInternetPasswordIndex] = [[_urlString substringWithRange:_parts[kSBURLInternetPasswordPart]] retain] );
      }
    }
    return ( [_cache[kSBURLInternetPasswordIndex] isNull] ? nil : _cache[kSBURLInternetPasswordIndex] );
  }
  
//

  - (SBString*) host
  {
    if ( ! _cache[kSBURLInternetHostIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLInternetHostPart]) ) {
        _cache[kSBURLInternetHostIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLInternetHostIndex] = [[_urlString substringWithRange:_parts[kSBURLInternetHostPart]] retain] );
      }
    }
    return ( [_cache[kSBURLInternetHostIndex] isNull] ? nil : _cache[kSBURLInternetHostIndex] );
  }
  
//

  - (SBNumber*) port
  {
    if ( ! _cache[kSBURLInternetPortIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLInternetPortPart]) ) {
        _cache[kSBURLInternetPortIndex] = [SBNull null];
        return nil;
      } else {
        unsigned int        port = 0;
        UChar               c;
        unsigned int        i = _parts[kSBURLInternetPortPart].start, iMax = SBRangeMax(_parts[kSBURLInternetPortPart]);
        
        while ( i < iMax ) {
          UChar             c = [_urlString characterAtIndex:i++];
          
          if ( c >= '0' && c <= '9' ) {
            port = (port * 10) + (c - '0');
          }
        }
        return ( _cache[kSBURLInternetPortIndex] = [[SBNumber numberWithUnsignedInt:port] retain] );
      }
    }
    return ( [_cache[kSBURLInternetPortIndex] isNull] ? nil : _cache[kSBURLInternetPortIndex] );
  }
  
//

  - (SBString*) uri
  {
    if ( ! _cache[kSBURLURIIndex] ) {
      if ( SBRangeEmpty(_parts[kSBURLURIPart]) ) {
        _cache[kSBURLURIIndex] = [SBNull null];
        return nil;
      } else {
        return ( _cache[kSBURLURIIndex] = [[_urlString substringWithRange:_parts[kSBURLURIPart]] retain] );
      }
    }
    return ( [_cache[kSBURLURIIndex] isNull] ? nil : _cache[kSBURLURIIndex] );
  }

//

  - (BOOL) isFilePathURL
  {
    return ( [[self scheme] caseInsensitiveCompare:SBURLFileScheme] == SBOrderSame );
  }

//

  - (SBError*) loadResourceData:(SBMutableData**)data
  {
    return [self loadResourceData:data headers:NULL];
  }
  - (SBError*) loadResourceHeaders:(SBMutableDictionary**)headers
  {
    return [self loadResourceData:NULL headers:headers];
  }
  - (SBError*) loadResourceData:(SBMutableData**)data
    headers:(SBMutableDictionary**)headers
  {
    SBMutableData*          theData = nil;
    SBMutableDictionary*    theHeaders = nil;
    
    if ( data ) {
      if ( (theData = *data) == nil ) {
        theData = [SBMutableData data];
        *data = theData;
      }
    }
    if ( headers ) {
      if ( (theHeaders = *headers) == nil ) {
        theHeaders = [[[SBMutableDictionary alloc] init] autorelease];
        *headers = theHeaders;
      }
    }
    
    if ( theData || theHeaders ) {
      return __SBURLLoader([_urlString utf8Characters], theData, theHeaders);
    }
    
    return [SBError errorWithDomain:SBURLLoadErrorDomain code:kSBURLLoadParameterError
                      supportingData:[SBDictionary dictionaryWithObject:@"Neither resource data nor headers were requested?!?" forKey:SBErrorExplanationKey]
                    ];
  }
  
@end

//
#pragma mark -
//

@implementation SBString(SBStringURLLoading)

  + (id) stringWithContentsOfURL:(SBURL*)aURL
  {
    SBMutableData*          rsrcContent = [[SBMutableData alloc] init];
    SBMutableDictionary*    headers = [[SBMutableDictionary alloc] init];
    SBError*                error = [aURL loadResourceData:&rsrcContent headers:&headers];
    
    if ( ! error ) {
      SBString*             rsrcString = nil;
      SBString*             contentType = [headers objectForKey:@"Content-Type"];
      SBString*             charset = @"UTF-8";
      
      //
      // The charset defaults to UTF-8; check for a Content-Type header and see if it
      // specifies a character set:
      //
      if ( contentType ) {
        SBRange             charsetRange = [contentType rangeOfString:@"charset=" options:SBStringCaseInsensitiveSearch];
        
        if ( ! SBRangeEmpty(charsetRange) ) {
          unsigned int      i = SBRangeMax(charsetRange), iMax = [contentType length];
          
          charsetRange.start = i;
          while ( i < iMax ) {
            UChar           c = [contentType characterAtIndex:i];
            
            if ( isspace(c) || ( c == ';' ) )
              break;
            i++;
          }
          if ( i != charsetRange.start ) {
            SBString*       charset;
            
            charsetRange.length = i - charsetRange.start;
            charset = [contentType substringWithRange:charsetRange];
          }
        }
      }
      //
      // Attempt to decode the resource data as a string:
      //
      rsrcString = [[[SBString alloc] initWithBytes:[rsrcContent bytes]
                                      count:[rsrcContent length]
                                      encoding:[charset utf8Characters]] autorelease];
        
      [rsrcContent release];
      [headers release];
      return rsrcString;
    }
    [rsrcContent release];
    [headers release];
    return nil;
  }
  
//

  - (id) initWithContentsOfURL:(SBURL*)aURL
  {
    Class                   myClass = [self class];
    SBMutableData*          rsrcContent = [[SBMutableData alloc] init];
    SBMutableDictionary*    headers = [[SBMutableDictionary alloc] init];
    SBError*                error = [aURL loadResourceData:&rsrcContent headers:&headers];
    
    // An alloc'ed SBString is worthless: 
    [self release];
    self = nil;
    
    if ( ! error ) {
      SBString*             contentType = [headers objectForKey:@"Content-Type"];
      SBString*             charset = @"UTF-8";
      
      //
      // The charset defaults to UTF-8; check for a Content-Type header and see if it
      // specifies a character set:
      //
      if ( contentType ) {
        SBRange             charsetRange = [contentType rangeOfString:@"charset=" options:SBStringCaseInsensitiveSearch];
        
        if ( ! SBRangeEmpty(charsetRange) ) {
          unsigned int      i = SBRangeMax(charsetRange), iMax = [contentType length];
          
          charsetRange.start = i;
          while ( i < iMax ) {
            UChar           c = [contentType characterAtIndex:i];
            
            if ( isspace(c) || ( c == ';' ) )
              break;
            i++;
          }
          if ( i != charsetRange.start ) {
            SBString*       charset;
            
            charsetRange.length = i - charsetRange.start;
            charset = [contentType substringWithRange:charsetRange];
          }
        }
      }
      //
      // Attempt to decode the resource data as a string:
      //
      self = [[myClass alloc] initWithBytes:[rsrcContent bytes]
                                      count:[rsrcContent length]
                                      encoding:[charset utf8Characters]];
    }
    [rsrcContent release];
    [headers release];
    return self;
  }

@end

//
#pragma mark -
//

@implementation SBData(SBDataURLLoading)

  + (id) dataWithContentsOfURL:(SBURL*)aURL
  {
    SBMutableData*    rsrcContent = [[SBMutableData alloc] init];
    SBError*          error = [aURL loadResourceData:&rsrcContent];
    SBData*           result = nil;
    
    if ( ! error )
      result = [[rsrcContent copy] autorelease];
    [rsrcContent release];
    return result;
  }
  
//

  - (id) initWithContentsOfURL:(SBURL*)aURL
  {
    if ( [self respondsTo:@selector(mutableBytes)] ) {
      if ( self = [self init] ) {
        SBMutableData*    SELF = (SBMutableData*)self;
        SBError*          error = [aURL loadResourceData:&SELF];
        
        if ( error ) {
          [self release];
          self = nil;
        }
      }
    } else {
      SBMutableData*    rsrcContent = [[SBMutableData alloc] init];
      SBError*          error = [aURL loadResourceData:&rsrcContent];
      
      if ( error ) {
        [self release];
        self = nil;
      } else {
        self = [self initWithData:rsrcContent];
      }
      [rsrcContent release];
    }
    return self;
  }

@end

