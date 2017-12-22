//
// SBFoundation : ObjC Class Library for Solaris
// SBDate.m
//
// UTC date/time handling thanks to ICU.
//
// $Id$
//

#import "SBDate.h"
#import "SBString.h"

#define IABS(I) ((I < 0) ? -I : I)

const char*     __SBTimeIntervalFormDescriptions[] = {
                          "seconds",
                          "days",
                          "months"
                        };

//
// For some reason ICU doesn't bother using the gettimeofday() interface on any Unix variant.
// instead it sticks to time(), which has no sub-second precision!!
//
static inline UDate
__SBDateCurrentTimestamp()
{
  struct timeval  posixTime;
  gettimeofday(&posixTime, NULL);
  return (UDate)(((int64_t)posixTime.tv_sec * U_MILLIS_PER_SECOND) + (posixTime.tv_usec/1000));
}

//

@interface SBTimeInterval_Seconds : SBTimeInterval
{
  double    _seconds;
}

- (id) initWithSeconds:(double)seconds;

@end

@interface SBTimeInterval_Days : SBTimeInterval_Seconds
{
  int       _days;
}

- (id) initWithDays:(int)days seconds:(double)seconds;

@end

@interface SBTimeInterval_Months : SBTimeInterval_Days
{
  int       _months;
}

- (id) initWithMonths:(int)months days:(int)days seconds:(double)seconds;

@end

@implementation SBTimeInterval

  + (id) timeIntervalWithSeconds:(double)seconds
  {
    int     days, months;
    
    //  Are we over the month limit?
    if ( fabs(seconds) >= (30 * 24 * 60 * 60) ) {
      months = floor( seconds / (30 * 24 * 60 * 60) );
      seconds -= months * (30 * 24 * 60 * 60);
      days = floor( seconds / (24 * 60 * 60) );
      seconds -= days * (24 * 60 * 60);
      return [[[SBTimeInterval_Months alloc] initWithMonths:months days:days seconds:seconds] autorelease];
    } else if ( fabs(seconds) >= (24 * 60 * 60) ) {
      days = floor( seconds / (24 * 60 * 60) );
      seconds -= days * (24 * 60 * 60);
      return [[[SBTimeInterval_Days alloc] initWithDays:days seconds:seconds] autorelease];
    }
    return [[[SBTimeInterval_Seconds alloc] initWithSeconds:seconds] autorelease];
  }
  
//

  + (id) timeIntervalWithDays:(int)days
    seconds:(double)seconds
  {
    int     altDays = 0, months = 0;
    
    //  Are we over the month limit?
    if ( fabs(seconds) >= (30 * 24 * 60 * 60) ) {
      months = floor( seconds / (30 * 24 * 60 * 60) );
      seconds -= months * (30 * 24 * 60 * 60);
      altDays = floor( seconds / (24 * 60 * 60) );
      seconds -= altDays * (24 * 60 * 60);
    } else if ( fabs(seconds) >= (24 * 60 * 60) ) {
      altDays = floor( seconds / (24 * 60 * 60) );
      seconds -= altDays * (24 * 60 * 60);
    }
    days += altDays;
    if ( IABS(days) > 30 ) {
      months += (days / 30);
      days %= 30;
    }
    if ( IABS(months) > 0 ) {
      return [[[SBTimeInterval_Months alloc] initWithMonths:months days:days seconds:seconds] autorelease];
    }
    else if ( IABS(days) > 0 ) {
      return [[[SBTimeInterval_Days alloc] initWithDays:days seconds:seconds] autorelease];
    }
    return [[[SBTimeInterval_Seconds alloc] initWithSeconds:seconds] autorelease];
  }

//

  + (id) timeIntervalWithMonths:(int)months
    days:(int)days
    seconds:(double)seconds
  {
    int     altDays = 0, altMonths = 0;
    
    //  Are we over the month limit?
    if ( fabs(seconds) >= (30 * 24 * 60 * 60) ) {
      altMonths = floor( seconds / (30 * 24 * 60 * 60) );
      seconds -= altMonths * (30 * 24 * 60 * 60);
      altDays = floor( seconds / (24 * 60 * 60) );
      seconds -= altDays * (24 * 60 * 60);
    } else if ( fabs(seconds) >= (24 * 60 * 60) ) {
      altDays = floor( seconds / (24 * 60 * 60) );
      seconds -= altDays * (24 * 60 * 60);
    }
    months += altMonths;
    days += altDays;
    if ( IABS(days) > 30 ) {
      months += (days / 30);
      days %= 30;
    }
    if ( IABS(months) > 0 ) {
      return [[[SBTimeInterval_Months alloc] initWithMonths:months days:days seconds:seconds] autorelease];
    }
    else if ( IABS(days) > 0 ) {
      return [[[SBTimeInterval_Days alloc] initWithDays:days seconds:seconds] autorelease];
    }
    return [[[SBTimeInterval_Seconds alloc] initWithSeconds:seconds] autorelease];
  }
  
