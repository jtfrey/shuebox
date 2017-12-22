//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxCollaboration.m
//
// Represents a SHUEBox collaboration.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxCollaboration.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBDate.h"
#import "SBValue.h"
#import "SBDatabaseAccess.h"
#import "SBObjectCache.h"
#import "SBZFSFilesystem.h"
#import "SHUEBoxPathManager.h"
#import "SHUEBoxRepository.h"
#import "SHUEBoxUser.h"
#import "SHUEBoxRole.h"
#import "SHUEBoxDictionary.h"
#import "SBNotification.h"

SBString* SHUEBoxCollaborationIdKey                     = @"collabid";
SBString* SHUEBoxCollaborationShortNameKey              = @"shortname";
SBString* SHUEBoxCollaborationDescriptionKey            = @"description";
SBString* SHUEBoxCollaborationQuotaKey                  = @"megabytesquota";
SBString* SHUEBoxCollaborationReservationKey            = @"megabytesreserved";
SBString* SHUEBoxCollaborationCompressionIsEnabledKey   = @"compressionisenabled";
SBString* SHUEBoxCollaborationHomeDirectoryKey          = @"homedirectory";
SBString* SHUEBoxCollaborationCreationTimestampKey      = @"created";
SBString* SHUEBoxCollaborationModificationTimestampKey  = @"modified";
SBString* SHUEBoxCollaborationProvisionedTimestampKey   = @"provisioned";
SBString* SHUEBoxCollaborationRemovalTimestampKey       = @"removeafter";

//

@interface SHUEBoxCollaboration(SHUEBoxCollaborationPrivate)

- (void) roleWasRemoved:(SBNotification*)aNotification;

@end

@implementation SHUEBoxCollaboration(SHUEBoxCollaborationPrivate)

  - (void) roleWasRemoved:(SBNotification*)aNotification
  {
    if ( _roles ) {
      SHUEBoxRole*    removedRole = [aNotification object];
      
      if ( removedRole )
        [_roles removeObject:removedRole];
    }
  }

@end

//

SBObjectCache* __SHUEBoxCollaborationCache = nil;

@implementation SHUEBoxCollaboration

  + (id) initialize
  {
    if ( __SHUEBoxCollaborationCache == nil ) {
      __SHUEBoxCollaborationCache = [[SBObjectCache alloc] initWithBaseClass:[SHUEBoxCollaboration class]];
      if ( __SHUEBoxCollaborationCache ) {
        [__SHUEBoxCollaborationCache createCacheIndexForKey:SHUEBoxCollaborationIdKey];
        [__SHUEBoxCollaborationCache createCacheIndexForKey:SHUEBoxCollaborationShortNameKey];
      }
    }
  }

//

  + (SBString*) tableNameForClass
  {
    return @"collaboration.definition";
  }
  
//

  + (SBString*) objectIdKeyForClass
  {
    return @"collabid";
  }
  
//

  + (SBArray*) propertyKeysForClass
  {
    static SBArray*     SHUEBoxCollaborationKeys = nil;
    
    if ( SHUEBoxCollaborationKeys == nil ) {
      SHUEBoxCollaborationKeys = [[SBArray alloc] initWithObjects:
                                        SHUEBoxCollaborationIdKey,
                                        SHUEBoxCollaborationShortNameKey,
                                        SHUEBoxCollaborationDescriptionKey,
                                        SHUEBoxCollaborationQuotaKey,
                                        SHUEBoxCollaborationReservationKey,
                                        SHUEBoxCollaborationCompressionIsEnabledKey,
                                        SHUEBoxCollaborationHomeDirectoryKey,
                                        SHUEBoxCollaborationCreationTimestampKey,
                                        SHUEBoxCollaborationModificationTimestampKey,
                                        SHUEBoxCollaborationProvisionedTimestampKey,
                                        SHUEBoxCollaborationRemovalTimestampKey,
                                        nil
                                      ];
    }
    return SHUEBoxCollaborationKeys;
  }

