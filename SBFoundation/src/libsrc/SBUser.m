//
// SBFoundation : ObjC Class Library for Solaris
// SBUser.m
//
// Provides a generic wrapper for objects which represent a user.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBUser.h"
#import "SBDictionary.h"

@implementation SBUser

  - (id) init
  {
    return [self initWithUserProperties:nil];
  }
  
//

  - (id) initWithUserProperties:(SBDictionary*)properties
  {
    if ( self = [super init] ) {
      [self setUserProperties:properties];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _userProperties ) [_userProperties release];
    [super dealloc];
  }
  
//

  - (SBDictionary*) userProperties
  {
    return _userProperties;
  }
  - (void) setUserProperties:(SBDictionary*)properties
  {
    if ( _userProperties ) {
      [_userProperties removeAllObjects];
      if ( properties ) {
        [_userProperties addElementsFromDictionary:properties];
      }
    } else if ( properties ) {
      _userProperties = [properties mutableCopy];
    } else {
      _userProperties = [[SBMutableDictionary alloc] init];
    }
  }

//

  - (SBString*) userPropertyForKey:(SBString*)aKey
  {
    return [_userProperties objectForKey:aKey];
  }
  - (BOOL) setUserProperty:(SBString*)value
    forKey:(SBString*)aKey
  {
    [_userProperties setObject:value forKey:aKey];
    return YES;
  }

//

  - (BOOL) authenticateWithPassword:(SBString*)password
  {
    SBString*     actualPassword = [self userPropertyForKey:SBUserPasswordKey];
    
    if ( actualPassword ) {
      if ( password )
        return [actualPassword isEqualToString:password];
      return NO;
    }
    return YES;
  }

//

  - (uid_t) uidForUser
  {
    SBString*     uidNumber = [self userPropertyForKey:SBUserUIDNumberKey];
    uid_t         uid = -1;
    
    if ( uidNumber ) {
      int         value = [uidNumber intValue];
      
      if ( value != 0 )
        uid = value;
    }
    return uid;
  }
  
//

  - (gid_t) primaryGidForUser
  {
    SBString*     gidNumber = [self userPropertyForKey:SBUserPrimaryGIDNumberKey];
    gid_t         gid = -1;
    
    if ( gidNumber ) {
      int         value = [gidNumber intValue];
      
      if ( value != 0 )
        gid = value;
    }
    return gid;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, "{\n");
    if ( _userProperties )
      [_userProperties summarizeToStream:stream];
    fprintf(stream, "\n}\n");
  }

//
#pragma mark SBKeyValueCoding
//

  - (id) valueForKey:(SBString*)aKey
  {
    return [_userProperties valueForKey:aKey];
  }
  - (void) setValue:(id)value
    forKey:(SBString*)aKey
  {
    [_userProperties setValue:value forKey:aKey];
  }

@end

//

SBString* SBUserIdentifierKey = @"uid";
SBString* SBUserUIDNumberKey = @"uidNumber";
SBString* SBUserPrimaryGIDNumberKey = @"gidNumber";
SBString* SBUserFullNameKey = @"cn";
SBString* SBUserLoginShellKey = @"loginShell";
SBString* SBUserHomeDirectoryKey = @"homeDirectory";
SBString* SBUserEmailAddressKey = @"mail";
SBString* SBUserPostalAddressKey = @"postalAddress";
SBString* SBUserTelephoneNumberKey = @"telephoneNumber";

SBString* SBUserPasswordKey = @"userPassword";
