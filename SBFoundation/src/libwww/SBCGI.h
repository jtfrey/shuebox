//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBCGI.h
//
// Basic framework for a CGI.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBHTTP.h"
#import "SBString.h"

@class SBDictionary, SBMutableDictionary, SBInetAddress;


/*!
  @typedef SBHTTPMethod
  @discussion
    An enumeration of the (known) HTTP methods to which this class responds.  Includes all of the
    methods defined by the DAV extension of HTTP.
*/
typedef enum {
  kSBHTTPMethodUnspecified = -1,
  kSBHTTPMethodGET = 0,
  kSBHTTPMethodPUT = 1,
  kSBHTTPMethodPOST = 2,
  kSBHTTPMethodDELETE = 3,
  kSBHTTPMethodCONNECT = 4,
  kSBHTTPMethodOPTIONS = 5,
  kSBHTTPMethodTRACE = 6,
  kSBHTTPMethodPATCH = 7,
  kSBHTTPMethodPROPFIND = 8,
  kSBHTTPMethodPROPPATCH = 9,
  kSBHTTPMethodMKCOL = 10,
  kSBHTTPMethodCOPY = 11,
  kSBHTTPMethodMOVE = 12,
  kSBHTTPMethodLOCK = 13,
  kSBHTTPMethodUNLOCK = 14,
  kSBHTTPMethodVERSION_CONTROL = 15,
  kSBHTTPMethodCHECKOUT = 16,
  kSBHTTPMethodUNCHECKOUT = 17,
  kSBHTTPMethodCHECKIN = 18,
  kSBHTTPMethodUPDATE = 19,
  kSBHTTPMethodLABEL = 20,
  kSBHTTPMethodREPORT = 21,
  kSBHTTPMethodMKWORKSPACE = 22,
  kSBHTTPMethodMKACTIVITY = 23,
  kSBHTTPMethodBASELINE_CONTROL = 24,
  kSBHTTPMethodMERGE = 25,
  kSBHTTPMethodINVALID = 26
} SBHTTPMethod;

/*!
  @function SBHTTPMethodToString
  @discussion
    Given an integral HTTP method identifier (from SBHTTPMethod), return an SBString containing
    the textual form of that method.
*/
SBString* SBHTTPMethodToString(SBHTTPMethod method);

/*!
  @function SBHTTPMethodFromString
  @discussion
    Parse aString and return the corresponding integral HTTP method identifier (from SBHTTPMethod).
    If aString does not contain a known HTTP method then kSBHTTPMethodINVALID is returned.
*/
SBHTTPMethod SBHTTPMethodFromString(SBString* aString);

/*!
  @function SBHTTPMethodFromEnv
  @discussion
    Similar to SBHTTPMethodFromString() with the string coming from the REQUEST_METHOD environment
    variable.
*/
SBHTTPMethod SBHTTPMethodFromEnv(void);

//


/*!
  @class SBCGI
  @abstract
    CGI handler
  @discussion
    The SBCGI class forms the basis for creating CGI programs.  It is aware of the standard environment
    variables set by Apache and by default initializes itself according to them.
    
    After an instance has been allocated and initialized, a response to the request can be composed.
    This amounts to adding HTTP headers and building the response text.  When processing has completed,
    the headers and response are "sent" by being output to stdout (where Apache will intercept and
    transmit them back to the remote agent).
*/
@interface SBCGI : SBObject
{
  SBUInteger                _flags;
  //
  SBString*                 _requestHost;
  SBHTTPMethod              _requestMethod;
  SBString*                 _requestUserAgent;
  SBString*                 _requestURI;
	//
	SBInteger									_isSecureHTTP;
	//
  SBString*                 _scriptName;
	SBString*									_pathInfo;
  //
  SBUInteger                _contentLength;
  BOOL                      _contentLengthSet;
  SBMIMEType*               _contentType;
  //
  SBDictionary*             _queryArguments;
  //
  SBString*                 _serverName;
  SBInetAddress*            _serverInetAddress;
  SBInteger                 _serverPort;
  SBString*                 _serverSoftware;
  //
  SBInetAddress*            _remoteInetAddress;
  SBInteger                 _remotePort;
	SBString*									_remoteUser;
  //
  SBMutableDictionary*      _responseHeaders;
  BOOL                      _responseHeadersSent;
	//
	SBMutableString*					_responseText;
}

/*!
  @method init
  @discussion
    Designated initializer; synthesize the CGI state from the standard Apache CGI environment
    variables.  At the very least the REQUEST_METHOD variable must be set in the environment, or
    the receiver will be released and nil returned.
*/
- (id) init;

/*!
  @method requestHost
  @discussion
    Returns the value of the HTTP_HOST CGI variable.
*/
- (SBString*) requestHost;

/*!
  @method requestMethod
  @discussion
    Returns the receiver's integral HTTP method (from SBHTTPMethod).
*/
- (SBHTTPMethod) requestMethod;

