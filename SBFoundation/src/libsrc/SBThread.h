//
// SBFoundation : ObjC Class Library for Solaris
// SBThread.h
//
// Class which wraps an Objective-C thread of execution.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBException.h"
#import "SBAutoreleasePool.h"
#import "SBDate.h"

#include <pthread.h>

@class SBMutableDictionary;

/*!
  @typedef SBAutoreleaseState
  @discussion
    Per-thread autorelease state gets added to SBThread instances using
    this data structure.  Don't ever touch it!
*/
typedef struct {
  SBAutoreleasePool*  cache;
  SBAutoreleasePool*  current;
  BOOL                threadInDealloc;
} SBAutoreleaseState;

/*!
  @class SBThread
  @discussion
    Instances of SBThread represent a separate thread of execution
    within a process.
    
    There are two methods by which threads are created.  The old-school
    method is to use the detachNewThreadSelector:toTarget:withObject:
    class method to invoke the specified method of the target object
    in a separate thread of execution.  No SBThread is returned, so you
    have no control over the thread.
    
    The modern alternative is to subclass SBThread, overriding the
    threadMain and hasBeenCancelled methods; chain your init... methods
    to SBThread's init method.  When the object is ready to execute,
    send the start method to it.
*/
@interface SBThread : SBObject
{
  SBString*             _identifier;
  SBMutableDictionary*  _properties;
  id                    _target;
  SEL                   _selector;
  id                    _argument;
  SBUInteger            _state;
  pthread_t             _nativeThread;
  int                   _lastSignalCaught;
  
@public
  SBExceptionState*     _exceptionState;
  SBAutoreleaseState    _autoreleaseState;
}

/*!
  @method currentThread
  @discussion
    Returns the SBThread in which the caller is executing.
*/
+ (SBThread*) currentThread;

/*!
  @method mainThread
  @discussion
    Returns the SBThread that represents the main program entry point.
*/
+ (SBThread*) mainThread;

/*!
  @method detachNewThreadSelector:toTarget:withObject:
  @discussion
    Creates a new thread in which the given message (aSelector) will be
    sent to aTarget.  The method in question should have no return value
    and should accept a single argument of type id:
    
      - (void) threadedEntryPoint:(id)argument
      
    The method will execute concurrently in a separate thread; control returns
    immediately to the caller in the original thread.
    
    The new thread is anonymous and cannot directly be controlled by other
    threads.  It runs to completion or the termination of the owning process.
*/
+ (void) detachNewThreadSelector:(SEL)aSelector toTarget:(id)aTarget withObject:(id)anObject;

/*!
  @method isMultiThreaded
  @discussion
    Returns YES if any SBThreads have been created by the process (ever).
*/
+ (BOOL) isMultiThreaded;

/*!
  @method isMainThread
  @discussion
    Returns YES if the thread in which the caller is executing is the process's
    main thread of execution.
*/
+ (BOOL) isMainThread;

/*!
  @method exit
  @discussion
    Force the caller's thread of execution to terminate.  This method has no
    effect on the process's main thread.

    If you attempt to exit the process's main thread an SBException will be
    raised.
*/
+ (void) exit;

/*!
  @method sleepForTimeInterval:
  @discussion
    Attempts to force the thread in which the caller is running to halt
    execution for the given time interval.
    
    This method may return early if the thread was cancelled.
*/
+ (void) sleepForTimeInterval:(SBTimeInterval*)anInterval;

/*!
  @method sleepForTimeInterval:
  @discussion
    Attempts to force the thread in which the caller is running to halt
    execution until the specified date and time.
    
    This method may return early if the thread was cancelled.
*/
+ (void) sleepUntilDate:(SBDate*)aDate;

/*!
  @method init
  @discussion
    Designated initializer for this class.  The resulting SBThread will be sent
    the threadMain message on a different thread of execution when it is sent
    the start message.
*/
- (id) init;

