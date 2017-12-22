//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBCollaborationMaintenanceTask.m
//
// Handles collaboration-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBCollaborationMaintenanceTask.h"
#import "SBMaintenanceTaskPrivate.h"

#import "SHUEBoxDictionary.h"
#import "SHUEBoxCollaboration.h"

#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBMailer.h"
#import "SBZFSFilesystem.h"

SBString* const SBCollaborationProvisionKey = @"collaboration.provision";
SBString* const SBCollaborationQuotaCheckKey = @"collaboration.quotaCheck";
SBString* const SBCollaborationQuotaUpdateKey = @"collaboration.quotaUpdate";
SBString* const SBCollaborationInactivityCheckKey = @"collaboration.inactivityCheck";
SBString* const SBCollaborationRemoveKey = @"collaboration.remove";

//

SBString* const SBCollaborationQuotaWarningThreshold = @"quota::warning-threshold";
SBString* const SBCollaborationQuotaCriticalThreshold = @"quota::critical-threshold";

//

@interface SBCollaborationMaintenanceTask(SBCollaborationMaintenanceTaskPrivate)

- (void) performProvision:(SBString*)shortName;
- (void) performQuotaCheck:(SBString*)shortName;
- (void) performQuotaUpdate:(SBString*)shortName;
- (void) performInactivityCheck:(SBString*)shortName;
- (void) performRemoval:(SBString*)shortName;

@end

@implementation SBCollaborationMaintenanceTask(SBCollaborationMaintenanceTaskPrivate)

  - (void) performProvision:(SBString*)shortName
  {
    SBArray       *needingProvision = nil;
    SBUInteger    count;
    
    if ( shortName ) {
      SHUEBoxCollaboration  *theCollab = [SHUEBoxCollaboration collaborationWithDatabase:[self maintenanceDatabase] shortName:shortName];
      
      if ( theCollab ) {
        if ( ! [theCollab hasBeenProvisioned] ) {
          needingProvision = [SBArray arrayWithObject:theCollab];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Collaboration `%S` already provisioned", [shortName utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested provisioning of undefined collaboration `%S`", [shortName utf16Characters]]];
      }
    } else {
      needingProvision = [SHUEBoxCollaboration unprovisionedCollaborationsWithDatabase:[self maintenanceDatabase]];
    }
    
    if ( needingProvision && (count = [needingProvision count]) ) {
      SBMutableString*    mailMessage = [[SBMutableString alloc] initWithUTF8String:"The SHUEBox ``scruffy'' maintenance daemon has just completed a collaboration provisioning run:\n\n"];
      
      while ( count-- ) {
        SHUEBoxCollaboration*   provisionThis = [needingProvision objectAtIndex:count];
        SBError*                provisionError = [provisionThis provisionResource];
        
        if ( provisionError ) {
          SBDictionary*         supportingData = [provisionError supportingData];
          SBString*             explanation = [supportingData objectForKey:SBErrorExplanationKey];
          
          [mailMessage appendFormat:"\n--------\nError while provisioning `%S`:  %S\n\n",
              [[provisionThis shortName] utf16Characters],
              [explanation utf16Characters]
            ];
          //
          // Was it just warnings?
          //
          if ( [provisionError code] == kSHUEBoxCollaborationProvisionWarning ) {
            SBArray*            warnings = [supportingData objectForKey:SBErrorUnderlyingErrorKey];
            SBUInteger          i = 0, iMax = [warnings count];
            
            while ( i < iMax ) {
              SBError*          warning = [warnings objectAtIndex:i++];
              
              if ( (explanation = [[warning supportingData] objectForKey:SBErrorExplanationKey]) )
                [mailMessage appendFormat:"  - %S\n", [explanation utf16Characters]];
              else
                [mailMessage appendFormat:"  - %S (code = %d)\n", [[warning domain] utf16Characters], [warning code]];
            }
          } else {
            [[self logFile] writeStringToLog:
                [SBString stringWithFormat:"Error while provisioning `%S` (%d):",
                    [[provisionThis shortName] utf16Characters],
                    [provisionError code]
                  ]
              ];
            [[self logFile] writeStringToLog:explanation];
          }
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully provisioned `%S`", [[provisionThis shortName] utf16Characters]]];
          [mailMessage appendFormat:"\n--------\nSuccessfully provisioned `%S`\n", [[provisionThis shortName] utf16Characters]];
          [mailMessage appendFormat:"  - Please add the following mount-point to Networker: %S\n\n", [[provisionThis homeDirectory] utf16Characters]];
        }
      }
      
      // Send an email:
      [[SBMailer sharedMailer] sendMessage:mailMessage withSubject:@"[SHUEBox::scruffy] collaboration provisioning results"];
      [mailMessage release];
    }
  }
  
