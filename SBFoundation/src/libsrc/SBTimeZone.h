//
// SBFoundation : ObjC Class Library for Solaris
// SBTimeZone.h
//
// Time zone management, thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/uloc.h"

/*!
  @class SBTimeZone
  @discussion
  ObjC wrapper to the ICU library's time zone functionality.
*/
@interface SBTimeZone : SBObject
{
  UChar*       _timeZoneIdentifier;
}

/*!
  @method defaultTimeZone
  
  Returns a shared SBTimeZone object which represents the current
  default time zone (according to ICU).
  
  Do not attempt to retain/release the returned object, please.
*/
+ (SBTimeZone*) defaultTimeZone;

+ (SBTimeZone*) utcTimeZone;

/*!
  @method initWithTimeZoneIdentifier:
  
  Initialize a newly-allocated instance using the provided time zone
  identifier.  See ICU documentation for a description of valid time zone
  identifiers. 
*/
- (id) initWithTimeZoneIdentifier:(SBString*)timeZoneId;
/*!
  @method timeZoneIdentifier
  
  Returns a pointer to a C string containing the receiver's canonical time zone
  identifier.
*/
- (UChar*) timeZoneIdentifier;

@end
