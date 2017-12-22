//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxRepository.h
//
// Base class for SHUEBox repositories.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxRepository.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBOrderedSet.h"
#import "SBDictionary.h"
#import "SBDate.h"
#import "SBValue.h"
#import "SBDatabaseAccess.h"
#import "SBObjectCache.h"
#import "SBFileManager.h"
#import "SBRegularExpression.h"

SBString* SHUEBoxRepositoryIdKey                      = @"reposid";
SBString* SHUEBoxRepositoryParentCollabIdKey          = @"collabid";
SBString* SHUEBoxRepositoryTypeKey                    = @"repositorytype";
SBString* SHUEBoxRepositoryShortNameKey               = @"shortname";
SBString* SHUEBoxRepositoryDescriptionKey             = @"description";
SBString* SHUEBoxRepositoryCreationTimestampKey       = @"created";
SBString* SHUEBoxRepositoryModificationTimestampKey   = @"modified";
SBString* SHUEBoxRepositoryProvisionedTimestampKey    = @"provisioned";
SBString* SHUEBoxRepositoryCanBeRemovedKey            = @"canberemoved";
SBString* SHUEBoxRepositoryRemovalTimestampKey        = @"removeafter";

//

SBComparisonResult
__SHUEBoxRepositoryRoleMemberComparator(
  id      reposFromSet,
  id      extRepos
)
{
  SBInteger   cmp = [reposFromSet shueboxRoleId] - [extRepos shueboxRoleId];
  
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

@interface SHUEBoxRepository(SHUEBoxRepositoryPrivate)

+ (Class) classForReposId:(SBInteger)reposId database:(id)database;
+ (SBDictionary*) classMappingsFromDatabase:(id)database;

- (void) loadRoleMembership;
- (SBOrderedSet*) roleMembership;
- (BOOL) commitRoleMembership;

@end

@implementation SHUEBoxRepository(SHUEBoxRepositoryPrivate)

  + (Class) classForReposId:(SBInteger)reposId
    database:(id)database
  {
    id      queryResult = [database executeQuery:
                                        [SBString stringWithFormat:"SELECT className FROM collaboration.repositoryType "
                                                                   "  WHERE repoTypeId = (SELECT repositoryType FROM collaboration.repository WHERE reposId = " SBIntegerFormat ")",
                                                        reposId]
                                ];
    if ( queryResult ) {
      SBString*     className = [queryResult objectForRow:0 fieldNum:0];
          
      if ( className ) {
        SBSTRING_AS_UTF8_BEGIN(className)
        
          return objc_get_class( className_utf8 );
          
        SBSTRING_AS_UTF8_END
      }
    }
    return Nil;
  }

//

  + (SBDictionary*) classMappingsFromDatabase:(id)database
  {
    SBDictionary*   mappings = nil;
    
    id      queryResult = [database executeQuery:@"SELECT repoTypeId, className FROM collaboration.repositoryType ORDER BY repoTypeId"];
    
    if ( queryResult ) {
      SBUInteger    i = 0, iMax = [queryResult numberOfRows];
      
      if ( iMax ) {
        SBMutableDictionary*  theMappings = [[SBMutableDictionary alloc] init];
        
        while ( i < iMax ) {
          SBNumber*   repoTypeId = [queryResult objectForRow:i fieldNum:0];
          SBString*   className = [queryResult objectForRow:i fieldNum:1];
          
          if ( repoTypeId && className && [className length] ) {
            [theMappings setObject:repoTypeId forKey:className];
            [theMappings setObject:className forKey:repoTypeId];
          }
          i++;
        }
        if ( [theMappings count] )
          mappings = [[theMappings copy] autorelease];
        [theMappings release];
      }
    }
    return mappings;
  }

//

  - (void) loadRoleMembership
	{
		id						queryResult = [[self parentDatabase] executeQuery:
																		[SBString stringWithFormat:"SELECT roleId FROM collaboration.repositoryACL WHERE reposId = " SBIntegerFormat " ORDER BY roleId", [self reposId]]
																	];
		SBUInteger		i = 0, iMax;
		
    if ( queryResult && [queryResult queryWasSuccessful] && (iMax = [queryResult numberOfRows]) ) {
			if ( _roles )
				[_roles release];
			_roles = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRepositoryRoleMemberComparator];
      
      while ( i < iMax ) {
        SBNumber*     roleId = [queryResult objectForRow:i++ fieldNum:0];
        SHUEBoxRole*  role = [SHUEBoxRole shueboxRoleWithDatabase:[self parentDatabase] roleId:[roleId integerValue]];
        
        if ( role )
          [_roles addObject:role];
      }
      
			_rolesModified = NO;
		}
	}
	