//

  - (void) performQuotaCheck:(SBString*)shortName
  {
    SBArray               *collaborations = nil;
    
    if ( shortName ) {
      SHUEBoxCollaboration  *theCollab = [SHUEBoxCollaboration collaborationWithDatabase:[self maintenanceDatabase] shortName:shortName];
      
      if ( theCollab ) {
        collaborations = [SBArray arrayWithObject:theCollab];
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested quota check for undefined collaboration `%S`", [shortName utf16Characters]]];
      }
    } else {
      collaborations = [SHUEBoxCollaboration collaborationsWithDatabase:[self maintenanceDatabase]];
    }
    
    if ( collaborations ) {
      SBMutableString*    mailMessage = [[SBMutableString alloc] initWithUTF8String:"The SHUEBox ``scruffy'' maintenance daemon has just completed a collaboration quota-check run:\n\n"];
      SBUInteger          i = 0, iMax = [collaborations count];
      SBUInteger          count = 0;
      float               warn = 96.0f, critical = 100.0f;
      SBString*           value;
      
      //
      // Try to retrieve the warning threshold from the database:
      //
      if ( (value = [[self maintenanceDatabase] stringForFullDictionaryKey:SBCollaborationQuotaWarningThreshold]) ) {
        warn = [value floatValue];
        if ( (warn < 0.0) || (warn > 100.0) )
          warn = 96.0f;
      }
      
      //
      // Try to retrieve the critical threshold from the database:
      //
      if ( (value = [[self maintenanceDatabase] stringForFullDictionaryKey:SBCollaborationQuotaCriticalThreshold]) ) {
        critical = [value floatValue];
        if ( (critical < 0.0) || (critical > 100.0) )
          critical = 100.0;
      }
      
      while ( i < iMax ) {
        SHUEBoxCollaboration* collaboration = [collaborations objectAtIndex:i++];
        
        if ( collaboration ) {
          SBZFSFilesystem*  collabFS = [collaboration filesystem];
          
          if ( collabFS ) {
            float           percentUsed = [collabFS inUsePercentage];
            
            if ( percentUsed >= critical ) {
              //
              // Usage is CRITICAL:
              //
            
              [[self logFile] writeStringToLog:
                  [SBString stringWithFormat:"CRITICAL:  disk usage %.1f%% for `%S`",
                      percentUsed,
                      [[collaboration shortName] utf16Characters]
                    ]
                ];
              [mailMessage appendFormat:"\n--------\nCRITICAL:  disk usage %.1f%% for `%S`\n\n",
                  percentUsed,
                  [[collaboration shortName] utf16Characters]
                ];
              count++;
            } else if ( percentUsed >= warn ) {
              //
              // Usage is nearing CRITICAL:
              //
            
              [[self logFile] writeStringToLog:
                  [SBString stringWithFormat:"WARNING:  disk usage %.1f%% for `%S`",
                      percentUsed,
                      [[collaboration shortName] utf16Characters]
                    ]
                ];
              [mailMessage appendFormat:"\n--------\nWARNING:  disk usage %.1f%% for `%S`\n\n",
                  percentUsed,
                  [[collaboration shortName] utf16Characters]
                ];
              count++;
            }
          } else {
            [[self logFile] writeStringToLog:
                [SBString stringWithFormat:"Could not get filesystem object for `%S`",
                    [[collaboration shortName] utf16Characters]
                  ]
              ];
            [mailMessage appendFormat:"\n--------\nCould not get filesystem object for `%S`\n\n",
                [[collaboration shortName] utf16Characters]
              ];
          }
        }
      }
      
      if ( count ) {
        // Send an email:
        [[SBMailer sharedMailer] sendMessage:mailMessage withSubject:@"[SHUEBox::scruffy] collaboration quota-check results"];
      }
      [mailMessage release];
    }
  }
  
