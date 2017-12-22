//
// SBFoundation : ObjC Class Library for Solaris
// SBCalendar.m
//
// Calendar date/time utilities thanks to ICU.
//
// $Id$
//

#import "SBCalendar.h"
#import "SBDate.h"
#import "SBString.h"
#import "SBLocale.h"

int __SBCalendarICUFieldMappings[] = {
                                    UCAL_ERA,
                                    UCAL_YEAR,
                                    UCAL_MONTH,
                                    UCAL_DAY_OF_MONTH,
                                    UCAL_HOUR_OF_DAY,
                                    UCAL_MINUTE,
                                    UCAL_SECOND,
                                    UCAL_ZONE_OFFSET,
                                    UCAL_WEEK_OF_YEAR,
                                    UCAL_DAY_OF_WEEK,
                                    UCAL_DAY_OF_WEEK_IN_MONTH
                                  };

static int __SBFieldNumForMask(
  unsigned int    mask
)
{
  int     i = 0;
  
  if ( mask ) {
    while ( mask != 1 ) {
      mask >>= 1;
      i++;
    }
  }
  return i;
}

@interface SBDateComponents(SBDateComponentsPrivate)

- (BOOL) getFields:(unsigned int)mask fromICUCalendar:(UCalendar*)icuCalendar;
- (void) setICUCalendarFromFields:(UCalendar*)icuCalendar;

@end

@implementation SBDateComponents(SBDateComponentsPrivate)

  - (BOOL) getFields:(unsigned int)mask
    fromICUCalendar:(UCalendar*)icuCalendar
  {
    int           i;
    
    _mask = 0;
    for ( i = 0 ; i < SBMaxCalendarUnit ; i++ ) {
      if ( mask & (1 << i) ) {
        UErrorCode  icuErr = U_ZERO_ERROR;
        int32_t     v = ucal_get(icuCalendar, __SBCalendarICUFieldMappings[i], &icuErr);
        
        if ( U_FAILURE(icuErr) )
          return NO;
        
        _fields[i] = v;
        _mask |= (1 << i);
      }
    }
    
    return YES;
  }
  
//

  - (void) setICUCalendarFromFields:(UCalendar*)icuCalendar
  {
    int     i;
    
    ucal_clear(icuCalendar);
    for ( i = 0 ; i < SBMaxCalendarUnit ; i++ ) {
      if ( _mask & (1 << i) ) {
        
        ucal_set(icuCalendar, __SBCalendarICUFieldMappings[i], _fields[i]);
      }
    }
  }

@end

//
#pragma mark -
//

@implementation SBDateComponents

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  era: %d\n"
        "  year: %d\n"
        "  month: %d\n"
        "  day: %d\n"
        "  hour: %d\n"
        "  minute: %d\n"
        "  second: %d\n"
        "  tz-offset: %d\n"
        "  week: %d\n"
        "  weekday: %d\n"
        "  weekday (ordinal): %d\n"
        "}\n",
        [self era],
        [self year],
        [self month],
        [self day],
        [self hour],
        [self minute],
        [self second],
        [self timeZoneOffset],
        [self week],
        [self weekday],
        [self weekdayOrdinal]
      );
  }

//

  - (void) setAllComponentsUndefined
  {
    _mask = 0;
  }

