//
// SBFoundation : ObjC Class Library for Solaris
// SBURL.h
//
// Wrap a generic URL.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"
#import "SBData.h"
#import "SBDictionary.h"

@class SBNumber, SBError;

/*!
  @const SBURLLoadErrorDomain
  @discussion
  Name of the error domain for errors produced by the SBURL resource
  retrieval functionality.
*/
extern SBString* SBURLLoadErrorDomain;

/*!
  @enum SBURL resource retrieval error codes
  @discussion
  Error codes for SBURLLoadErrorDomain
*/
enum {
  kSBURLLoadOkay              = 0,
  
  kSBURLLoadSystemError,
  kSBURLLoadParameterError
};

/*!
  @const SBURLFileScheme
  @discussion
  String constant which contains "file".
*/
extern SBString* SBURLFileScheme;

/*!
  @class SBURL
  @discussion
  Instances of SBURL break a string containing a URL into its component pieces
  (host name and port, scheme, etc).  The individual pieces may then be accessed
  using simple accessor methods.  A URL decomposes at first into
  
    <scheme>:<resource specifier>
    
  The resource specifier then further decomposes in a scheme-specific way; the
  generic pieces of the resource specifier are
  
    ((user)(:password)@)(hostname(:port))/(uri)
  
  The SBURL class also implements a very basic URL resource retrieval
  mechanism on top of the cURL library.  Basically, you can ask for the resource
  and/or any HTTP headers associated with the URL and you'll get back an SBData
  and/or SBMutableDictionary object, respectively.  The retrieval is not
  asynchronous so the calls will block while the cURL retrieves the URL.
*/
@interface SBURL : SBObject
{
  SBString*       _urlString;
  SBRange         _parts[13];
  id              _cache[8];
}

