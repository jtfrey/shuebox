//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SBHTTP.h
//
// Base inclusions for HTTP support.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBString.h"
#import "SBCharacterSet.h"

@class SBDictionary;

/*!
  @protocol SBHTTPHeaderSupport
  @discussion
  Protocol which encapsulates methods that can be adopted by classes that
  wish to add HTTP headers to a HTTP session.
*/
@protocol SBHTTPHeaderSupport

/*!
  @method appendHTTPHeaders:
  @discussion
    The receiver should append any HTTP headers to the content string.  If
    the receiver appends a blank line (signaling the end of headers) the behavior
    of the HTTP response will be undefined.
*/
- (void) appendHTTPHeaders:(SBMutableString*)content;

@end


/*!
  @category SBCharacterSet(SBHTTPAdditions)
  @discussion
    Additions to the SBCharacterSet class to provide support for character sets
    associated with the HTTP protocol.
*/
@interface SBCharacterSet(SBHTTPAdditions)

/*!
  @method httpTokenCharacterSet
  @discussion
    Returns a character set whose membership is all characters valid in HTTP
    tokens.
*/
+ (SBCharacterSet*) httpTokenCharacterSet;

@end


/*!
  @category SBString(SBHTTPAdditions)
  @discussion
    Additions to the SBString class to provide support for HTTP/XML string
    handling.
*/
@interface SBString(SBHTTPAdditions)

/*!
  @method stringWithURLEncodedString:
  @discussion
    Returns an autoreleased instance containing a copy of aString for
    which all URL-encoded sequences (%XX) have been decoded.
*/
+ (id) stringWithURLEncodedString:(SBString*)aString;
+ (id) stringWithURLEncodedString:(SBString*)aString fromFormData:(BOOL)fromFormData;

/*!
  @method stringWithURLEncodedUTF8String:
  @discussion
    Returns an autoreleased instance containing a copy of cString for
    which all URL-encoded sequences (%XX) have been decoded.
*/
+ (id) stringWithURLEncodedUTF8String:(const char*)cString;
+ (id) stringWithURLEncodedUTF8String:(const char*)cString fromFormData:(BOOL)fromFormData;

/*!
  @method stringWithURLEncodedUTF8String:length:
  @discussion
    Returns an autoreleased instance containing a copy of the first length
    characters of cString for which all URL-encoded sequences (%XX) have
    been decoded.
*/
+ (id) stringWithURLEncodedUTF8String:(const char*)cString length:(SBUInteger)length;
+ (id) stringWithURLEncodedUTF8String:(const char*)cString length:(SBUInteger)length fromFormData:(BOOL)fromFormData;

/*!
  @method initWithURLEncodedString:
  @discussion
    Initializes the receiver to contain a copy of aString for which all
    URL-encoded sequences (%XX) have been decoded.
*/
- (id) initWithURLEncodedString:(SBString*)aString;
- (id) initWithURLEncodedString:(SBString*)aString fromFormData:(BOOL)fromFormData;

/*!
  @method initWithURLEncodedUTF8String:
  @discussion
    Initializes the receiver to contain a copy of cString for which all
    URL-encoded sequences (%XX) have been decoded.
*/
- (id) initWithURLEncodedUTF8String:(const char*)cString;
- (id) initWithURLEncodedUTF8String:(const char*)cString fromFormData:(BOOL)fromFormData;

/*!
  @method initWithURLEncodedUTF8String:length:
  @discussion
    Initializes the receiver to contain a copy of the first length characters
    of cString for which all URL-encoded sequences (%XX) have been decoded.
*/
- (id) initWithURLEncodedUTF8String:(const char*)cString length:(SBUInteger)length;
- (id) initWithURLEncodedUTF8String:(const char*)cString length:(SBUInteger)length fromFormData:(BOOL)fromFormData;

/*!
  @method stringWithXMLSafeUTF8String:
  @discussion
    Returns an autoreleased instance containing a copy of cString for which
    all XML-unsafe characters have been escaped.
*/
+ (id) stringWithXMLSafeUTF8String:(const char*)cString;

/*!
  @method stringWithXMLSafeUTF8String:length:
  @discussion
    Returns an autoreleased instance containing a copy of the first length
    characters of cString for which all XML-unsafe characters have been escaped.
*/
+ (id) stringWithXMLSafeUTF8String:(const char*)cString length:(SBUInteger)length;