//

  - (int) era
  {
    if ( _mask & SBEraCalendarUnit )
      return _fields[__SBFieldNumForMask(SBEraCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) year
  {
    if ( _mask & SBYearCalendarUnit )
      return _fields[__SBFieldNumForMask(SBYearCalendarUnit)];
    return SBUndefinedDateComponent;
  }

//

  - (int) month
  {
    if ( _mask & SBMonthCalendarUnit )
      return _fields[__SBFieldNumForMask(SBMonthCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) day
  {
    if ( _mask & SBDayCalendarUnit )
      return _fields[__SBFieldNumForMask(SBDayCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) hour
  {
    if ( _mask & SBHourCalendarUnit )
      return _fields[__SBFieldNumForMask(SBHourCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) minute
  {
    if ( _mask & SBMinuteCalendarUnit )
      return _fields[__SBFieldNumForMask(SBMinuteCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) second
  {
    if ( _mask & SBSecondCalendarUnit )
      return _fields[__SBFieldNumForMask(SBSecondCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) timeZoneOffset
  {
    if ( _mask & SBTimeZoneOffsetCalendarUnit )
      return _fields[__SBFieldNumForMask(SBTimeZoneOffsetCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) week
  {
    if ( _mask & SBWeekCalendarUnit )
      return _fields[__SBFieldNumForMask(SBWeekCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) weekday
  {
    if ( _mask & SBWeekdayCalendarUnit )
      return _fields[__SBFieldNumForMask(SBWeekdayCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (int) weekdayOrdinal
  {
    if ( _mask & SBWeekdayOrdinalCalendarUnit )
      return _fields[__SBFieldNumForMask(SBWeekdayOrdinalCalendarUnit)];
    return SBUndefinedDateComponent;
  }
  
//

  - (void) setEra:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBEraCalendarUnit;
    } else {
      _mask |= SBEraCalendarUnit;
      _fields[__SBFieldNumForMask(SBEraCalendarUnit)] = v;
    }
  }
  
//

  - (void) setYear:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBYearCalendarUnit;
    } else {
      _mask |= SBYearCalendarUnit;
      _fields[__SBFieldNumForMask(SBYearCalendarUnit)] = v;
    }
  }
  
//

  - (void) setMonth:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBMonthCalendarUnit;
    } else {
      _mask |= SBMonthCalendarUnit;
      _fields[__SBFieldNumForMask(SBMonthCalendarUnit)] = v;
    }
  }
  
//

  - (void) setDay:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBDayCalendarUnit;
    } else {
      _mask |= SBDayCalendarUnit;
      _fields[__SBFieldNumForMask(SBDayCalendarUnit)] = v;
    }
  }
  
//

  - (void) setHour:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBHourCalendarUnit;
    } else {
      _mask |= SBHourCalendarUnit;
      _fields[__SBFieldNumForMask(SBHourCalendarUnit)] = v;
    }
  }
  
//

  - (void) setMinute:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBMinuteCalendarUnit;
    } else {
      _mask |= SBMinuteCalendarUnit;
      _fields[__SBFieldNumForMask(SBMinuteCalendarUnit)] = v;
    }
  }
  
//

  - (void) setSecond:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBSecondCalendarUnit;
    } else {
      _mask |= SBSecondCalendarUnit;
      _fields[__SBFieldNumForMask(SBSecondCalendarUnit)] = v;
    }
  }
  
//

  - (void) setTimeZoneOffset:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBTimeZoneOffsetCalendarUnit;
    } else {
      _mask |= SBTimeZoneOffsetCalendarUnit;
      _fields[__SBFieldNumForMask(SBTimeZoneOffsetCalendarUnit)] = v;
    }
  }
  
//

  - (void) setWeek:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBWeekCalendarUnit;
    } else {
      _mask |= SBWeekCalendarUnit;
      _fields[__SBFieldNumForMask(SBWeekCalendarUnit)] = v;
    }
  }
  
//

  - (void) setWeekday:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBWeekdayCalendarUnit;
    } else {
      _mask |= SBWeekdayCalendarUnit;
      _fields[__SBFieldNumForMask(SBWeekdayCalendarUnit)] = v;
    }
  }
  
//

  - (void) setWeekdayOrdinal:(int)v
  {
    if ( v == SBUndefinedDateComponent ) {
      _mask &= ~SBWeekdayOrdinalCalendarUnit;
    } else {
      _mask |= SBWeekdayOrdinalCalendarUnit;
      _fields[__SBFieldNumForMask(SBWeekdayOrdinalCalendarUnit)] = v;
    }
  }

//

  - (BOOL) isDateOnly
  {
    // The era may or may not be set, we really don't care:
    return ( (_mask | SBEraCalendarUnit) == SBDateCalendarUnits );
  }
  
//

  - (BOOL) isTimeOnly
  {
    // The time zone offset may or may not be set, we really don't care:
    return ( (_mask | SBTimeZoneOffsetCalendarUnit) == SBTimeCalendarUnits );
  }

@end

//
#pragma mark -
//

@interface SBCalendar(SBCalendarPrivate)

- (BOOL) setupCalendar;

@end

@implementation SBCalendar(SBCalendarPrivate)

  - (BOOL) setupCalendar
  {
    UErrorCode    icuErr = U_ZERO_ERROR;
    
    _icuCalendar = ucal_open(
                        ( _tzId ? [_tzId utf16Characters] : NULL ),
                        ( _tzId ? [_tzId length] : 0 ),
                        ( _locale ? [_locale localeIdentifier] : NULL ),
                        UCAL_TRADITIONAL,
                        &icuErr
                      );
    if ( U_SUCCESS(icuErr) ) {
      if ( _minDaysInFirstWeek != SBUndefinedDateComponent )
        [self setMinimumDaysInFirstWeek:_minDaysInFirstWeek];
      else
        _minDaysInFirstWeek = ucal_getAttribute(_icuCalendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK);
        
      if ( _firstWeekday != SBUndefinedDateComponent )
        [self setFirstWeekday:_firstWeekday];
      else
        _firstWeekday = ucal_getAttribute(_icuCalendar, UCAL_FIRST_DAY_OF_WEEK);
        
      return YES;
    }
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBCalendar

  + (SBCalendar*) defaultCalendar
  {
    static SBCalendar*    __SBDefaultCalendar = nil;
    
    if ( __SBDefaultCalendar == nil ) {
      __SBDefaultCalendar = [[SBCalendar alloc] init];
    }
    return __SBDefaultCalendar;
  }
  
//
    
  + (SBCalendar*) calendarWithTimeZoneId:(SBString*)tzId
  {
    return [[[SBCalendar alloc] initWithTimeZoneId:tzId] autorelease];
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
      _firstWeekday = _minDaysInFirstWeek = 0x7fffffff;
    }
    return self;
  }

