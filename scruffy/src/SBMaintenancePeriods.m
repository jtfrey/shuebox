//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMaintenancePeriods.m
//
// Class which handles lookup of named interval values.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBMaintenancePeriods.h"

#import "SBString.h"
#import "SBDictionary.h"
#import "SBDate.h"
#import "SBPostgres.h"

@interface SBMaintenancePeriods(SBMaintenancePeriodsPrivate)

- (SBPostgresDatabase*) database;
- (BOOL) loadPeriodDictionary;

@end

@implementation SBMaintenancePeriods(SBMaintenancePeriodsPrivate)

  - (SBPostgresDatabase*) database
  {
    return _database;
  }

//

  - (BOOL) loadPeriodDictionary
  {
    // Null-out the current dictionary:
    if ( _periodsByName ) {
      [_periodsByName release];
      _periodsByName = nil;
    }
    
    if ( _database ) {
      // Do the query:
      SBPostgresQueryResult*      qResult = [_database executeQuery:@"SELECT key,duration FROM period"];
      SBUInteger                  iMax;
      
      if ( qResult && [qResult queryWasSuccessful] ) {
        if ( (iMax = [qResult numberOfRows]) ) {
          SBString*                 keys[iMax];
          SBTimeInterval*           vals[iMax];
          SBUInteger                i = 0;
          
          while ( i < iMax ) {
            keys[i] = [qResult objectForRow:i fieldNum:0];
            vals[i] = [qResult objectForRow:i fieldNum:1];
            i++;
          }
          _periodsByName = [[SBDictionary dictionaryWithObjects:vals forKeys:keys count:iMax] retain];
        }
        return YES;
      }
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBMaintenancePeriods : SBObject

  + (id) maintenancePeriodsWithDatabase:(SBPostgresDatabase*)aDatabase
  {
    static SBMaintenancePeriods*      lastInstance = nil;
    
    if ( lastInstance ) {
      if ( [lastInstance database] == aDatabase ) {
        return lastInstance;
      }
      [lastInstance release];
    }
    
    lastInstance = [[SBMaintenancePeriods alloc] initWithDatabase:aDatabase];
    return lastInstance;
  }

//

  - (id) initWithDatabase:(SBPostgresDatabase*)aDatabase
  {
    if ( self = [super init] ) {
      _database = [aDatabase retain];
      [self loadPeriodDictionary];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _periodsByName ) [_periodsByName release];
    if ( _database ) [_database release];
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " ( count: %d ) {\n",
        [_periodsByName count]
      );
    if ( _periodsByName ) {
      SBEnumerator*   ePeriodName = [_periodsByName keyEnumerator];
      SBString*       periodName;
      
      while ( periodName = [ePeriodName nextObject] ) {
        SBTimeInterval*   interval = [_periodsByName objectForKey:periodName];
        
        fprintf(stream, "  ");
        [periodName writeToStream:stream];
        fprintf(
            stream,
            " : %d months %d days %d seconds\n",
            [interval monthsInTimeInterval],
            [interval daysInTimeInterval],
            (int)[interval secondsInTimeInterval]
          );
      }
    }
    fprintf(stream,"}\n");
  }

//

  - (BOOL) refreshPeriodsFromDatabase
  {
    return [self loadPeriodDictionary];
  }

//

  - (SBUInteger) periodCount
  {
    if ( _periodsByName )
      return [_periodsByName count];
    return 0;
  }


  - (SBTimeInterval*) periodWithName:(SBString*)periodName
  {
    if ( _periodsByName && periodName )
      return (SBTimeInterval*)[_periodsByName objectForKey:periodName];
    return nil;
  }

//

  - (SBEnumerator*) periodNameEnumerator
  {
    if ( _periodsByName )
      return [_periodsByName keyEnumerator];
    return nil;
  }

@end