/*!
  @method initWithXMLSafeUTF8String:
  @discussion
    Initializes the receiver to contain a copy of cString for which all
    XML-unsafe characters have been escaped.
*/
- (id) initWithXMLSafeUTF8String:(const char*)cString;

/*!
  @method initWithXMLSafeUTF8String:length:
  @discussion
    Initializes the receiver to contain a copy of the first length characters
    of cString for which all XML-unsafe characters have been escaped.
*/
- (id) initWithXMLSafeUTF8String:(const char*)cString length:(SBUInteger)length;

/*!
  @method decodeURLEncodedString
  @discussion
    Decode all URL-encoded sequences in the receiver and return an SBString
    that contains that form.
    
    If the receiver contains no URL-encoded sequences then it returns itself.
*/
- (SBString*) decodeURLEncodedString;
- (SBString*) decodeURLEncodedStringFromFormData:(BOOL)fromFormData;

/*!
  @method urlEncodedString
  @discussion
    URL-encode the receiver and return an SBString containing that alternate
    form.
    
    If the receiver contains no characters that demand encoding then it
    returns itself.
*/
- (SBString*) urlEncodedString;

/*!
  @method xmlSafeString
  @discussion
    Return a copy of the receiver for which any XML reserved characters have
    been properly escaped.
    
    If the receiver is itself XML-safe then it returns itself.
*/
- (SBString*) xmlSafeString;

/*!
  @method normalizedHTTPToken
  @discussion
    Returns a copy of the receiver that has been normalized as an HTTP protocol
    token.  Normalizing here equates to stripping invalid characters and
    capitalizing any alphabetic characters occurring after a hyphen while
    lowercasing all other alphabetic characters.
*/
- (SBString*) normalizedHTTPToken;

@end


/*!
  @category SBMutableString(SBHTTPAdditions)
  @discussion
    Additions to the SBMutableString class to provide support for HTTP/XML string
    handling.
*/
@interface SBMutableString(SBHTTPAdditions)

/*!
  @method urlEncodeAndAppendString:
  @discussion
    Append aString to the receiver in URL-encoded form.
*/
- (void) urlEncodeAndAppendString:(SBString*)aString;

/*!
  @method makeXMLSafeAndAppendString:
  @discussion
    Append aString to the receiver in XML-safe form.
*/
- (void) makeXMLSafeAndAppendString:(SBString*)aString;

@end


/*!
  @class SBMIMEType
  @discussion
    Instances of SBMIMEType represent a MIME type.  A MIME type consists of a
    media type and sub-type presented as two strings separated by a slash, a'la
    "text/plain".  The MIME type may be augmented by key-value pairs delimited
    by a semi-colon:
    
        text/plain; charset=utf-8; compressed=gz
*/
@interface SBMIMEType : SBObject
{
  SBString*         _mediaType;
  SBString*         _mediaSubType;
  SBDictionary*     _parameters;
}

/*!
  @method mimeTypeWithString:
  @discussion
    Returns an autoreleased instance that contains the parsed components of
    mimeString.  If mimeString is not a valid MIME type string then nil
    is returned.
*/
+ (SBMIMEType*) mimeTypeWithString:(SBString*)mimeString;

/*!
  @method initWithString:
  @discussion
    Initializes the receiver to contain the parsed components of mimeString.
    If mimeString is not a valid MIME type string then the receiver is released
    and nil is returned.
*/
- (id) initWithString:(SBString*)mimeString;

/*!
  @method mediaType
  @discussion
    Return the receiver's media type.
*/
- (SBString*) mediaType;

/*!
  @method mediaSubType
  @discussion
    Return the receiver's media sub-type.
*/
- (SBString*) mediaSubType;

/*!
  @method parameters
  @discussion
    Return the SBDictionary of MIME type paramters associated with the receiver.
*/
- (SBDictionary*) parameters;

/*!
  @method parameterForName:
  @discussion
    If the receiver contains a MIME type parameter with the given parameterName,
    return its value.  Otherwise, nil is returned.
*/
- (SBString*) parameterForName:(SBString*)parameterName;

@end

