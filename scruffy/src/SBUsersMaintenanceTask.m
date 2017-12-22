//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBUsersMaintenanceTask.m
//
// Handles user-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBUsersMaintenanceTask.h"
#import "SBMaintenanceTaskPrivate.h"

#import "SHUEBoxUser.h"

#import "SBString.h"
#import "SBArray.h"

SBString* const SBUsersInactivityCheckKey = @"users.inactivityCheck";
SBString* const SBUsersRemoveKey = @"users.remove";
SBString* const SBUsersSendWelcomeMessageKey = @"users.sendWelcomeMessage";

//

@interface SBUsersMaintenanceTask(SBUsersMaintenanceTaskPrivate)

- (void) performInactivityCheck:(SBString*)userId;
- (void) performRemoval:(SBString*)userId;
- (void) performSendWelcomeMessage:(SBString*)userId;

@end

@implementation SBUsersMaintenanceTask(SBUsersMaintenanceTaskPrivate)

  - (void) performInactivityCheck:(SBString*)userId
  {
    [[self logFile] writeFormatToLog:"User inactivity check not yet implemented."];
  }
  
//

  - (void) performRemoval:(SBString*)userId
  {
    SBArray*      needingRemoval = nil;
    SBUInteger    count;
    
    if ( userId ) {
      SHUEBoxUser      *removeThis = [SHUEBoxUser shueboxUserWithDatabase:[self maintenanceDatabase] userId:(SHUEBoxUserId)[userId longLongIntValue]];
      
      if ( removeThis ) {
        if ( [removeThis shouldBeRemoved] ) {
          needingRemoval = [SBArray arrayWithObject:removeThis];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"User id=%S not marked for removal", [userId utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested removal of undefined user id=%S", [userId utf16Characters]]];
      }
    } else {
      needingRemoval = [SHUEBoxUser shueboxUsersForRemovalWithDatabase:[self maintenanceDatabase]];
    }
    
    if ( needingRemoval && (count = [needingRemoval count]) ) {
      while ( count-- ) {
        SHUEBoxUser*            removeThis = [needingRemoval objectAtIndex:count];
        SBError*                removeError = [removeThis removeFromDatabase];
        
        if ( removeError ) {
          [[self logFile] writeStringToLog:
              [SBString stringWithFormat:"Error while removing `%S` (%d):",
                  [[removeThis shortName] utf16Characters],
                  [removeError code]
                ]
            ];
          [[self logFile] writeStringToLog:[[removeError supportingData] objectForKey:SBErrorExplanationKey]];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully removed `%S`", [[removeThis shortName] utf16Characters]]];
        }
      }
    }
  }
  
//

  - (void) performSendWelcomeMessage:(SBString*)userId
  {
    SBArray*      needingWelcome = [SHUEBoxUser shueboxUsersNeedingWelcomeMessageWithDatabase:[self maintenanceDatabase]];
    SBUInteger    count;
    
    if ( needingWelcome && (count = [needingWelcome count]) ) {
      while ( count-- ) {
        SHUEBoxUser*            welcomeThis = [needingWelcome objectAtIndex:count];
        SBError*                welcomeError = [welcomeThis sendWelcomeMessage];
        
        if ( welcomeError ) {
          [[self logFile] writeStringToLog:
              [SBString stringWithFormat:"Error while sending welcome message to `%S` (%d):",
                  [[welcomeThis shortName] utf16Characters],
                  [welcomeError code]
                ]
            ];
          [[self logFile] writeStringToLog:[[welcomeError supportingData] objectForKey:SBErrorExplanationKey]];
        } else if ( ! [welcomeThis commitModifications] ) {
          [[self logFile] writeStringToLog:
              [SBString stringWithFormat:"Welcome message sent, but unable to commit `%S` to database",
                  [[welcomeThis shortName] utf16Characters]
                ]
            ];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully sent welcome message to `%S`", [[welcomeThis shortName] utf16Characters]]];
        }
      }
    }
  }

@end

//
#pragma mark -
//

@implementation SBUsersMaintenanceTask

  + (void) load
  {
    SBArray*     keyArray = [[SBArray alloc] initWithObjects:
                                  SBUsersInactivityCheckKey,
                                  SBUsersRemoveKey,
                                  SBUsersSendWelcomeMessageKey,
                                  nil
                                ];
    
    [self registerClass:self forTaskKeys:keyArray];
    [keyArray release];
  }
  
//

  - (void) setTaskKey:(SBString*)taskKey
  {
    [super setTaskKey:taskKey];
    
    if ( [taskKey isEqual:SBUsersInactivityCheckKey] )
      _performMaintenanceTaskSelector = @selector(performInactivityCheck:);
    else if ( [taskKey isEqual:SBUsersRemoveKey] )
      _performMaintenanceTaskSelector = @selector(performRemoval:);
    else if ( [taskKey isEqual:SBUsersSendWelcomeMessageKey] )
      _performMaintenanceTaskSelector = @selector(performSendWelcomeMessage:);
    else
      _performMaintenanceTaskSelector = NULL;
  }
  
//

  - (void) performMaintenanceTaskWithPayloadString:(SBString*)payloadString
  {
    if ( _performMaintenanceTaskSelector )
      [self perform:_performMaintenanceTaskSelector with:payloadString];
    [super performMaintenanceTaskWithPayloadString:payloadString];
  }

@end