//

	- (SBOrderedSet*) roleMembership
	{
		return _roles;
	}
	
//

	- (BOOL) commitRoleMembership
	{
		SBUInteger					i, iMax;
		BOOL								transactionStarted = NO;
		id									database = [self parentDatabase];
		SBMutableString*		query = nil;
		SBInteger           reposId = [self reposId];
    
		// Make any additions first:
		if ( _addRoles && (iMax = [_addRoles count]) ) {
			if ( ! (transactionStarted = [database beginTransaction]) )
				return NO;
			
			query = [[SBMutableString alloc] init];
			
			i = 0;
			while ( i < iMax ) {
				SHUEBoxRole*  role = [_addRoles objectAtIndex:i++];
				
				if ( role ) {
          [query deleteAllCharacters];
					[query appendFormat:"INSERT INTO collaboration.repositoryACL (reposId, roleId) VALUES (" SBIntegerFormat ", %lld)", reposId, (long long)[role shueboxRoleId]];
					if ( ! [database executeQueryWithBooleanResult:query] )
						goto badExit;
				}
			}
		}
		
		// Now for removals:
		if ( _removeRoles && (iMax = [_removeRoles count]) ) {
			if ( ! transactionStarted && ! (transactionStarted = [database beginTransaction]) )
				return NO;
			
			if ( ! query )
				query = [[SBMutableString alloc] init];
			
			i = 0;
			while ( i < iMax ) {
				SHUEBoxRole*  role = [_removeRoles objectAtIndex:i++];
				
				if ( role ) {
          [query deleteAllCharacters];
					[query appendFormat:"DELETE FROM collaboration.repositoryACL WHERE reposId = " SBIntegerFormat " AND roleId = %lld", reposId, (long long)[role shueboxRoleId]];
					if ( ! [database executeQueryWithBooleanResult:query] )
						goto badExit;
				}
			}
		}
		
		if ( query ) [query release];
		
		// Did we start a transaction?
		if ( transactionStarted ) {
			if ( [database commitLastTransaction] ) {
				if ( _addRoles )
					[_addRoles removeAllObjects];
				if ( _removeRoles )
					[_removeRoles removeAllObjects];
				_rolesModified = NO;
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
#pragma mark -
//

SBObjectCache*  __SHUEBoxRepositoryCache = nil;

@implementation SHUEBoxRepository

  + (id) initialize
  {
    if ( __SHUEBoxRepositoryCache == nil ) {
      __SHUEBoxRepositoryCache = [[SBObjectCache alloc] initWithBaseClass:[SHUEBoxRepository class]];
      if ( __SHUEBoxRepositoryCache )
        [__SHUEBoxRepositoryCache createCacheIndexForKey:SHUEBoxRepositoryIdKey];
    }
  }

//

  + (SBString*) tableNameForClass
  {
    return @"collaboration.repository";
  }
  
//

  + (SBString*) objectIdKeyForClass
  {
    return @"reposid";
  }
  
//

  + (SBArray*) propertyKeysForClass
  {
    static SBArray*     SHUEBoxRepositoryKeys = nil;
    
    if ( SHUEBoxRepositoryKeys == nil ) {
      SHUEBoxRepositoryKeys = [[SBArray alloc] initWithObjects:
                                        SHUEBoxRepositoryIdKey,
                                        SHUEBoxRepositoryParentCollabIdKey,
                                        SHUEBoxRepositoryTypeKey,
                                        SHUEBoxRepositoryShortNameKey,
                                        SHUEBoxRepositoryDescriptionKey,
                                        SHUEBoxRepositoryCreationTimestampKey,
                                        SHUEBoxRepositoryModificationTimestampKey,
                                        SHUEBoxRepositoryProvisionedTimestampKey,
                                        SHUEBoxRepositoryCanBeRemovedKey,
                                        SHUEBoxRepositoryRemovalTimestampKey,
                                        nil
                                      ];
    }
    return SHUEBoxRepositoryKeys;
  }

//

  + (SBArray*) repositoriesWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT reposId FROM collaboration.repository"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxRepository*      objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     reposId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( reposId )
          objects[index++] = [self repositoryWithDatabase:database reposId:[reposId intValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }
  
//

  + (SBArray*) unprovisionedRepositoriesWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT reposId FROM collaboration.repository WHERE provisioned IS NULL"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxRepository*      objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     reposId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( reposId )
          objects[index++] = [self repositoryWithDatabase:database reposId:[reposId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (SBArray*) repositoriesForRemovalWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT reposId FROM collaboration.repository WHERE removeafter <= now() AND canBeRemoved = true"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxRepository*      objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     reposId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( reposId )
          objects[index++] = [self repositoryWithDatabase:database reposId:[reposId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (SBArray*) repositoriesForCollaboration:(SHUEBoxCollaboration*)aCollaboration
  {
    //
    // The query sorts results by descending creation date; this ensures that the "web" repository only appears at the tail end of the configuration
    // files.  This is the simplest way to enforce that...
    //
    id                database = [aCollaboration parentDatabase];
    SBString*         queryString = [[SBString alloc] initWithFormat:"SELECT reposId FROM collaboration.repository WHERE collabid = " SBIntegerFormat " ORDER BY created DESC", [aCollaboration collabId]];
    
    if ( queryString ) {
      id                idLookup = [database executeQuery:queryString];
      SBUInteger        rowCount;
      
      [queryString release];
      if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
        SHUEBoxRepository*      objects[rowCount];
        SBUInteger              index = 0;
        
        while ( rowCount-- ) {
          SBNumber*     reposId = [idLookup objectForRow:rowCount fieldNum:0];
        
          if ( reposId )
            objects[index++] = [self repositoryWithDatabase:database reposId:[reposId integerValue]];
        }
        if ( index )
          return [SBArray arrayWithObjects:objects count:index];
      }
    }
    return nil;
  }
  
//

  + (id) createRepositoryWithCollaboration:(SHUEBoxCollaboration*)parentCollaboration
    reposTypeId:(SBInteger)reposTypeId
    shortName:(SBString*)shortName
    description:(SBString*)description
    error:(SBError**)error
  {
    id          newRepository = nil;
    id          database = [parentCollaboration parentDatabase];
    
    // First things first:  do we have a valid repository type?
    SBDictionary*           reposMap = [SHUEBoxRepository classMappingsFromDatabase:database];
    
    if ( ! reposMap ) {
      if ( error )
        *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                              code:kSHUEBoxRepositoryTypeMapFailed
                              supportingData:[SBDictionary dictionaryWithObject:@"An error occurred while gathering repository type information from the database"
                                                forKey:SBErrorExplanationKey]
                          ];
      return nil;
    }
    if ( ! [reposMap containsKey:[SBNumber numberWithInteger:reposTypeId]] ) {
      if ( error )
        *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                              code:kSHUEBoxRepositoryInvalidTypeId
                              supportingData:[SBDictionary dictionaryWithObject:@"The indicated repository type is not recognized by the system"
                                                forKey:SBErrorExplanationKey]
                          ];
      return nil;
    }
    
    // Now try to validate the repository name:
    SBRegularExpression*    regex = [[SBRegularExpression alloc] initWithUTF8String:"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$" flags:UREGEX_MULTILINE];
    
    if ( regex ) {
      [regex setSubjectString:shortName];
      if ( [regex isFullMatch] ) {
        // The name is okay syntactically -- could still overlap with an existing repository name, of course:
        if ( ! [SHUEBoxRepository repositoryWithParentCollaboration:parentCollaboration shortName:shortName] ) {
          // Looks like we're good to go!
          SBString*     queryString;
          
          if ( description && [description length] ) {
            queryString = [[SBString alloc] initWithFormat:"INSERT INTO collaboration.repository (collabId, repositoryType, shortName, description) VALUES (" SBIntegerFormat ", " SBIntegerFormat ", '%S', '%S' )",
                                                [parentCollaboration collabId],
                                                reposTypeId,
                                                [shortName utf16Characters],
                                                [[database stringEscapedForQuery:description] utf16Characters]
                                              ];
                                                
          } else {
            queryString = [[SBString alloc] initWithFormat:"INSERT INTO collaboration.repository (collabId, repositoryType, shortName) VALUES (" SBIntegerFormat ", " SBIntegerFormat ", '%S' )",
                                                [parentCollaboration collabId],
                                                reposTypeId,
                                                [shortName utf16Characters]
                                              ];
          }
          if ( queryString ) {
            BOOL      result = [database executeQueryWithBooleanResult:queryString];
            
            [queryString release];
            if ( result ) {
              [parentCollaboration reloadRepositories];
              newRepository = [SHUEBoxRepository repositoryWithParentCollaboration:parentCollaboration shortName:shortName];
            } else if ( error ) {
              *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                    code:kSHUEBoxRepositoryCreationFailed
                                    supportingData:[SBDictionary dictionaryWithObject:[SBString stringWithFormat:"Unable to create a repository named %S", [shortName utf16Characters]]
                                                      forKey:SBErrorExplanationKey]
                                ];
            }
          }
        } else if ( error ) {
          // Already exists:
          *error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                code:kSHUEBoxRepositoryAlreadyExists
                                supportingData:[SBDictionary dictionaryWithObject:[SBString stringWithFormat:"A repository with the name %S already exists in this collaboration", [shortName utf16Characters]]
                                                  forKey:SBErrorExplanationKey]
                            ];
        }
      }
      [regex release];
    }
    return newRepository;
  }

//

  + (id) repositoryWithDatabase:(id)database
    reposId:(SBInteger)reposId
  {
    id            object = nil;
    SBNumber*     objId = [SBNumber numberWithInteger:reposId];
    
    if ( ! (object = [__SHUEBoxRepositoryCache cachedObjectForKey:SHUEBoxRepositoryIdKey value:objId]) ) {
      //
      // Lookup the class we should be using:
      //
      Class       targetClass = [SHUEBoxRepository classForReposId:reposId database:database];
      
      if ( targetClass ) {
        object = [targetClass databaseObjectWithDatabase:database objectId:reposId];
        
        if ( object )
          [__SHUEBoxRepositoryCache addObjectToCache:object];
      }
    }
    return object;
  }
  
//

  + (id) repositoryWithParentCollaboration:(SHUEBoxCollaboration*)parentCollaboration
    shortName:(SBString*)shortName
  {
    SHUEBoxRepository*  object = nil;
    
    // Get the database from the collaboration:
    id                  database = [parentCollaboration parentDatabase];
    
    // Lookup the repository id for the short name:
    SBString*           queryString = [[SBString alloc] initWithFormat:
                                "SELECT reposId FROM collaboration.repository WHERE collabid = " SBIntegerFormat " AND shortName = '%S'",
                                [parentCollaboration collabId],
                                [[database stringEscapedForQuery:shortName] utf16Characters] 
                              ];
    if ( queryString ) {
      id                idLookup = [database executeQuery:queryString];
      SBUInteger        rowCount;
      
      [queryString release];
      if ( idLookup && [idLookup queryWasSuccessful] && [idLookup numberOfRows] ) {
        SBNumber*       reposId = [idLookup objectForRow:0 fieldNum:0];
        
        if ( reposId )
          object = [self repositoryWithDatabase:database reposId:[reposId integerValue]];
      }

    }
    return object;
  }

//

  - (void) dealloc
  {
    if ( _repositoryURI ) [_repositoryURI release];
    if ( _parentCollaboration ) [_parentCollaboration release];
    if ( _homeDirectory ) [_homeDirectory release];
    
		if ( _roles ) [_roles release];
		if ( _addRoles ) [_addRoles release];
		if ( _removeRoles ) [_removeRoles release];
    
    [super dealloc];
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( otherObject == self ) {
      return YES;
    }
    if ( [otherObject isKindOf:[SHUEBoxRepository class]] ) {
      if ( [otherObject parentCollabId] == [self parentCollabId] ) {
        if ( [otherObject reposId] == [self reposId] ) {
          return YES;
        }
        if ( [[otherObject shortName] isEqual:[self shortName]] && ([self repositoryTypeId] == [otherObject repositoryTypeId]) ) {
          return YES;
        }
      }
    }
    return NO;
  }

//

  - (SBInteger) reposId
  {
    SBNumber*     reposId = [self propertyForKey:SHUEBoxRepositoryIdKey];
    
    if ( [reposId isKindOf:[SBNumber class]] )
      return [reposId integerValue];
    return 0;
  }

//

  - (SBInteger) parentCollabId
  {
    SBNumber*     collabId = [self propertyForKey:SHUEBoxRepositoryParentCollabIdKey];
    
    if ( [collabId isKindOf:[SBNumber class]] )
      return [collabId integerValue];
    return 0;
  }
  - (SHUEBoxCollaboration*) parentCollaboration
  {
    if ( ! _parentCollaboration )
      _parentCollaboration = [[SHUEBoxCollaboration collaborationWithDatabase:[self parentDatabase] collabId:[self parentCollabId]] retain];
    return _parentCollaboration;
  }

//

  - (SBString*) shortName
  {
    SBString*     value = [self propertyForKey:SHUEBoxRepositoryShortNameKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  
//

  - (SBString*) description
  {
    SBString*     value = [self propertyForKey:SHUEBoxRepositoryDescriptionKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setDescription:(SBString*)description
  {
    if ( (description && ! [description isEqual:[self description]]) || ([self description] != nil) ) {
      [self setProperty:( description ? (id)description : (id)[SBNull null] ) forKey:SHUEBoxRepositoryDescriptionKey];
    }
  }
  
//

  - (SBInteger) repositoryTypeId
  {
    SBNumber*     reposType = [self propertyForKey:SHUEBoxRepositoryTypeKey];
    
    if ( [reposType isKindOf:[SBNumber class]] )
      return [reposType integerValue];
    return 0;
  }
  - (SBString*) repositoryType
  {
    return nil;
  }

//

  - (SBDate*) creationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxRepositoryCreationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (SBDate*) modificationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxRepositoryModificationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }

//

  - (SBDate*) provisionedTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxRepositoryProvisionedTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (BOOL) hasBeenProvisioned
  {
    return ( [[self propertyForKey:SHUEBoxRepositoryProvisionedTimestampKey] isKindOf:[SBDate class]] );
  }

//

  - (BOOL) canBeRemoved
  {
    SBNumber*     canBeRemoved = [self propertyForKey:SHUEBoxRepositoryCanBeRemovedKey];
    
    if ( [canBeRemoved isKindOf:[SBNumber class]] )
      return [canBeRemoved boolValue];
    return NO;
  }
  - (SBDate*) removalTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxRepositoryRemovalTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setRemovalTimestamp:(SBDate*)removalTimestamp
  {
    [self setProperty:( removalTimestamp ? (id)removalTimestamp : (id)[SBNull null] ) forKey:SHUEBoxRepositoryRemovalTimestampKey];
  }
  - (BOOL) scheduledForRemoval
  {
    return ( [[self propertyForKey:SHUEBoxRepositoryRemovalTimestampKey] isKindOf:[SBDate class]] );
  }
  - (BOOL) shouldBeRemoved
  {
    if ( [self canBeRemoved] ) {
      SBDate*       removalTime = [self propertyForKey:SHUEBoxRepositoryRemovalTimestampKey];
      
      return ( removalTime && ([removalTime compare:[SBDate dateWhichIsAlwaysNow]] == SBOrderAscending) );
    }
    return NO;
  }
  
//

  - (SBString*) homeDirectory
  {
    if ( ! _homeDirectory ) {
      SBString*       collabHome = [[self parentCollaboration] homeDirectory];
      
      if ( collabHome )
        _homeDirectory = [[collabHome stringByAppendingPathComponent:[self shortName]] retain];
    }
    return _homeDirectory;
  }

//

  - (SBError*) setupHomeDirectory
  {
    return nil;
  }

//

  - (SBError*) tearDownHomeDirectory
  {
    return nil;
  }

//

  - (BOOL) roleHasAccess:(SHUEBoxRole*)aRole
  {
    if ( ! _roles )
      [self loadRoleMembership];
    
    if ( _roles ) {
			SBUInteger		i = [_roles indexOfObject:aRole];
      
			if ( i != SBNotFound )
				return YES;
		}
    return NO;
  }
  - (BOOL) roleIdHasAccess:(SHUEBoxRoleId)roleId
  {
    return [self roleHasAccess:[SHUEBoxRole shueboxRoleWithDatabase:[self parentDatabase] roleId:roleId]];
  }
  
//

  - (void) grantRoleAccess:(SHUEBoxRole*)aRole
  {
		if ( ! _roles ) {
			[self loadRoleMembership];
			if ( ! _roles )
				_roles = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRepositoryRoleMemberComparator];
		}
		
		if ( _roles ) {
			SBUInteger		i = [_roles indexOfObject:aRole];
			
			if ( i == SBNotFound ) {
				[_roles addObject:aRole];
				
				if ( ! _addRoles )
					_addRoles = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRepositoryRoleMemberComparator];
				[_addRoles addObject:aRole];
				
				_rolesModified = YES;
			}
		}
  }
  - (void) grantRoleIdAccess:(SHUEBoxRoleId)roleId
  {
    return [self grantRoleAccess:[SHUEBoxRole shueboxRoleWithDatabase:[self parentDatabase] roleId:roleId]];
  }
  
//

  - (void) denyRoleAccess:(SHUEBoxRole*)aRole
  {
		if ( ! _roles ) {
			[self loadRoleMembership];
			if ( ! _roles )
				return;
		}
    
    SBUInteger		i = [_roles indexOfObject:aRole];
    
    if ( i != SBNotFound ) {
      [_roles removeObjectAtIndex:i];
      
      if ( ! _removeRoles )
        _removeRoles = [[SBOrderedSet alloc] initWithComparator:__SHUEBoxRepositoryRoleMemberComparator];
      [_removeRoles addObject:aRole];
      
      _rolesModified = YES;
    }
  }
  - (void) denyRoleIdAccess:(SHUEBoxRoleId)roleId
  {
    return [self denyRoleAccess:[SHUEBoxRole shueboxRoleWithDatabase:[self parentDatabase] roleId:roleId]];
  }
  
//

  - (SBEnumerator*) roleGranteeEnumerator
  {
    if ( ! _roles )
      [self loadRoleMembership];
      
    if ( _roles )
      return [_roles objectEnumerator];
    return nil;
  }
  
//

  - (SBUInteger) roleGranteeCount
  {
    if ( ! _roles )
      [self loadRoleMembership];
      
    return ( _roles ? [_roles count] : 0 );
  }
  - (SHUEBoxRole*) roleGranteeAtIndex:(SBUInteger)index
  {
    if ( ! _roles )
      [self loadRoleMembership];
      
    return ( _roles ? [_roles objectAtIndex:index] : nil );
  }

//

  - (SBError*) appendApacheHTTPConfToString:(SBMutableString*)confString
  {
    return nil;
  }
  
//

  - (SBError*) appendApacheHTTPSConfToString:(SBMutableString*)confString
  {
    [confString appendFormat:
        "  AuthSHUEBoxCollaborationId \"%S\"\n"
        "  AuthSHUEBoxRepositoryId \"%S\"\n"
        "  Require shuebox-repo-user\n",
        [[[self parentCollaboration] shortName] utf16Characters],
        [[self shortName] utf16Characters]
      ];
    return nil;
  }

//
#pragma mark SHUEBoxURI protocol
//

  - (SBString*) uriString
  {
    if ( ! _repositoryURI ) {
      SBString*       baseURI = [[self parentCollaboration] uriString];
      
      if ( baseURI )
        _repositoryURI = [[SBString alloc] initWithFormat:"%S/%S", [baseURI utf16Characters], [[self shortName] utf16Characters]];
    }
    return _repositoryURI;
  }

//
#pragma mark SHUEBoxProvisioning protocol:
//

  - (SBError*) provisionResource
  {
    SBString*     errorExplanation = nil;
    int           errorCode = kSHUEBoxRepositoryProvisionUnneccesary;
    
    // Check to be sure we have't been provisioned yet:
    if ( ! [self hasBeenProvisioned] ) {
      //
      // In this, the abstract base class for repositories, we merely create the directory for
      // the repository; we leave it up to the subclasses to finish setting-up the directory
      // and then update the repository's record in the database.
      //
      SBString*     reposHome = [self homeDirectory];
      
      if ( ! [[SBFileManager sharedFileManager] directoryExistsAtPath:reposHome] ) {
        errorCode = kSHUEBoxRepositoryProvisionFailed;
        if ( [[SBFileManager sharedFileManager] createDirectoryAtPath:reposHome mode:(S_IRWXU | S_IRWXG | S_ISUID)] ) {
          //
          // We won't worry about ownership, that should have been inherited thanks to our careful usage of
          // the setuid bit.  So once we get here, all was okay thus far!
          //
          SBError*    anError = [self setupHomeDirectory];
          
          if ( ! anError ) {
            //
            // Update the database:
            //
            [self setProperty:[SBDate date] forKey:SHUEBoxRepositoryProvisionedTimestampKey];
            if ( ! [self commitModifications] ) {
              errorExplanation = [SBString stringWithFormat:"Unable to update repository object in database (reposId=" SBIntegerFormat ")", [self reposId]];
            } else {
              //
              // Make Apache sit up and take notice:
              //
              [[self retain] autorelease];
              [[self parentCollaboration] reloadRepositories];
              anError = [[self parentCollaboration] updateApacheConfiguration];
            }
          }
          return anError;
        } else {
          errorExplanation = [SBString stringWithFormat:"Repository directory could not be created (reposId=" SBIntegerFormat ")", [self reposId]];
        }
      } else {
        errorExplanation = [SBString stringWithFormat:"Repository (reposId=" SBIntegerFormat ") does not need provisioning.", [self reposId]];
      }
    } else {
      errorExplanation = [SBString stringWithFormat:"Repository (reposId=" SBIntegerFormat ") does not need provisioning.", [self reposId]];
    }
    
    // Error out:
    if ( errorExplanation )
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:[SBDictionary dictionaryWithObject:errorExplanation forKey:SBErrorExplanationKey]];
    return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:nil];
  }
  
//

  - (SBError*) destroyResource
  {
    SBString*               errorExplanation = nil;
    int                     errorCode = kSHUEBoxRepositoryDestroyUnneccesary;
    SHUEBoxCollaboration*   parentCollab = [self parentCollaboration];
    
    if ( [self shouldBeRemoved] ) {
      SBError*    tearDownError = [self tearDownHomeDirectory];
      
      // "tearDown" gives subclasses a chance to do something interesting with the data prior to its
      // being scrubbed:
      if ( tearDownError )
        return tearDownError;
        
      errorCode = kSHUEBoxRepositoryDestroyFailed;
      
      if ( [[SBFileManager sharedFileManager] removeItemAtPath:[self homeDirectory]] ) {
        // Directory is gone, update the database:
        if ( [self deleteFromDatabase] ) {
          // As we ask the cache and collaboration to release references to us, we could wind up being
          // deallocated!  So we retain ourself and autorelease that reference:
          self = [[self retain] autorelease];
          
          // Make sure to drop us from the cache now, too:
          if ( __SHUEBoxRepositoryCache )
            [__SHUEBoxRepositoryCache evictObjectFromCache:self];
            
          // Our parent collaboration shouldn't be holding us anymore, either:
          [[self retain] autorelease];
          [parentCollab reloadRepositories];
            
          // Make Apache notice:
          return [parentCollab updateApacheConfiguration];
        } else {
          errorExplanation = [SBString stringWithFormat:"Unable to remove repository (reposId=" SBIntegerFormat ") from database.", [self reposId]];
        }
      } else {
        errorExplanation = [SBString stringWithFormat:"Home directory for repository (reposId=" SBIntegerFormat ") could not be removed.", [self reposId]];
      }
    } else {
      errorExplanation = [SBString stringWithFormat:"Repository (reposId=" SBIntegerFormat ") does not require removal.", [self reposId]];
    }
    
    // Error out:
    if ( errorExplanation )
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:[SBDictionary dictionaryWithObject:errorExplanation forKey:SBErrorExplanationKey]];
    return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:nil];
  }

//
#if 0
#pragma mark SBDatabaseObject methods
#endif
//

	- (BOOL) hasBeenModified
	{
		if ( _rolesModified )
			return YES;
		return [super hasBeenModified];
	}

//

	- (void) refreshCommittedProperties
	{
		if ( _roles ) {
			[_roles release];
			_roles = nil;
		}
		if ( _addRoles ) {
			[_addRoles release];
			_addRoles = nil;
		}
		if ( _removeRoles ) {
			[_removeRoles release];
			_removeRoles = nil;
		}
		[super refreshCommittedProperties];
	}
	
//

	- (void) revertModifications
	{
		if ( _rolesModified ) {
      [_roles release];
      _roles = nil;
    }
    if ( _addRoles ) {
      [_addRoles removeAllObjects];
    }
    if ( _removeRoles ) {
      [_removeRoles removeAllObjects];
    }
    _rolesModified = NO;
		[super revertModifications];
	}

//

	- (BOOL) commitModifications
	{
		BOOL			rc = YES;
		
		if ( _rolesModified )
			rc = [self commitRoleMembership];
		if ( rc )
			rc = [super commitModifications];
		return rc;
	}

@end
