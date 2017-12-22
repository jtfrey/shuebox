//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMaintenanceTaskPrivate.h
//
// Class cluster for SHUEBox maintenance tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBAutoreleasePool.h"
#import "SBPostgres.h"
#import "SBString.h"
#import "SBValue.h"
#import "SBDictionary.h"
#import "SBArray.h"
#import "SBDate.h"
#import "SBValue.h"
#import "SBNotification.h"
#import "SBFileManager.h"
#import "SBTimer.h"
#import "SBError.h"
#import "SBRunLoop.h"
#import "SBLogger.h"

#import "SBPIDFile.h"

@interface SBMaintenanceTask(SBMaintenanceTaskPrivate)

+ (void) registerClass:(Class)aClass forTaskKeys:(SBArray*)taskKeys;
+ (Class) classForTaskKey:(SBString*)taskKey;

- (id) initWithDatabase:(SBPostgresDatabase*)database queryResult:(SBPostgresQueryResult*)queryResult row:(SBUInteger)row;

- (BOOL) stateOfFlag:(SBUInteger)flag;
- (void) setState:(BOOL)state ofFlag:(SBUInteger)flag;

- (BOOL) setProperties:(SBDictionary*)properties;

- (void) setupTaskTimer;

- (void) prepareQueries;

- (BOOL) acquireTaskLock;
- (BOOL) dropTaskLock;
- (SBDate*) shouldBePerformedAt;

- (void) setTaskId:(SBInteger)taskId;
- (void) setTaskKey:(SBString*)taskKey;
- (void) setTaskDescription:(SBString*)taskDescription;
- (void) setPeriod:(SBTimeInterval*)period;
- (void) setPostgresNotificationName:(SBString*)postresNotificationName;
- (void) setLastPerformedAt:(SBDate*)lastPerformedAt;

- (void) performMaintenanceTaskOnTimer:(id)aTimer;
- (void) performMaintenanceTaskWrapper:(SBString*)payloadString;

@end
