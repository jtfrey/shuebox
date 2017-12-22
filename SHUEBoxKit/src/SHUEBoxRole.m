//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxRole.m
//
// Class which wraps SHUEBox roles.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBoxRole.h"
#import "SHUEBoxCollaboration.h"
#import "SBString.h"
#import "SBRegularExpression.h"
#import "SBOrderedSet.h"
#import "SBEnumerator.h"
#import "SBValue.h"
#import "SBDictionary.h"
#import "SBDatabaseAccess.h"
#import "SBObjectCache.h"
#import "SBNotification.h"

SBString* SHUEBoxRoleCollabIdKey              = @"collabid";
SBString* SHUEBoxRoleIdKey                    = @"roleid";
SBString* SHUEBoxRoleShortNameKey             = @"shortname";
SBString* SHUEBoxRoleDescriptionKey           = @"description";
SBString* SHUEBoxRoleIsLockedKey              = @"locked";
SBString* SHUEBoxRoleIsSystemOwnedKey         = @"systemowned";


SBString* SHUEBoxRoleWasRemovedNotification   = @"SHUEBoxRoleWasRemovedNotification";


SBObjectCache* __SHUEBoxRoleCache = nil;

//

SBComparisonResult
__SHUEBoxRoleMemberComparator(
  id      userFromSet,
  id      extUser
)
{
  SHUEBoxUserId   cmp = [userFromSet shueboxUserId] - [extUser shueboxUserId];
  
  if ( cmp == 0 )
    return SBOrderSame;
  if ( cmp < 0 )
    return SBOrderAscending;
  return SBOrderDescending;
}

//
#if 0
#pragma mark -
#endif
//

@interface SHUEBoxRole(SHUEBoxRolePrivate)

- (void) loadRoleMembership;
- (SBOrderedSet*) membership;
- (BOOL) commitMembership;

@end

@implementation SHUEBoxRole(SHUEBoxRolePrivate)

	- (void) loadRoleMembership
	{
		id						queryResult = [[self parentDatabase] executeQuery:
																		[SBString stringWithFormat:"SELECT userId FROM collaboration.roleMember WHERE roleId = %lld ORDER BY userId", [self shueboxRoleId]]
																	];
		SBUInteger		i = 0, iMax;
		
    if ( queryResult && [queryResult queryWasSuccessful] && (iMax = [queryResult numberOfRows]) ) {
			if ( _membership )
				[_membership release];
			_membership = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRoleMemberComparator];
      
      while ( i < iMax ) {
        SBNumber*     userId = [queryResult objectForRow:i++ fieldNum:0];
        SHUEBoxUser*  user = [SHUEBoxUser shueboxUserWithDatabase:[self parentDatabase] userId:[userId int64Value]];
        
        if ( user ) {
          [_membership addObject:user];
        }
      }
			_membershipModified = NO;
		}
	}
	
//

	- (SBOrderedSet*) membership
	{
		return _membership;
	}
	
