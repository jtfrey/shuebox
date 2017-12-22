//
// SBFoundation : ObjC Class Library for Solaris
// SBUser.h
//
// Provides a generic wrapper for objects which represent a user.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"

@class SBDictionary, SBMutableDictionary;

/*!
  @class SBUser
  @discussion
    The SBUser class provides a basic (but highly extensible) representation
    of a user agent.  The class is setup to be primarily a wrapper to a
    mutable dictionary with a pre-defined set of keys for standard user agent
    properties.  Additional convenience methods are present to ease the use
    of these properties.
*/
@interface SBUser : SBObject
{
  SBMutableDictionary*  _userProperties;
}

/*!
  @method init
  @discussion
    Initializes an SBUser instance with no defined properties.
*/
- (id) init;

/*!
  @method initWithUserProperties:
  @discussion
    Initializes an SBUser instance which contains the properties defined
    in the passed-in properties dictionary.
*/
- (id) initWithUserProperties:(SBDictionary*)properties;

/*!
  @method userProperties
  @discussion
    Returns the receiver's user property dictionary.
*/
- (SBDictionary*) userProperties;

/*!
  @method setUserProperties:
  @discussion
    Removes all data from the receiver's property dictionary and adds
    those present in the passed-in properties dictionary.
*/
- (void) setUserProperties:(SBDictionary*)properties;

/*!
  @method userPropertyForKey:
  @discussion
    Returns the value currently associated with the user property indicated
    by aKey in the receiver.
*/
- (SBString*) userPropertyForKey:(SBString*)aKey;

/*!
  @method userPropertyForKey:
  @discussion
    Sets the value associated with the user property indicated by aKey in
    the receiver.
*/
- (BOOL) setUserProperty:(SBString*)value forKey:(SBString*)aKey;

/*!
  @method authenticateWithPassword:
  @discussion
    Performs simple (cleartext) authentication of the passed-in password against
    the receiver's SBUserPasswordKey property.  If the receiver has no property
    with this key, then YES is returned (lack of password implies no password
    necessary, e.g.)
*/
- (BOOL) authenticateWithPassword:(SBString*)password;

/*!
  @method uidForUser
  @discussion
    If the receiver defines the SBUserUIDNumberKey property, then its value is
    converted to a UNIX-native uid_t and returned.  If the property is not
    defined or cannot be converted, -1 is returned.
*/
- (uid_t) uidForUser;

/*!
  @method primaryGidForUser
  @discussion
    If the receiver defines the SBUserPrimaryGIDNumberKey property, then its value
    is converted to a UNIX-native gid_t and returned.  If the property is not
    defined or cannot be converted, -1 is returned.
*/
- (gid_t) primaryGidForUser;

@end

/*!
  @constant SBUserIdentifierKey
  @discussion
    String which keys a user's identifier (e.g. UNIX username).
*/
extern SBString* SBUserIdentifierKey;
/*!
  @constant SBUserUIDNumberKey
  @discussion
    String which keys a user's UNIX user number.
*/
extern SBString* SBUserUIDNumberKey;
/*!
  @constant SBUserPrimaryGIDNumberKey
  @discussion
    String which keys a user's primary UNIX group number.
*/
extern SBString* SBUserPrimaryGIDNumberKey;
/*!
  @constant SBUserFullNameKey
  @discussion
    String which keys a user's full name (e.g. UNIX GECOS passwd field).
*/
extern SBString* SBUserFullNameKey;
/*!
  @constant SBUserLoginShellKey
  @discussion
    String which keys a user's default shell path.
*/
extern SBString* SBUserLoginShellKey;
/*!
  @constant SBUserHomeDirectoryKey
  @discussion
    String which keys a user's home directory.
*/
extern SBString* SBUserHomeDirectoryKey;
/*!
  @constant SBUserEmailAddressKey
  @discussion
    String which keys a user's primary email address.
*/
extern SBString* SBUserEmailAddressKey;
/*!
  @constant SBUserPostalAddressKey
  @discussion
    String which keys a user's postal mailing address.
*/
extern SBString* SBUserPostalAddressKey;
/*!
  @constant SBUserTelephoneNumberKey
  @discussion
    String which keys a user's primary telephone number.
*/
extern SBString* SBUserTelephoneNumberKey;
/*!
  @constant SBUserPasswordKey
  @discussion
    String which keys a user's password.  The password may be
    cleartext or some encrypted form -- that is an implementation
    detail of consumer code.
*/
extern SBString* SBUserPasswordKey;
