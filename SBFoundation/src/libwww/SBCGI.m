//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBCGI.m
//
// Basic framework for a CGI.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBCGI.h"
#import "SBData.h"
#import "SBDictionary.h"
#import "SBEnumerator.h"
#import "SBInetAddress.h"
#import "SBFileHandle.h"

enum {
  kSBCGIFlagQueryStringHasBeenParsed        = 1 << 0
};

const char*   __SBHTTPMethodCStrings[kSBHTTPMethodINVALID + 1] = {
                    "GET",
                    "PUT",
                    "POST",
                    "DELETE",
                    "CONNECT",
                    "OPTIONS",
                    "TRACE",
                    "PATCH",
                    "PROPFIND",
                    "PROPPATCH",
                    "MKCOL",
                    "COPY",
                    "MOVE",
                    "LOCK",
                    "UNLOCK",
                    "VERSION_CONTROL",
                    "CHECKOUT",
                    "UNCHECKOUT",
                    "CHECKIN",
                    "UPDATE",
                    "LABEL",
                    "REPORT",
                    "MKWORKSPACE",
                    "MKACTIVITY",
                    "BASELINE_CONTROL",
                    "MERGE",
                    "INVALID"
                  };
SBString*     __SBHTTPMethodStrings[kSBHTTPMethodINVALID + 1] = {
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil,
                    nil
                  };

//

SBString*
SBHTTPMethodToString(
  SBHTTPMethod  method
)
{
  SBString*     methodStr = nil;
  
  if ( (method >= kSBHTTPMethodGET) && (method <= kSBHTTPMethodINVALID) ) {
    if ( (methodStr = __SBHTTPMethodStrings[method]) == nil ) {
      methodStr = __SBHTTPMethodStrings[method] = [[SBString alloc] initWithUTF8String:__SBHTTPMethodCStrings[method]];
    }
  }
  return methodStr;
}

//

SBHTTPMethod
SBHTTPMethodFromString(
  SBString*     aString
)
{
  int           i = kSBHTTPMethodGET, iMax = kSBHTTPMethodINVALID + 1;
  
  if ( aString && [aString length] ) {
    while ( i < iMax ) {
      SBString*   methodString = SBHTTPMethodToString(i);
      
      if ( methodString && ([methodString caseInsensitiveCompare:aString] == SBOrderSame) )
        return i;
      i++;
    }
  }
  return kSBHTTPMethodUnspecified;
}

//

SBHTTPMethod
SBHTTPMethodFromEnv()
{
  const char*   methodStr = getenv("REQUEST_METHOD");
  
  if ( methodStr ) {
    int           i = 0, iMax = kSBHTTPMethodINVALID + 1;
    
    while ( i < iMax ) {
      if ( strcasecmp(methodStr, __SBHTTPMethodCStrings[i]) == 0 )
        return i;
      i++;
    }
  }
  return kSBHTTPMethodUnspecified;
}

//

BOOL
SBHTTPIsFormData(
  SBMIMEType*   mimeType,
  BOOL          *isMultipart,
  SBCGI*        self
)
{
  SBString*     mediaType = [mimeType mediaType];
  SBString*     subType = [mimeType mediaSubType];
  
  if ( (mediaType && ([mediaType caseInsensitiveCompare:@"multipart"] == SBOrderSame)) && (subType && ([subType caseInsensitiveCompare:@"form-data"] == SBOrderSame)) ) {
    *isMultipart = YES;
    return YES;
  }
  
  if ( (mediaType && ([mediaType caseInsensitiveCompare:@"application"] == SBOrderSame)) && (subType && ([subType caseInsensitiveCompare:@"x-www-form-urlencoded"] == SBOrderSame)) ) {
    *isMultipart = NO;
    return YES;
  }
  
  return NO;
}

//

char*
strnchr(
  const char  *s,
  size_t      n,
  int         c
)
{
  while ( n-- && ((c == 0) || *s) ) {
    if ( *s == (char)c ) return (char*)s;
    s++;
  }
  return NULL;
}

//
#pragma mark -
//

@interface SBCGI(SBCGIPrivate)

- (void) parseQueryArguments;

@end

