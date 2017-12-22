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
    "scheduled" to fire so long as the runloop is given CPU time in that mode.  Delayed
    
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
}

+ (SBRunLoop*) currentRunLoop;
+ (SBRunLoop*) mainRunLoop;

- (void) addTimer:(SBTimer*)aTimer forMode:(SBString*)aMode;

- (void) performSelector:(SEL)aSelector target:(id)target argument:(id)anArgument order:(unsigned)order modes:(SBArray*)modes;
- (void) cancelPerformSelectorsWithTarget:(id)target;
- (void) cancelPerformSelector:(SEL)aSelector target:(id)target argument:(id)anArgument;

- (SBString*) currentMode;

- (SBDate*) limitDateForMode:(SBString*)mode;

- (void) acceptInputForMode:(SBString*)aMode beforeDate:(SBDate*)endDate;

- (void) run;
- (void) runUntilDate:(SBDate*)endDate;
- (BOOL) runMode:(SBString*)mode beforeDate:(SBDate*)endDate;

@end

@interface SBObject(SBObjectDelayedPerforming)

- (void) performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(SBTimeInterval*)delay;
- (void) performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(SBTimeInterval*)delay inModes:(SBArray*)modes;

+ (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget;
+ (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anArgument;

@end

extern SBString* const SBRunLoopDefaultMode;
