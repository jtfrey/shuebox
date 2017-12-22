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

#import "SHUEBoxCollaboration.h"
#import "SHUEBoxRole.h"

@class SBDate, SBString, SBMutableString, SBArray, SBOrderedSet;

@interface SHUEBoxRepository : SBDatabaseObject <SHUEBoxApacheConf,SHUEBoxURI, SHUEBoxProvisioning>
{
  SHUEBoxCollaboration*   _parentCollaboration;
  SBString*               _homeDirectory;
  SBString*               _repositoryURI;
  //
	SBOrderedSet*           _roles;
	BOOL                    _rolesModified;
  SBOrderedSet*           _addRoles;
	SBOrderedSet*           _removeRoles;
}

+ (SBArray*) repositoriesWithDatabase:(id)database;
+ (SBArray*) unprovisionedRepositoriesWithDatabase:(id)database;
+ (SBArray*) repositoriesForRemovalWithDatabase:(id)database;
+ (SBArray*) repositoriesForCollaboration:(SHUEBoxCollaboration*)aCollaboration;

+ (id) createRepositoryWithCollaboration:(SHUEBoxCollaboration*)parentCollaboration reposTypeId:(SBInteger)reposTypeId
          shortName:(SBString*)shortName description:(SBString*)description error:(SBError**)error;

+ (id) repositoryWithDatabase:(id)database reposId:(SBInteger)reposId;
+ (id) repositoryWithParentCollaboration:(SHUEBoxCollaboration*)parentCollaboration shortName:(SBString*)shortName;

- (SBInteger) reposId;

- (SBInteger) parentCollabId;
- (SHUEBoxCollaboration*) parentCollaboration;

- (SBString*) shortName;

- (SBString*) description;
- (void) setDescription:(SBString*)description;

- (SBInteger) repositoryTypeId;
- (SBString*) repositoryType;

- (SBDate*) creationTimestamp;
- (SBDate*) modificationTimestamp;

- (SBDate*) provisionedTimestamp;
- (BOOL) hasBeenProvisioned;

- (BOOL) canBeRemoved;
- (SBDate*) removalTimestamp;
- (void) setRemovalTimestamp:(SBDate*)removalTimestamp;
- (BOOL) scheduledForRemoval;
- (BOOL) shouldBeRemoved;

//

- (SBString*) homeDirectory;
- (SBError*) setupHomeDirectory;
- (SBError*) tearDownHomeDirectory;

//

/*!
	@method roleHasAccess:
	
	Returns YES if aRole has access to the receiver.
*/
- (BOOL) roleHasAccess:(SHUEBoxRole*)aRole;

/*!
	@method roleIdHasAccess:
	
	Returns YES if the given roleId is a member of the receiver.
*/
- (BOOL) roleIdHasAccess:(SHUEBoxRoleId)roleId;

/*!
	@method grantRoleAccess:
	
	Adds the given SHUEBoxRole to the list of roles which have access to the receiver. 
*/
- (void) grantRoleAccess:(SHUEBoxRole*)aRole;

/*!
	@method grantRoleIdAccess:
	
	Adds the given integral SHUEBoxRole identifier to the list of roles which have
  access to the receiver. 
*/
- (void) grantRoleIdAccess:(SHUEBoxRoleId)roleId;

/*!
	@method denyRoleAccess:
	
	Remove the given SHUEBoxRole from the list of roles which have access to the receiver. 
*/
- (void) denyRoleAccess:(SHUEBoxRole*)aRole;

/*!
	@method denyRoleIdAccess:
	
	Remove the given SHUEBoxRole identifier from the list of roles which have access
  to the receiver. 
*/
- (void) denyRoleIdAccess:(SHUEBoxRoleId)roleId;

/*!
	@method roleGranteeEnumerator
	
	Returns an SBEnumerator that iterates over the SHUEBoxRole objects that have been
  granted access to the receiver.
*/
- (SBEnumerator*) roleGranteeEnumerator;

/*!
	@method roleGranteeCount
	
	Returns the number of SHUEBox roles that have been granted access to the
  receiver.
*/
- (SBUInteger) roleGranteeCount;

/*!
	@method roleGranteeAtIndex:
	
	Returns the SHUEBoxRole object at the specified index in the list of roles that
  have been granted access to the receiver.
*/
- (SHUEBoxRole*) roleGranteeAtIndex:(SBUInteger)index;

@end

extern SBString* SHUEBoxRepositoryIdKey;
extern SBString* SHUEBoxRepositoryShortNameKey;
extern SBString* SHUEBoxRepositoryDescriptionKey;
extern SBString* SHUEBoxRepositoryCreationTimestampKey;
extern SBString* SHUEBoxRepositoryModificationTimestampKey;
extern SBString* SHUEBoxRepositoryProvisionedTimestampKey;
extern SBString* SHUEBoxRepositoryCanBeRemovedKey;
extern SBString* SHUEBoxRepositoryAllowsBrowsingKey;
extern SBString* SHUEBoxRepositoryRemovalTimestampKey;
