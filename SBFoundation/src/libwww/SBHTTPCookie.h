//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBHTTPCookie.h
//
// Base class for HTTP cookie handling.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBHTTP.h"
#import "SBDictionary.h"

@class SBString, SBDate;

/*!
  @class SBHTTPCookie
  @discussion
    Instances of SBHTTPCookie represent an HTTP cookie.  A cookie is a key (name) and value with some
    optional modifiers (ttl, base path/domain, and SSL requirement).
    
    This class adopts the SBHTTPHeaderSupport protocol for the sake of appending HTTP cookie headers
    to response data.
*/
@interface SBHTTPCookie : SBObject <SBHTTPHeaderSupport>
{
  SBString*       _cookieName;
  SBString*       _cookieValue;
  SBInteger       _timeToLive;
  SBString*       _basePath;
  SBString*       _baseDomain;
  BOOL            _secureConnectionRequired;
}

/*!
  @method cookiesFromEnv
  @discussion
    Extract all cookies from the HTTP_COOKIE environment variable and return an SBDictionary
    keyed by the cookie names.
*/
+ (SBDictionary*) cookiesFromEnv;

/*!
  @method initWithCookieName:andValue:
  @discussion
    Initialize the receiver to have the given cookie name and value.
*/
- (id) initWithCookieName:(SBString*)name andValue:(SBString*)value;

/*!
  @method cookieName
  @discussion
    Returns the receiver's cookie name.
*/
- (SBString*) cookieName;

/*!
  @method setCookieName:
  @discussion
    Set the receiver's cookie name to aString.
*/
- (void) setCookieName:(SBString*)aString;

/*!
  @method cookieValue
  @discussion
    Returns the receiver's cookie value.
*/
- (SBString*) cookieValue;

/*!
  @method setCookieValue:
  @discussion
    Set the receiver's cookie value to aString.
*/
- (void) setCookieValue:(SBString*)aString;

/*!
  @method timeToLive
  @discussion
    Returns the receiver's time-to-live (in seconds).  If there is no expiration for
    a cookie the time-to-live is zero.
*/
- (SBInteger) timeToLive;

/*!
  @method setTimeToLive
  @discussion
    Set the receiver's time-to-live to the given ttl (in seconds).  If ttl is zero
    then the cookie will not be set to expire.
*/
- (void) setTimeToLive:(SBInteger)ttl;

/*!
  @method expirationDate
  @discussion
    Returns the receiver's expiration date.  If the cookie does not expire then
    nil is returned.
*/
- (SBDate*) expirationDate;

/*!
  @method setExpirationDate:
  @discussion
    Set the receiver to expire on the given date.  If expirationDate is nil then
    the cookie with not be set to expire.
*/
- (void) setExpirationDate:(SBDate*)expirationDate;

/*!
  @method basePath
  @discussion
    Returns the base path for which the receiver's cookie is valid.
*/
- (SBString*) basePath;

/*!
  @method setBasePath:
  @discussion
    Set the base path for which the receiver's cookie is valid.
*/
- (void) setBasePath:(SBString*)aString;

/*!
  @method baseDomain
  @discussion
    Returns the base DNS domain for which the receiver's cookie is valid.
*/
- (SBString*) baseDomain;

/*!
  @method setBaseDomain:
  @discussion
    Set the base DNS domain for which the receiver's cookie is valid.
*/
- (void) setBaseDomain:(SBString*)aString;

/*!
  @method secureConnectionRequired
  @discussion
    Returns boolean YES if the receiver's cookie requires the SSL-encrypted
    HTTP protocol.
*/
- (BOOL) secureConnectionRequired;

/*!
  @method setSecureConnectionRequired:
  @discussion
    If secureConnectionRequired is boolean YES then the receiver's cookie requires
    the SSL-encrypted HTTP protocol for transmission.
*/
- (void) setSecureConnectionRequired:(BOOL)secureConnectionRequired;

/*!
  @method asString
  @discussion
    Return an SBString containing the textual form of the receiver's cookie.
*/
- (SBString*) asString;

@end

//

/*!
  @category SBDictionary(SBHTTPCookieAdditions)
  @discussion
    Additions to the SBDictionary class to support HTTP cookies.
*/
@interface SBDictionary(SBHTTPCookieAdditions)

/*!
  @method dictionaryWithCookiesFromEnv
  @discussion
    Extract all cookies from the HTTP_COOKIE environment variable and return an SBDictionary
    keyed by the cookie names.
*/
+ (SBDictionary*) dictionaryWithCookiesFromEnv;

/*!
  @method dictionaryWithCookieString:
  @discussion
    Extract all cookies from cookieString and return an SBDictionary keyed by the cookie names.
*/
+ (SBDictionary*) dictionaryWithCookieString:(SBString*)cookieString;

/*!
  @method initWithCookiesFromEnv
  @discussion
    Initialize the receiver to contain (keyed by name) all cookies present in the HTTP_COOKIE
    environment variable.
*/
- (id) initWithCookiesFromEnv;

/*!
  @method initWithCookieString:
  @discussion
    Initialize the receiver to contain (keyed by name) all cookies present in the cookieString.
*/
- (id) initWithCookieString:(SBString*)cookieString;

@end
