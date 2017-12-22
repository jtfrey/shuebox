//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxUser.h
//
// Class cluster which represents SHUEBox users.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"
#import "SBDatabaseObject.h"

typedef int64_t SHUEBoxUserId;

@class SBDate, SBString, SBArray, SHUEBoxCollaboration;

@interface SHUEBoxUser : SBDatabaseObject
{
  id      _delegate;
}

+ (void) flushUserCache;
+ (void) removeUserFromCache:(SHUEBoxUser*)aUser;

+ (SBArray*) shueboxUsersForRemovalWithDatabase:(id)database;
+ (SBArray*) shueboxUsersNeedingWelcomeMessageWithDatabase:(id)database;
+ (SBArray*) shueboxUsersForCollaboration:(SHUEBoxCollaboration*)collaboration;

+ (id) shueboxUserWithDatabase:(id)database userId:(SHUEBoxUserId)userId;
+ (id) shueboxUserWithDatabase:(id)database shortName:(SBString*)shortName;

- (SHUEBoxUserId) shueboxUserId;

- (BOOL) isGuestUser;
- (BOOL) isSuperUser;

- (SBString*) shortName;

- (SBString*) fullName;
- (void) setFullName:(SBString*)fullName;

- (SBString*) emailAddress;

- (SBDate*) creationTimestamp;
- (SBDate*) modificationTimestamp;

- (BOOL) hasAuthenticated;
- (SBDate*) lastAuthenticated;

- (BOOL) canBeRemoved;
- (SBDate*) removalTimestamp;
- (void) setRemovalTimestamp:(SBDate*)removalTimestamp;
- (BOOL) scheduledForRemoval;
- (BOOL) shouldBeRemoved;
- (SBError*) removeFromDatabase;

- (SBError*) sendWelcomeMessage;
- (SBError*) confirmAccountWithCode:(SBString*)confirmationCode;

@end

@interface SHUEBoxUser(SHUEBoxUserAuthentication)

+ (id) authenticateWithDatabase:(id)database shortName:(SBString*)shortName password:(SBString*)password;
- (BOOL) authenticateUsingPassword:(SBString*)password;

- (BOOL) setPassword:(SBString*)newPassword;

@end
