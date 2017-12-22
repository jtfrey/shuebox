//
// SBFoundation : ObjC Class Library for Solaris
// SBDate.h
//
// UTC date/time handling thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/utmscale.h"
#include "unicode/ucal.h"

/*!
  @class SBTimeInterval
  @discussion
  Instances of SBTimeInterval wrap a time interval.  Time intervals may be created as
  second, day, or month counts.
*/
@interface SBTimeInterval : SBObject
/*!
  @method timeIntervalWithSeconds:
  
  Returns an initialized, autoreleased instance of SBTimeInterval which wraps a number
  of seconds.
*/
+ (id) timeIntervalWithSeconds:(double)seconds;
/*!
  @method timeIntervalWithDays:seconds:
  
  Returns an initialized, autoreleased instance of SBTimeInterval which wraps a number
  of days.  The count is integer-based so this is whole days (24 hours) only; an
  interval that does not fall on a day boundary will always be rounded down.
*/
+ (id) timeIntervalWithDays:(SBInteger)days seconds:(double)seconds;
/*!
  @method timeIntervalWithMonths:days:seconds:
  
  Returns an initialized, autoreleased instance of SBTimeInterval which wraps a number
  of months.  The count is integer-based so this is whole months (30 days) only; an
  interval that does not fall on a month boundary will always be rounded down.
*/
+ (id) timeIntervalWithMonths:(SBInteger)months days:(SBInteger)days seconds:(double)seconds;
/*!
  @method secondsInTimeInterval
  
  Returns the number of seconds (as a double) in the receiver's time interval.
*/
- (double) secondsInTimeInterval;
/*!
  @method daysInTimeInterval
  
  Returns the number of days (as an int) in the receiver's time interval.  An
  interval that does not fall on a day boundary will be rounded down.
*/
- (SBInteger) daysInTimeInterval;
/*!
  @method monthsInTimeInterval
  
  Returns the number of months (as an int) in the receiver's time interval.  An
  interval that does not fall on a month boundary will be rounded down.
*/
- (SBInteger) monthsInTimeInterval;
/*!
  @method totalSecondsInTimeInterval

  Returns the total number of seconds in the time interval, with day and month counts
  converted to seconds and coallesced into the total.
*/
- (double) totalSecondsInTimeInterval;

@end

/*!
  @class SBDate
  @discussion
  An SBDate encapsulates a UTC timestamp.  Methods are provided to
  initialize instances from the current time, a Unix timestamp, even
  a number of seconds relative to another SBDate.
  
  Some basic temporal comparisons are provided to determine the
  ordering of dates.
*/
@interface SBDate : SBObject <SBStringValue>

/*!
  @method utcTimestamp
  
  Returns the receiver's UTC timestamp.
*/
- (int64_t) utcTimestamp;

@end

/*!
  @category SBDate(SBDateCreation)
  @discussion
  Groups all methods that create and initialize SBDate objects.
*/
@interface SBDate(SBDateCreation)

