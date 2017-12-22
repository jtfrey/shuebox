//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBRepositoryMaintenanceTask.m
//
// Handles repository-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBRepositoryMaintenanceTask.h"
#import "SBMaintenanceTaskPrivate.h"

#import "SHUEBoxRepository.h"

#import "SBString.h"
#import "SBArray.h"
#import "SBMailer.h"

SBString* const SBRepositoryProvisionKey = @"repository.provision";
SBString* const SBRepositoryRemoveKey = @"repository.remove";

//

@interface SBRepositoryMaintenanceTask(SBRepositoryMaintenanceTaskPrivate)

- (void) performProvision:(SBString*)repositoryId;
- (void) performRemoval:(SBString*)repositoryId;

@end

@implementation SBRepositoryMaintenanceTask(SBRepositoryMaintenanceTaskPrivate)

  - (void) performProvision:(SBString*)repositoryId
  {
    SBArray       *needingProvision = nil;
    SBUInteger    count;
    
    if ( repositoryId ) {
      SHUEBoxRepository         *provisionThis = [SHUEBoxRepository repositoryWithDatabase:[self maintenanceDatabase] reposId:(SBInteger)[repositoryId longLongIntValue]];
      
      if ( provisionThis ) {
        if ( ! [provisionThis hasBeenProvisioned] ) {
          needingProvision = [SBArray arrayWithObject:provisionThis];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Repository id=%S already provisioned", [repositoryId utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested provisioning of undefined repository id=%S", [repositoryId utf16Characters]]];
      }
    } else {
      needingProvision = [SHUEBoxRepository unprovisionedRepositoriesWithDatabase:[self maintenanceDatabase]];
    }
    
    if ( needingProvision && (count = [needingProvision count]) ) {
      SBMutableString*    mailMessage = [[SBMutableString alloc] initWithUTF8String:"The SHUEBox ``scruffy'' maintenance daemon has just completed a repository provisioning run:\n\n"];
      
      while ( count-- ) {
        SHUEBoxRepository*      provisionThis = [needingProvision objectAtIndex:count];
        SHUEBoxCollaboration*   theCollaboration = [provisionThis parentCollaboration];
        SBError*                provisionError = [provisionThis provisionResource];
        
        if ( provisionError ) {
          [[self logFile] writeStringToLog:
              [SBString stringWithFormat:"Error while provisioning `%S` (%d):",
                  [[provisionThis shortName] utf16Characters],
                  [provisionError code]
                ]
            ];
          [[self logFile] writeStringToLog:[[provisionError supportingData] objectForKey:SBErrorExplanationKey]];
          
          [mailMessage appendFormat:"\n--------\n%S\n\n", [[[provisionError supportingData] objectForKey:SBErrorExplanationKey] utf16Characters]];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully provisioned `%S`", [[provisionThis shortName] utf16Characters]]];
          
          [mailMessage appendFormat:"\n--------\nSuccessfully provisioned `%S/%S`\n",
              [[theCollaboration shortName] utf16Characters],
              [[provisionThis shortName] utf16Characters]
            ];
        }
      }
      
      // Send an email:
      [[SBMailer sharedMailer] sendMessage:mailMessage withSubject:@"[SHUEBox::scruffy] repository provisioning results"];
      [mailMessage release];
    }
  }
  
//

  - (void) performRemoval:(SBString*)repositoryId
  {
    SBArray       *needingRemoval = nil;
    SBUInteger    count;
    
    if ( repositoryId ) {
      SHUEBoxRepository         *removeThis = [SHUEBoxRepository repositoryWithDatabase:[self maintenanceDatabase] reposId:(SBInteger)[repositoryId longLongIntValue]];
      
      if ( removeThis ) {
        if ( [removeThis shouldBeRemoved] ) {
          needingRemoval = [SBArray arrayWithObject:removeThis];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Repository id=%S not marked for removal", [repositoryId utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested removal of undefined repository id=%S", [repositoryId utf16Characters]]];
      }
    } else {
      needingRemoval = [SHUEBoxRepository repositoriesForRemovalWithDatabase:[self maintenanceDatabase]];
    }
    
    if ( needingRemoval && (count = [needingRemoval count]) ) {
      while ( count-- ) {
        SHUEBoxRepository*      removeThis = [needingRemoval objectAtIndex:count];
        SBError*                removeError = [removeThis destroyResource];
        
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

@end

//
#pragma mark -
//

@implementation SBRepositoryMaintenanceTask

  + (void) load
  {
    SBArray*     keyArray = [[SBArray alloc] initWithObjects:
                                  SBRepositoryProvisionKey,
                                  SBRepositoryRemoveKey,
                                  nil
                                ];
    
    [self registerClass:self forTaskKeys:keyArray];
    [keyArray release];
  }
  
//

  - (void) setTaskKey:(SBString*)taskKey
  {
    [super setTaskKey:taskKey];
    
    if ( [taskKey isEqual:SBRepositoryProvisionKey] )
      _performMaintenanceTaskSelector = @selector(performProvision:);
    else if ( [taskKey isEqual:SBRepositoryRemoveKey] )
      _performMaintenanceTaskSelector = @selector(performRemoval:);
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