//

	- (BOOL) commitMembership
	{
		SBUInteger					i, iMax;
		BOOL								transactionStarted = NO;
		id									database = [self parentDatabase];
		SBMutableString*		query = nil;
		SHUEBoxRoleId				roleId = [self shueboxRoleId];
		
		// Make any additions first:
		if ( _add && (iMax = [_add count]) ) {
			if ( ! (transactionStarted = [database beginTransaction]) )
				return NO;
			
			query = [[SBMutableString alloc] init];
			
			i = 0;
			while ( i < iMax ) {
				SHUEBoxUser*    user = [_add objectAtIndex:i++];
				
				if ( user ) {
          [query deleteAllCharacters];
					[query appendFormat:"INSERT INTO collaboration.roleMember (roleId, userId) VALUES (%lld, %lld)", (long long)roleId, (long long)[user shueboxUserId]];
					if ( ! [database executeQueryWithBooleanResult:query] )
						goto badExit;
				}
			}
		}
		
		// Now for removals:
		if ( _remove && (iMax = [_remove count]) ) {
			if ( ! transactionStarted && ! (transactionStarted = [database beginTransaction]) )
				return NO;
			
			if ( ! query )
				query = [[SBMutableString alloc] init];
			
			i = 0;
			while ( i < iMax ) {
				SHUEBoxUser*    user = [_remove objectAtIndex:i++];
				
				if ( user ) {
          [query deleteAllCharacters];
					[query appendFormat:"DELETE FROM collaboration.roleMember WHERE roleId = %lld AND userId = %lld", (long long)roleId, (long long)[user shueboxUserId]];
					if ( ! [database executeQueryWithBooleanResult:query] )
						goto badExit;
				}
			}
		}
		
		if ( query ) [query release];
		
		// Did we start a transaction?
		if ( transactionStarted ) {
			if ( [database commitLastTransaction] ) {
				if ( _add )
          [_add removeAllObjects];
				if ( _remove )
					[_remove removeAllObjects];
				_membershipModified = NO;
			} else {
				return NO;
			}
		}
			
		return YES;

badExit:
		if ( query ) [query release];
		if ( transactionStarted )
			[database discardLastTransaction];
		return NO;
	}

@end

//
#if 0
#pragma mark -
#endif
//

@interface SHUEBoxRoleEnumerator : SBEnumerator
{
	SHUEBoxRole*			_parentRole;
	SBOrderedSet*     _membership;
	SBUInteger				_i, _iMax;
}

- (id) initWithRole:(SHUEBoxRole*)aRole;

@end

//

@implementation SHUEBoxRoleEnumerator

	- (id) initWithRole:(SHUEBoxRole*)aRole
	{
		if ( (self = [super init]) ) {
			_membership = [aRole membership];
			if ( _membership ) {
				_parentRole = [aRole retain];
				_i = 0;
				_iMax = [_membership count];
			}
		}
		return self;
	}
	
//

	- (void) dealloc
	{
		if ( _parentRole ) [_parentRole release];
		
		[super dealloc];
	}

//

	- (id) nextObject
	{
		if ( _i < _iMax )
			return [_membership objectAtIndex:_i++];
		return nil;
	}

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SHUEBoxRole

  + (id) initialize
  {
    if ( __SHUEBoxRoleCache == nil ) {
      __SHUEBoxRoleCache = [[SBObjectCache alloc] initWithBaseClass:[SHUEBoxRole class]];
      
      if ( __SHUEBoxRoleCache ) {
        [__SHUEBoxRoleCache createCacheIndexForKey:SHUEBoxRoleIdKey];
      }
    }
  }

//

  + (void) flushRoleCache
  {
    if ( __SHUEBoxRoleCache )
      [__SHUEBoxRoleCache flushCache];
  }
  
//

  + (void) removeRoleFromCache:(SHUEBoxRole*)aRole
  {
    if ( __SHUEBoxRoleCache )
      [__SHUEBoxRoleCache evictObjectFromCache:aRole];
  }

//

  + (SBString*) tableNameForClass
  {
    return @"collaboration.role";
  }
  
//

  + (SBString*) objectIdKeyForClass
  {
    return SHUEBoxRoleIdKey;
  }
  
//

  + (SBArray*) propertyKeysForClass
  {
    static SBArray*     SHUEBoxRoleKeys = nil;
    
    if ( SHUEBoxRoleKeys == nil ) {
      SHUEBoxRoleKeys = [[SBArray alloc] initWithObjects:
                                        SHUEBoxRoleCollabIdKey,
                                        SHUEBoxRoleIdKey,
                                        SHUEBoxRoleShortNameKey,
                                        SHUEBoxRoleDescriptionKey,
                                        SHUEBoxRoleIsLockedKey,
                                        SHUEBoxRoleIsSystemOwnedKey,
                                        nil
                                      ];
    }
    return SHUEBoxRoleKeys;
  }