//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( self == otherObject )
      return YES;
    if ( [otherObject isKindOf:[SBTimeInterval class]] )
      return ( fabs([self totalSecondsInTimeInterval] - [(SBTimeInterval*)otherObject totalSecondsInTimeInterval]) < 1e-6 );
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  seconds:          %lf\n"
        "  days:             %d\n"
        "  months:           %d\n"
        "}\n",
        [self secondsInTimeInterval],
        [self daysInTimeInterval],
        [self monthsInTimeInterval]
      );
  }

//

  - (double) secondsInTimeInterval
  {
    return 0.0;
  }
  - (int) daysInTimeInterval
  {
    return 0;
  }
  - (int) monthsInTimeInterval
  {
    return 0;
  }

//

  - (double) totalSecondsInTimeInterval
  {
    return ([self secondsInTimeInterval] + ([self daysInTimeInterval] + [self monthsInTimeInterval] * 30) * (24 * 60 * 60));
  }

@end

@implementation SBTimeInterval_Seconds

  - (id) initWithSeconds:(double)seconds
  {
    if ( self = [super init] )
      _seconds = seconds;
    return self;
  }

//

  - (double) secondsInTimeInterval
  {
    return _seconds;
  }
  - (int) daysInTimeInterval
  {
    return 0;
  }
  - (int) monthsInTimeInterval
  {
    return 0;
  }

@end

@implementation SBTimeInterval_Days

  - (id) initWithDays:(int)days
    seconds:(double)seconds
  {
    if ( self = [super initWithSeconds:seconds] )
      _days = days;
    return self;
  }

//

  - (int) daysInTimeInterval
  {
    return _days;
  }
  - (int) monthsInTimeInterval
  {
    return 0;
  }

@end

@implementation SBTimeInterval_Months

  - (id) initWithMonths:(int)months
    days:(int)days
    seconds:(double)seconds
  {
    if ( self = [super initWithDays:days seconds:seconds] )
      _months = months;
    return self;
  }

//

  - (int) monthsInTimeInterval
  {
    return _months;
  }

@end

//
#pragma mark -
//

@interface SBConcreteDate : SBDate
{
  int64_t       _utcTime;
@public
  BOOL          _isConst;
}

@end

@interface SBAlwaysCurrentDate : SBDate
{
}

@end

//
#pragma mark -
//

@implementation SBDate

  + (id) alloc
  {
    if ( self == [SBDate class] )
      return [SBConcreteDate alloc];
    return [super alloc];
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBDate class]] )
      return [self isEqualToDate:(SBDate*)otherObject];
    return NO;
  }

//

  - (int64_t) utcTimestamp
  {
    return 0;
  }
  
//

  - (SBString*) stringValue
  {
    char      buffer[32];
    time_t    ts = [self unixTimestamp];
    
    if ( strftime(buffer, 32, "%Y-%m-%d %H:%M:%S", localtime(&ts)) > 0 )
      return [SBString stringWithUTF8String:buffer];
    return nil;
  }
  
@end

@implementation SBDate(SBDateCreation)

  + (SBDate*) date
  {
    return [[[self alloc] init] autorelease];
  }
  
//

  + (SBDate*) dateWithUTCTimestamp:(int64_t)ticks
  {
    return [[[self alloc] initWithUTCTimestamp:ticks] autorelease];
  }
  
//

  + (SBDate*) dateWithUnixTimestamp:(time_t)seconds
  {
    return [[[self alloc] initWithUnixTimestamp:seconds] autorelease];
  }
  
//

  + (SBDate*) dateWithSecondsSinceNow:(int)seconds
  {
    UDate       now = __SBDateCurrentTimestamp() + (seconds * 1e3);
    
    return [[[self alloc] initWithICUDate:now] autorelease];
  }

//

  + (SBDate*) dateWithSeconds:(int)seconds
    sinceDate:(SBDate*)anotherDate
  {
    return [[[self alloc] initWithSeconds:seconds sinceDate:anotherDate] autorelease];
  }

//

  + (SBDate*) dateWithTimeInterval:(SBTimeInterval*)timeInterval
    sinceDate:(SBDate*)anotherDate
  {
    return [[[self alloc] initWithTimeInterval:timeInterval sinceDate:anotherDate] autorelease];
  }
  
//

  + (SBDate*)dateWithICUDate:(UDate)icuDate
  {
    return [[[self alloc] initWithICUDate:icuDate] autorelease];
  }

//

  - (id) init
  {
    return [self initWithICUDate:__SBDateCurrentTimestamp()];
  }
  
//

  - (id) initWithUTCTimestamp:(int64_t)ticks
  {
    return [super init];
  }
  
//

  - (id) initWithUnixTimestamp:(time_t)seconds
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int64_t       utcTime;
    
    utcTime = utmscale_fromInt64((int64_t)seconds, UDTS_UNIX_TIME, &icuErr);
    if ( U_FAILURE(icuErr) ) {
      [self release];
      self = nil;
    } else {
      self = [self initWithUTCTimestamp:utcTime];
    }
    return self;
  }
  