/*!
  @method date
  
  Returns an autoreleased instance of SBDate which wraps the timestamp
  that was current when the instance was created.
*/
+ (SBDate*) date;
/*!
  @method dateWithUTCTimestamp:
  
  Returns an autoreleased instance of SBDate which represents the given
  UTC timestamp -- ticks relative to the UTC epoch.
*/
+ (SBDate*) dateWithUTCTimestamp:(int64_t)ticks;
/*!
  @method dateWithUnixTimestamp:
  
  Returns an autoreleased instance of SBDate which represents the given
  Unix timestamp (as returned by the time() function, for example).
*/
+ (SBDate*) dateWithUnixTimestamp:(time_t)seconds;
/*!
  @method dateWithSecondsSinceNow:
  
  Returns an autoreleased instance of SBDate which represents the given
  offset (in seconds) from the current date and time.
*/
+ (SBDate*) dateWithSecondsSinceNow:(SBInteger)seconds;
/*!
  @method dateWithSeconds:sinceDate:
  
  Returns an autoreleased instance of SBDate which represents the given
  offset (in seconds) from a reference date (anotherDate).
*/
+ (SBDate*) dateWithSeconds:(SBInteger)seconds sinceDate:(SBDate*)anotherDate;
/*!
  @method dateWithTimeInterval:sinceDate:
  
  Returns an autoreleased instance of SBDate which represents the given
  offset (as a SBTimeInterval object) from a reference date (anotherDate).
*/
+ (SBDate*) dateWithTimeInterval:(SBTimeInterval*)timeInterval sinceDate:(SBDate*)anotherDate;
/*!
  @method dateWithICUDate:
  
  Returns an autoreleased instance of SBDate which represents the given
  ICU date -- the number of milliseconds since 1970-01-01 00:00:00 UTC.
*/
+ (SBDate*) dateWithICUDate:(UDate)icuDate;
/*!
  @method init
  
  Initializes a newly allocated instance of SBDate to represent the system
  timestamp at that moment.
*/
- (id) init;
/*!
  @method initWithUTCTimestamp:
  
  Initializes a newly allocated instance of SBDate to represent the given
  UTC timestamp -- ticks relative to the UTC epoch.
*/
- (id) initWithUTCTimestamp:(int64_t)ticks;
/*!
  @method initWithUnixTimestamp:
  
  Initializes a newly allocated instance of SBDate to represent the given
  Unix timestamp (as returned by the time() function, for example).
*/
- (id) initWithUnixTimestamp:(time_t)seconds;
/*!
  @method initWithSecondsSinceNow:
  
  Initializes a newly allocated instance of SBDate to represent the given
  offset (in seconds) from the current date and time.
*/
- (id) initWithSecondsSinceNow:(SBInteger)seconds;
/*!
  @method initWithSeconds:sinceDate:
  
  Initializes a newly allocated instance of SBDate to represent the given
  offset (in seconds) from a reference date (anotherDate).
*/
- (id) initWithSeconds:(SBInteger)seconds sinceDate:(SBDate*)anotherDate;
/*!
  @method initWithTimeInterval:sinceDate:
  
  Initializes a newly allocated instance of SBDate to represent the given
  offset (as a SBTimeInterval object) from a reference date (anotherDate).
*/
- (id) initWithTimeInterval:(SBTimeInterval*)timeInterval sinceDate:(SBDate*)anotherDate;
/*!
  @method initWithICUDate:
  
  Initializes a newly allocated instance of SBDate to represent the given
  ICU date -- the number of milliseconds since 1970-01-01 00:00:00 UTC.
*/
- (id) initWithICUDate:(UDate)icuDate;
/*!
  @method dateWhichIsAlwaysNow
  
  Returns a shared SBDate instance that is dynamic:  whatever message you send
  to the object, it will always behave as though it wraps the current time.
  
  This is distinct from the objects returned by the "date" class method:  instances
  returned by that method are a static snapshot of the time when the instance was
  created.
*/
+ (SBDate*) dateWhichIsAlwaysNow;
/*!
  @method distantFuture
  @discussion
    Returns an SBData object that represents the most distant representable date
    in the future.
*/
+ (SBDate*) distantFuture;
/*!
  @method distantPast
  @discussion
    Returns an SBData object that represents the most distant representable date
    in the past.
*/
+ (SBDate*) distantPast;

@end

/*!
  @category SBDate(SBExtendedDate)
  @discussion
  Groups all methods that extend the basic SBDate object.  Subclasses of SBDate that
  at least override the utcTimestamp method automatically inherit these methods.
*/
@interface SBDate(SBExtendedDate)

/*!
  @method unixTimestamp
  
  Returns the Unix timestamp which corresponds to the receiver's UTC timestamp.
*/
- (time_t) unixTimestamp;
/*!
  @method icuDate
  
  Returns the ICU date which corresponds to the receiver's UTC timestamp.
*/
- (UDate) icuDate;
/*!
  @method earlierDate:
  
  Returns the receiver itself if its UTC timestamp <= the UTC timestamp of anotherDate;
  otherwise, returns anotherDate.
*/
- (SBDate*) earlierDate:(SBDate*)anotherDate;
/*!
  @method laterDate:
  
  Returns the receiver itself if its UTC timestamp >= the UTC timestamp of anotherDate;
  otherwise, returns anotherDate.
*/
- (SBDate*) laterDate:(SBDate*)anotherDate;
/*!
  @method compare:
  
  Returns SBOrderDescending if anotherDate occurs before the receiver; SBOrderAscending
  if anotherDate occurs after the receiver; and SBOrderSame if the two are equivalent.
*/
- (SBComparisonResult) compare:(SBDate*)anotherDate;
/*!
  @method isEqualToDate:
  
  Returns YES if the receiver and anotherDate represent equivalent UTC timestamps.
*/
- (BOOL) isEqualToDate:(SBDate*)anotherDate;
/*!
  @method timeIntervalSinceDate:
  
  Returns an SBTimeInterval containing the interval between anotherDate and the date
  represented by the receiver.  The interval will be negative if anotherDate is in 
  the receiver's future.
*/
- (SBTimeInterval*) timeIntervalSinceDate:(SBDate*)anotherDate;

@end