//

	+ (SBArray*) shueboxRolesForCollaboration:(SHUEBoxCollaboration*)collaboration
	{
		id								database = [collaboration parentDatabase];
    id                idLookup = [database executeQuery:[SBString stringWithFormat:"SELECT roleId FROM collaboration.role WHERE collabId = " SBIntegerFormat, [collaboration collabId]]];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxRole*    objects[rowCount];
      SBUInteger      index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     roleId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( roleId )
          objects[index++] = [self shueboxRoleWithDatabase:database roleId:[roleId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
	}

//

  + (id) createRoleWithCollaboration:(SHUEBoxCollaboration*)collaboration
    shortName:(SBString*)shortName
    description:(SBString*)description
    error:(SBError**)error
  {
    id          newRole = nil;
    id          database = [collaboration parentDatabase];
    
    // Now try to validate the role name:
    SBRegularExpression*    regex = [[SBRegularExpression alloc] initWithUTF8String:"^[a-zA-Z0-9][a-zA-Z0-9_. -]*$" flags:UREGEX_MULTILINE];
    
    if ( regex ) {
      [regex setSubjectString:shortName];
      if ( [regex isFullMatch] ) {
        // The name is okay syntactically -- could still overlap with an existing repository name, of course:
        if ( ! [collaboration shueboxRoleWithName:shortName] ) {
          // Looks like we're good to go!
          SBString*     queryString;
          
          if ( description && [description length] ) {
            queryString = [[SBString alloc] initWithFormat:"INSERT INTO collaboration.role (collabId, shortName, description) VALUES (" SBIntegerFormat ", '%S', '%S' )",
                                                [collaboration collabId],
                                                [shortName utf16Characters],
                                                [[database stringEscapedForQuery:description] utf16Characters]
                                              ];
                                                
          } else {
            queryString = [[SBString alloc] initWithFormat:"INSERT INTO collaboration.role (collabId, shortName) VALUES (" SBIntegerFormat ", '%S' )",
                                                [collaboration collabId],
                                                [shortName utf16Characters]
                                              ];
          }
          if ( queryString ) {
            BOOL      result = [database executeQueryWithBooleanResult:queryString];
            
            [queryString release];
            if ( result ) {
              [collaboration reloadRoles];
              newRole = [collaboration shueboxRoleWithName:shortName];
            } else if ( error ) {
              *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                    code:kSHUEBoxRoleCreationFailed
                                    supportingData:[SBDictionary dictionaryWithObject:[SBString stringWithFormat:"Unable to create a role named %S", [shortName utf16Characters]]
                                                      forKey:SBErrorExplanationKey]
                                ];
            }
          }
        } else if ( error ) {
          // Already exists:
          *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                code:kSHUEBoxRoleAlreadyExists
                                supportingData:[SBDictionary dictionaryWithObject:[SBString stringWithFormat:"A role with the name %S already exists in this collaboration", [shortName utf16Characters]]
                                                  forKey:SBErrorExplanationKey]
                            ];
        }
      }
      [regex release];
    }
    return newRole;
  }

//

	+ (id) shueboxAdministratorRoleForCollaboration:(SHUEBoxCollaboration*)collaboration
	{
		return [self shueboxRoleWithCollaboration:collaboration shortName:@"administrator"];
	}

//

	+ (id) shueboxEveryoneRoleForCollaboration:(SHUEBoxCollaboration*)collaboration
	{
		return [self shueboxRoleWithCollaboration:collaboration shortName:@"everyone"];
	}

//

  + (id) shueboxRoleWithDatabase:(id)database
    roleId:(SHUEBoxRoleId)roleId;
  {
    id            object = nil;
    SBNumber*     objId = [SBNumber numberWithInt64:roleId];
    
    if ( ! (object = [__SHUEBoxRoleCache cachedObjectForKey:SHUEBoxRoleIdKey value:objId]) ) {
      object = [self databaseObjectWithDatabase:database objectId:roleId];
      
      if ( object )
        [__SHUEBoxRoleCache addObjectToCache:object];
    } else {
      [object refreshCommittedProperties];
    }
    return object;
  }
  
