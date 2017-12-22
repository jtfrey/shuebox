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

#import "SBUDUser.h"
#import "SBLDAP.h"
#import "SBObjectCache.h"
#import "SBDictionary.h"

@interface SBUDUser(SBUDUserPrivate)

+ (SBLDAPConnection*) sharedLDAPConnection;

- (id) initWithUserProperties:(SBDictionary*)properties ldapDN:(SBString*)ldapDN;

@end

@implementation SBUDUser(SBUDUserPrivate)

  + (SBLDAPConnection*) sharedLDAPConnection
  {
    static SBLDAPConnection*    __SBUDUserLDAPConnection = nil;
    
    if ( __SBUDUserLDAPConnection == nil )
      __SBUDUserLDAPConnection = [[SBLDAPConnection ldapConnectionWithServer:@"ldap.udel.edu"] retain];
    return __SBUDUserLDAPConnection;
  }
  
//

  - (id) initWithUserProperties:(SBDictionary*)properties
    ldapDN:(SBString*)ldapDN
  {
    if ( self = [super initWithUserProperties:properties] ) {
      if ( ldapDN )
        _ldapDN = [ldapDN copy];
    }
    return self;
  }

@end

//
#pragma mark -
//

SBObjectCache* __SBUDUserCache = nil;

@implementation SBUDUser : SBUser

  + (id) initialize
  {
    if ( __SBUDUserCache == nil ) {
      __SBUDUserCache = [[SBObjectCache alloc] initWithBaseClass:[SBUDUser class]];
      if ( __SBUDUserCache ) {
        [__SBUDUserCache createCacheIndexForKey:SBUserIdentifierKey];
        [__SBUDUserCache createCacheIndexForKey:SBUDUserNumberKey];
        [__SBUDUserCache createCacheIndexForKey:SBUDUserEmplidKey];
        [__SBUDUserCache createCacheIndexForKey:SBUDUserNSSIdKey];
      }
    }
  }