/*!
  @method requestUserAgent
  @discussion
    Returns the value of the HTTP_USER_AGENT CGI variable.
*/
- (SBString*) requestUserAgent;

/*!
  @method requestURI
  @discussion
    Returns the value of the REQUEST_URI CGI variable.
*/
- (SBString*) requestURI;

/*!
  @method isSecureHTTP
  @discussion
    Returns boolean YES if the request was made via an SSL-secured HTTP connection.
*/
- (BOOL) isSecureHTTP;

/*!
  @method scriptName
  @discussion
    Returns the value of the SCRIPT_NAME CGI variable.
*/
- (SBString*) scriptName;

/*!
  @method pathInfo
  @discussion
    Returns the value of the PATH_INFO CGI variable.  Path info is any additional
    hierarchical component of the requested URI that extends past the handled
    target -- mostly used for REST APIs, etc.
*/
- (SBString*) pathInfo;

/*!
  @method contentLength
  @discussion
    Returns the length (in bytes) of the content associated with the request (as
    provided in the CONTENT_LENGTH CGI variable).
*/
- (SBUInteger) contentLength;

/*!
  @method contentType
  @discussion
    Returns the MIME type of the content associated with the request (as provided
    in the CONTENT_TYPE CGI variable).
*/
- (SBMIMEType*) contentType;

/*!
  @method serverName
  @discussion
    Returns the value of the SERVER_NAME CGI variable.
*/
- (SBString*) serverName;

/*!
  @method serverInetAddress
  @discussion
    Returns the value of the SERVER_ADDR CGI variable.
*/
- (SBInetAddress*) serverInetAddress;

/*!
  @method serverPort
  @discussion
    Returns the value of the SERVER_PORT CGI variable.
*/
- (SBInteger) serverPort;

/*!
  @method serverSoftware
  @discussion
    Returns the value of the SERVER_SOFTWARE CGI variable.
*/
- (SBString*) serverSoftware;

/*!
  @method remoteInetAddress
  @discussion
    Returns the value of the REMOTE_ADDR CGI variable.
*/
- (SBInetAddress*) remoteInetAddress;

/*!
  @method remotePort
  @discussion
    Returns the value of the REMOTE_PORT CGI variable.
*/
- (SBInteger) remotePort;

/*!
  @method remoteUser
  @discussion
    Returns the value of the REMOTE_USER CGI variable.
*/
- (SBString*) remoteUser;

/*!
  @method queryArguments
  @discussion
    Returns an SBDictionary containing all query parameters that were part of the request
    associated with the receiver.
*/
- (SBDictionary*) queryArguments;

/*!
  @method queryArgumentForKey:
  @discussion
    If the request associated with the receiver contained a query parameter with a name
    matching key, returns that parameter's value.  Otherwise, returns nil.
*/
- (SBString*) queryArgumentForKey:(SBString*)key;

/*!
  @method responseHeaderValueForName:
  @discussion
    Check the receiver's dictionary of response headers for one matching name and return
    its value if found.  Otherwise, returns nil.
*/
- (SBString*) responseHeaderValueForName:(SBString*)name;
/*!
  @method setResponseHeaderValue:forName:
  @discussion
    If response headers have not yet been sent, set the given value for the HTTP header
    with the given name.
    
    The name argument is normalized before being used so only a single value is
    allowed.
    
    If value is nil then the given HTTP header is expunged.
*/
- (void) setResponseHeaderValue:(SBString*)value forName:(SBString*)name;

/*!
  @method sendResponseHeaders
  @discussion
    Write all reponse headers associated with the receiver to stdout and terminate
    the header section of the response in preparation for response content.
*/
- (void) sendResponseHeaders;

/*!
  @method responseText
  @discussion
    Returns the receiver's response text accumulator.
*/
- (SBMutableString*) responseText;

/*!
  @method appendStringToResponseText:
  @discussion
    Append aString to the receiver's response text accumulator.
*/
- (void) appendStringToResponseText:(SBString*)aString;

/*!
  @method appendFormatToResponseText:,...
  @discussion
    Convert the variable argument list to a string following the specified format
    and append the result to the receiver's response text accumulator.
*/
- (void) appendFormatToResponseText:(const char*)format,...;

/*!
  @method clearResponseText
  @discussion
    Discard any text already present in the receiver's response text accumulator.
*/
- (void) clearResponseText;

/*!
  @method sendResponse
  @discussion
    If response headers were not previously (explicitly) sent, do so now and append a
    Content-Length header given the size of the receiver's response text accumlator.
    Write the response text to stdout thereafter.
*/
- (void) sendResponse;

/*!
  @method sendDebuggingData
  @discussion
    Appends a descripion of the CGI environment to the receiver's response text
    accumulator and sends it the sendResponse message.
*/
- (void) sendDebuggingData;

@end
