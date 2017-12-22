//
// SBFoundation : ObjC Class Library for Solaris
// SBThread.m
//
// Class which wraps an Objective-C thread of execution.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBThread.h"
#import "SBRunLoop.h"
#import "SBAutoreleasePool.h"
#import "SBLock.h"
#import "SBNotification.h"

//

static pthread_key_t          __SBThreadObjectKey;
static BOOL                   __SBThreadHasGoneMultithreaded = NO;
static SBThread*              __SBThreadMainThread = nil;

//

SBString* SBWillBecomeMultiThreadedNotification = @"SBWillBecomeMultiThreadedNotification";
SBString* SBThreadWillExitNotification = @"SBThreadWillExitNotification";

//

enum {
  SBThreadNotRunning = 0,
  SBThreadIsExecuting,
  SBThreadIsCancelled,
  SBThreadIsFinished
};

//

@interface SBThread(SBThreadPrivate)

- (void) setLastSignalCaught:(int)sigmask;
- (void) setState:(unsigned int)state;
- (void*) startThread;
- (void) sleepUntilDate:(SBDate*)aDate;

@end

//

void
__SBThreadCancelCleanup(
  void*     aThread
)
{
  [(SBThread*)aThread setState:SBThreadIsFinished];
  [(SBThread*)aThread hasBeenCancelled];
}

//

void
__SBThreadSignalHandler(
  int       sigmask
)
{
  struct sigaction      action;
  
  [[SBThread currentThread] setLastSignalCaught:sigmask];
  action.sa_handler = __SBThreadSignalHandler;
  sigaction(sigmask, &action, NULL);
}

//

@implementation SBThread(SBThreadPrivate)

  - (void) setLastSignalCaught:(int)sigmask
  {
    _lastSignalCaught = sigmask;
  }

//

  - (void) setState:(unsigned int)state
  {
    _state = state;
  }

//

  - (void*) startThread
  {
    // Have we gone multithreaded for the first time?
    [SBGlobalLock lock];
    if ( ! __SBThreadHasGoneMultithreaded ) {
      __SBThreadHasGoneMultithreaded = YES;
      [SBGlobalLock unlock];
      [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBWillBecomeMultiThreadedNotification object:self userInfo:nil];
    } else {
      [SBGlobalLock unlock];
    }
    
    _state = SBThreadIsExecuting;
    
    // Stash a reference to ourself in the thread-specific data:
    pthread_setspecific(__SBThreadObjectKey, self);
    
    // Set cancelability:
    pthread_setcanceltype(_nativeThread, PTHREAD_CANCEL_DEFERRED);
    pthread_setcancelstate(_nativeThread, PTHREAD_CANCEL_ENABLE);
    
    // Execute the thread's main function:
    pthread_cleanup_push(__SBThreadCancelCleanup, self);
      [self threadMain];
    pthread_cleanup_pop(0);
    
    // All done!
    _state = SBThreadIsFinished;
    
    [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBThreadWillExitNotification object:self userInfo:nil];
    
    return NULL;
  }

//

  - (void) sleepUntilDate:(SBDate*)aDate
  {
    time_t          now = time(NULL);
    time_t          then = [aDate unixTimestamp];
    double          delta = difftime(then, now);
    
    // Take it in 30 minute chunks to begin with:
    while ( (_state == SBThreadIsExecuting) && (delta > (30 * 60)) ) {
      sleep(30 * 60);
      now = time(NULL);
      delta = difftime(then, now);
    }
    while ( (_state == SBThreadIsExecuting) && (delta > 0) ) {
      sleep((int)delta);
      now = time(NULL);
      delta = difftime(then, now);
    }
  }

@end

//

void*
__SBThreadDetach(
  void*     aThread
)
{
  return [(SBThread*)aThread startThread];
}

//
#pragma mark -
//

@implementation SBThread

  + (id) initialize
  {
    if ( self == [SBThread class] ) {
      // Get the per-thread SBThread-stashing-key setup and allocate the main
      // thread itself:
      pthread_key_create(&__SBThreadObjectKey, NULL);
      pthread_setspecific(__SBThreadObjectKey, (__SBThreadMainThread = [[SBThread alloc] init]));
    }
  }

//

  + (SBThread*) currentThread { return (SBThread*)pthread_getspecific(__SBThreadObjectKey); }
  + (SBThread*) mainThread { return __SBThreadMainThread; }
  
//

  + (void) detachNewThreadSelector:(SEL)aSelector
    toTarget:(id)aTarget
    withObject:(id)anObject
  {
    SBThread*       newThread = [[SBThread alloc] initWithTarget:aTarget selector:aSelector object:anObject];
    
    if ( newThread )
      [newThread start];
    else
      [SBException raise:@"Unable to spawn new thread." format:NULL];
  }
  
//

  + (BOOL) isMultiThreaded { return __SBThreadHasGoneMultithreaded; }

//

  + (BOOL) isMainThread
  {
    return [[self currentThread] isMainThread];
  }
  - (BOOL) isMainThread
  {
    return ( (self == __SBThreadMainThread) ? YES : NO );
  }

