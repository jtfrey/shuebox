//
// scruffy : maintenance scheduler daemon for SHUEBox
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

*/
@interface SBDate : SBObject
{
  int64_t       _utcTime;
}

+ (SBDate*) date;
+ (SBDate*) dateWithUTCTimestamp:(int64_t)ticks;
+ (SBDate*) dateWithUnixTimestamp:(time_t)seconds;
+ (SBDate*) dateWithSeconds:(int)seconds sinceDate:(SBDate*)anotherDate;
+ (SBDate*) dateWithICUDate:(UDate)icuDate;

- (id) init;
- (id) initWithUTCTimestamp:(int64_t)ticks;
- (id) initWithUnixTimestamp:(time_t)seconds;
- (id) initWithSeconds:(int)seconds sinceDate:(SBDate*)anotherDate;
- (id) initWithICUDate:(UDate)icuDate;

- (int64_t) utcTimestamp;
- (time_t) unixTimestamp;
- (UDate) icuDate;

- (SBDate*) earlierDate:(SBDate*)anotherDate;
- (SBDate*) laterDate:(SBDate*)anotherDate;

- (SBComparisonResult) compare:(SBDate*)anotherDate;
- (BOOL) isEqualToDate:(SBDate*)anotherDate;


@end
