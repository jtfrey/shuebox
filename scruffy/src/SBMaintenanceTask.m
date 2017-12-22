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

#import "SBMaintenanceTask.h"
#import "SBMaintenanceTaskPrivate.h"

#import "SBLogger.h"

static SBString* SBMaintenanceTaskIdKey               = @"taskid";
static SBString* SBMaintenanceTaskKeyKey              = @"key";
static SBString* SBMaintenanceTaskDescriptionKey      = @"description";
static SBString* SBMaintenanceTaskPeriodKey           = @"period";
static SBString* SBMaintenanceTaskNotificationNameKey = @"notification";
static SBString* SBMaintenanceTaskIsEnabledKey        = @"isenabled";
static SBString* SBMaintenanceTaskInProgressKey       = @"inprogress";
static SBString* SBMaintenanceTaskPerformedAtKey      = @"performedat";

//

enum {
  kSBMaintenanceTaskIsEnabled                 = 1UL << 0,
  kSBMaintenanceTaskIsReady                   = 1UL << 1,
  kSBMaintenanceTaskNotificationRegistered    = 1UL << 2
};

//

static SBMutableDictionary* __SBMaintenanceTaskKeyToClassMappings = nil;

//

@implementation SBMaintenanceTask(SBMaintenanceTaskPrivate)

  + (void) registerClass:(Class)aClass
    forTaskKeys:(SBArray*)taskKeys
  {
    if ( ! __SBMaintenanceTaskKeyToClassMappings )
      __SBMaintenanceTaskKeyToClassMappings = [[SBMutableDictionary alloc] init];
    
    if ( __SBMaintenanceTaskKeyToClassMappings && taskKeys ) {
      SBUInteger  i = 0, iMax = [taskKeys count];
      
      while ( i < iMax ) {
        SBValue*    classPtr = [[SBValue alloc] initWithBytes:&aClass objCType:@encode(Class)];
        
        [__SBMaintenanceTaskKeyToClassMappings setObject:classPtr forKey:[taskKeys objectAtIndex:i++]];
        [classPtr release];
      }
    }
  }

//

  + (Class) classForTaskKey:(SBString*)taskKey
  {
    Class   theClass = self;
    
    if ( __SBMaintenanceTaskKeyToClassMappings ) {
      SBValue*    classPtr = [__SBMaintenanceTaskKeyToClassMappings objectForKey:taskKey];
      
      if ( classPtr )
        [classPtr getValue:&theClass];
    }
    return theClass;
  }

//

  - (id) initWithDatabase:(SBPostgresDatabase*)database
    queryResult:(SBPostgresQueryResult*)queryResult
    row:(SBUInteger)row
  {
    if ( self = [super init] ) {
      _database = [database retain];
      
      if ( queryResult && [queryResult queryWasSuccessful] )
        [self setProperties:(SBMutableDictionary*)[queryResult dictionaryForRow:row createMutable:YES]];
      
      if ( [self taskId] <= 0 ) {
        [self release];
        self = nil;
      } else {
        _logFile = [[SBLogger loggerWithFileAtPath:[self taskKey]] retain];
        [_logFile writeFormatToLog:"Task handler started."];
      }
    }
    return self;
  }
  
