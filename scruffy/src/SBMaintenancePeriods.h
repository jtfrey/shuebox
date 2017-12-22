//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMaintenancePeriods.h
//
// Class which handles lookup of named interval values.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBEnumerator, SBString, SBDictionary, SBTimeInterval, SBPostgresDatabase;

/*!
  @class SBMaintenancePeriods
  @discussion
  The SBMaintenancePeriods class is an in-memory representation of the "period"
  table in the shuebox database.  An instance of the class grabs the period names and
  time intervals and forms a dictionary from them, mapping name to interval.  Intervals
  are accessed by means of the periodWithName: method.  An enumerator which iterates over
  the defined period names may be retrieved, as well.
*/
@interface SBMaintenancePeriods : SBObject
{
  SBPostgresDatabase*   _database;
  SBDictionary*         _periodsByName;
}

/*!
  @method maintenancePeriodsWithDatabase:
  @discussion
  Returns a newly-allocated, autoreleased instance which has been initialized using the
  "period" table of aDatabase.
  
  This method "remembers" the last allocated instance so that subsequent invocations on
  the same database will return the same instance.  This affords a minimal, simple way
  of minimizing the number of instances of this class that are floating around.
*/
+ (id) maintenancePeriodsWithDatabase:(SBPostgresDatabase*)aDatabase;
/*!
  @method initWithDatabase:
  @discussion
  Initialize an instance using rows from the "period" table in aDatabase.
*/
- (id) initWithDatabase:(SBPostgresDatabase*)aDatabase;
/*!
  @method refreshPeriodsFromDatabase
  @discussion
  Attempt to refresh the receiver's in-memory period name-to-interval mapping from the
  "period" table in the database used to initialize it.  Returns YES if
  the database lookup was successful, NO otherwise.
*/
- (BOOL) refreshPeriodsFromDatabase;
/*!
  @method periodCount
  @discussion
  Returns the number of period name-to-interval pairs contained in the receiver.
*/
- (SBUInteger) periodCount;
/*!
  @method periodWithName:
  @discussion
  If the given periodName exists in the receiver, return the time interval associated with
  it.  Otherwise, returns nil.
*/
- (SBTimeInterval*) periodWithName:(SBString*)periodName;
/*!
  @method periodNameEnumerator
  @discussion
  If the receiver contains any period name-to-interval mappings, returns an SBEnumerator
  that will iterate over the names.  Otherwise, returns nil.
*/
- (SBEnumerator*) periodNameEnumerator;

@end