//

  - (void) performQuotaUpdate:(SBString*)shortName
  {
    id                        database = [self maintenanceDatabase];
    
    if ( shortName ) {
      SHUEBoxCollaboration    *theCollab = [SHUEBoxCollaboration collaborationWithDatabase:database shortName:shortName];
      
      if ( theCollab ) {
        SBError               *syncError = [theCollab syncFilesystemProperties];
            
        if ( syncError ) {
          [[self logFile] writeStringToLog:
              [SBString stringWithFormat:"Error while updating filesystem properties on `%S` (%d):",
                  [[theCollab shortName] utf16Characters],
                  [syncError code]
                ]
            ];
          [[self logFile] writeStringToLog:[[syncError supportingData] objectForKey:SBErrorExplanationKey]];
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully updated quota and reservation limits on `%S`", [[theCollab shortName] utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested quota update for undefined collaboration `%S`", [shortName utf16Characters]]];
      }
    } else {
      id                idLookup = [database executeQuery:@"SELECT collabId FROM collaboration.definition WHERE modified > (SELECT performedat FROM maintenance.task WHERE key = 'collaboration.quotaUpdate')"];
      SBUInteger        rowCount;
      
      if ( idLookup && [idLookup queryWasSuccessful] && (rowCount = [idLookup numberOfRows]) ) {
        
        while ( rowCount-- ) {
          SBNumber*     collabId = [idLookup objectForRow:rowCount fieldNum:0];
          
          if ( collabId ) {
            SHUEBoxCollaboration*   theCollab = [SHUEBoxCollaboration collaborationWithDatabase:database collabId:[collabId integerValue]];
            SBError*                syncError = [theCollab syncFilesystemProperties];
            
            if ( syncError ) {
              [[self logFile] writeStringToLog:
                  [SBString stringWithFormat:"Error while updating filesystem properties on `%S` (%d):",
                      [[theCollab shortName] utf16Characters],
                      [syncError code]
                    ]
                ];
              [[self logFile] writeStringToLog:[[syncError supportingData] objectForKey:SBErrorExplanationKey]];
            } else {
              [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully updated quota and reservation limits on `%S`", [[theCollab shortName] utf16Characters]]];
            }
          }
        }
      }
    }
  }
  
//

  - (void) performInactivityCheck:(SBString*)shortName
  {
    [[self logFile] writeFormatToLog:"Collaboration inactivity check not yet implemented."];
  }
  
