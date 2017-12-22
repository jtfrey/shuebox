//
// SBFoundation : ObjC Class Library for Solaris
// SBLocale.h
//
// Locale management, thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/uloc.h"

/*!
  @class SBLocale
  @discussion
  ObjC wrapper to the ICU library's locale functionality.
*/
@interface SBLocale : SBObject
{
  char*       _localeIdentifier;
}

/*!
  @method systemLocale
  
  Returns a shared SBLocale object which represents the system's native
  locale (according to ICU).
  
  Do not attempt to retain/release the returned object, please.
*/
+ (SBLocale*) systemLocale;
/*!
  @method defaultLocale
  
  Returns a shared SBLocale object which represents the current
  default locale (according to ICU).
  
  Do not attempt to retain/release the returned object, please.
*/
+ (SBLocale*) defaultLocale;

/*!
  @method initWithLocaleIdentifier:
  
  Initialize a newly-allocated instance using the provided locale
  identifier.  See ICU documentation for a description of valid locale
  identifiers. 
*/
- (id) initWithLocaleIdentifier:(const char*)localeId;
/*!
  @method localeIdentifier
  
  Returns a pointer to a C string containing the receiver's canonical locale
  identifier.
*/
- (const char*) localeIdentifier;
/*!
  @method setAsDefaultLocale
  
  Set the ICU-wide default locale to the receiver's locale; this affects
  this application itself, not other applications using ICU on the host
  (e.g. we're not setting an enviroment variable or something).
*/
- (void) setAsDefaultLocale;

@end