//

  - (BOOL) stateOfFlag:(SBUInteger)flag
  {
    return ((_flags & flag) == flag) ? YES : NO;
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

//

  - (BOOL) setProperties:(SBDictionary*)properties
  {
    SBNumber*     value;
    
    // Enabled:
    value = [properties objectForKey:SBMaintenanceTaskIsEnabledKey];
    [self setState:((value && ! [value isNull]) ? [value boolValue] : NO) ofFlag:kSBMaintenanceTaskIsEnabled];
    
    // Task id:
    value = [properties objectForKey:SBMaintenanceTaskIdKey];
    [self setTaskId:((value && ! [value isNull]) ? [value integerValue] : 0)];
    
    [self setTaskKey:[properties objectForKey:SBMaintenanceTaskKeyKey]];
    [self setTaskDescription:[properties objectForKey:SBMaintenanceTaskDescriptionKey]];
    [self setPeriod:[properties objectForKey:SBMaintenanceTaskPeriodKey]];
    [self setPostgresNotificationName:[properties objectForKey:SBMaintenanceTaskNotificationNameKey]];
    [self setLastPerformedAt:[properties objectForKey:SBMaintenanceTaskPerformedAtKey]];
    
    // Ready?
    [self setState:((_taskTimer || [self stateOfFlag:kSBMaintenanceTaskNotificationRegistered]) ? YES : NO) ofFlag:kSBMaintenanceTaskIsReady];
    
    return YES;
  }

//

  - (void) setupTaskTimer
  {
    if ( _taskTimer ) {
      [_taskTimer invalidate];
      [_taskTimer release];
      _taskTimer = nil;
    }
    if ( [self isEnabled] && _period && (_taskId > 0) ) {
      SBDate*     when = [self shouldBePerformedAt];
      
      if ( ! when )
        when = _lastPerformedAt;
        
      _taskTimer = [[SBTimer alloc] initWithFireDate:when interval:_period target:self selector:@selector(performMaintenanceTaskOnTimer:) userInfo:_period repeats:YES];
      if ( _taskTimer )
        [[SBRunLoop currentRunLoop] addTimer:_taskTimer forMode:SBRunLoopDefaultMode];
    }
  }

//

  - (void) prepareQueries
  {
    if ( _acquireLock ) { [_acquireLock release]; _acquireLock = nil; }
    if ( _dropLock ) { [_dropLock release]; _dropLock = nil; }
    if ( _nextPerformAt ) { [_nextPerformAt release]; _nextPerformAt = nil; }
    if ( _taskId > 0 ) {
      _acquireLock = [[SBString alloc] initWithFormat:"SELECT taskWithIdAcquireLock(" SBIntegerFormat ")", _taskId];
      _dropLock = [[SBString alloc] initWithFormat:"SELECT taskWithIdReleaseLock(" SBIntegerFormat ")", _taskId];
      _nextPerformAt = [[SBString alloc] initWithFormat:"SELECT nextTimeForTaskById(" SBIntegerFormat ")", _taskId];
    }
  }
  
//

  - (BOOL) acquireTaskLock
  {
    SBPostgresQueryResult*    queryResult = [_database executeQuery:_acquireLock];
    
    if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
      return ( [[queryResult objectForRow:0 fieldNum:0] boolValue] );
    }
    return NO;
  }
  - (BOOL) dropTaskLock
  {
    SBPostgresQueryResult*    queryResult = [_database executeQuery:_dropLock];
    
    if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
      return ( [[queryResult objectForRow:0 fieldNum:0] boolValue] );
    }
    return NO;
  }

//

  - (SBDate*) shouldBePerformedAt
  {
    SBPostgresQueryResult*    queryResult = [_database executeQuery:_nextPerformAt];
    
    if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
      return [queryResult objectForRow:0 fieldNum:0];
    }
    return nil;
  }

//

  - (void) setTaskId:(SBInteger)taskId
  {
    if ( taskId != _taskId ) {
      _taskId = taskId;
      [self prepareQueries];
    }
  }
  
//

  - (void) setTaskKey:(SBString*)taskKey
  {
    if ( taskKey ) {
      if ( [taskKey isNull] )
        taskKey = nil;
      else
        taskKey = [taskKey retain];
    }
    if ( _taskKey ) [_taskKey release];
    _taskKey = taskKey;
  }
  
//

  - (void) setTaskDescription:(SBString*)taskDescription
  {
    if ( taskDescription ) {
      if ( [taskDescription isNull] )
        taskDescription = nil;
      else
        taskDescription = [taskDescription retain];
    }
    if ( _taskDescription ) [_taskDescription release];
    _taskDescription = taskDescription;
  }

//

  - (void) setPeriod:(SBTimeInterval*)period
  {
    if ( ! period || [period isNull] ) {
      period = nil;
      if ( ! _period )
        return;
    }
    if ( (! _period && period) || (_period && ! period) || (! [_period isEqual:period]) ) {
      if ( period ) period = [period retain];
      if ( _period ) [_period release];
      _period = period;
      
      // Reset the timer if it exists:
      [self setupTaskTimer];
    }
  }

//

  - (void) setPostgresNotificationName:(SBString*)postgresNotificationName
  {
    if ( ! postgresNotificationName || [postgresNotificationName isNull] ) {
      postgresNotificationName = nil;
      if ( ! _postgresNotificationName )
        return;
    }
    if ( (! _postgresNotificationName && postgresNotificationName) || (_postgresNotificationName && !postgresNotificationName ) || (! [_postgresNotificationName isEqual:postgresNotificationName]) ) {
      //
      // Unregister if we were already listening:
      //
      if ( _postgresNotificationName && [self stateOfFlag:kSBMaintenanceTaskNotificationRegistered] ) {
        [_database unregisterObject:self forNotification:_postgresNotificationName];
        [self setState:NO ofFlag:kSBMaintenanceTaskNotificationRegistered];
        [_postgresNotificationName release];
      }
      //
      // Register if we will be listening:
      //
      if ( postgresNotificationName ) {
        postgresNotificationName = [postgresNotificationName retain];
        if ( [self isEnabled] ) {
          [_database registerObject:self forNotification:postgresNotificationName];
          [self setState:YES ofFlag:kSBMaintenanceTaskNotificationRegistered];
        }
      }
      _postgresNotificationName = postgresNotificationName;
    } else if ( _postgresNotificationName && [self isEnabled] && ! [self stateOfFlag:kSBMaintenanceTaskNotificationRegistered] ) {
      //
      // Register if we will be listening:
      //
      [_database registerObject:self forNotification:_postgresNotificationName];
      [self setState:YES ofFlag:kSBMaintenanceTaskNotificationRegistered];
    }
  }