//

  + (void) exit
  {
    SBThread*     currentThread = [SBThread currentThread];
    
    if ( currentThread ) {
      if ( currentThread != __SBThreadMainThread )
        [currentThread release];
      else
        [SBException raise:@"Attempt to exit the main thread of execution" format:NULL];
    } else {
      [SBException raise:@"No thread of execution to exit" format:NULL];
    }
  }
  
//

  + (void) sleepForTimeInterval:(SBTimeInterval*)anInterval
  {
    [self sleepUntilDate:[SBDate dateWithTimeInterval:anInterval sinceDate:[SBDate dateWhichIsAlwaysNow]]];
  }
  
//

  + (void) sleepUntilDate:(SBDate*)aDate
  {
    SBThread*     currentThread = [SBThread currentThread];
    
    if ( currentThread )
      [currentThread sleepUntilDate:aDate];
  }

//

  - (id) init
  {
    if ( (self = [super init]) ) {
      _properties = [[SBMutableDictionary alloc] init];
    }
    return self;
  }

//

  - (id) initWithTarget:(id)aTarget
    selector:(SEL)aSelector
    object:(id)anObject
  {
    if ( (self = [self init]) ) {
      _target = [aTarget retain];
      _selector = aSelector;
      _argument = [anObject retain];
    }
    return self;
  }

//

  - (void) release
  {
    if ( self == __SBThreadMainThread )
      [SBException raise:@"Attempt to release main thread of execution" format:NULL];
    [super release];
  }
  - (void) autorelease
  {
    if ( self == __SBThreadMainThread )
      return;
    [super autorelease];
  }

//

  - (void) dealloc
  {
    if ( _state == SBThreadIsExecuting ) {
      [self cancel];
      while ( _state == SBThreadIsCancelled ) {
        // Allow cleanup time...
        usleep(100);
      }
    }
    _autoreleaseState.threadInDealloc = YES;
    while( (_autoreleaseState.current) )
      [_autoreleaseState.current release];
    if ( _target ) [_target release];
    if ( _argument ) [_argument release];
    if ( _identifier ) [_identifier release];
    if ( _properties ) [_properties release];
    
    if ( _state != SBThreadNotRunning )
      pthread_join(_nativeThread, NULL);
      
    [super dealloc];
  }

//

  - (void) start
  {
    if ( _state == SBThreadNotRunning ) {
      pthread_attr_t        attr;
      int                   rc;
      
      pthread_attr_init(&attr);
      pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
      rc = pthread_create(
                &_nativeThread,
                &attr,
                __SBThreadDetach,
                self
              );
      pthread_attr_destroy(&attr);
      if ( rc != 0 )
        [SBException raise:@"Unable to detach thread (unknown error)" format:NULL];
    }
  }

//

  - (int) lastSignalCaught { return _lastSignalCaught; }
  
//

  - (void) respondsToSignals:(sigset_t*)signals
  {
    sigset_t      sigstate;
    
    sigemptyset(signals);
    if ( pthread_sigmask(SIG_BLOCK, NULL, &sigstate) == 0 ) {
      int         sigmask = 0;
      
      while ( sigmask < SIGUSR2 ) {
        if ( ! sigismember(&sigstate, sigmask) )
          sigaddset(signals, sigmask);
        sigmask++;
      }
    }
  }

//

  - (BOOL) setRespondsToSignals:(sigset_t*)signals
  {
    int                 sigmask = 0;
    struct sigaction    action;
    sigset_t            blockAll;
    
    while ( sigmask < SIGUSR2 ) {
      if ( sigismember(signals, sigmask) ) {
        action.sa_handler = __SBThreadSignalHandler;
        sigaction(sigmask, &action, NULL);
      }
      sigmask++;
    }
    sigfillset(&blockAll);
    if ( (pthread_sigmask(SIG_BLOCK, &blockAll, NULL) == 0) && (pthread_sigmask(SIG_UNBLOCK, signals, NULL) == 0) )
      return YES;
    return NO;
  }

//

  - (void) kill:(int)signalId
  {
    if ( _state == SBThreadIsExecuting )
      pthread_kill(_nativeThread, signalId);
  }

//

  - (void) cancel
  {
    if ( _state == SBThreadIsExecuting )
      pthread_cancel(_nativeThread);
  }

//

  - (void) threadMain
  {
    if ( _target && _selector ) {
      id (*imp)(id,SEL,id);
      
      if ((imp = (id(*)(id, SEL, id))objc_msg_lookup(_target, _selector)))
        (*imp)(_target, _selector, _argument);
      else
        [SBException raise:@"Unable to call thread detach method" format:NULL];
    }
  }

//

  - (SBString*) identifier { return _identifier; }
  - (void) setIdentifier:(SBString*)identifier
  {
    if ( identifier ) identifier = [identifier retain];
    if ( _identifier ) [_identifier release];
    _identifier = identifier;
  }

//

  - (SBMutableDictionary*) properties
  {
    return _properties;
  }

//

  - (BOOL) isExecuting
  {
    return ( _state == SBThreadIsExecuting );
  }
  
//

  - (BOOL) isCancelled
  {
    return ( _state == SBThreadIsCancelled );
  }
  
//

  - (BOOL) isFinished
  {
    return ( _state == SBThreadIsFinished );
  }
  
//

  - (void) hasBeenCancelled
  {
  }

@end
