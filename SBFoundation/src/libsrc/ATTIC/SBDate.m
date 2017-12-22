//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBDate.m
//
// UTC date/time handling thanks to ICU.
//
// $Id$
//

#import "SBDate.h"

@implementation SBDate

  + (SBDate*) date
  {
    return [[[SBDate alloc] init] autorelease];
  }
  
//

  + (SBDate*) dateWithUTCTimestamp:(int64_t)ticks
  {
    return [[[SBDate alloc] initWithUTCTimestamp:ticks] autorelease];
  }
  
//

  + (SBDate*) dateWithUnixTimestamp:(time_t)seconds
  {
    return [[[SBDate alloc] initWithUnixTimestamp:seconds] autorelease];
  }
  
//

  + (SBDate*) dateWithSeconds:(int)seconds
    sinceDate:(SBDate*)anotherDate
  {
    return [[[SBDate alloc] initWithSeconds:seconds sinceDate:anotherDate] autorelease];
  }

//

  + (SBDate*)dateWithICUDate:(UDate)icuDate
  {
    return [[[SBDate alloc] initWithICUDate:icuDate] autorelease];
  }

//

  - (id) init
  {
    return [self initWithUnixTimestamp:time(NULL)];
  }
  
//

  - (id) initWithUTCTimestamp:(int64_t)ticks
  {
    if ( self = [super init] ) {
      _utcTime = ticks;
    }
    return self;
  }

//

  - (id) initWithUnixTimestamp:(time_t)seconds
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _utcTime = utmscale_fromInt64((int64_t)seconds, UDTS_UNIX_TIME, &icuErr);
      if ( U_FAILURE(icuErr) ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithSeconds:(int)seconds
    sinceDate:(SBDate*)anotherDate
  {
    // A UTC tick = 100 nanosecond; therefore:
    //
    //  X seconds * (10^9 nanosecond) / (second) * (tick) / (100 nanosecond) = (X)(10^7) ticks
    //
    int64_t       ticks = seconds * 10000000;
    
    return [self initWithUTCTimestamp:[anotherDate utcTimestamp] + ticks];
  }
  
//

  - (id) initWithICUDate:(UDate)icuDate
  {
    if ( self = [super init] ) {
      UErrorCode    icuErr = U_ZERO_ERROR;
      
      _utcTime = utmscale_fromInt64((int64_t)icuDate, UDTS_ICU4C_TIME, &icuErr);
      if ( U_FAILURE(icuErr) ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (int64_t) utcTimestamp
  {
    return _utcTime;
  }
  
//

  - (time_t) unixTimestamp
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    
    return (time_t)utmscale_toInt64(_utcTime, UDTS_UNIX_TIME, &icuErr);
  }
  
//

  - (UDate) icuDate
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    
    return (UDate)utmscale_toInt64(_utcTime, UDTS_ICU4C_TIME, &icuErr);
  }

//

  - (SBDate*) earlierDate:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime < _utcTime )
        return anotherDate;
    }
    return self;
  }
  
//

  - (SBDate*) laterDate:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime > _utcTime )
        return anotherDate;
    }
    return self;
  }
  
//

  - (SBComparisonResult) compare:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime > _utcTime )
        return SBOrderAscending;
      if ( otherTime == _utcTime )
        return SBOrderSame;
    }
    return SBOrderDescending;
  }
  
//

  - (BOOL) isEqualToDate:(SBDate*)anotherDate
  {
    if ( anotherDate )
      return ( (_utcTime == [anotherDate utcTimestamp]) ? YES : NO );
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " { _utcTime = %lld | UDate = %lg }\n", _utcTime, [self icuDate]);
  }

@end
