//
// SBFoundation : ObjC Class Library for Solaris
// SBTimeZone.m
//
// Time zone management, thanks to ICU.
//
// $Id$
//

#import "SBTimeZone.h"
#import "SBString.h"

static SBTimeZone* __SBUTCTimeZoneSharedInstance = nil;
static SBTimeZone* __SBDefaultTimeZoneSharedInstance = nil;

@implementation SBTimeZone

  + (SBTimeZone*) defaultTimeZone
  {
    if ( __SBDefaultTimeZoneSharedInstance == nil ) {
      __SBDefaultTimeZoneSharedInstance = [[SBTimeZone alloc] initWithTimeZoneIdentifier:nil];
    }
    return __SBDefaultTimeZoneSharedInstance;
  }

//

  + (SBTimeZone*) utcTimeZone
  {
    if ( __SBUTCTimeZoneSharedInstance == nil ) {
      __SBUTCTimeZoneSharedInstance = [[SBTimeZone alloc] initWithTimeZoneIdentifier:@"UTC"];
    }
    return __SBUTCTimeZoneSharedInstance;
  }

//

  - (id) initWithTimeZoneIdentifier:(SBString*)timeZoneId
  {
    if ( self = [super init] ) {
      SBUInteger    tzLen = 0;
      
      if ( timeZoneId && (tzLen = [timeZoneId length]) ) {
        _timeZoneIdentifier = objc_malloc(sizeof(UChar) * (tzLen + 1));
        [timeZoneId copyCharactersToBuffer:_timeZoneIdentifier length:tzLen + 1];
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _timeZoneIdentifier ) objc_free(_timeZoneIdentifier);
    [super dealloc];
  }
  
//

  - (UChar*) timeZoneIdentifier
  {
    return _timeZoneIdentifier;
  }
  
@end