@implementation SBCGI(SBCGIPrivate)

  - (void) parseQueryArguments
  {
    SBMutableDictionary*    d = [[SBMutableDictionary alloc] init];
    char*                   queryStr = getenv("QUERY_STRING");
    
    if ( queryStr ) {
      char*                 sKey = queryStr;
      char*                 eKey;
      
      while ( sKey && (eKey = strchr(sKey, '=')) ) {
        // Found an '=' sign, now isolate the value:
        char*               sVal = eKey + 1;
        char*               eVal = strchr(sVal, '&');
        
        SBString*   key = [[SBString alloc] initWithURLEncodedUTF8String:sKey length:(eKey - sKey)];
        SBString*   value;
        
        if ( eVal )
          value = [[SBString alloc] initWithURLEncodedUTF8String:sVal length:(eVal - sVal)];
        else
          value = [[SBString alloc] initWithURLEncodedUTF8String:sVal];
        
        [d setObject:value forKey:key];
        [key release];
        [value release];
        
        sKey = ( eVal ? eVal + 1 : NULL );
      }
    }
    
    //
    // Check if the content type says we're getting form data:
    //
    SBMIMEType*     contentType = [self contentType];
    BOOL            isMultipart;
    
    if ( contentType && SBHTTPIsFormData(contentType, &isMultipart,self) ) {
      SBFileHandle* inputFH = [SBFileHandle fileHandleWithStandardInput];
      SBUInteger    dataLen = [self contentLength];
      SBData*       inputData = nil;
      
      if ( dataLen > 0 ) {
        inputData = [inputFH readDataOfLength:dataLen];
      } else {
        inputData = [inputFH readDataToEndOfFile];
      }
      if ( inputData ) {
        //
        // Parse the data:
        //
        if ( isMultipart ) {
          // T.B.D.
          [self appendStringToResponseText:[contentType mediaType]];
          [self appendStringToResponseText:@"/"];
          [self appendStringToResponseText:[contentType mediaSubType]];
        } else {
          queryStr = (char*)[inputData bytes];
          dataLen = [inputData length];
          
          char*                 sKey = queryStr;
          char*                 eKey;
          
          while ( dataLen && sKey && (eKey = strnchr(sKey, dataLen, '=')) ) {
            // Found an '=' sign, now isolate the value:
            SBString*           key = [[SBString alloc] initWithURLEncodedUTF8String:sKey length:(eKey - sKey) fromFormData:YES];
            SBString*           value;
            
            char*               sVal = eKey + 1;
            
            dataLen -= sVal - sKey;
            
            char*               eVal = strnchr(sVal, dataLen, '&');
            
            if ( eVal )
              value = [[SBString alloc] initWithURLEncodedUTF8String:sVal length:(eVal - sVal) fromFormData:YES];
            else
              value = [[SBString alloc] initWithURLEncodedUTF8String:sVal length:dataLen fromFormData:YES];
            
            [d setObject:value forKey:key];
            [key release];
            [value release];
            
            sKey = ( eVal ? eVal + 1 : NULL );
            dataLen = ( eVal ? dataLen - (sKey - sVal) : 0 );
          }
        }
      } else {
        [self appendStringToResponseText:@"No data."];
      }
    }
      
    if ( [d count] )
      _queryArguments = [d copy];
    [d release];
    
    _flags |= kSBCGIFlagQueryStringHasBeenParsed;
  }

@end

//
#pragma mark -
//

@implementation SBCGI

  - (id) init
  {
    if ( (self = [super init]) ) {
      if ( (_requestMethod = SBHTTPMethodFromEnv()) == kSBHTTPMethodUnspecified ) {
        [self release];
        return nil;
      }
      _remotePort = _serverPort = _isSecureHTTP = -1;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _requestHost ) [_requestHost release];
    if ( _requestUserAgent ) [_requestUserAgent release];
    if ( _requestURI ) [_requestURI release];
    if ( _scriptName ) [_scriptName release];
    if ( _pathInfo ) [_pathInfo release];
    if ( _contentType ) [_contentType release];
    if ( _queryArguments ) [_queryArguments release];
    if ( _serverName ) [_serverName release];
    if ( _serverInetAddress ) [_serverInetAddress release];
    if ( _serverSoftware ) [_serverSoftware release];
    if ( _remoteInetAddress ) [_remoteInetAddress release];
		if ( _remoteUser ) [_remoteUser release];
    if ( _responseHeaders ) [_responseHeaders release];
		if ( _responseText ) [_responseText release];
    
    [super dealloc];
  }

//

  - (SBString*) requestHost
  {
    if ( ! _requestHost ) {
      const char*     requestHost = getenv("HTTP_HOST");
      
      if ( requestHost )
        _requestHost = [[SBString alloc] initWithUTF8String:requestHost];
    }
    return _requestHost;
  }
	
//

  - (SBHTTPMethod) requestMethod
  {
    return _requestMethod;
  }

//

  - (SBString*) requestUserAgent
  {
    if ( ! _requestUserAgent ) {
      const char*     userAgent = getenv("HTTP_USER_AGENT");
      
      if ( userAgent )
        _requestUserAgent = [[SBString alloc] initWithUTF8String:userAgent];
    }
    return _requestUserAgent;
  }
	
