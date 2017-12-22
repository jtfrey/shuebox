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

#import "SBMaintenanceTask.h"

@interface SBMaintenanceTaskManager : SBObject
{
  SBMutableDictionary*      _tasksByKey;
  SBPostgresDatabase*       _database;
  SBLogger*									_logFile;
  SBUInteger                _flags;
}

+ (id) maintenanceTaskManagerWithDatabase:(SBPostgresDatabase*)database;

- (SBMaintenanceTask*) maintenanceTaskWithId:(int)taskId;
- (SBMaintenanceTask*) maintenanceTaskWithKey:(SBString*)taskKey;

- (BOOL) isRunning;
- (void) setIsRunning:(BOOL)isRunning;

- (BOOL) redoConfig;
- (void) setRedoConfig:(BOOL)redoConfig;

- (int) enterTaskManagerRunloop;

@end
