//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxRole.h
//
// Class which wraps SHUEBox roles.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBoxUser.h"

typedef int64_t SHUEBoxRoleId;

@class SHUEBoxCollaboration, SBEnumerator, SBOrderedSet;

@interface SHUEBoxRole : SBDatabaseObject
{
	SBOrderedSet*       _membership;
	BOOL								_membershipModified;
	//
	SBOrderedSet*       _add;
	SBOrderedSet*       _remove;
}

/*!
	@method flushRoleCache
	
	Remove all cached SHUEBoxRole objects.
*/
+ (void) flushRoleCache;

/*!
	@method removeRoleFromCache:
	
	Remove the specified SHUEBoxRole object from the cache.
*/
+ (void) removeRoleFromCache:(SHUEBoxRole*)aRole;

/*!
	@method shueboxRolesForCollaboration:
	
	Returns an array containing all of the defined SHUEBoxRole objects
	for the given collaboration.
*/
+ (SBArray*) shueboxRolesForCollaboration:(SHUEBoxCollaboration*)collaboration;

/*!
  @method createRoleWithCollaboration:shortName:description
  
  Attempts to add a new role to the given collaboration.  If successful, the new role is
  returned.  Otherwise, nil is returned and error is set to an SBError object describing
  the problem that occurred.
*/
+ (id) createRoleWithCollaboration:(SHUEBoxCollaboration*)collaboration
          shortName:(SBString*)shortName description:(SBString*)description error:(SBError**)error;

/*!
	@method shueboxEveryoneRoleForCollaboration:
	
	For the given collaboration, returns an autoreleased instance that represents
	the role containing all users of the collaboration.
*/
+ (id) shueboxEveryoneRoleForCollaboration:(SHUEBoxCollaboration*)collaboration;

/*!
	@method shueboxAdministratorRoleForCollaboration:
	
	For the given collaboration, returns an autoreleased instance that represents
	the role containing users granted administrative privileges on the collaboration.
*/
+ (id) shueboxAdministratorRoleForCollaboration:(SHUEBoxCollaboration*)collaboration;

/*!
	@method shueboxRoleWithDatabase:roleId:
	
	Primitive method, returns an autoreleased instance that represents the role having the
	given integral id in the database.
*/
+ (id) shueboxRoleWithDatabase:(id)database roleId:(SHUEBoxRoleId)roleId;

/*!
	@method shueboxRoleWithCollaboration:shortName:
	
	Returns an autoreleased instance of this class which represents the role within the
	given collaboration that is named according to shortName.
*/
+ (id) shueboxRoleWithCollaboration:(SHUEBoxCollaboration*)collaboration shortName:(SBString*)shortName;

/*!
	@method shueboxRoleId
	
	Returns the integral role identifier for the receiver.
*/
- (SHUEBoxRoleId) shueboxRoleId;

/*!
	@method parentCollaborationId
	
	Returns the integral identifier associated with the collaboration to which the
	receiver role belongs.
*/
- (SBInteger) parentCollaborationId;

/*!
	@method shortName
	
	Returns the succint name for the receiver role.
*/
- (SBString*) shortName;

/*!
  @method setShortName:
  
  Rename the receiver role.
*/
- (void) setShortName:(SBString*)shortName;

/*!
	@method description
	
	Returns the receiver role's verbose description.
*/
- (SBString*) description;
/*!
	@method setDescription:
	
	Sets the receiver role's verbose description.
*/
- (void) setDescription:(SBString*)description;

/*!
	@method isLocked
	
	Returns YES if the receiver role cannot be modified.
*/
- (BOOL) isLocked;
/*!
	@method isSystemOwned
	
	Returns YES if the receiver role is part of the SHUEBox system and not defined by the collaboration
	administrators.
*/
- (BOOL) isSystemOwned;

/*!
	@method isMember:
	
	Returns YES if aUser is a member of the receiver role.
*/
- (BOOL) isMember:(SHUEBoxUser*)aUser;

/*!
	@method isMemberByUserId:
	
	Returns YES if the given userId is a member of the receiver role.
*/
- (BOOL) isMemberByUserId:(SHUEBoxUserId)userId;

/*!
	@method addMember:
	
	Adds the given SHUEBoxUser to the receiver role. 
*/
- (void) addMember:(SHUEBoxUser*)aUser;

/*!
	@method addMemberByUserId:
	
	Adds the given integral SHUEBoxUser identifier to the receiver role. 
*/
- (void) addMemberByUserId:(SHUEBoxUserId)userId;

/*!
	@method removeMember:
	
	Remove the given SHUEBoxUser from the receiver role. 
*/
- (void) removeMember:(SHUEBoxUser*)aUser;

/*!
	@method removeMemberWithUserId:
	
	Removes the given integral SHUEBoxUser identifier from the receiver role. 
*/
- (void) removeMemberWithUserId:(SHUEBoxUserId)userId;

/*!
	@method roleMemberEnumerator
	
	Returns an SBEnumerator that iterates over the SHUEBoxUser objects that are members
	of the receiver role.
*/
- (SBEnumerator*) roleMemberEnumerator;

/*!
	@method roleMemberCount
	
	Returns the number of members in the receiver role.
*/
- (SBUInteger) roleMemberCount;

/*!
	@method roleMemberAtIndex:
	
	Returns the SHUEBoxUser object at the specified index in the list of members of the
	receiver role.
*/
- (SHUEBoxUser*) roleMemberAtIndex:(SBUInteger)index;

/*!
  @method removeFromParentCollaboration
  
  Attempt to delete this role.
*/
- (BOOL) removeFromParentCollaboration;

@end

/*!
  @constant SHUEBoxRoleWasRemovedNotification
  
  Broadcast by a SHUEBoxRole instance that has been successfully removed from its
  parent collaboration in the database.
*/
extern SBString* SHUEBoxRoleWasRemovedNotification;