//

  - (void) setLastPerformedAt:(SBDate*)lastPerformedAt
  {
    if ( lastPerformedAt ) {
      if ( [lastPerformedAt isNull] )
        lastPerformedAt = nil;
      else
        lastPerformedAt = [lastPerformedAt retain];
    }
    if ( _lastPerformedAt ) [_lastPerformedAt release];
    _lastPerformedAt = lastPerformedAt;
  }

//

  - (void) performMaintenanceTaskOnTimer:(id)aTimer
  {
    SBTimeInterval*   theInterval = [(SBTimer*)aTimer timeInterval];
    int               hours, minutes, seconds = [theInterval secondsInTimeInterval];
    
    hours = seconds / 3600; seconds -= (hours * 3600);
    minutes = seconds / 60; seconds -= (minutes * 60);
    
    [_logFile writeFormatToLog:"Waking up for periodic run of task: " SBIntegerFormat " months " SBIntegerFormat " days %02d:%02d:%02d",
        [theInterval monthsInTimeInterval],
        [theInterval daysInTimeInterval],
        hours, minutes, seconds
      ];
    [self performMaintenanceTaskWrapper:nil];
  }

//

  - (void) performMaintenanceTaskWrapper:(SBString*)payloadString
  {
    if ( [self acquireTaskLock] ) {
      [self performMaintenanceTaskWithPayloadString:payloadString];
      [self dropTaskLock];
    } else {
      [_logFile writeStringToLog:@"Unable to get task lock — check for an aged non-null `performedAt` field in maintenance.task!"];
    }
  }

@end

//
#pragma mark -
//

@implementation SBMaintenanceTask

  + (id) maintenanceTaskWithDatabase:(SBPostgresDatabase*)database
    taskId:(int)taskId
  {
    SBMaintenanceTask*    newTask = nil;
    
    // Generate the query:
    SBString*             queryString = [[SBString alloc] initWithFormat:"SELECT taskid,key,description,period,notification,isenabled,inprogress,performedat FROM task WHERE taskId = " SBIntegerFormat, taskId];
    
    if ( queryString ) {
      SBPostgresQueryResult*    queryResult = [database executeQuery:queryString];
      
      if ( queryResult && [queryResult numberOfRows] ) {
        SBString*               taskKey = [queryResult objectForRow:0 fieldNum:0];
        
        if ( taskKey )
          newTask = [[[[self classForTaskKey:taskKey] alloc] initWithDatabase:database queryResult:queryResult row:0] autorelease];
      }
      [queryString release];
    }
    return newTask;
  }

//

  + (id) maintenanceTaskWithDatabase:(SBPostgresDatabase*)database
    taskKey:(SBString*)taskKey
  {
    SBMaintenanceTask*    newTask = nil;
    
    // Generate the query:
    SBString*             queryString = [[SBString alloc] initWithFormat:"SELECT taskid,key,description,period,notification,isenabled,inprogress,performedat FROM task WHERE key = '%S'", [taskKey utf16Characters]];
  
    if ( queryString ) {
      SBPostgresQueryResult*    queryResult = [database executeQuery:queryString];
    
      if ( queryResult && [queryResult numberOfRows] )
        newTask = [[[[self classForTaskKey:taskKey] alloc] initWithDatabase:database queryResult:queryResult row:0] autorelease];
        
      [queryString release];
    }
    return newTask;
  }

