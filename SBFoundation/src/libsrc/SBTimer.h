//
// SBFoundation : ObjC Class Library for Solaris
// SBTimer.h
//
// Class which facilitates delayed execution.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBDate, SBTimeInterval;

/*!
  @class SBTimer
  @discussion
    You use the SBTimer class to create timer objects or, more simply, timers.  A timer waits until a certain time
    interval has elapsed and then fires, sending a specified message to a target object.
    
    Timers work in conjunction with run loops.  To use a timer effectively, you should be aware of how run loops
    operate — see SBRunLoop.  Note in particular that run loops retain their timers, so you can release a timer
    after you have added it to a run loop.
    
    A timer is not a real-time mechanism; it fires only when one of the run loop modes to which the timer has been
    added is running and able to check if the timer’s firing time has passed.  Because of the various input sources
    a typical run loop manages, the effective resolution of the time interval for a timer is limited.  If a timer’s
    firing time occurs during a long callout or while the run loop is in a mode that is not monitoring the timer,
    the timer does not fire until the next time the run loop checks the timer.  Therefore, the actual time at which
    the timer fires potentially can be a significant period of time after the scheduled firing time.
    
    REPEATING TIMERS
    
    You specify whether a timer is repeating or non-repeating at creation time.  A non-repeating timer fires once and
    then invalidates itself automatically, thereby preventing the timer from firing again.  By contrast, a repeating
    timer fires and then reschedules itself on the same run loop.
    
    A repeating timer always schedules itself based on the scheduled firing time, as opposed to the actual firing time.
    For example, if a timer is scheduled to fire at a particular time and every 5 seconds after that, the scheduled
    firing time will always fall on the original 5 second time intervals, even if the actual firing time gets delayed.
    If the firing time is delayed so far that it passes one or more of the scheduled firing times, the timer is fired
    only once for that time period; the timer is then rescheduled, after firing, for the next scheduled firing time in
    the future.
*/
@interface SBTimer : SBObject
{
  SBTimeInterval*     _timeInterval;
  SBDate*             _fireDate;
  
  id                  _target;
  SEL                 _selector;
  id                  _userInfo;
  
  BOOL                _isValid;
}

/*!
  @method scheduledTimerWithFireDate:target:selector:userInfo:
  @discussion
    Returns an autoreleased instance scheduled in the current runloop that will fire on the specified date, invoking
    the given selector on the target object.
*/
+ (SBTimer*) scheduledTimerWithFireDate:(SBDate*)aDate target:(id)target selector:(SEL)selector userInfo:(id)userInfo;
/*!
  @method scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:
  @discussion
    Returns an autoreleased instance scheduled in the current runloop that will fire after the given time interval,
    invoking the given selector on the target object.  If repeats is YES, the timer will repeatedly fire on the given
    time interval.
*/
+ (SBTimer*) scheduledTimerWithTimeInterval:(SBTimeInterval*)theTimeInterval target:(id)target selector:(SEL)selector userInfo:(id)userInfo repeats:(BOOL)repeats;
/*!
  @method timerWithFireDate:target:selector:userInfo:
  @discussion
    Returns an autoreleased instance that will fire on the specified date, invoking the given selector on the target
    object.
*/
+ (SBTimer*) timerWithFireDate:(SBDate*)aDate target:(id)target selector:(SEL)selector userInfo:(id)userInfo;
/*!
  @method timerWithTimeInterval:target:selector:userInfo:repeats:
  @discussion
    Returns an autoreleased instance that will fire after the given time interval, invoking the given selector on the
    target object.  If repeats is YES, the timer will repeatedly fire on the given time interval.
*/
+ (SBTimer*) timerWithTimeInterval:(SBTimeInterval*)theTimeInterval target:(id)target selector:(SEL)selector userInfo:(id)userInfo repeats:(BOOL)repeats;

/*!
  @method initWithFireDate:interval:target:selector:userInfo:repeats:
  @discussion
    Initializes the receiver to invoke the method indicated by selector on target; the method must take a single argument of
    type id:
    
      - (void) methodFiredByTimer:(id)argument
    
    If aDate is not nil, then the invocation will happen on or after that date and time.  If theTimeInterval is also not
    nil and repeats is YES, then the receiver will reschedule on that interval forward from aDate.
    
    If aDate is nil, then theTimeInterval must be non-nil.  The firing date is calculated by adding theTimeInterval to the
    current date and time, and the value of repeats indicates whether or not the receiver fires once or periodically.
    
    The target and userInfo objects are retained by the receiver.
*/
- (id) initWithFireDate:(SBDate*)aDate interval:(SBTimeInterval*)theTimeInterval target:(id)target selector:(SEL)selector userInfo:(id)userInfo repeats:(BOOL)repeats;

/*!
  @method fireDate
  @discussion
    Returns the date and time at which the receiver will next fire.
*/
- (SBDate*) fireDate;

/*!
  @method setFireDate:
  @discussion
    If the timer has not been invalidated, changes the date and time at which
    the receiver will next fire.  If fireDate has passed, then the receiver
    fires immediately and reschedules if set to repeat.
*/
- (void) setFireDate:(SBDate*)fireDate;

/*!
  @method timeInterval
  @discussion
    Returns the time interval used by the receiver when rescheduling itself after
    firing.  Returns nil if the receiver does not repeat.
*/
- (SBTimeInterval*) timeInterval;

/*!
  @method userInfo
  @discussion
    Returns the user-specified "additional info" object passed to the receiver when it was created.
*/
- (id) userInfo;

/*!
  @method isValid
  @discussion
    Returns YES if the receiver is currently scheduled to fire at some time in the future.
*/
- (BOOL) isValid;

/*!
  @method invalidate
  @discussion
    Immediately mark the receiver as no longer scheduled and prevent it from firing again.
*/
- (void) invalidate;

/*!
  @method fire
  @discussion
    If the receiver is scheduled, fire it immediately (regardless of the scheduled time) and
    reschedule if it repeates.
*/
- (void) fire;

@end
