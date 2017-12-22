//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxCollaboration.h
//
// Represents a SHUEBox collaboration.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"
#import "SBDatabaseObject.h"
#import "SHUEBoxApacheManager.h"

@class SBDate, SBString, SBArray, SBMutableArray, SBZFSFilesystem, SHUEBoxUser, SHUEBoxRole;

@protocol SHUEBoxURI

- (SBString*) uriString;

@end

@protocol SHUEBoxProvisioning

- (SBError*) provisionResource;
- (SBError*) destroyResource;

@end

@interface SHUEBoxCollaboration : SBDatabaseObject <SHUEBoxApacheConf,SHUEBoxURI, SHUEBoxProvisioning>
{
  SBZFSFilesystem*  _filesystem;
  SBString*         _uriString;
  SBMutableArray*   _repositories;
  SBMutableArray*   _users;
  SBMutableArray*   _roles;
}

+ (void) flushCollaborationCache;
+ (void) removeCollaborationFromCache:(SHUEBoxCollaboration*)aCollaboration;

+ (SBArray*) collaborationsWithDatabase:(id)database;
+ (SBArray*) unprovisionedCollaborationsWithDatabase:(id)database;
+ (SBArray*) collaborationsForRemovalWithDatabase:(id)database;
+ (SBArray*) collaborationsWithDatabase:(id)database forUser:(SHUEBoxUser*)user;

+ (id) collaborationWithDatabase:(id)database collabId:(SBInteger)collabId;
+ (id) collaborationWithDatabase:(id)database shortName:(SBString*)shortName;

- (SBInteger) collabId;

- (SBString*) shortName;

- (SBString*) description;
- (void) setDescription:(SBString*)description;

- (SBUInteger) megabytesQuota;
- (void) setMegabytesQuota:(SBUInteger)mb;
- (SBUInteger) megabytesReserved;
- (void) setMegabytesReserved:(SBUInteger)mb;

- (BOOL) compressionIsEnabled;
- (void) setCompressionIsEnabled:(BOOL)state;

- (SBString*) homeDirectory;
- (SBDate*) creationTimestamp;
- (SBDate*) modificationTimestamp;

- (SBDate*) provisionedTimestamp;
- (BOOL) hasBeenProvisioned;

- (SBDate*) removalTimestamp;
- (void) setRemovalTimestamp:(SBDate*)removalTimestamp;
- (BOOL) scheduledForRemoval;
- (BOOL) shouldBeRemoved;
- (SBError*) removeFromDatabase;

//

- (SBZFSFilesystem*) filesystem;
- (SBError*) syncFilesystemProperties;

- (SBError*) updateApacheConfiguration;

- (SBError*) installResource:(SBString*)resourceName;
- (SBError*) installResource:(SBString*)resourceName withInstanceName:(SBString*)instanceName;

//

- (void) reloadRoles;
- (void) reloadRepositories;
- (void) reloadUsers;

- (SBArray*) repositories;
- (SBArray*) shueboxUsers;
- (SBArray*) shueboxRoles;

- (SHUEBoxUser*) shueboxUserWithId:(SBInteger)userId;
- (SHUEBoxUser*) shueboxUserWithName:(SBString*)userName;

- (SHUEBoxRole*) shueboxRoleWithId:(SBInteger)roleId;
- (SHUEBoxRole*) shueboxRoleWithName:(SBString*)roleName;

- (SHUEBoxRole*) administratorSHUEBoxRole;
- (BOOL) userIsAdministrator:(SHUEBoxUser*)aUser;

- (SHUEBoxRole*) everyoneSHUEBoxRole;
- (BOOL) userIsMember:(SHUEBoxUser*)aUser;

@end

extern SBString* SHUEBoxCollaborationIdKey;
extern SBString* SHUEBoxCollaborationShortNameKey;
extern SBString* SHUEBoxCollaborationDescriptionKey;
extern SBString* SHUEBoxCollaborationQuotaKey;
extern SBString* SHUEBoxCollaborationReservationKey;
extern SBString* SHUEBoxCollaborationCompressionIsEnabledKey;
extern SBString* SHUEBoxCollaborationHomeDirectoryKey;
extern SBString* SHUEBoxCollaborationCreationTimestampKey;
extern SBString* SHUEBoxCollaborationModificationTimestampKey;
extern SBString* SHUEBoxCollaborationProvisionedTimestampKey;
extern SBString* SHUEBoxCollaborationRemovalTimestampKey;