/*!
  @method urlWithScheme:host:uri:
  @discussion
  Returns an autoreleased instance initialized according to the basic URL components
  provided.  Only the scheme is required to be non-nil:  the URI with scheme
  "file" and a nil host and uri is "file:///" and is perfectly valid.
*/
+ (id) urlWithScheme:(SBString*)scheme host:(SBString*)host uri:(SBString*)uri;
/*!
  @method urlWithFilePath:
  @discussion
  Convenience method which calls-through as
  
    ... initWithScheme:SBURLFileScheme host:nil uri:filepath]
    
  If the provided filepath begins with a character other than '/', then the path
  is taken to be relative to an arbitrary (but implicit) root path.
*/
+ (id) urlWithFilePath:(SBString*)filepath;
/*!
  @method urlWithString:
  @discussion
  Returns an autoreleased instance initialized by parsing the given urlString.
  If urlString was not recognizable as a URL, nil is returned.
*/
+ (id) urlWithString:(SBString*)urlString;
/*!
  @method initWithScheme:host:uri:
  @discussion
  Initializes a newly-allocated instance according to the basic URL components
  provided.  Only the scheme is required to be non-nil:  the URI with scheme
  "file" and a nil host and uri is "file:///" and is perfectly valid.
*/
- (id) initWithScheme:(SBString*)scheme host:(SBString*)host uri:(SBString*)uri;
/*!
  @method initWithFilePath:
  @discussion
  Convenience method which calls-through as
  
    ... initWithScheme:SBURLFileScheme host:nil uri:filepath]
    
  If the provided filepath begins with a character other than '/', then the path
  is taken to be relative to an arbitrary (but implicit) root path.
*/
- (id) initWithFilePath:(SBString*)filepath;
/*!
  @method initWithString:
  @discussion
  Initializes a newly-allocated instance by parsing the given urlString.  If urlString
  was not recognizable as a URL, the instance is released and nil is returned.
*/
- (id) initWithString:(SBString*)urlString;
/*!
  @method scheme
  @discussion
  Returns a string containing the scheme portion of the receiver's URL.
*/
- (SBString*) scheme;
/*!
  @method resourceSpecifier
  @discussion
  Returns a string containing the resource specifier portion of the receiver's URL.
*/
- (SBString*) resourceSpecifier;
/*!
  @method user
  @discussion
  Returns a string containing the user that was found in the receiver's resource
  specifier, or nil if no user was included in the originating URL.
*/
- (SBString*) user;
/*!
  @method password
  @discussion
  Returns a string containing the password that was found in the receiver's resource
  specifier, or nil if no password was included in the originating URL.
*/
- (SBString*) password;
/*!
  @method host
  @discussion
  Returns a string containing the host that was found in the receiver's resource
  specifier, or nil if no host was included in the originating URL.
*/
- (SBString*) host;
/*!
  @method port
  @discussion
  Returns an SBNumber containing the port number that was found in the receiver's resource
  specifier, or nil if no port number was included in the originating URL.
*/
- (SBNumber*) port;
/*!
  @method uri
  @discussion
  Returns a string containing the URI that was found in the receiver's resource
  specifier, or nil if the originating URL contained no URI.
*/
- (SBString*) uri;
/*!
  @method isFilePathURL
  @discussion
  Returns YES if the receiver contains a URL in the "file" scheme.
*/
- (BOOL) isFilePathURL;
/*!
  @method loadResourceData:
  @discussion
  Convenience method that calls-through as
  
    .. loadResourceData:data headers:NULL];
*/
- (SBError*) loadResourceData:(SBMutableData**)data;
/*!
  @method loadResourceHeaders:
  @discussion
  Convenience method that calls-through as
  
    .. loadResourceData:NULL headers:headers];
*/
- (SBError*) loadResourceHeaders:(SBMutableDictionary**)headers;
/*!
  @method loadResourceData:
  @discussion
  Attempts to load the resource data (and/or HTTP headers) associated with the receiver's
  URL.
  
  The "data" argument is a pointer to an SBMutableData instance -- the instance can a nil
  object, e.g.
  
    SBMutableData*       myData = nil;
    
    [aURL loadResourceData:&myData headers:NULL];
  
  in which case the loadResourceData: method will allocate an SBData object and
  return it at myData.  You can also allocate your own SBData instance and use
  it, e.g.
  
    SBMutableData*       myData = [[SBMutableData alloc] init];
    
    [aURL loadResourceData:&myData headers:NULL];
  
  If "data" is NULL then the receiver will _not_ attempt to retrieve the data associated
  with the resource (e.g. an HTTP HEADER request is performed instead).
  
  The "headers" argument works exactly like the "data" argument.  Pass NULL if you don't
  want the headers or a pointer to an SBMutableDictionary instance.  Again, the instance
  can be nil if you want loadResourceData:headers: to allocate the dictionary for you.
  
  An SBError object will be returned if the retrieval fails for any reason; if the
  retrieval was successful, nil is returned.
*/
- (SBError*) loadResourceData:(SBMutableData**)data headers:(SBMutableDictionary**)headers;

@end

/*!
  @category SBString(SBStringURLLoading)
  @discussion
  Category which groups methods that create/initialize an SBString object with the contents
  of a URL.  These methods will consult the Content-Type header (if available) in order to
  properly transcode the retrieved data into SBString's internal Unicode representation.
*/
@interface SBString(SBStringURLLoading)

/*!
  @method stringWithContentsOfURL:
  @discussion
  Returns an autoreleased instance initialized to contain the textual data retrieved from
  aURL.
*/
+ (id) stringWithContentsOfURL:(SBURL*)aURL;
/*!
  @method initWithContentsOfURL:
  @discussion
  Initializes an instance of SBString to contain the textual data retrieved from aURL.
*/
- (id) initWithContentsOfURL:(SBURL*)aURL;

@end

/*!
  @category SBData(SBDataURLLoading)
  @discussion
  Category which groups methods that create/initialize an SBData object with the contents
  of a URL.
*/
@interface SBData(SBDataURLLoading)

/*!
  @method dataWithContentsOfURL:
  @discussion
  Returns an autoreleased instance initialized to contain the binary data retrieved from
  aURL.
*/
+ (id) dataWithContentsOfURL:(SBURL*)aURL;
/*!
  @method initWithContentsOfURL:
  @discussion
  Initializes an instance of SBData to contain the binary data retrieved from aURL.
*/
- (id) initWithContentsOfURL:(SBURL*)aURL;

@end
