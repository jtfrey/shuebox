//
// SBFoundation : ObjC Class Library for Solaris
// SBError.h
//
// Generic class for returning error information to a caller.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBDictionary, SBMailer;

/*!
  @const SBPOSIXErrorDomain
  @discussion
  String constant used to describe error objects associated with the POSIX/UNIX layer of
  the system.
*/
extern SBString* SBPOSIXErrorDomain;

/*!
  @const SBFoundationErrorDomain
  @discussion
  String constant used to describe error objects associated with the SBFoundation
  library and its components.
*/
extern SBString* SBFoundationErrorDomain;

/*!
  @class SBError
  @discussion
  An instance of SBError is used to pass richer exception information back to a calling
  routine.  All errors have a "domain" which describes the layer of the system which
  produced the error (POSIX function call, SBFoundation routine, etc).  The error code
  is a signed integer (the errno from a POSIX failure, for example).  Any additional
  bits of information that explain the error further are contained in an SBDictionary
  associated with the SBError object.
*/
@interface SBError : SBObject
{
  SBString*       _domain;
  int             _code;
  SBDictionary*   _supportingData;
}

/*!
  @method posixErrorWithCode:supportingData:
  @discussion
  Returns an autoreleased instance which wraps an error in the SBPOSIXErrorDomain with
  the provided code and supporting data.
*/
+ (id) posixErrorWithCode:(int)code supportingData:(SBDictionary*)data;
/*!
  @method foundationErrorWithCode:supportingData:
  @discussion
  Returns an autoreleased instance which wraps an error in the SBFoundationErrorDomain with
  the provided code and supporting data.
*/
+ (id) foundationErrorWithCode:(int)code supportingData:(SBDictionary*)data;
/*!
  @method errorWithDomain:code:supportingData:
  @discussion
  Returns an autoreleased instance which wraps an error in the specified domain with the
  provided code and supporting data.
*/
+ (id) errorWithDomain:(SBString*)domain code:(int)code supportingData:(SBDictionary*)data;

/*!
  @method initWithDomain:code:supportingData:
  @discussion
  Initializes a newly-allocated instance.  The domain must be a non-nil, non-zero-length
  SBString object, otherwise the instance is released and nil is returned.
  
  The domain string and data dictionary are sent the "copy" message to retain an immutable
  copy for the receiver.
*/
- (id) initWithDomain:(SBString*)domain code:(int)code supportingData:(SBDictionary*)data;

/*!
  @method domain
  @discussion
  Returns the receiver's error domain string.
*/
- (SBString*) domain;
/*!
  @method code
  @discussion
  Returns the receiver's error code.
*/
- (int) code;
/*!
  @method supportingData
  @discussion
  Returns the receiver's supportingData dictionary.
*/
- (SBDictionary*) supportingData;

/*!
  @method writeErrorSummaryToStream:
  @discussion
  Presents a formatted TTY display of the error.
*/
- (void) writeErrorSummaryToStream:(FILE*)stream;

/*!
  @method emailErrorSummaryWithMailer:
  @discussion
  Uses the provided SBMailer to send an email containing the error summary.
*/
- (void) emailErrorSummaryWithMailer:(SBMailer*)aMailer;

@end

/*!
  @const SBErrorExplanationKey
  @discussion
  Standard key which should be used for explanatory text added to a supporting data
  dictionary; value is "explanation".
*/
extern SBString* SBErrorExplanationKey;