//

  - (void) performRemoval:(SBString*)shortName
  {
    SBMutableString           *mailMessage = nil;
    
    if ( shortName ) {
      SHUEBoxCollaboration    *removeThis = [SHUEBoxCollaboration collaborationWithDatabase:[self maintenanceDatabase] shortName:shortName];
      
      if ( removeThis ) {
        if ( [removeThis shouldBeRemoved] ) {
          SBError             *removeError = [removeThis destroyResource];
          
          mailMessage = [[SBMutableString alloc] initWithUTF8String:"The SHUEBox ``scruffy'' maintenance daemon has just completed a collaboration removal run:\n\n"];
          if ( removeError ) {
            [[self logFile] writeStringToLog:
                [SBString stringWithFormat:"Error while removing `%S` (%d):",
                    [[removeThis shortName] utf16Characters],
                    [removeError code]
                  ]
              ];
            [[self logFile] writeStringToLog:[[removeError supportingData] objectForKey:SBErrorExplanationKey]];
            
            [mailMessage appendFormat:"\n--------\nError while removing `%S`:  %S\n\n",
                [[removeThis shortName] utf16Characters],
                [[[removeError supportingData] objectForKey:SBErrorExplanationKey] utf16Characters]
              ];
          } else {
            [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully removed `%S`", [[removeThis shortName] utf16Characters]]];
            [mailMessage appendFormat:"\n--------\nSuccessfully removed `%S`\n", [[removeThis shortName] utf16Characters]];
            [mailMessage appendFormat:"  - Please remove the following mount-point from Networker: %S\n\n", [[removeThis homeDirectory] utf16Characters]];
          }
        } else {
          [[self logFile] writeStringToLog:[SBString stringWithFormat:"Collaboration `%S` not marked as needing removal", [shortName utf16Characters]]];
        }
      } else {
        [[self logFile] writeStringToLog:[SBString stringWithFormat:"Requested removal of undefined collaboration `%S`", [shortName utf16Characters]]];
      }
    } else {
      SBArray*      needingRemoval = [SHUEBoxCollaboration collaborationsForRemovalWithDatabase:[self maintenanceDatabase]];
      SBUInteger    count;
      
      if ( needingRemoval && (count = [needingRemoval count]) ) {
        mailMessage = [[SBMutableString alloc] initWithUTF8String:"The SHUEBox ``scruffy'' maintenance daemon has just completed a collaboration removal run:\n\n"];
        
        while ( count-- ) {
          SHUEBoxCollaboration*   removeThis = [needingRemoval objectAtIndex:count];
          SBError*                removeError = [removeThis destroyResource];
          
          if ( removeError ) {
            [[self logFile] writeStringToLog:
                [SBString stringWithFormat:"Error while removing `%S` (%d):",
                    [[removeThis shortName] utf16Characters],
                    [removeError code]
                  ]
              ];
            [[self logFile] writeStringToLog:[[removeError supportingData] objectForKey:SBErrorExplanationKey]];
            
            [mailMessage appendFormat:"\n--------\nError while removing `%S`:  %S\n\n",
                [[removeThis shortName] utf16Characters],
                [[[removeError supportingData] objectForKey:SBErrorExplanationKey] utf16Characters]
              ];
          } else {
            [[self logFile] writeStringToLog:[SBString stringWithFormat:"Successfully removed `%S`", [[removeThis shortName] utf16Characters]]];
            [mailMessage appendFormat:"\n--------\nSuccessfully removed `%S`\n", [[removeThis shortName] utf16Characters]];
            [mailMessage appendFormat:"  - Please remove the following mount-point from Networker: %S\n\n", [[removeThis homeDirectory] utf16Characters]];
          }
        }
      }
    }
    
    if ( mailMessage ) {
      // Send an email:
      [[SBMailer sharedMailer] sendMessage:mailMessage withSubject:@"[SHUEBox::scruffy] collaboration removal results"];
      [mailMessage release];
    }
  }

@end

//
#pragma mark -
//

@implementation SBCollaborationMaintenanceTask

  + (void) load
  {
    SBArray*     keyArray = [[SBArray alloc] initWithObjects:
                                  SBCollaborationProvisionKey,
                                  SBCollaborationQuotaCheckKey,
                                  SBCollaborationQuotaUpdateKey,
                                  SBCollaborationInactivityCheckKey,
                                  SBCollaborationRemoveKey,
                                  nil
                                ];
    
    [self registerClass:self forTaskKeys:keyArray];
    [keyArray release];
  }
  
//

  - (void) setTaskKey:(SBString*)taskKey
  {
    [super setTaskKey:taskKey];
    
    if ( [taskKey isEqual:SBCollaborationProvisionKey] )
      _performMaintenanceTaskSelector = @selector(performProvision:);
    else if ( [taskKey isEqual:SBCollaborationQuotaCheckKey] )
      _performMaintenanceTaskSelector = @selector(performQuotaCheck:);
    else if ( [taskKey isEqual:SBCollaborationQuotaUpdateKey] )
      _performMaintenanceTaskSelector = @selector(performQuotaUpdate:);
    else if ( [taskKey isEqual:SBCollaborationInactivityCheckKey] )
      _performMaintenanceTaskSelector = @selector(performInactivityCheck:);
    else if ( [taskKey isEqual:SBCollaborationRemoveKey] )
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