/*!
  @method initWithTarget:selector:object:
  @discussion
    Initializes a new instance of SBThread.  When the thread is sent the start
    message, the aSelector message will be sent to aTarget (with a single argument
    of anObject).
    
    The method aSelector is responsible for setting up an autorelease pool for the
    newly detached thread and freeing that pool before it exits.  If you can
    guarantee that no objects will be created and autoreleased within the context
    of aSelector, then no pool is necessary.
*/
- (id) initWithTarget:(id)aTarget selector:(SEL)aSelector object:(id)anObject;

/*!
  @method lastSignalCaught
  @discussion
    Returns the last signal seen by the receiver thread.
*/
- (int) lastSignalCaught;

/*!
  @method respondsToSignals:
  @discussion
    Fills-in signals with the current signals to which the receiver thread
    responds.
*/
- (void) respondsToSignals:(sigset_t*)signals;

/*!
  @method setRespondsToSignals:
  @discussion
    Sets the receiver thread's signal mask and signal handlers such that all
    those signals set in the signals sigset will be caught and noted for
    later introspection via the lastCaughtSignal method.
*/
- (BOOL) setRespondsToSignals:(sigset_t*)signals;

/*!
  @method kill:
  @discussion
    Send the specified signal to the receiver thread.
*/
- (void) kill:(int)signalId;

/*!
  @method cancel
  @discussion
    Attempt to cancel the receiver's thread of exection.  If successful the thread
    terminates early.  The hasBeenCancelled method can be overridden to provide
    subclasses with a chance to cleanup before their thread is destroyed.
*/
- (void) cancel;

/*!
  @method start
  @discussion
    This method spawns a new thread and invokes the receiver’s threadMain method in the
    new thread.  If you initialized the receiver with a target and selector, the default
    threadMain method invokes that selector automatically.

    If this thread is the first thread detached in the application, this method posts the
    SBWillBecomeMultiThreadedNotification to the default notification center.
*/
- (void) start;

/*!
  @method threadMain
  @discussion
    The default implementation of this method takes the target and selector used to initialize
    the receiver and invokes the selector on the specified target.  If you subclass SBThread
    you can override this method and use it to implement the main body of your thread instead.
    If you do so, you do not need to chain to SBThread's implementation.

    You should never invoke this method directly.  You should always start your thread by invoking
    the start method.
*/
- (void) threadMain;

/*!
  @method identifier
  @discussion
    Returns the textual identifier assigned to the receiver.
*/
- (SBString*) identifier;

/*!
  @method setIdentifier:
  @discussion
    Assigns a textual identifier to the receiver.
*/
- (void) setIdentifier:(SBString*)identifier;

/*!
  @method properties
  @discussion
    Use the returned dictionary to store thread-specific data.  The thread dictionary is not used
    during any manipulations of the SBThread object — it is simply a place where you can store
    any interesting data.
*/
- (SBMutableDictionary*) properties;

/*!
  @method isMainThread
  @discussion
    Returns YES if the receiver is the process's main thread of execution.
*/
- (BOOL) isMainThread;

/*!
  @method isExecuting
  @discussion
    Returns YES if the receiver thread is currently executing.
*/
- (BOOL) isExecuting;

/*!
  @method isCancelled
  @discussion
    Returns YES if the receiver thread has been cancelled but has not yet
    finished cleaning-up.
*/
- (BOOL) isCancelled;

/*!
  @method isFinished
  @discussion
    Returns YES if the receiver thread has completed execution.
*/
- (BOOL) isFinished;

/*!
  @method hasBeenCancelled
  @discussion
    Subclasses should override this method if they require any cleanup
    after a thread has been prematurely cancelled.
*/
- (void) hasBeenCancelled;

@end

/*!
  @constant SBWillBecomeMultiThreadedNotification
  @discussion
    Name of the notification delivered to the default notification center when
    the program first spawns a new SBThread.
*/
extern SBString* SBWillBecomeMultiThreadedNotification;

/*!
  @constant SBThreadWillExitNotification
  @discussion
    Name of the notification delivered to the default notification center when
    an SBThread is about to terminate.
*/
extern SBString* SBThreadWillExitNotification;