//
  
  + (id) shueboxRoleWithCollaboration:(SHUEBoxCollaboration*)collaboration
    shortName:(SBString*)shortName
  {
    SHUEBoxRole*        object = nil;
    
    // Get the database from the collaboration:
    id                  database = [collaboration parentDatabase];
    
    // Lookup the repository id for the short name:
    SBString*           queryString = [[SBString alloc] initWithFormat:
                                "SELECT roleId FROM collaboration.role WHERE collabid = " SBIntegerFormat " AND shortName = '%S'",
                                [collaboration collabId],
                                [[database stringEscapedForQuery:shortName] utf16Characters] 
                              ];
    if ( queryString ) {
      id                idLookup = [database executeQuery:queryString];
      SBUInteger        rowCount;
      
      [queryString release];
      if ( idLookup && [idLookup queryWasSuccessful] && [idLookup numberOfRows] ) {
        SBNumber*       roleId = [idLookup objectForRow:0 fieldNum:0];
        
        if ( roleId )
          object = [self shueboxRoleWithDatabase:database roleId:[roleId integerValue]];
      }

    }
    return object;
  }

//

	- (void) dealloc
	{
		if ( _membership ) [_membership release];
		if ( _add ) [_add release];
		if ( _remove ) [_remove release];
		
		[super dealloc];
	}

//

  - (SHUEBoxRoleId) shueboxRoleId
  {
    SBNumber*     roleId = [self propertyForKey:SHUEBoxRoleIdKey];
    
    if ( [roleId isKindOf:[SBNumber class]] )
      return (SHUEBoxRoleId)[roleId int64Value];
    return 0;
  }

//

  - (SBInteger) parentCollaborationId
  {
    SBNumber*     collabId = [self propertyForKey:SHUEBoxRoleCollabIdKey];
    
    if ( [collabId isKindOf:[SBNumber class]] )
      return [collabId integerValue];
    return 0;
  }

