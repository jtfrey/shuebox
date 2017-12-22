//
// SBFoundation : ObjC Class Library for Solaris
// SBRunLoop.h
//
// Class which facilitates multiplexed i/o and time-delayed execution of
// code.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBMutableDictionary, SBArray, SBMutableArray, SBTimer, SBDate, SBTimeInterval;

/*!
  @class SBRunLoop
  @discussion
    Each thread within a process is assigned an instance of SBRunLoop the first time
    the currentRunLoop class method is invoked from within that thread.  The runloop
    manages all timed execution and i/o multiplexing for a thread.
    
    A runloop classifies i/o sources and timers by a mode string.  The default mode
    is accessed by using the SBRunLoopDefaultMode constant.  Modes can be selectively
    targetted when CPU time is given to the runloop; thus, only certain i/o sources
    and timers will be considered for CPU time.
    
    There are essentially two kinds of timed execution which a runloop will perform.
    Instances of SBTimer can be added to a specific mode for a runloop, and will be
    "scheduled" to fire so long as the runloop is given CPU time in that mode.  This
    class also augments SBObject to allow for delayed invocation of a selector on an
    object.
*/
@interface SBRunLoop : SBObject
{
  SBString*               _currentMode;
  SBMutableDictionary*    _timers;
  SBMutableDictionary*    _inputSources;
  SBMutableDictionary*    _outputSources;
  SBMutableArray*         _messageQueue;
  SBMutableArray*         _timedMessageQueue;
  void*                   _inputSourceMap;
  void*                   _outputSourceMap;
  BOOL                    _earlyExit;
}

/*!
  @method currentRunLoop
  @discussion
    Returns the run loop currently in scope in the current thread.
*/
+ (SBRunLoop*) currentRunLoop;
/*!
  @method mainRunLoop
  @discussion
    Returns the primary loop for the current thread.
*/
+ (SBRunLoop*) mainRunLoop;

/*!
  @method addTimer:forMode:
  @discussion
    Schedule aTimer for periodic execution in the receiver runloop when
    the runloop is given time in mode aMode.
*/
- (void) addTimer:(SBTimer*)aTimer forMode:(SBString*)aMode;

/*!
  @method performSelector:target:argument:order:modes:
  @discussion
    Queues the invocation of aSelector on the target object with priority over other
    queued invocations dictated by order:  lower order implies earlier execution.  The selector
    should refer to a void-type method that takes a single argument of type id.
    
    When the receiver runloop gets time in any of the selected modes, it will invoke
    
      [target performSelector:aSelector object:anArgument]
    
    and remove the invocation from the queue.
*/
- (void) performSelector:(SEL)aSelector target:(id)target argument:(id)anArgument order:(SBUInteger)order modes:(SBArray*)modes;
/*!
  @method cancelPerformSelectorsWithTarget:
  @discussion
    Remove all queued invocations for the given target object.
*/
- (void) cancelPerformSelectorsWithTarget:(id)target;
/*!
  @method cancelPerformSelector:target:argument:
  @discussion
    Remove all queued invocations with the specific combination of target, selector, and
    argument to the method.
*/
- (void) cancelPerformSelector:(SEL)aSelector target:(id)target argument:(id)anArgument;

/*!
  @method currentMode
  @discussion
    Returns the string that identifies the current mode in which the receiver is running.
*/
- (SBString*) currentMode;
/*!
  @method limitDateForMode:
  @discussion
    Performs one pass through the receiver runloop in the specified mode and returns the
    date at which the next timer is scheduled to fire.
*/
- (SBDate*) limitDateForMode:(SBString*)mode;
/*!
  @method acceptInputForMode:beforeDate:
  @discussion
    Runs the receiver loop once or until the specified date, accepting input only for the
    specified mode.  If no input sources or timers are attached to the run loop, this method exits
    immediately.
*/
- (void) acceptInputForMode:(SBString*)aMode beforeDate:(SBDate*)endDate;
/*!
  @method run
  @discussion
    Puts the receiver into a permanent loop in SBRunLoopDefaultMode, during which time it processes
    data from all attached input sources.  Timers and queued invocations will also be processed.
*/
- (void) run;
/*!
  @method runUntilDate:
  @discussion
    Similar to the run method but with a terminal date/time specified.
*/
- (void) runUntilDate:(SBDate*)endDate;
/*!
  @method runMode:beforeDate:
  @discussion
    Runs the receiver loop once, blocking for input in the specified mode until a given date.  Timers
    and queue invocations will be processed, as well.
*/
- (BOOL) runMode:(SBString*)mode beforeDate:(SBDate*)endDate;
/*!
  @method setEarlyExit:
  @discussion
    If earlyExit is YES, then the receiver should exit from its loop as soon as possible. 
*/
- (void) setEarlyExit:(BOOL)earlyExit;

@end

/*!
  @category SBObject(SBObjectDelayedPerforming)
  @discussion
    Extensions to SBObject that allow for delayed invocation.
*/
@interface SBObject(SBObjectDelayedPerforming)

/*!
  @method performSelector:withObject:afterDelay:
  @discussion
    Augmented version of performSelector:withObject: that queues the invocation in the current
    runloop to be performed after the given time interval.
*/
- (void) performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(SBTimeInterval*)delay;
/*!
  @method performSelector:withObject:afterDelay:inModes:
  @discussion
    Augmented version of performSelector:withObject: that queues the invocation in the current
    runloop to be performed after the given time interval and only when the current runloop is in
    a mode present in the modes array.
*/
- (void) performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(SBTimeInterval*)delay inModes:(SBArray*)modes;
/*!
  @method cancelPreviousPerformRequestsWithTarget:
  @discussion
    Remove all queue invocations of aTarget from the current runloop.
*/
+ (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget;
/*!
  @method cancelPreviousPerformRequestsWithTarget:selector:object:
  @discussion
    Remove all queue invocations of aSelector on aTarget (with single argument anArgument) from
    the current runloop.
*/
+ (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument;

@end

/*!
  @constant SBRunLoopDefaultMode
  @discussion
    String constant that identifies the default mode for a runloop.
*/
extern SBString* const SBRunLoopDefaultMode;
