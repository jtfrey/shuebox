//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMaintenanceTask.h
//
// Class cluster for SHUEBox maintenance tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBMutableDictionary, SBDate, SBTimeInterval, SBTimer, SBError, SBLogger, SBArray, SBPostgresDatabase;

@interface SBMaintenanceTask : SBObject
{
  @protected
  SBPostgresDatabase*           _database;
  SBInteger                     _taskId;
  SBString*                     _taskKey;
  SBString*                     _taskDescription;
  SBTimeInterval*               _period;
  SBString*                     _postgresNotificationName;
  SBDate*                       _lastPerformedAt;
  //
  id                            _acquireLock, _dropLock, _nextPerformAt;
  SBTimer*                      _taskTimer;
  SBLogger*											_logFile;
  SBUInteger                    _flags;
}

+ (id) maintenanceTaskWithDatabase:(SBPostgresDatabase*)database taskId:(SBInteger)taskId;
+ (id) maintenanceTaskWithDatabase:(SBPostgresDatabase*)database taskKey:(SBString*)taskKey;

- (SBPostgresDatabase*) maintenanceDatabase;

- (SBInteger) taskId;
- (SBString*) taskKey;
- (SBString*) taskDescription;
- (SBTimeInterval*) period;
- (SBString*) postgresNotificationName;
- (SBDate*) lastPerformedAt;

- (BOOL) isEnabled;
- (BOOL) isReady;

- (void) performMaintenanceTask;
- (void) performMaintenanceTaskWithPayloadString:(SBString*)payloadString;
- (void) invalidateTaskTimer;

- (SBLogger*) logFile;

- (void) updateConfigurationFromDatabase;

@end