//

  + (id) udUserWithUserIdentifier:(SBString*)uid
  {
    id        userObj = nil;
    
    if ( ! (userObj = [__SBUDUserCache cachedObjectForKey:SBUserIdentifierKey value:uid]) ) {
      SBLDAPConnection*     ldapConn = [SBUDUser sharedLDAPConnection];
      
      if ( ldapConn ) {
        SBLDAPSearchResult* searchResult = [ldapConn searchWithAttributeKey:SBUserIdentifierKey value:uid];
        
        if ( searchResult && [searchResult isKindOf:[SBLDAPSearchResult class]] ) {
          SBString*         altValue;
                    
          // We should now know usernum and emplid, so we can search the other caches:
          if ( (altValue = [searchResult attributeValueForKey:SBUDUserEmplidKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserEmplidKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNumberKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNumberKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNSSIdKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNSSIdKey value:altValue];
          }
          if ( ! userObj ) {
            userObj = [[[SBUDUser alloc] initWithUserProperties:[searchResult attributes] ldapDN:[searchResult distinguishedName]] autorelease];
            if ( userObj )
              [__SBUDUserCache addObjectToCache:userObj];
          }
        }
      }
    }
    return userObj;
  }

//

  + (id) udUserWithUserNumber:(SBString*)userNum
  {
    id        userObj = nil;
    
    if ( ! (userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNumberKey value:userNum]) ) {
      SBLDAPConnection*     ldapConn = [SBUDUser sharedLDAPConnection];
      
      if ( ldapConn ) {
        SBLDAPSearchResult* searchResult = [ldapConn searchWithAttributeKey:SBUDUserNumberKey value:userNum];
        
        if ( searchResult && [searchResult isKindOf:[SBLDAPSearchResult class]] ) {
          SBString*         altValue;
                    
          // We should now know emplid and identifier, so we can search the other caches:
          if ( (altValue = [searchResult attributeValueForKey:SBUserIdentifierKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUserIdentifierKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserEmplidKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserEmplidKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNSSIdKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNSSIdKey value:altValue];
          }
          if ( ! userObj ) {
            userObj = [[[SBUDUser alloc] initWithUserProperties:[searchResult attributes] ldapDN:[searchResult distinguishedName]] autorelease];
            if ( userObj )
              [__SBUDUserCache addObjectToCache:userObj];
          }
        }
      }
    }
    return userObj;
  }

//

  + (id) udUserWithEmplid:(SBString*)emplid
  {
    id        userObj = nil;
    
    if ( ! (userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserEmplidKey value:emplid]) ) {
      SBLDAPConnection*     ldapConn = [SBUDUser sharedLDAPConnection];
      
      if ( ldapConn ) {
        SBLDAPSearchResult* searchResult = [ldapConn searchWithAttributeKey:SBUDUserEmplidKey value:emplid];
        
        if ( searchResult && [searchResult isKindOf:[SBLDAPSearchResult class]] ) {
          SBString*         altValue;
                    
          // We should now know usernum and identifier, so we can search the other caches:
          if ( (altValue = [searchResult attributeValueForKey:SBUserIdentifierKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUserIdentifierKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNumberKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNumberKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNSSIdKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNSSIdKey value:altValue];
          }
          if ( ! userObj ) {
            userObj = [[[SBUDUser alloc] initWithUserProperties:[searchResult attributes] ldapDN:[searchResult distinguishedName]] autorelease];
            if ( userObj )
              [__SBUDUserCache addObjectToCache:userObj];
          }
        }
      }
    }
    return userObj;
  }

//

  + (id) udUserWithNSSId:(SBString*)nssId
  {
    id        userObj = nil;
    
    if ( ! (userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNSSIdKey value:nssId]) ) {
      SBLDAPConnection*     ldapConn = [SBUDUser sharedLDAPConnection];
      
      if ( ldapConn ) {
        SBLDAPSearchResult* searchResult = [ldapConn searchWithAttributeKey:SBUDUserNSSIdKey value:nssId];
        
        if ( searchResult && [searchResult isKindOf:[SBLDAPSearchResult class]] ) {
          SBString*         altValue;
                    
          // We should now know usernum and identifier, so we can search the other caches:
          if ( (altValue = [searchResult attributeValueForKey:SBUserIdentifierKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUserIdentifierKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserNumberKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserNumberKey value:altValue];
          }
          if ( ! userObj && (altValue = [searchResult attributeValueForKey:SBUDUserEmplidKey]) ) {
            userObj = [__SBUDUserCache cachedObjectForKey:SBUDUserEmplidKey value:altValue];
          }
          if ( ! userObj ) {
            userObj = [[[SBUDUser alloc] initWithUserProperties:[searchResult attributes] ldapDN:[searchResult distinguishedName]] autorelease];
            if ( userObj )
              [__SBUDUserCache addObjectToCache:userObj];
          }
        }
      }
    }
    return userObj;
  }

//

  - (void) dealloc
  {
    if ( _ldapDN ) [_ldapDN release];
    [super dealloc];
  }

//

  - (BOOL) setUserProperty:(SBString*)value
    forKey:(SBString*)aKey
  {
    // LDAP properties are NOT modifiable!
    return NO;
  }

//

  - (BOOL) authenticateWithPassword:(SBString*)password
  {
    SBLDAPConnection*     ldapConn = [SBUDUser sharedLDAPConnection];
    BOOL                  success = NO;
    
    if ( ldapConn ) {
      // Since we're going to try a bind, let's make a duplicate connection -- we can't
      // simply unbind after binding, we have to close the connection:
      SBLDAPConnection*   bindConn = [ldapConn copy];
      
      if ( bindConn ) {
        success = [bindConn booleanBindWithDN:_ldapDN password:password error:NULL];
        [bindConn release];
      }
    }
    return success;
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    fprintf(
        stream,
        "%s@%p[%u] {\n  ldapDN: ",
        [self name],
        self,
        [self referenceCount]
      );
    if ( _ldapDN )
      [_ldapDN writeToStream:stream];
    fprintf(stream, "\n  attributes:\n");
    if ( _userProperties )
      [_userProperties summarizeToStream:stream];
    fprintf(stream, "\n}\n");
  }

@end

//

SBString* SBUDUserNumberKey = @"udUsernum";
SBString* SBUDUserEmplidKey = @"udEmplid";
SBString* SBUDUserTitleKey = @"title";
SBString* SBUDUserNSSIdKey = @"udNSSid";
