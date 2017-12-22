//
// SBLDAPKit - LDAP-oriented extensions to SBFoundation
// SBUDUser.h
//
// UD account information from central LDAP.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBUser.h"
#import "SBLDAP.h"

/*!
  @class SBUDUser
  @discussion
    SBUDUser is a concrete subclass of SBUser that interacts with the UD central LDAP
    cluster to load user information.
*/
@interface SBUDUser : SBUser
{
  SBString*     _ldapDN;
}

/*!
  @method udUserWithUserIdentifier:
  @discussion
    Given uid is a UDelNetId, lookup the LDAP directory with a matching "uid" and
    return an autoreleased instance that wraps it.
*/
+ (id) udUserWithUserIdentifier:(SBString*)uid;

/*!
  @method udUserWithUserNumber:
  @discussion
    Lookup the LDAP directory with a "udUsernum" matching the given userNum and
    return an autoreleased instance that wraps it.
*/
+ (id) udUserWithUserNumber:(SBString*)userNum;

/*!
  @method udUserWithEmplid:
  @discussion
    Lookup the LDAP directory with a "udEmplid" matching the given emplid and
    return an autoreleased instance that wraps it.
*/
+ (id) udUserWithEmplid:(SBString*)emplid;

/*!
  @method udUserWithNSSId:
  @discussion
    Lookup the LDAP directory with a "udNSSid" matching the given nssId and
    return an autoreleased instance that wraps it.
*/
+ (id) udUserWithNSSId:(SBString*)nssId;

@end

/*!
  @constant SBUDUserNumberKey
  @discussion
    String constant for the "udUsernum" LDAP attribute key.
*/
extern SBString* SBUDUserNumberKey;

/*!
  @constant SBUDUserEmplidKey
  @discussion
    String constant for the "udEmplid" LDAP attribute key.
*/
extern SBString* SBUDUserEmplidKey;

/*!
  @constant SBUDUserTitleKey
  @discussion
    String constant for the "title" LDAP attribute key.
*/
extern SBString* SBUDUserTitleKey;

/*!
  @constant SBUDUserNSSIdKey
  @discussion
    String constant for the "udNSSid" LDAP attribute key.
*/
extern SBString* SBUDUserNSSIdKey;