//

  - (id) initWithICUDate:(UDate)icuDate
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    int64_t       utcTime;
    
    utcTime = utmscale_fromInt64((int64_t)icuDate, UDTS_ICU4C_TIME, &icuErr);
    if ( U_FAILURE(icuErr) ) {
      [self release];
      self = nil;
    } else {
      self = [self initWithUTCTimestamp:utcTime];
    }
    return self;
  }

//

  - (id) initWithSecondsSinceNow:(int)seconds
  {
    UDate       now = __SBDateCurrentTimestamp() + (seconds * 1e3);
    
    return [self initWithICUDate:now];
  }

//

  - (id) initWithSeconds:(int)seconds
    sinceDate:(SBDate*)anotherDate
  {
    // A UTC tick = 100 nanosecond; therefore:
    //
    //  X seconds * (10^9 nanosecond) / (second) * (tick) / (100 nanosecond) = (X)(10^7) ticks
    //
    int64_t       ticks = (int64_t)seconds * (int64_t)10000000;
    
    return [self initWithUTCTimestamp:[anotherDate utcTimestamp] + ticks];
  }
  
//

  - (id) initWithTimeInterval:(SBTimeInterval*)timeInterval
    sinceDate:(SBDate*)anotherDate
  {
    return [self initWithSeconds:[timeInterval totalSecondsInTimeInterval] sinceDate:anotherDate];
  }
  
//

  + (SBDate*) dateWhichIsAlwaysNow
  {
    static SBAlwaysCurrentDate* SBDateAlwaysNow = nil;
    
    if ( SBDateAlwaysNow == nil ) {
      SBDateAlwaysNow = [[SBAlwaysCurrentDate alloc] init];
    }
    return SBDateAlwaysNow;
  }
  
//

  + (SBDate*) distantFuture
  {
    static SBConcreteDate* __SBDateDistantFuture = nil;
    
    if ( ! __SBDateDistantFuture ) {
      __SBDateDistantFuture = [[SBConcreteDate alloc] initWithUTCTimestamp:(int64_t)LONG_LONG_MAX];
      __SBDateDistantFuture->_isConst = YES;
    }
    return __SBDateDistantFuture;
  }
  
//

  + (SBDate*) distantPast
  {
    static SBConcreteDate* __SBDateDistantPast = nil;
    
    if ( ! __SBDateDistantPast ) {
      __SBDateDistantPast = [[SBConcreteDate alloc] initWithUTCTimestamp:(int64_t)LONG_LONG_MIN];
      __SBDateDistantPast->_isConst = YES;
    }
    return __SBDateDistantPast;
  }

@end

@implementation SBDate(SBExtendedDate)

  - (time_t) unixTimestamp
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    
    return (time_t)utmscale_toInt64([self utcTimestamp], UDTS_UNIX_TIME, &icuErr);
  }
  
//

  - (UDate) icuDate
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    
    return (UDate)utmscale_toInt64([self utcTimestamp], UDTS_ICU4C_TIME, &icuErr);
  }

//

  - (SBDate*) earlierDate:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime < [self utcTimestamp] )
        return anotherDate;
    }
    return self;
  }
  
//

  - (SBDate*) laterDate:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime > [self utcTimestamp] )
        return anotherDate;
    }
    return self;
  }
  
//

  - (SBComparisonResult) compare:(SBDate*)anotherDate
  {
    if ( anotherDate ) {
      int64_t     otherTime = [anotherDate utcTimestamp];
      
      if ( otherTime > [self utcTimestamp] )
        return SBOrderAscending;
      if ( otherTime == [self utcTimestamp] )
        return SBOrderSame;
    }
    return SBOrderDescending;
  }
  
//

  - (BOOL) isEqualToDate:(SBDate*)anotherDate
  {
    if ( anotherDate )
      return ( ([self utcTimestamp] == [anotherDate utcTimestamp]) ? YES : NO );
    return NO;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " { utcTime = %lld | UDate = %lf }\n", [self utcTimestamp], [self icuDate]);
  }

//

  - (SBTimeInterval*) timeIntervalSinceDate:(SBDate*)anotherDate
  {
    double      ticksThen = [anotherDate utcTimestamp];
    double      ticksNow = [self utcTimestamp];
    
    return [SBTimeInterval timeIntervalWithSeconds:(ticksNow - ticksThen) / 10000000.0];
  }

@end

//
#pragma mark -
//

@implementation SBConcreteDate

  - (id) initWithUTCTimestamp:(int64_t)ticks
  {
    if ( self = [super initWithUTCTimestamp:ticks] ) {
      _utcTime = ticks;
    }
    return self;
  }

//

  - (id) retain
  {
    if ( _isConst )
      return self;
    return [super retain];
  }

//

  - (void) release
  {
    if ( ! _isConst )
      [super release];
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

@end

//
#pragma mark -
//

@implementation SBAlwaysCurrentDate

  - (int64_t) utcTimestamp
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    
    return (int64_t)utmscale_fromInt64((int64_t)__SBDateCurrentTimestamp(), UDTS_ICU4C_TIME, &icuErr);
  }
  
//

  - (time_t) unixTimestamp
  {
    return time(NULL);
  }

@end
