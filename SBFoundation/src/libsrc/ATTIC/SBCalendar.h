//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBCalendar.h
//
// Calendar date/time utilities thanks to ICU.
//
// $Id$
//

#import "SBObject.h"

#include "unicode/ucal.h"

/*!
  @enum Calendar units
  
  This enumeration defines bitmapped constants that denote individual units comprising
  a calendar, e.g. the year, the month, the hour.  Multiple units are denoted by
  bitwise-ORing the constants.
*/
enum {
  SBEraCalendarUnit                 = 1 << 0,
  SBYearCalendarUnit                = 1 << 1,
  SBMonthCalendarUnit               = 1 << 2,
  SBDayCalendarUnit                 = 1 << 3,
  SBHourCalendarUnit                = 1 << 4,
  SBMinuteCalendarUnit              = 1 << 5,
  SBSecondCalendarUnit              = 1 << 6,
  SBWeekCalendarUnit                = 1 << 7,
  SBWeekdayCalendarUnit             = 1 << 8,
  SBWeekdayOrdinalCalendarUnit      = 1 << 9,
  
  SBDateCalendarUnits               = SBEraCalendarUnit |
                                      SBYearCalendarUnit |
                                      SBMonthCalendarUnit |
                                      SBDayCalendarUnit,
  
  SBTimeCalendarUnits               = SBHourCalendarUnit |
                                      SBMinuteCalendarUnit |
                                      SBSecondCalendarUnit,
                                      
  SBAllCalendarUnits                = SBDateCalendarUnits |
                                      SBTimeCalendarUnits |
                                      SBWeekCalendarUnit |
                                      SBWeekdayCalendarUnit |
                                      SBWeekdayOrdinalCalendarUnit,
                                      
  SBMaxCalendarUnit                 = 10
};

@class SBDateComponents, SBDate, SBString, SBLocale;


/*!
  @class SBCalendar
  
  ObjC wrapper to the ICU library's UCalendar object.  See the ICU documentation for
  more information:
  
    http://icu-project.org/apiref/icu4c/ucal_8h.html
  
*/
@interface SBCalendar : SBObject
{
  UCalendar*      _icuCalendar;
  SBString*       _tzId;
  SBLocale*       _locale;
  unsigned int    _minDaysInFirstWeek,_firstWeekday;
}

/*!
  @method defaultCalendar
  
  Returns a shared SBCalendar object which corresponds to the system's default time
  zone.
*/
+ (SBCalendar*) defaultCalendar;
/*!
  @method calendarWithTimeZoneId:
  
  Returns an autoreleased instance of SBCalendar which has been initialized to use the
  provided time zone; valid tzId strings are documented at:
  
    http://icu-project.org/apiref/icu4c/classTimeZone.html
    
*/
+ (SBCalendar*) calendarWithTimeZoneId:(SBString*)tzId;

/*!
  @method initWithTimeZoneId:
  
  Initialize a newly-allocated instance of SBCalendar to use the provided time zone; valid
  tzId strings are documented at:
  
    http://icu-project.org/apiref/icu4c/classTimeZone.html
    
*/
- (id) initWithTimeZoneId:(SBString*)tzId;

/*!
  @method dateFromComponents:
  
  Convert a date provided as components (year, month, day, etc.) to an SBDate object which
  contains a "canonical" numerical representation of the specified date and time.
*/
- (SBDate*) dateFromComponents:(SBDateComponents*)components;
/*!
  @method components:fromDate:
  
  Given an SBDate object which contains a "canonical" numerical representation of a date and
  time, return an SBDateComponents object which contains the requested calendar unit values
  (year, month, day, etc.)  The desired units (from the Calendar units enumeration) should
  be bitwise-ORed and passed as the "mask" argument.
*/
- (SBDateComponents*) components:(unsigned int)mask fromDate:(SBDate*)date;

/*!
  @method setFirstWeekday:
  
  Set which day of the week (relative to UCAL_SUNDAY) should be considered the first day of a
  week in the receiver's calendar.
  
  Note that this behavior is affected by the receiver's minimumDaysInFirstWeek setting.
*/
- (void) setFirstWeekday:(unsigned)weekday;
/*!
  @method firstWeekday
  
  Returns the day of the week (relative to UCAL_SUNDAY) which the receiver's calendar treats as
  the first day of a week.
*/
- (unsigned) firstWeekday;
/*!
  @method setMinimumDaysInFirstWeek:
  
  Set the minimum number of leading days of a month which must be grouped within a "week" (as defined
  by the calendar) in order for that week to be considered part of the month in question.  E.g. if
  mdw is greater than 2 and March begins on a Friday, then March 3 (Sunday) leads the first week of
  March.
  
  Note that this behavior is affected by the receiver's firstWeekday setting.
*/
- (void) setMinimumDaysInFirstWeek:(unsigned)mdw;
/*!
  @method minimumDaysInFirstWeek
  
  Returns the minimum number of days in the first week of a month as set for the receiver's
  calendar.
*/
- (unsigned) minimumDaysInFirstWeek;
/*!
  @method locale
  
  Returns the SBLocale currently being applied to the receiver's calendar.  If the return value
  is nil, then the current default locale is in-use.
*/
- (SBLocale*) locale;
/*!
  @method setLocale:
  
  Set the receiver to use a specific locale in its calendar's computations.
*/
- (void) setLocale:(SBLocale*)locale;

@end

/*!
  @enum SBUndefinedDateComponent
  
  Value which indicates that a specific calendar unit (in an instance of SBDateComponents) is
  not set.
*/
enum {
  SBUndefinedDateComponent = 0x7fffffff
};

/*!
  @class SBDateComponents
  
  A class which wraps the component units that make-up a calendar's reckoning of a date and
  time.  The methods are all pretty well-defined, so I won't document them.
  
  The weekday and weekdayOrdinal fields do bear additional documentation:  weekday correlates
  to UCAL_SUNDAY et al. while weekdayOrdinal correlates to the week within the month, e.g.
  first, second, third.  Together, these two values provide a way to reference the "FIRST SUNDAY"
  or "SECOND TUESDAY" of a month.
*/
@interface SBDateComponents : SBObject
{
  unsigned int      _mask;
  int               _fields[SBMaxCalendarUnit];
}

- (void) setAllComponentsUndefined;

- (int) era;
- (int) year;
- (int) month;
- (int) day;
- (int) hour;
- (int) minute;
- (int) second;
- (int) week;
- (int) weekday;
- (int) weekdayOrdinal;

- (void) setEra:(int)v;
- (void) setYear:(int)v;
- (void) setMonth:(int)v;
- (void) setDay:(int)v;
- (void) setHour:(int)v;
- (void) setMinute:(int)v;
- (void) setSecond:(int)v;
- (void) setWeek:(int)v;
- (void) setWeekday:(int)v;
- (void) setWeekdayOrdinal:(int)v;

@end