//

  - (SBString*) requestURI
  {
    if ( ! _requestURI ) {
      const char*     requestURI = getenv("REQUEST_URI");
      
      if ( requestURI )
        _requestURI = [[SBString alloc] initWithUTF8String:requestURI];
    }
    return _requestURI;
  }
  
//

	- (BOOL) isSecureHTTP
	{
		if ( _isSecureHTTP == -1 ) {
			const char*			https = getenv("HTTPS");
			
			if ( https && ! strcasecmp(https, "on") )
				_isSecureHTTP = YES;
			else
				_isSecureHTTP = NO;
		}
		return _isSecureHTTP;
	}

//

	- (SBString*) scriptName
	{
		if ( ! _scriptName ) {
      const char*     scriptName = getenv("SCRIPT_NAME");
      
      if ( scriptName )
        _scriptName = [[SBString alloc] initWithUTF8String:scriptName];
		}
		return _scriptName;
	}

//

	- (SBString*) pathInfo
	{
		if ( ! _pathInfo ) {
      const char*     pathInfo = getenv("PATH_INFO");
      
      if ( pathInfo )
        _pathInfo = [[SBString alloc] initWithUTF8String:pathInfo];
		}
		return _pathInfo;
	}

//

  - (SBUInteger) contentLength
  {
    if ( ! _contentLengthSet ) {
      const char*     contentLength = getenv("CONTENT_LENGTH");
      
      if ( contentLength )
        _contentLength = (SBUInteger)strtoll(contentLength, NULL, 10);
      _contentLengthSet = YES;
    }
    return _contentLength;
  }
  - (SBMIMEType*) contentType
  {
    if ( ! _contentType ) {
      const char*     contentType = getenv("CONTENT_TYPE");
      
      if ( contentType )
        _contentType = [[SBMIMEType alloc] initWithString:[SBString stringWithUTF8String:contentType]];
    }
    return _contentType;
  }

//

  - (SBString*) serverName
  {
    if ( ! _serverName ) {
      const char*     serverName = getenv("SERVER_NAME");
      
      if ( serverName )
        _serverName = [[SBString alloc] initWithUTF8String:serverName];
    }
    return _serverName;
  }
	
//

  - (SBInetAddress*) serverInetAddress
  {
    if ( ! _serverInetAddress ) {
      const char*     serverAddr = getenv("SERVER_ADDR");
      
      if ( serverAddr )
        _serverInetAddress = [[SBInetAddress inetAddressWithCString:serverAddr] retain];
    }
    return _serverInetAddress;
  }
	
//

  - (SBInteger) serverPort
  {
    if ( _serverPort == -1 ) {
      const char*     serverPort = getenv("SERVER_PORT");
      
      if ( serverPort )
        _serverPort = strtol(serverPort, NULL, 10);
    }
    return _serverPort;
  }
	
//

  - (SBString*) serverSoftware
  {
    if ( ! _serverSoftware ) {
      const char*     serverSoftware = getenv("SERVER_SOFTWARE");
      
      if ( serverSoftware )
        _serverSoftware = [[SBString alloc] initWithUTF8String:serverSoftware];
    }
    return _serverSoftware;
  }

//

  - (SBInetAddress*) remoteInetAddress
  {
    if ( ! _remoteInetAddress ) {
      const char*     remoteAddr = getenv("REMOTE_ADDR");
      
      if ( remoteAddr )
        _remoteInetAddress = [[SBInetAddress inetAddressWithCString:remoteAddr] retain];
    }
    return _remoteInetAddress;
  }
	
//

  - (SBInteger) remotePort
  {
    if ( _remotePort == -1 ) {
      const char*     remotePort = getenv("REMOTE_PORT");
      
      if ( remotePort )
        _remotePort = strtol(remotePort, NULL, 10);
    }
    return _remotePort;
  }
	
//

	- (SBString*) remoteUser
	{
		if ( ! _remoteUser ) {
      const char*     remoteUser = getenv("REMOTE_USER");
      
      if ( remoteUser )
        _remoteUser = [[SBString alloc] initWithUTF8String:remoteUser];
		}
		return _remoteUser;
	}

//

  - (SBDictionary*) queryArguments
  {
    if ( ! (_flags & kSBCGIFlagQueryStringHasBeenParsed) )
      [self parseQueryArguments];
    return _queryArguments;
  }
  - (SBString*) queryArgumentForKey:(SBString*)key
  {
    if ( ! (_flags & kSBCGIFlagQueryStringHasBeenParsed) )
      [self parseQueryArguments];
    if ( _queryArguments )
      return [_queryArguments objectForKey:key];
    return nil;
  }