//

  - (id) initWithTimeZoneId:(SBString*)tzId
  {
    if ( self = [self init] ) {
      if ( tzId )
        _tzId = [tzId copy];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _icuCalendar ) ucal_close(_icuCalendar);
    if ( _tzId ) [_tzId release];
    [super dealloc];
  }

//

  - (SBDate*) dateFromComponents:(SBDateComponents*)components
  {
    //
    // Attempt to set our calendar's components:
    //
    UErrorCode      icuErr = U_ZERO_ERROR;
    UDate           icuDate;
    
    if ( ! _icuCalendar && ! [self setupCalendar] )
      return nil;
    
    [components setICUCalendarFromFields:_icuCalendar];
    icuDate = ucal_getMillis(_icuCalendar, &icuErr);
    if ( U_SUCCESS(icuErr) ) {
      return [SBDate dateWithICUDate:icuDate];
    }
    return nil;
  }
  
//

  - (SBDateComponents*) components:(unsigned int)mask
    fromDate:(SBDate*)date
  {
    SBDateComponents*   parts = nil;
    
    if ( ! _icuCalendar && ! [self setupCalendar] )
      return nil;
    
    if ( ( parts = [[SBDateComponents alloc] init] ) ) {
      UErrorCode        icuErr = U_ZERO_ERROR;
      
      ucal_setMillis(_icuCalendar, [date icuDate], &icuErr);
      if ( U_SUCCESS(icuErr) && [parts getFields:mask fromICUCalendar:_icuCalendar] )
        return [parts autorelease];
      [parts release];
    }
    return nil;
  }

//

  - (void)setFirstWeekday:(unsigned)weekday
  {
    _firstWeekday = weekday;
    if ( _icuCalendar )
      ucal_setAttribute(_icuCalendar, UCAL_FIRST_DAY_OF_WEEK, (int32_t)weekday);
  }
  
//

  - (unsigned)firstWeekday
  {
    if ( _icuCalendar )
      return (unsigned)ucal_getAttribute(_icuCalendar, UCAL_FIRST_DAY_OF_WEEK);
    return _firstWeekday;
  }
  
//

  - (void) setMinimumDaysInFirstWeek:(unsigned)mdw
  {
    _minDaysInFirstWeek = mdw;
    if ( _icuCalendar )
      ucal_setAttribute(_icuCalendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, (int32_t)mdw);
  }
  
//

  - (unsigned) minimumDaysInFirstWeek
  {
    if ( _icuCalendar )
      return (unsigned)ucal_getAttribute(_icuCalendar, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK);
    return _minDaysInFirstWeek;
  }

//

  - (SBLocale*) locale
  {
    return _locale;
  }
  - (void) setLocale:(SBLocale*)locale
  {
    if ( locale ) locale = [locale retain];
    if ( _locale ) [_locale release];
    _locale = locale;
    
    if ( _icuCalendar ) {
      ucal_close(_icuCalendar);
      _icuCalendar = NULL;
    }
  }

//

  - (int) defaultGMTOffset
  {
    UErrorCode      icuErr = U_ZERO_ERROR;
    UDate           icuDate;
    
    if ( ! _icuCalendar && ! [self setupCalendar] )
      return 0;
    ucal_setMillis(_icuCalendar, ucal_getNow(), &icuErr);
    if ( U_SUCCESS(icuErr) ) {
      return ( ucal_get(_icuCalendar, UCAL_ZONE_OFFSET, &icuErr) + ucal_get(_icuCalendar, UCAL_DST_OFFSET, &icuErr));
    }
    return 0;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    const char*     localeId = ( _locale ? [_locale localeIdentifier] : "<system>" );
    
    [super summarizeToStream:stream];
    fprintf(stream,
            " {\n"
            "  locale: %s\n"
            "  timezone: %s\n"
            "  mdw: %u\n"
            "  fwd: %u\n"
            "}\n",
            localeId,
            ( _tzId ? (const char*)[_tzId utf8Characters] : "<default>" ),
            _minDaysInFirstWeek,
            _firstWeekday
          );
  }
  
@end