//

  + (void) flushCollaborationCache
  {
    if ( __SHUEBoxCollaborationCache )
      [__SHUEBoxCollaborationCache flushCache];
  }
  
//

  + (void) removeCollaborationFromCache:(SHUEBoxCollaboration*)aCollaboration
  {
    if ( __SHUEBoxCollaborationCache )
      [__SHUEBoxCollaborationCache evictObjectFromCache:aCollaboration];
  }

//

  + (SBArray*) collaborationsWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT collabId FROM collaboration.definition"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxCollaboration*   objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     collabId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( collabId )
          objects[index++] = [self collaborationWithDatabase:database collabId:[collabId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (SBArray*) unprovisionedCollaborationsWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT collabId FROM collaboration.definition WHERE provisioned IS NULL"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxCollaboration*   objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     collabId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( collabId )
          objects[index++] = [self collaborationWithDatabase:database collabId:[collabId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (SBArray*) collaborationsForRemovalWithDatabase:(id)database
  {
    id                idLookup = [database executeQuery:@"SELECT collabId FROM collaboration.definition WHERE removeafter <= now()"];
    SBUInteger        rowCount;
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxCollaboration*   objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     collabId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( collabId )
          objects[index++] = [self collaborationWithDatabase:database collabId:[collabId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (SBArray*) collaborationsWithDatabase:(id)database
    forUser:(SHUEBoxUser*)user
  {
    SBString*         queryStr = [[SBString alloc] initWithFormat:
                                              "SELECT collabId FROM collaboration.definition"
                                              "  WHERE collabId IN (SELECT collabId FROM collaboration.member"
                                              "    WHERE userId = %lld)",
                                              (long long int)[user shueboxUserId]
                                        ];
    id                idLookup = [database executeQuery:queryStr];
    SBUInteger        rowCount;
    
    [queryStr release];
    
    if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
      SHUEBoxCollaboration*   objects[rowCount];
      SBUInteger              index = 0;
      
      while ( rowCount-- ) {
        SBNumber*     collabId = [idLookup objectForRow:rowCount fieldNum:0];
      
        if ( collabId )
          objects[index++] = [self collaborationWithDatabase:database collabId:[collabId integerValue]];
      }
      if ( index )
        return [SBArray arrayWithObjects:objects count:index];
    }
    return nil;
  }

//

  + (id) collaborationWithDatabase:(id)database
    collabId:(SBInteger)collabId
  {
    id            object = nil;
    SBNumber*     objId = [SBNumber numberWithInteger:collabId];
    
    if ( ! (object = [__SHUEBoxCollaborationCache cachedObjectForKey:SHUEBoxCollaborationIdKey value:objId]) ) {
      object = [self databaseObjectWithDatabase:database objectId:collabId];
      
      if ( object )
        [__SHUEBoxCollaborationCache addObjectToCache:object];
    } else {
      [object refreshCommittedProperties];
    }
    return object;
  }
  
//
  
  + (id) collaborationWithDatabase:(id)database
    shortName:(SBString*)shortName
  {
    id            object = nil;
    
    if ( ! (object = [__SHUEBoxCollaborationCache cachedObjectForKey:SHUEBoxCollaborationShortNameKey value:shortName]) ) {
      object = [self databaseObjectWithDatabase:database key:SHUEBoxCollaborationShortNameKey value:shortName];
      
      if ( object )
        [__SHUEBoxCollaborationCache addObjectToCache:object];
    } else {
      [object refreshCommittedProperties];
    }
    return object;
  }

//

  - (id) init
  {
    if ( (self = [super init]) ) {
      [[SBNotificationCenter defaultNotificationCenter] addObserver:self selector:@selector(roleWasRemoved:) identifier:SHUEBoxRoleWasRemovedNotification object:nil];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _uriString ) [_uriString release];
    if ( _filesystem ) [_filesystem release];
    
    [[SBNotificationCenter defaultNotificationCenter] removeObserver:self];
    
    [super dealloc];
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( otherObject == self ) {
      return YES;
    }
    if ( [otherObject isKindOf:[SHUEBoxCollaboration class]] ) {
      if ( [otherObject collabId] == [self collabId] ) {
        return YES;
      }
      if ( [[otherObject shortName] isEqual:[self shortName]] ) {
        return YES;
      }
    }
    return NO;
  }

//

  - (SBInteger) collabId
  {
    SBNumber*     collabId = [self propertyForKey:SHUEBoxCollaborationIdKey];
    
    if ( [collabId isKindOf:[SBNumber class]] )
      return [collabId integerValue];
    return 0;
  }

//

  - (SBString*) shortName
  {
    SBString*     value = [self propertyForKey:SHUEBoxCollaborationShortNameKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  
//

  - (SBString*) description
  {
    SBString*     value = [self propertyForKey:SHUEBoxCollaborationDescriptionKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setDescription:(SBString*)description
  {
    if ( (description && ! [description isEqual:[self description]]) || ([self description] != nil) ) {
      [self setProperty:( description ? (id)description : (id)[SBNull null] ) forKey:SHUEBoxCollaborationDescriptionKey];
    }
  }
  
//

  - (SBUInteger) megabytesQuota
  {
    SBNumber*     value = [self propertyForKey:SHUEBoxCollaborationQuotaKey];
    
    if ( [value isKindOf:[SBNumber class]] )
      return [value unsignedIntegerValue];
    return 0;
  }
  - (void) setMegabytesQuota:(SBUInteger)mb
  {
    if ( mb != [self megabytesQuota] ) {
      [self setProperty:(id)[SBNumber numberWithUnsignedInteger:mb] forKey:SHUEBoxCollaborationQuotaKey];
    }
  }
  - (SBUInteger) megabytesReserved
  {
    SBNumber*     value = [self propertyForKey:SHUEBoxCollaborationReservationKey];
    
    if ( [value isKindOf:[SBNumber class]] )
      return [value unsignedIntegerValue];
    return 0;
  }
  - (void) setMegabytesReserved:(SBUInteger)mb
  {
    if ( mb != [self megabytesReserved] ) {
      [self setProperty:(id)[SBNumber numberWithUnsignedInteger:mb] forKey:SHUEBoxCollaborationReservationKey];
    }
  }
  
//

  - (BOOL) compressionIsEnabled
  {
    SBNumber*     value = [self propertyForKey:SHUEBoxCollaborationCompressionIsEnabledKey];
    
    if ( [value isKindOf:[SBNumber class]] )
      return [value boolValue];
    return NO;
  }
  - (void) setCompressionIsEnabled:(BOOL)state
  {
    if ( state != [self compressionIsEnabled] ) {
      [self setProperty:(id)[SBNumber numberWithBool:state] forKey:SHUEBoxCollaborationCompressionIsEnabledKey];
    }
  }

//

  - (SBString*) homeDirectory
  {
    SBString*     value = [self propertyForKey:SHUEBoxCollaborationHomeDirectoryKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  
//

  - (SBDate*) creationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxCollaborationCreationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (SBDate*) modificationTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxCollaborationModificationTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }

//

  - (SBDate*) provisionedTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxCollaborationProvisionedTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (BOOL) hasBeenProvisioned
  {
    return ( [[self propertyForKey:SHUEBoxCollaborationProvisionedTimestampKey] isKindOf:[SBDate class]] );
  }

//

  - (SBDate*) removalTimestamp
  {
    SBDate*     value = [self propertyForKey:SHUEBoxCollaborationRemovalTimestampKey];
    
    if ( [value isNull] )
      return nil;
    return value;
  }
  - (void) setRemovalTimestamp:(SBDate*)removalTimestamp
  {
    [self setProperty:( removalTimestamp ? (id)removalTimestamp : (id)[SBNull null] ) forKey:SHUEBoxCollaborationRemovalTimestampKey];
  }
  - (BOOL) scheduledForRemoval
  {
    return ( [[self propertyForKey:SHUEBoxCollaborationRemovalTimestampKey] isKindOf:[SBDate class]] );
  }
  - (BOOL) shouldBeRemoved
  {
    SBDate*       removalTime = [self propertyForKey:SHUEBoxCollaborationRemovalTimestampKey];
    
    return ( removalTime && ([removalTime compare:[SBDate dateWhichIsAlwaysNow]] == SBOrderAscending) );
  }

//

  - (SBError*) removeFromDatabase
  {
    SBInteger     collabId = [self collabId];
    SBError*      anError = nil;
    
    if ( collabId > 0 ) {
      // Update the database accordingly:
      if ( ! [self deleteFromDatabase] ) {
        anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationRemovalFailed
                      supportingData:[SBDictionary dictionaryWithObject:
                          [SBString stringWithFormat:"Unable to remove collaboration `%S` from database.", [[self shortName] utf16Characters]]
                          forKey:SBErrorExplanationKey
                        ]
                    ];
      } else {
        // Make sure to drop us from the cache now, too:
        [SHUEBoxCollaboration removeCollaborationFromCache:self];
      }
    } else {
      anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationRemovalFailed
                          supportingData:[SBDictionary dictionaryWithObject:
                              [SBString stringWithFormat:"Invalid collaboration id : " SBIntegerFormat ".", collabId]
                              forKey:SBErrorExplanationKey
                            ]
                        ];
    }
    return anError;
  }

//

  - (SBZFSFilesystem*) filesystem
  {
    if ( ! _filesystem ) {
      SBString*           shortName = [self shortName];
      
      if ( shortName )
        _filesystem = [[[SHUEBoxPathManager shueboxPathManager] zfsFilesystemForCollaborationId:shortName] retain];
    }
    return _filesystem;
  }
  
//

  - (SBError*) syncFilesystemProperties
  {
    SBZFSFilesystem*    collabFS = [self filesystem];
    
    if ( collabFS ) {
      SBUInteger              value;
      BOOL                    state;
      SBZFSCompressionType    compressType = [collabFS compressionType];
      
      value = [self megabytesQuota];
      if ( ! [collabFS setQuotaMegabytes:value] ) {
        return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationFilesystemError supportingData:
                          [SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Unable to set collaboration ZFS quota: %S", [[collabFS zfsFilesystem] utf16Characters]]
                              forKey:SBErrorExplanationKey]
                    ];
      }
      value = [self megabytesReserved];
      if ( ! [collabFS setReservedMegabytes:value] ) {
        return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationFilesystemError supportingData:
                          [SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Unable to set collaboration ZFS reservation: %S", [[collabFS zfsFilesystem] utf16Characters]]
                              forKey:SBErrorExplanationKey]
                    ];
      }
      state = [self compressionIsEnabled];
      if ( (state && (compressType == SBZFSCompressionTypeNone)) || (! state && (compressType != SBZFSCompressionTypeNone)) ) {
        if ( ! [collabFS setCompressionType:( state ? SBZFSCompressionTypeDefault : SBZFSCompressionTypeNone )] ) {
          return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationFilesystemError supportingData:
                          [SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Unable to set collaboration ZFS compression state: %S", [[collabFS zfsFilesystem] utf16Characters]]
                              forKey:SBErrorExplanationKey]
                    ];
        }
      }
    } else {
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationFilesystemError supportingData:
                          [SBDictionary dictionaryWithObject:@"Unable to get filesystem for collaboration." forKey:SBErrorExplanationKey]
                  ];
    }
    return nil;
  }

//

  - (SBError*) updateApacheConfiguration
  {
    SBMutableString*    config = [[SBMutableString alloc] init];
    SBError*            error;
    
    // Build the HTTP configuration:
    error = [self appendApacheHTTPConfToString:config];
    if ( ! error ) {
      BOOL              needsRestart = NO;
      
      // Write the file:
      error = [[SHUEBoxApacheManager shueboxApacheManager] writeConfiguration:config forCollaboration:self isHTTPS:NO];
      if ( ! error ) {
        if ( [config length] > 0 )
          needsRestart = YES;
        
        // Build the HTTPS configuration:
        [config deleteAllCharacters];
        error = [self appendApacheHTTPSConfToString:config];
        if ( ! error ) {
          // Write the file:
          error = [[SHUEBoxApacheManager shueboxApacheManager] writeConfiguration:config forCollaboration:self isHTTPS:YES];
          if ( ! error && ([config length] > 0) )
            needsRestart = YES;
        }
      }
      
      // Do a restart?
      if ( ! error && needsRestart )
        error = [[SHUEBoxApacheManager shueboxApacheManager] gracefulRestart];
    }
    return error;
  }

//

  - (SBError*) installResource:(SBString*)resourceName
  {
    return [self installResource:resourceName withInstanceName:nil];
  }
  - (SBError*) installResource:(SBString*)resourceName
    withInstanceName:(SBString*)instanceName
  {
    // So where are we installing this?
    SBString*       myRoot = [self homeDirectory];
    SBError*        error = nil;
    
    if ( myRoot ) {
      error = [[SHUEBoxPathManager shueboxPathManager] installResource:resourceName inDirectory:myRoot withInstanceName:instanceName];
    } else {
      error = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationProvisionFailed supportingData:
                          [SBDictionary dictionaryWithObject:@"Unable to get root directory for collaboration." forKey:SBErrorExplanationKey]
                  ];
    }
    return error;
  }

//

  - (void) reloadRoles
  {
    if ( _roles ) {
      [_roles release];
      _roles = nil;
    }
  }

//

  - (void) reloadRepositories
  {
    if ( _repositories ) {
      [_repositories release];
      _repositories = nil;
    }
  }
  
//

  - (void) reloadUsers
  {
    if ( _users ) {
      [_users release];
      _users = nil;
    }
  }

//

  - (SBArray*) repositories
  {
    if ( _repositories == nil ) {
      SBArray*    repositories = [SHUEBoxRepository repositoriesForCollaboration:self];
      if ( repositories ) {
        if ( [repositories count] )
          _repositories = [repositories mutableCopy];
        else
          _repositories = nil;
      }
    }
    return _repositories;
  }
	
//

	- (SBArray*) shueboxUsers
	{
		if ( _users == nil ) {
			SBArray*    users = [SHUEBoxUser shueboxUsersForCollaboration:self];
			if ( users ) {
				if ( [users count] )
					_users = [users mutableCopy];
				else
					_users = nil;
			}
		}
		return _users;
	}
	
//

	- (SBArray*) shueboxRoles
	{
		if ( _roles == nil ) {
			SBArray*    roles = [SHUEBoxRole shueboxRolesForCollaboration:self];
			if ( roles ) {
				if ( [roles count] )
					_roles = [roles mutableCopy];
				else
					_roles = nil;
			}
		}
		return _roles;
	}
	
//

  - (SHUEBoxUser*) shueboxUserWithId:(SBInteger)userId
  {
		SBArray*						users = [self shueboxUsers];
		
		if ( users ) {
			SBUInteger				i = 0, iMax = [users count];
			
			while ( i < iMax ) {
				SHUEBoxUser*		user = [users objectAtIndex:i++];
				
				if ( [user shueboxUserId] == userId )
					return user;
			}
		}
		return nil;
  }

//

  - (SHUEBoxUser*) shueboxUserWithName:(SBString*)userName
  {
		SBArray*						users = [self shueboxUsers];
		
		if ( users ) {
			SBUInteger				i = 0, iMax = [users count];
			
			while ( i < iMax ) {
				SHUEBoxUser*		user = [users objectAtIndex:i++];
				
				if ( [userName isEqual:[user shortName]] )
					return user;
			}
		}
		return nil;
  }

//

  - (SHUEBoxRole*) shueboxRoleWithId:(SBInteger)roleId
  {
		SBArray*						roles = [self shueboxRoles];
		
		if ( roles ) {
			SBUInteger				i = 0, iMax = [roles count];
			
			while ( i < iMax ) {
				SHUEBoxRole*		role = [roles objectAtIndex:i++];
				
				if ( [role shueboxRoleId] == roleId )
					return role;
			}
		}
		return nil;
  }

//

	- (SHUEBoxRole*) shueboxRoleWithName:(SBString*)roleName
	{
		SBArray*						roles = [self shueboxRoles];
		
		if ( roles ) {
			SBUInteger				i = 0, iMax = [roles count];
			
			while ( i < iMax ) {
				SHUEBoxRole*		role = [roles objectAtIndex:i++];
				
				if ( [roleName isEqual:[role shortName]] )
					return role;
			}
		}
		return nil;
	}
	
//

	- (SHUEBoxRole*) administratorSHUEBoxRole
	{
		return [self shueboxRoleWithName:@"administrator"];
	}

//

	- (BOOL) userIsAdministrator:(SHUEBoxUser*)aUser
	{
		SHUEBoxRole*	adminRole = [self administratorSHUEBoxRole];
		
		return ( adminRole ? [adminRole isMember:aUser] : NO );
	}
  
//

  - (SHUEBoxRole*) everyoneSHUEBoxRole
	{
		return [self shueboxRoleWithName:@"everyone"];
	}

//

  - (BOOL) userIsMember:(SHUEBoxUser*)aUser
	{
		SHUEBoxRole*	everyoneRole = [self everyoneSHUEBoxRole];
		
		return ( everyoneRole ? [everyoneRole isMember:aUser] : NO );
	}

//
#pragma mark SHUEBoxApacheConf protocol
//

  - (SBError*) appendApacheHTTPConfToString:(SBMutableString*)confString
  {
    // Hit-up all of the repositories; the collaboration itself has nothing to add to
    // the config:
    SBArray*        repos = [self repositories];
    
    if ( repos ) {
      SBUInteger    i = 0, iMax = [repos count];
      
      while ( i < iMax ) {
        SBError*    error = [[repos objectAtIndex:i++] appendApacheHTTPConfToString:confString];
        
        if ( error )
          return error;
      }
    }
    return nil;
  }
  
//

  - (SBError*) appendApacheHTTPSConfToString:(SBMutableString*)confString
  {
    const UChar*    shortName = [[self shortName] utf16Characters];
    
    // Add the meta data interface support:
    [confString appendFormat:
                  "# For administrative control of the collaboration:\n"
                  "<Location /%S/__METADATA__>\n"
                  "  AuthSHUEBoxCollaborationId \"%S\"\n"
                  "  <Limit GET>\n"
                  "    Require shuebox-collab-user\n"
                  "  </Limit>\n"
                  "  <Limit PUT POST DELETE>\n"
                  "    Require shuebox-collab-admin\n"
                  "  </Limit>\n"
                  "</Location>\n\n",
                  shortName,
                  shortName
                ];
    
    // Hit-up all of the repositories:
    SBArray*        repos = [self repositories];
    
    if ( repos ) {
      SBUInteger    i = 0, iMax = [repos count];
      
      while ( i < iMax ) {
        SBError*    error = [[repos objectAtIndex:i++] appendApacheHTTPSConfToString:confString];
        
        if ( error )
          return error;
      }
    }
    return nil;
  }
  
//
#pragma mark SHUEBoxURI protocol
//

  - (SBString*) uriString
  {
    if ( ! _uriString ) {
      SBString*     baseURI = [[self parentDatabase] stringForFullDictionaryKey:SHUEBoxDictionarySystemBaseURIPathKey];
      
      if ( baseURI ) {
        const char* format = "%S%S";
        
        if ( [baseURI characterAtIndex:[baseURI length] - 1] != '/' )
          format = "%S/%S";
        _uriString = [[SBString alloc] initWithFormat:format,
                        [baseURI utf16Characters],
                        [[self shortName] utf16Characters]
                      ];
      } else {
        _uriString = [[self shortName] retain];
      }
    }
    return _uriString;
  }

//
#pragma mark SHUEBoxProvisioning protocol:
//

  - (SBError*) provisionResource
  {
    SBError*      anError;
    SBString*     errorExplanation = nil;
    int           errorCode;
    
    // Check to be sure we have't been provisioned yet:
    if ( [self hasBeenProvisioned] ) {
      errorCode = kSHUEBoxCollaborationProvisionUnneccesary;
      errorExplanation = [SBString stringWithFormat:"Collaboration (collabId=" SBIntegerFormat ") does not need provisioning.", [self collabId]];
      goto exitWithError;
    }
    
    SBString*     shortName = [self shortName];
    
    if ( ! shortName ) {
      errorCode = kSHUEBoxCollaborationProvisionFailed;
      errorExplanation = [SBString stringWithFormat:"Collaboration (collabId=" SBIntegerFormat ") lacks a shortName!", [self collabId]];
      goto exitWithError;
    }
    
    SBZFSFilesystem*  collabFS = [[SHUEBoxPathManager shueboxPathManager] zfsFilesystemForCollaborationId:shortName];
        
    // Does a ZFS filesystem already exist for it?
    if ( ! collabFS ) {
      // Create the filesystem and get it mounted:
      collabFS = [[SHUEBoxPathManager shueboxPathManager] createZFSFilesystemForCollaborationId:shortName];
      
      if ( ! collabFS ) {
        errorCode = kSHUEBoxCollaborationProvisionFailed;
        errorExplanation = [SBString stringWithFormat:"Could not create and mount a ZFS filesystem for collaboration '%S' (collabId=" SBIntegerFormat ")", [shortName utf16Characters], [self collabId]];
        goto exitWithError;
      }
    }

    //
    // Set permissions on the collaboration's root directory:
    //
    SBString*       collabRoot = [self homeDirectory];
    
    if ( ! collabRoot ) {
      errorCode = kSHUEBoxCollaborationProvisionNoMountpoint;
      errorExplanation = [SBString stringWithFormat:"Unable to get www-root template or mountpoint for collaboration '%S' (collabId=" SBIntegerFormat ")", [shortName utf16Characters], [self collabId]];
      goto exitWithError;
    }
        
    //
    // Update the database:
    //
    [self setProperty:[SBDate date] forKey:SHUEBoxCollaborationProvisionedTimestampKey];
    if ( ! [self commitModifications] ) {
      errorCode = kSHUEBoxCollaborationProvisionFailed;
      errorExplanation = [SBString stringWithFormat:"Unable to update collaboration object in database (collabId=" SBIntegerFormat ")", [self collabId]];
      goto exitWithError;
    }
    
    //
    // Delay any Apache restarts for now; that way, any repositories we create won't also be HUP'ing
    // the web server as we go along:
    //
    [[SHUEBoxApacheManager shueboxApacheManager] setDelayRestarts:YES];
    
    // Make Apache sit up and take notice:
    if ( (anError = [self updateApacheConfiguration]) ) {
      [[SHUEBoxApacheManager shueboxApacheManager] setDelayRestarts:NO];
      return anError;
    }
        
    //
    // From here on out, errors are not necessarily terminal.  So we'll create an array of them
    // and if by the time we're done it's populated, then we return a "warning" SBError that
    // contains the list of errors.
    //
    SBMutableArray* errorList = [[SBMutableArray alloc] init];
    
    //
    // Set permissions on the collaboration's home directory:
    //
    //   Group owner:   webservd
    //   Mode:          S_IRWXU | S_IRWXG | S_ISGID
    //
    if ( ! [[SBFileManager sharedFileManager] setOwnerUId:[[SHUEBoxApacheManager shueboxApacheManager] apacheUserId]
              andGId:[[SHUEBoxApacheManager shueboxApacheManager] apacheGroupId]
              posixMode:(S_IRWXU | S_IRWXG | S_ISGID)
              atPath:collabRoot
            ]
    )
    {
      [errorList addObject:[SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingObjectsAndKeys:
                                [SBString stringWithFormat:"Unable to set ownership and permissions on %S", [collabRoot utf16Characters]], SBErrorExplanationKey,
                                nil
                              ]
                        ];
    }
    
    //
    // Try to set initial quota, reservation, and compression:
    //
    if ( (anError = [self syncFilesystemProperties]) ) {
      [errorList addObject:anError];
    }
    
    //
    // Handle any repositories that were initially created for this collaboration:
    //
    SBArray*      initialRepos = [SHUEBoxRepository repositoriesForCollaboration:self];
    SBUInteger    repoMax;
    
    if ( initialRepos && (repoMax = [initialRepos count]) ) {
      SBUInteger        repoIdx = 0;
      
      while ( repoIdx < repoMax ) {
        if ( (anError = [[initialRepos objectAtIndex:repoIdx++] provisionResource]) ) {
          [errorList addObject:anError];
        }
      }
    }
    
    //
    // No need to postpone Apache restarts any longer.  By disabling the delay, the
    // SHUEBoxApacheManager will act on any restart condition it accumulated after we turned
    // the delay feature on, though!
    //
    [[SHUEBoxApacheManager shueboxApacheManager] setDelayRestarts:NO];
    
    //
    // Look at our list of errors; if there were any, return a warning SBError:
    //
    if ( [errorList count] ) {
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationProvisionWarning supportingObjectsAndKeys:
                                [SBString stringWithFormat:"There were problems while provisioning collaboration `%S`.", [shortName utf16Characters]], SBErrorExplanationKey,
                                [errorList autorelease], SBErrorUnderlyingErrorKey,
                                nil
                              ];
    }
    [errorList release];
    return nil;

exitWithError:
    // Error out:
    if ( errorExplanation )
      return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:[SBDictionary dictionaryWithObject:errorExplanation forKey:SBErrorExplanationKey]];
    return [SBError errorWithDomain:SHUEBoxErrorDomain code:errorCode supportingData:nil];
  }

//

  - (SBError*) destroyResource
  {
    SBError*      anError;
    
    // Remove the Apache configs:
    anError = [[SHUEBoxApacheManager shueboxApacheManager] removeConfigurationForCollaboration:self isHTTPS:NO];
    if ( ! anError ) {
      anError = [[SHUEBoxApacheManager shueboxApacheManager] removeConfigurationForCollaboration:self isHTTPS:YES];
      if ( ! anError ) {
        //
        // Make Apache sit up and take notice:
        //
        anError = [[SHUEBoxApacheManager shueboxApacheManager] gracefulRestart];
        if ( ! anError ) {
          SBZFSFilesystem*    collabShare = [self filesystem];
          
          // Scrub the ZFS share!
          if ( collabShare ) {
            SBString*         zfsName = [[collabShare zfsFilesystem] retain];
            
            [collabShare release];
            if ( [SBZFSFilesystem destroyZFSFilesystem:zfsName] ) {
              // All done!  Update the database accordingly:
              if ( ! [self deleteFromDatabase] ) {
                anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationDestroyFailed
                              supportingData:[SBDictionary dictionaryWithObject:
                                  [SBString stringWithFormat:"Unable to remove collaboration `%S` from database.", [[self shortName] utf16Characters]]
                                  forKey:SBErrorExplanationKey
                                ]
                            ];
              } else {
                // As we ask the cache to release its reference to us, we could wind up being
                // deallocated!  So we retain ourself and autorelease that reference:
                self = [[self retain] autorelease];
                
                // Make sure to drop us from the cache now, too:
                if ( __SHUEBoxCollaborationCache )
                  [__SHUEBoxCollaborationCache evictObjectFromCache:self];
              }
            } else {
              anError = [SBError errorWithDomain:SHUEBoxErrorDomain code:kSHUEBoxCollaborationDestroyFailed
                            supportingData:[SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Unable to destroy ZFS filesystem for `%S`.", [[self shortName] utf16Characters]]
                                forKey:SBErrorExplanationKey
                              ]
                          ];
            }
            [zfsName release];
          }
        }
      }
    }
    return anError;
  }

@end