//

  - (SBString*) responseHeaderValueForName:(SBString*)name
  {
    if ( _responseHeaders && name )
      return [_responseHeaders objectForKey:[name normalizedHTTPToken]];
    return nil;
  }
  - (void) setResponseHeaderValue:(SBString*)value
    forName:(SBString*)name
  {
    if ( _responseHeadersSent )
      return;
      
    if ( (name = [name normalizedHTTPToken]) ) {
      if ( ! _responseHeaders && value ) {
        _responseHeaders = [[SBMutableDictionary alloc] initWithObjects:&value forKeys:&name count:1];
      } else if ( value ) {
        [_responseHeaders setObject:value forKey:name];
      } else {
        [_responseHeaders removeObjectForKey:name];
      }
    }
  }

//

  - (void) sendResponseHeaders
  {
    SBString*         k;
    SBString*         v;
    
    if ( _responseHeadersSent )
      return;
    
    //
    // Send a content type:
    //
    v = [self responseHeaderValueForName:@"Content-Type"];
    if ( ! v ) {
      printf("Content-Type: text/plain; charset=utf-8\r\n");
    }
    if ( _responseHeaders && [_responseHeaders count] ) {
      //
      // Loop over all headers:
      //
      SBEnumerator*     kEnum = [_responseHeaders keyEnumerator];
      
      if ( kEnum ) {
        while ( (k = [kEnum nextObject]) ) {
          v = [_responseHeaders objectForKey:k];
          [k writeToStream:stdout];
          printf(": ");
          if ( v )
            [v writeToStream:stdout];
          printf("\r\n");
        }
      }
    }
    printf("\r\n");
    fflush(stdout);
    _responseHeadersSent = YES;
  }
  
//

	- (SBMutableString*) responseText
	{
		if ( ! _responseText )
			_responseText = [[SBMutableString alloc] init];
		return _responseText;
	}
	
//

	- (void) appendStringToResponseText:(SBString*)aString
	{
		SBMutableString*		text = [self responseText];
		
		if ( text )
			[text appendString:aString];
	}
	
//

	- (void) appendFormatToResponseText:(const char*)format,
		...
	{
		va_list							vargs;
		SBString*						newText;
		
		va_start(vargs, format);
		newText = [[SBString alloc] initWithFormat:format arguments:vargs];
		va_end(vargs);
		
		if ( newText ) {
			[self appendStringToResponseText:newText];
			[newText release];
		}
	}
	
//

	- (void) clearResponseText
	{
		if ( _responseText )
			[_responseText deleteAllCharacters];
	}

//

	- (void) sendResponse
	{
		if ( _responseText ) {
			if ( ! _responseHeadersSent ) {
				// Tack-on a content length if it wasn't present:
				if ( ! [self responseHeaderValueForName:@"Content-Length"] ) {
					[self setResponseHeaderValue:[SBString stringWithFormat:"%lld", (long long int)[_responseText length]]
							forName:@"Content-Length"];
				}
				// Send the response headers:
				[self sendResponseHeaders];
			}
			// Send the text:
			[_responseText writeToStream:stdout];
      fflush(stdout);
		} else {
			// Just be sure we sent the response headers...
			[self sendResponseHeaders];
		}
	}

//

  - (void) sendDebuggingData
  {
    SBString*					host = [self requestHost];
		SBString*					agent = [self requestUserAgent];
		SBString*					uri = [self requestURI];
		SBString*					pathInfo = [self pathInfo];
		SBString*					server = [self serverName];
    SBInetAddress*		inetAddr;
    
		[self appendFormatToResponseText:
								"Method:    %s\n"
								"Host:      %S\n"
								"Agent:     %S\n"
								"URI:       %S\n"
								"Path Info: %S\n"
								"Server:    %S : %d\n",
								__SBHTTPMethodCStrings[ [self requestMethod] ],
								( host ? [host utf16Characters] : (UChar*)"" ),
								( agent ? [agent utf16Characters] : (UChar*)"" ),
								( uri ? [uri utf16Characters] : (UChar*)"" ),
								( pathInfo ? [pathInfo utf16Characters] : (UChar*)"" ),
								( server ? [server utf16Characters] : (UChar*)"" ),
								[self serverPort]
							];
    
    if ( (inetAddr = [self remoteInetAddress]) ) {
			SBString*			asString = [inetAddr inetAddressAsString];
			
			[self appendFormatToResponseText:"Remote:    %S : %d\n", [asString utf16Characters], [self remotePort]];
			if ( (asString = [self remoteUser]) ) {
				[self appendFormatToResponseText:"           `%S`\n", [asString utf16Characters]];
			}
    }
    
		[self sendResponse];
  }

@end