//

  - (void) dealloc
  {
    if ( _logFile ) {
      [_logFile writeFormatToLog:"Task handler shutting down."];
      [_logFile release];
    }
  
    if ( _database ) [_database release];
    if ( _taskKey ) [_taskKey release];
    if ( _taskDescription ) [_taskDescription release];
    if ( _period ) [_period release];
    if ( _postgresNotificationName ) [_postgresNotificationName release];
    if ( _lastPerformedAt ) [_lastPerformedAt release];
    
    if ( _acquireLock ) [_acquireLock release];
    if ( _dropLock ) [_dropLock release];
    if ( _nextPerformAt ) [_nextPerformAt release];
    
    if ( _taskTimer ) {
      [_taskTimer invalidate];
      [_taskTimer release];
    }
    
    [super dealloc];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " ( id = " SBIntegerFormat " | key = '",
        [self taskId]
      );
    [[self taskKey] writeToStream:stream];
    fprintf(
        stream,
        "' ) {\n"
        "  enabled: %s\n"
        "  ready: %s\n"
        "  notify-registered: %s\n",
        ( [self isEnabled] ? "yes" : "no" ),
        ( [self isReady] ? "yes" : "no" ),
        ( [self stateOfFlag:kSBMaintenanceTaskNotificationRegistered] ? "yes" : "no" )
      );
    
    // Description:
    if ( _taskDescription ) {
      fprintf(
          stream,
          "  description: '"
        );
      [_taskDescription writeToStream:stream];
      fprintf(
          stream,
          "'\n"
        );
    }
    
    // Period:
    if ( _period ) {
      int         hours, minutes, seconds = (int)[_period secondsInTimeInterval];
      
      hours = seconds / 3600; seconds -= (hours * 3600);
      minutes = seconds / 60; seconds -= (minutes * 60);
      
      fprintf(
          stream,
          "  period: " SBIntegerFormat " months " SBIntegerFormat " days %02d:%02d:%02d\n",
          [_period monthsInTimeInterval],
          [_period daysInTimeInterval],
          hours, minutes, seconds
        );
    }
    
    // Notification:
    if ( _postgresNotificationName ) {
      fprintf(
          stream,
          "  postgres notification name: '"
        );
      [_postgresNotificationName writeToStream:stream];
      fprintf(
          stream,
          "'\n"
        );
    }
    
    fprintf(stream,"}\n");
  }

//

  - (SBPostgresDatabase*) maintenanceDatabase
  {
    return _database;
  }

//

  - (SBInteger) taskId
  {
    return _taskId;
  }

//

  - (SBString*) taskKey
  {
    return _taskKey;
  }

//

  - (SBString*) taskDescription
  {
    return _taskDescription;
  }

//

  - (SBTimeInterval*) period
  {
    return _period;
  }
  
//

  - (SBString*) postgresNotificationName
  {
    return _postgresNotificationName;
  }
  
//

  - (SBDate*) lastPerformedAt
  {
    return _lastPerformedAt;
  }
  
//

  - (BOOL) isEnabled
  {
    return [self stateOfFlag:kSBMaintenanceTaskIsEnabled];
  }
  
//

  - (BOOL) isReady
  {
    return [self stateOfFlag:kSBMaintenanceTaskIsReady];
  }

//

  - (void) performMaintenanceTask
  {
    [self performMaintenanceTaskWithPayloadString:nil];
  }
  - (void) performMaintenanceTaskWithPayloadString:(SBString*)payloadString
  {
    SBDate*     now = [[SBDate alloc] init];
    
    [self setLastPerformedAt:now];
    [now release];
  }

//

  - (void) invalidateTaskTimer
  {
    if ( _taskTimer ) {
      [_taskTimer invalidate];
      [[SBRunLoop currentRunLoop] limitDateForMode:SBRunLoopDefaultMode];
      [_taskTimer release];
      _taskTimer = nil;
    }
  }

//

  - (SBLogger*) logFile
  {
    return _logFile;
  }

//

  - (void) updateConfigurationFromDatabase
  {
    if ( _database ) {
      // Generate the query:
      SBString*   queryString = [[SBString alloc] initWithFormat:"SELECT * FROM task WHERE taskId = %d", [self taskId]];
      
      if ( queryString ) {
        SBPostgresQueryResult*    queryResult = [_database executeQuery:queryString];
        
        if ( queryResult && [queryResult queryWasSuccessful] ) {
          SBDictionary*           properties = [queryResult dictionaryForRow:0];
          
          if ( properties )
            [self setProperties:properties];
        }
        [queryString release];
      }
    }
  }

//

  - (void) notificationFromDatabase:(SBNotification*)aNotify
  {
    SBString      *payloadString = nil;
    SBDictionary  *userInfo = [aNotify userInfo];
    
    if ( userInfo ) {
      payloadString = [userInfo objectForKey:SBPostgresNotifierPayloadStringKey];
    }
    if ( payloadString ) {
      [_logFile writeFormatToLog:"Waking up on notification from database: %s, %s", [[aNotify identifier] utf8Characters], [payloadString utf8Characters]];
    } else {
      [_logFile writeFormatToLog:"Waking up on notification from database: %s", [[aNotify identifier] utf8Characters]];
    }
    [self performMaintenanceTaskWrapper:payloadString];
  }

@end
