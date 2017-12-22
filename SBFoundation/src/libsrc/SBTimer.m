//
// SBFoundation : ObjC Class Library for Solaris
// SBTimer.m
//
// Class which facilitates delayed execution.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBTimer.h"
#import "SBDate.h"
#import "SBRunLoop.h"
#import "SBDateFormatter.h"
#import "SBString.h"

@implementation SBTimer

  + (SBTimer*) scheduledTimerWithFireDate:(SBDate*)aDate
    target:(id)target
    selector:(SEL)selector
    userInfo:(id)userInfo
  {
    SBTimer*    newTimer = [[[SBTimer alloc] initWithFireDate:aDate interval:nil target:target selector:selector userInfo:userInfo repeats:NO] autorelease];
    
    [[SBRunLoop currentRunLoop] addTimer:newTimer forMode:SBRunLoopDefaultMode];
    return newTimer;
  }
  
//

  + (SBTimer*) scheduledTimerWithTimeInterval:(SBTimeInterval*)theTimeInterval
    target:(id)target
    selector:(SEL)selector
    userInfo:(id)userInfo
    repeats:(BOOL)repeats
  {
    SBTimer*    newTimer = [[[SBTimer alloc] initWithFireDate:nil interval:theTimeInterval target:target selector:selector userInfo:userInfo repeats:repeats] autorelease];
    
    [[SBRunLoop currentRunLoop] addTimer:newTimer forMode:SBRunLoopDefaultMode];
    return newTimer;
  }
  
//

  + (SBTimer*) timerWithFireDate:(SBDate*)aDate
    target:(id)target
    selector:(SEL)selector
    userInfo:(id)userInfo
  {
    return [[[SBTimer alloc] initWithFireDate:aDate interval:nil target:target selector:selector userInfo:userInfo repeats:NO] autorelease];
  }
  
//

  + (SBTimer*) timerWithTimeInterval:(SBTimeInterval*)theTimeInterval
    target:(id)target
    selector:(SEL)selector
    userInfo:(id)userInfo
    repeats:(BOOL)repeats
  {
    return [[[SBTimer alloc] initWithFireDate:nil interval:theTimeInterval target:target selector:selector userInfo:userInfo repeats:repeats] autorelease];
  }
  
//

  - (id) initWithFireDate:(SBDate*)aDate
    interval:(SBTimeInterval*)theTimeInterval
    target:(id)target
    selector:(SEL)selector
    userInfo:(id)userInfo
    repeats:(BOOL)repeats
  {
    if ( (aDate || theTimeInterval) && (self = [super init]) ) {
      _target = [target retain];
      _selector = selector;
      _userInfo = [userInfo retain];
        
      // If we were given a fire date, then we'll fire at that time
      // and possibly continue to reschedule (if an interval was provided
      // and repeats is YES)
      if ( aDate ) {
        if ( theTimeInterval && repeats )
          _timeInterval = [theTimeInterval retain];
        [self setFireDate:aDate];
      } else {
        // No actual date, use the time interval relative to now.  If
        // we are to repeat, then retain the time interval, too:
        if ( repeats )
          _timeInterval = [theTimeInterval retain];
        aDate = [[SBDate alloc] initWithSecondsSinceNow:[_timeInterval totalSecondsInTimeInterval]];
        [self setFireDate:aDate];
        [aDate release];
      }
    } else {
      [self release];
      self = nil;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    [self invalidate];
    if ( _target ) [_target release];
    if ( _userInfo ) [_userInfo release];
    if ( _fireDate ) [_fireDate release];
    if ( _timeInterval ) [_timeInterval release];
    [super dealloc];
  }

//

  - (SBTimeInterval*) timeInterval { return _timeInterval; }
  - (SBDate*) fireDate { return _fireDate; }
  - (void) setFireDate:(SBDate*)fireDate
  {
    if ( fireDate ) fireDate = [fireDate retain];
    if ( _fireDate ) [_fireDate release];
    _fireDate = fireDate;
    _isValid = YES;
    
    if ( [[SBDate dateWhichIsAlwaysNow] earlierDate:_fireDate] == _fireDate )
      // Fire now and reschedule:
      [self fire];
  }

//

  - (id) userInfo { return _userInfo; }

//

  - (BOOL) isValid
  {
    return _isValid;
  }
  
//

  - (void) invalidate
  {
    _isValid = NO;
    if ( _fireDate ) {
      [_fireDate release];
      _fireDate = nil;
    }
    if ( _timeInterval ) {
      [_timeInterval release];
      _timeInterval = nil;
    }
  }
  
//

  - (void) fire
  {
    if ( _isValid ) {
      // Make it invalid now if not repeating:
      if ( ! _timeInterval )
        _isValid = NO;
      
      // Do the action:
      [_target perform:_selector with:self];
    
      // Move forward from the fire date by steps of _timeInterval
      // until we have a time later than now:
      if ( _isValid) {
        SBDate*       nextFireDate = [[SBDate alloc] initWithTimeInterval:_timeInterval sinceDate:_fireDate];
        
        while ( 1 ) {
          if ( [[SBDate dateWhichIsAlwaysNow] earlierDate:nextFireDate] == nextFireDate ) {
            SBDate*   nextNextFireDate = [[SBDate alloc] initWithTimeInterval:_timeInterval sinceDate:nextFireDate];
            
            [nextFireDate release];
            nextFireDate = nextNextFireDate;
          } else {
            break;
          }
        }
        [_fireDate release];
        _fireDate = nextFireDate;
      }
    }
  }

@end