//

  - (SBString*) shortName
  {
    SBString*     value = [self propertyForKey:SHUEBoxRoleShortNameKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setShortName:(SBString*)shortName
  {
    if ( shortName )
      [self setProperty:shortName forKey:SHUEBoxRoleShortNameKey];
  }
  
//

  - (SBString*) description
  {
    SBString*     value = [self propertyForKey:SHUEBoxRoleDescriptionKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setDescription:(SBString*)description
  {
    if ( description )
      [self setProperty:description forKey:SHUEBoxRoleDescriptionKey];
  }

//

  - (BOOL) isLocked
  {
    SBNumber*     lockedFlag = [self propertyForKey:SHUEBoxRoleIsLockedKey];
    
    if ( lockedFlag && [lockedFlag isKindOf:[SBNumber class]] )
      return [lockedFlag boolValue];
    return NO;
  }
  
//

  - (BOOL) isSystemOwned
  {
    SBNumber*     ownedFlag = [self propertyForKey:SHUEBoxRoleIsSystemOwnedKey];
    
    if ( ownedFlag && [ownedFlag isKindOf:[SBNumber class]] )
      return [ownedFlag boolValue];
    return NO;
  }
  
//

  - (BOOL) isMember:(SHUEBoxUser*)aUser
  {
    if ( ! _membership )
			[self loadRoleMembership];
    
    if ( aUser && _membership ) {
      SBUInteger		i = [_membership indexOfObject:aUser];
      
			if ( i != SBNotFound )
				return YES;
    }
    return NO;
  }
  - (BOOL) isMemberByUserId:(SHUEBoxUserId)userId
  {
    return [self isMember:[SHUEBoxUser shueboxUserWithDatabase:[self parentDatabase] userId:userId]];
  }

//

	- (void) addMember:(SHUEBoxUser*)aUser
	{
		if ( [self isLocked] )
			return;
			
    if ( ! _membership ) {
			[self loadRoleMembership];
			if ( ! _membership )
				_membership = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRoleMemberComparator];
		}
		
		if ( _membership ) {
			SBUInteger		insertIdx = [_membership indexOfObject:aUser];
			
			if ( insertIdx == SBNotFound ) {
				[_membership addObject:aUser];
				
				if ( ! _add )
					_add = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRoleMemberComparator];
				[_add addObject:aUser];
				
				_membershipModified = YES;
			}
		}
	}
	- (void) addMemberByUserId:(SHUEBoxUserId)userId
	{
    [self addMember:[SHUEBoxUser shueboxUserWithDatabase:[self parentDatabase] userId:userId]];
	}

//

	- (void) removeMember:(SHUEBoxUser*)aUser
	{
		if ( [self isLocked] )
			return;
			
    if ( ! _membership )
			[self loadRoleMembership];
		
		if ( _membership ) {
			SBUInteger		i = [_membership indexOfObject:aUser];
			
			if ( i != SBNotFound ) {
				if ( ! _remove )
					_remove = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRoleMemberComparator];
				[_remove addObject:[_membership objectAtIndex:i]];
				[_membership removeObjectAtIndex:i];
				
				_membershipModified = YES;
			}
		}
	}
	- (void) removeMemberWithUserId:(SHUEBoxUserId)userId
	{
    [self removeMember:[SHUEBoxUser shueboxUserWithDatabase:[self parentDatabase] userId:userId]];
	}
	
//

	- (SBEnumerator*) roleMemberEnumerator
	{
    if ( ! _membership )
			[self loadRoleMembership];
		
		return [[[SHUEBoxRoleEnumerator alloc] initWithRole:self] autorelease];
	}
	
//

	- (SBUInteger) roleMemberCount
	{
    if ( ! _membership )
			[self loadRoleMembership];
		
		if ( _membership )
			return [_membership count];
		
		return 0;
	}

//

	- (SHUEBoxUser*) roleMemberAtIndex:(SBUInteger)index
	{
    if ( ! _membership )
			[self loadRoleMembership];
		
		if ( _membership )
			return (SHUEBoxUser*)[_membership objectAtIndex:index];
		
		return nil;
	}
  
//

  - (BOOL) removeFromParentCollaboration
  {
    BOOL    result = NO;
    
    if ( ! [self isSystemOwned] ) {
      result = 		[[self parentDatabase] executeQueryWithBooleanResult:
																		[SBString stringWithFormat:"DELETE FROM collaboration.role WHERE roleId = %lld", [self shueboxRoleId]]
																	];
      if ( result )
        [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SHUEBoxRoleWasRemovedNotification object:self];
    }
    return result;
  }

//
#if 0
#pragma mark SBDatabaseObject methods
#endif
//

	- (BOOL) hasBeenModified
	{
		if ( _membershipModified )
			return YES;
		return [super hasBeenModified];
	}

//

	- (void) refreshCommittedProperties
	{
		if ( _membership ) {
			[_membership release];
			_membership = nil;
		}
		if ( _add ) {
			[_add removeAllObjects];
		}
		if ( _remove ) {
			[_remove removeAllObjects];
		}
		[super refreshCommittedProperties];
	}
	
//

	- (void) revertModifications
	{
		if ( _membershipModified ) {
      [_membership release];
      _membership = nil;
    }
    if ( _add ) {
      [_add release];
      _add = nil;
    }
    if ( _remove ) {
      [_remove release];
      _remove = nil;
    }
    _membershipModified = NO;
		[super revertModifications];
	}

//

	- (BOOL) commitModifications
	{
		BOOL			rc = YES;
		
		if ( _membershipModified )
			rc = [self commitMembership];
		if ( rc )
			rc = [super commitModifications];
		return rc;
	}

@end
