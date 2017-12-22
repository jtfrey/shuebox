//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMaintenanceTaskManager.h
//
// Task manager for scruffy.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBMaintenanceTaskManager.h"

#import "SBString.h"
#import "SBAutoreleasePool.h"
#import "SBPostgres.h"
#import "SBNotification.h"
#import "SBDictionary.h"
#import "SBRunLoop.h"
#import "SBLogger.h"

//

static SBString* SBScruffyConfigChangeNotification = @"maintenanceTaskUpdate";
static SBString* SBScruffyTerminateNotification = @"maintenanceShutdown";

//

enum {
  kSBMaintenanceTaskManagerIsRunning = 1UL << 0,
  kSBMaintenanceTaskManagerRedoConfig = 1UL << 1
};

//

@interface SBMaintenanceTaskManager(SBMaintenanceTaskManagerPrivate)

- (id) initWithDatabase:(SBPostgresDatabase*)database;

- (BOOL) stateOfFlag:(SBUInteger)flag;
- (void) setState:(BOOL)state ofFlag:(SBUInteger)flag;

@end

@implementation SBMaintenanceTaskManager(SBMaintenanceTaskManagerPrivate)

  - (id) initWithDatabase:(SBPostgresDatabase*)database
  {
    if ( self = [super init] ) {
      if ( (_logFile = [[SBLogger loggerWithFileAtPath:@"scruffy"] retain]) ) {
        [_logFile writeFormatToLog:"Scruffy is starting up."];
        _database = [database retain];
        _tasksByKey = [[SBMutableDictionary alloc] init];
        _flags = kSBMaintenanceTaskManagerRedoConfig;
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
  //

  - (BOOL) stateOfFlag:(SBUInteger)flag
  {
    return ( (_flags & flag) == flag ) ? YES : NO;
  }
  
//

  - (void) setState:(BOOL)state
    ofFlag:(SBUInteger)flag
  {
    if ( state )
      _flags |= flag;
    else
      _flags &= ~flag;
  }

@end

//
#pragma mark -
//

@implementation SBMaintenanceTaskManager

  + (id) maintenanceTaskManagerWithDatabase:(SBPostgresDatabase*)database
  {
    return [[[SBMaintenanceTaskManager alloc] initWithDatabase:database] autorelease];
  }

//

  - (SBMaintenanceTask*) maintenanceTaskWithId:(int)taskId
  {
  
  }
  
//

  - (SBMaintenanceTask*) maintenanceTaskWithKey:(SBString*)taskKey
  {
    
  }

//

  - (void) dealloc
  {
    if ( _logFile )
      [_logFile writeFormatToLog:"Scruffy is shutting down."];
      
    if ( _tasksByKey ) {
      // Force all tasks to invalidate timer's they're holding:
      [_tasksByKey makeObjectsPerformSelector:@selector(invalidateTaskTimer)];
      [_tasksByKey release];
    }
    if ( _database ) [_database release];
    
    if ( _logFile )
      [_logFile release];
      
    [super dealloc];
  }

//

  - (BOOL) isRunning
  {
    return [self stateOfFlag:kSBMaintenanceTaskManagerIsRunning];
  }
  - (void) setIsRunning:(BOOL)isRunning
  {
    [self setState:isRunning ofFlag:kSBMaintenanceTaskManagerIsRunning];
  }
  
//

  - (BOOL) redoConfig
  {
    return [self stateOfFlag:kSBMaintenanceTaskManagerRedoConfig];
  }
  - (void) setRedoConfig:(BOOL)redoConfig
  {
    [self setState:redoConfig ofFlag:kSBMaintenanceTaskManagerIsRunning];
  }

//

  - (int) enterTaskManagerRunloop
  {
    int         rc = 0;
    
    // Register for "scruffy" notifications:
    [_database registerObject:self forNotification:SBScruffyConfigChangeNotification];
    [_database registerObject:self forNotification:SBScruffyTerminateNotification];
    
    [self setState:YES ofFlag:kSBMaintenanceTaskManagerIsRunning];
    
    while ( [self isRunning] ) {
      SBAutoreleasePool*        localPool = [[SBAutoreleasePool alloc] init];
      
      if ( [self redoConfig] ) {
        SBMutableArray*         extantTasks = [[_tasksByKey allKeys] mutableCopy];
        SBPostgresQueryResult*  queryResult = [_database executeQuery:@"SELECT key FROM task WHERE isEnabled"];
        
        if ( queryResult && [queryResult queryWasSuccessful] ) {
          SBUInteger            taskCount = [queryResult numberOfRows];
          
          if ( taskCount ) {
            SBUInteger          row = 0;
            
            [_logFile writeFormatToLog:"Found " SBUIntegerFormat " enabled maintenance task%s.",
                taskCount,
                ( taskCount != 1 ? "s" : "" )
              ];
            while ( row < taskCount ) {
              SBString*             taskKey = [queryResult objectForRow:row fieldNum:0];
              
              if ( taskKey ) {
                SBMaintenanceTask*  aTask = [_tasksByKey objectForKey:taskKey];
                
                //  Do we already have it?
                if ( aTask ) {
                  [extantTasks removeObject:taskKey];
                  
                  //  Force an update of the task object:
                  [aTask updateConfigurationFromDatabase];
                } else if ( (aTask = [SBMaintenanceTask maintenanceTaskWithDatabase:_database taskKey:taskKey]) ) {
                  [_logFile writeFormatToLog:"Allocated new task \"%s\" with id %d",
                      [taskKey utf8Characters],
                      [aTask taskId]
                    ];
                  if ( [aTask isEnabled] || [aTask isReady] ) {
                    //  New one!
                    [_tasksByKey setObject:aTask forKey:taskKey];
                  } else {
                    [_logFile writeFormatToLog:"Failed to start task \"%s\"", [taskKey utf8Characters]];
                  }
                }
              } else {
                [_logFile writeFormatToLog:"Key retrieval failed on row %d", row];
              }
              row++;
            }
            
            //  Any tasks we didn't re-configure are now unnecessary, so
            //  get rid of 'em:
            if ( extantTasks ) {
              if ( [extantTasks count] ) {
              unsigned int      i = 0, iMax = [extantTasks count];
                
                while ( i < iMax ) {
                  id    key = [extantTasks objectAtIndex:i++];
                  
                  [_logFile writeFormatToLog:"Stopping task \"%s\"", [key utf8Characters]];
                  [_tasksByKey removeObjectForKey:key];
                }
              }
              [extantTasks release];
            }
            
            //  Provide a summary of the tasks:
          } else {
            [_tasksByKey removeAllObjects];
          }
        } else {
          [_logFile writeFormatToLog:"Error during database operation:"];
          [_logFile writeFormatToLog:"  %s", [[_database lastErrorMessage] utf8Characters]];
          rc = EINVAL;
          break;
        }
        [self setRedoConfig:NO];
      }
      
      // Cleanup all autorelease junk:
      [localPool release];
      
      // Enter the runloop:
      [[SBRunLoop currentRunLoop] run];
    }
    [_database unregisterObject:self forNotification:SBScruffyConfigChangeNotification];
    [_database unregisterObject:self forNotification:SBScruffyTerminateNotification];
    
    return rc;
  }

//

  - (void) notificationFromDatabase:(SBNotification*)aNotify
  {
    [_logFile writeFormatToLog:"Notification from database: %s", [[aNotify identifier] utf8Characters]];
    if ( [[aNotify identifier] isEqual:SBScruffyConfigChangeNotification] )
      [self setRedoConfig:YES];
    else if ( [[aNotify identifier] isEqual:SBScruffyTerminateNotification] )
      [self setIsRunning:NO];
    [[SBRunLoop currentRunLoop] setEarlyExit:YES];
  }

@end
