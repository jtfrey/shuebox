//
// SBFoundation : ObjC Class Library for Solaris
// SBRunLoop.m
//
// Class which facilitates multiplexed i/o and time-delayed execution of
// code.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBRunLoop.h"
#import "SBRunLoopPrivate.h"
#import "SBDictionary.h"
#import "SBArray.h"
#import "SBTimer.h"
#import "SBDate.h"
#import "SBStream.h"
#import "SBStreamPrivate.h"
#import "SBThread.h"
#import "SBException.h"

#include <sys/types.h>
#include <sys/socket.h>

//

SBString* const SBRunLoopDefaultMode = @"SBRunLoopDefaultMode";

SBString* const SBRunLoopThreadKey = @"SBRunLoopForThread";

//

typedef struct {
  int       fd;
  id        object;
} SBRunLoopObjectForDescriptor;

int
__SBRunLoopObjectForDescriptorBSearchDriver(
  const void* key,
  const void* value
)
{
  int       keyFd = *((int*)key);
  int       valueFd = ((SBRunLoopObjectForDescriptor*)value)->fd;
  
  return (keyFd - valueFd);
}

//

typedef struct {
  SBUInteger                      count, capacity;
  SBRunLoopObjectForDescriptor*   objectMap;
} SBRunLoopObjectMap;

//

SBRunLoopObjectMap*
__SBRunLoopObjectMapAlloc(
  SBUInteger        sizeHint
)
{
  SBRunLoopObjectMap*   objMap = NULL;
  size_t                byteSize = sizeof(SBRunLoopObjectMap);
  
  if ( sizeHint == 0 )
    sizeHint = 8;
  else
    sizeHint = 8 * (sizeHint / 8 + ((sizeHint % 8) ? 1 : 0));
  
  byteSize += sizeHint * sizeof(SBRunLoopObjectForDescriptor);
  
  if ( (objMap = objc_malloc(byteSize)) ) {
    void*     p = ((void*)objMap) + sizeof(SBRunLoopObjectMap);
    
    objMap->count = 0; objMap->capacity = sizeHint;
    objMap->objectMap = (SBRunLoopObjectForDescriptor*)p;
  }
  return objMap;
}

//

SBRunLoopObjectMap*
__SBRunLoopObjectMapRealloc(
  SBRunLoopObjectMap*   anObjMap,
  SBUInteger            sizeHint
)
{
  SBRunLoopObjectMap*   newObjMap = NULL;
  size_t                byteSize = sizeof(SBRunLoopObjectMap);
  
  if ( sizeHint <= anObjMap->capacity )
    return anObjMap;
  
  if ( sizeHint == 0 )
    sizeHint = 8;
  else
    sizeHint = 8 * (sizeHint / 8 + ((sizeHint % 8) ? 1 : 0));
  
  byteSize += sizeHint * sizeof(SBRunLoopObjectForDescriptor);
  
  if ( (newObjMap = objc_realloc(anObjMap, byteSize)) ) {
    void*     p = ((void*)newObjMap) + sizeof(SBRunLoopObjectMap);
    
    newObjMap->capacity = sizeHint;
    newObjMap->objectMap = (SBRunLoopObjectForDescriptor*)p;
    
    return newObjMap;
  }
  return anObjMap;
}

//

id
__SBRunLoopObjectMapObjectForFD(
  SBRunLoopObjectMap*   anObjMap,
  int                   fd
)
{
  SBRunLoopObjectForDescriptor* match = bsearch(
                                            &fd,
                                            anObjMap->objectMap,
                                            anObjMap->count,
                                            sizeof(SBRunLoopObjectForDescriptor),
                                            __SBRunLoopObjectForDescriptorBSearchDriver
                                          );
  if ( match )
    return match->object;
  return nil;
}

//

void
__SBRunLoopObjectMapAdd(
  SBRunLoopObjectMap*   anObjMap,
  int                   fd,
  id                    object
)
{
  if ( anObjMap->count < anObjMap->capacity ) {
    SBUInteger          i = 0;
    
    while ( i < anObjMap->count ) {
      if ( anObjMap->objectMap[i].fd > fd ) {
        // Insert here:
        memmove(&anObjMap->objectMap[i + 1], &anObjMap->objectMap[i], anObjMap->count - i);
        anObjMap->objectMap[i].fd = fd;
        anObjMap->objectMap[i].object = object;
        anObjMap->count++;
        return;
      } else if ( anObjMap->objectMap[i].fd == fd ) {
        // Replace here:
        anObjMap->objectMap[i].object = object;
        anObjMap->count++;
        return;
      }
      i++;
    }
    anObjMap->objectMap[i].fd = fd;
    anObjMap->objectMap[i].object = object;
    anObjMap->count++;
  }
}

//

void
__SBRunLoopObjectMapDebug(
  SBRunLoopObjectMap*   anObjMap
)
{
  SBUInteger            i = 0;
  
  printf("SBRunLoopObjectMap@%p ( %u / %u ) {\n", anObjMap, anObjMap->count, anObjMap->capacity);
  while ( i < anObjMap->count ) {
    printf("  %05d => %p\n", anObjMap->objectMap[i].fd, anObjMap->objectMap[i].object);
    i++;
  }
  printf("}\n");
}

//
#pragma mark -
//

@interface SBRunLoopQueuedMessage : SBObject
{
  id              _target;
  SEL             _selector;
  id              _argument;
  SBUInteger      _order;
  SBArray*        _modes;
  SBTimer*        _timer;
}

- (id) initWithSelector:(SEL)selector target:(id)target argument:(id)argument order:(SBUInteger)order modes:(SBArray*)modes;

- (void) invalidate;
- (BOOL) matchesTarget:(id)target;
- (BOOL) matchesSelector:(SEL)selector target:(id)target argument:(id)argument;

- (SBUInteger) order;
- (SBTimer*) timer;
- (void) setTimer:(SBTimer*)aTimer;
- (SBArray*) modes;
- (void) fire;

@end

@implementation SBRunLoopQueuedMessage

  - (id) initWithSelector:(SEL)selector
    target:(id)target
    argument:(id)argument
    order:(SBUInteger)order
    modes:(SBArray*)modes
  {
    if ( (self = [super init]) ) {
      _target = [target retain];
      _selector = selector;
      _argument = ( argument ? [argument retain] : nil );
      _order = order;
      _modes = [modes copy];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _timer ) [_timer invalidate];
    if ( _modes ) [_modes release];
    if ( _argument ) [_argument release];
    if ( _target ) [_target release];
    [super dealloc];
  }
  
//

  - (void) invalidate
  {
    if ( _timer ) {
      [_timer invalidate];
      _timer = nil;
    }
  }

//

  - (BOOL) matchesTarget:(id)target
  {
    return ( (target == _target) ? YES : NO );
  }
  
//

  - (BOOL) matchesSelector:(SEL)selector
    target:(id)target
    argument:(id)argument
  {
    return ( ((target == _target) && sel_eq(selector, _selector) && ((argument == _argument) || ([argument isEqual:_argument]))) ? YES : NO );
  }
  
//

  - (SBUInteger) order { return _order; }
  
//

  - (SBTimer*) timer { return _timer; }
  - (void) setTimer:(SBTimer*)aTimer
  {
    // aTimer retains us, not vice versa:
    _timer = aTimer;
  }

//

  - (SBArray*) modes { return _modes; }
  
//

  - (void) fire
  {
    [_target perform:_selector with:_argument];
    if ( _timer )
      [[[SBRunLoop currentRunLoop] timedMessageQueue] removeObjectIdenticalTo:self];
  }

@end


//
#pragma mark -
//

SBRunLoop*
__SBRunLoopFromThreadProperties(
  SBMutableDictionary*    threadProperties
)
{
  SBRunLoop*      runLoop = [threadProperties objectForKey:SBRunLoopThreadKey];
  
  if ( ! runLoop ) {
    if ( (runLoop = [[SBRunLoop alloc] init]) ) {
      [threadProperties setObject:runLoop forKey:SBRunLoopThreadKey];
      [runLoop release];
    }
  }
  return runLoop;
}

//

@implementation SBRunLoop

  + (id) initialize
  {
    //
    // Make sure a broken connection doesn't kill the program:
    //
    signal(SIGPIPE, SIG_IGN);
  }

//

  + (SBRunLoop*) currentRunLoop
  {
    SBThread*               currentThread = [SBThread currentThread];
    SBMutableDictionary*    threadProperties = ( currentThread ? [currentThread properties] : (SBMutableDictionary*)nil );
    
    return ( threadProperties ? (SBRunLoop*)__SBRunLoopFromThreadProperties(threadProperties) : (SBRunLoop*)nil );
  }
  
//

  + (SBRunLoop*) mainRunLoop
  {
    SBThread*               mainThread = [SBThread mainThread];
    SBMutableDictionary*    threadProperties = ( mainThread ? [mainThread properties] : (SBMutableDictionary*)nil );
    
    return ( threadProperties ? (SBRunLoop*)__SBRunLoopFromThreadProperties(threadProperties) : (SBRunLoop*)nil );
  }

//

  - (id) init
  {
    if ( (self = [super init]) ) {
      _timers             = [[SBMutableDictionary alloc] init];
      _inputSources       = [[SBMutableDictionary alloc] init];
      _outputSources      = [[SBMutableDictionary alloc] init];
      _messageQueue       = [[SBMutableArray alloc] init];
      _timedMessageQueue  = [[SBMutableArray alloc] init];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _timers ) [_timers release];
    if ( _inputSources ) [_inputSources release];
    if ( _outputSources ) [_outputSources release];
    if ( _messageQueue ) [_messageQueue release];
    if ( _timedMessageQueue ) [_timedMessageQueue release];
    
    if ( _inputSourceMap ) objc_free(_inputSourceMap);
    if ( _outputSourceMap ) objc_free(_outputSourceMap);
    
    [super dealloc];
  }

//

  - (void) addTimer:(SBTimer*)aTimer
    forMode:(SBString*)aMode
  {
    SBMutableArray*     timersForMode = [_timers objectForKey:aMode];
    
    if ( ! timersForMode ) {
      timersForMode = [[SBMutableArray alloc] init];
      [_timers setObject:timersForMode forKey:aMode];
      [timersForMode release];
    }
    if ( ! [timersForMode containsObject:aTimer] )
      [timersForMode addObject:aTimer];
  }

//

  - (void) performSelector:(SEL)aSelector
    target:(id)target
    argument:(id)anArgument
    order:(unsigned)order
    modes:(SBArray*)modes
  {
    SBRunLoopQueuedMessage*     message = [[SBRunLoopQueuedMessage alloc] initWithSelector:aSelector
                                                target:target argument:anArgument order:order modes:modes];
    if ( message ) {
      [self addMessageToQueue:message afterExtant:YES];
      [message release];
    }
  }
  
//

  - (void) cancelPerformSelectorsWithTarget:(id)target
  {
    SBUInteger      i = 0, iMax = [_messageQueue count];
    
    while ( i < iMax ) {
      SBRunLoopQueuedMessage*   msg = [_messageQueue objectAtIndex:i];
      
      if ( [msg matchesTarget:target] ) {
        [msg invalidate];
        [_messageQueue removeObjectAtIndex:i];
        iMax--;
      } else {
        i++;
      }
    }
  }
  
//

  - (void) cancelPerformSelector:(SEL)aSelector
    target:(id)target
    argument:(id)anArgument
  {
    SBUInteger      i = 0, iMax = [_messageQueue count];
    
    while ( i < iMax ) {
      SBRunLoopQueuedMessage*   msg = [_messageQueue objectAtIndex:i];
      
      if ( [msg matchesSelector:aSelector target:target argument:anArgument] ) {
        [msg invalidate];
        [_messageQueue removeObjectAtIndex:i];
        iMax--;
      } else {
        i++;
      }
    }
  }

//

  - (SBString*) currentMode { return _currentMode; }

//

  - (SBDate*) limitDateForMode:(SBString*)mode
  {
    // Run the loop once non-blocking fashion and retrieve the soonest timer firing time
    SBDate*     limit = nil;
    
    [self runMode:mode beforeDate:nil nextTimerFiresAt:&limit];
    return limit;
  }

//

  - (void) acceptInputForMode:(SBString*)aMode
    beforeDate:(SBDate*)endDate
  {
    if ( [self countOfInputSourcesForMode:aMode] + [self countOfTimersForMode:aMode] > 0 )
      [self runMode:aMode beforeDate:endDate nextTimerFiresAt:NULL];
  }

//

  - (void) run
  {
    [self runUntilDate:[SBDate distantFuture]];
  }
  
//

  - (void) runUntilDate:(SBDate*)endDate
  {
    SBDate*     now = [SBDate dateWhichIsAlwaysNow];
    
    if ( ! endDate )
      endDate = now;
      
    while ( [now laterDate:endDate] == endDate ) {
      SBAutoreleasePool*      loopPool = [[SBAutoreleasePool alloc] init];
      SBDate*                 waitUntil = nil;
      
      if ( (waitUntil = [self limitDateForMode:SBRunLoopDefaultMode]) ) {
        waitUntil = [waitUntil earlierDate:endDate];
      } else {
        waitUntil = endDate;
      }
      
      if ( ! [self runMode:SBRunLoopDefaultMode beforeDate:waitUntil] ) {
        // We didn't process any input, so go ahead and just sleep until
        // the limiting date arrives:
        while ( [now laterDate:waitUntil] == waitUntil ) {
          SBTimeInterval*   sleepInterval = [waitUntil timeIntervalSinceDate:now];
          double            secondsToWait = [sleepInterval totalSecondsInTimeInterval];
          struct timespec   sleepTime;
          
          if ( secondsToWait > LONG_MAX ) {
            sleepTime.tv_sec = LONG_MAX;
            sleepTime.tv_nsec = 0;
          } else {
            sleepTime.tv_sec = floor(secondsToWait);
            sleepTime.tv_nsec = floor((secondsToWait - sleepTime.tv_sec) * 1.0e9);
          }
          nanosleep(&sleepTime, NULL);
        }
      }
      [loopPool release];
    }
  }
  
//

  - (BOOL) runMode:(SBString*)aMode
    beforeDate:(SBDate*)endDate
  {
    return [self runMode:aMode beforeDate:endDate nextTimerFiresAt:NULL];
  }

@end

//

@implementation SBRunLoop(SBRunLoopPrivate)

  - (BOOL) runMode:(SBString*)aMode
    beforeDate:(SBDate*)aDate
    nextTimerFiresAt:(SBDate**)fireDate
  {
    BOOL                  rc = NO;
    
    //
    // The actual workhorse of SBRunLoop -- fires-off any timers which have expired for aMode,
    // does queued-message invocations, and then blocks waiting for i/o on any watched file
    // descriptors.
    //
    if ( ! aMode )
      return rc;
    
    SBAutoreleasePool*    localPool = [[SBAutoreleasePool alloc] init];
    SBDate*               now = [SBDate dateWhichIsAlwaysNow];
    SBString*             oldMode = _currentMode;
    SBDate*               runUntil;
    SBUInteger            i, iMax;
    
    // Change mode:
    _currentMode = aMode;
    
    // Let's see if we have any queued messages that need to be sent:
    if ( (iMax = [_messageQueue count]) ) {
      SBMutableArray*   messages = [_messageQueue mutableCopy];
      
      [_messageQueue removeAllObjects];
      i = 0; iMax = [messages count];
      while ( i < iMax ) {
        SBRunLoopQueuedMessage*   msg = [messages objectAtIndex:i];
        
        if ( msg && [[msg modes] containsObject:aMode] ) {
          [msg fire];
          [messages removeObjectAtIndex:i];
          iMax--;
        } else {
          i++;
        }
      }
      if ( iMax ) {
        // There must still be one or more messages that weren't for this mode; add
        // them back into the queue:
        i = 0;
        while ( i < iMax ) {
          id      msg = [messages objectAtIndex:i++];
          
          if ( msg )
            [self addMessageToQueue:msg afterExtant:NO];
        }
      }
      [messages release];
    }
    
    // If someone wants a limit date, then by default let's give 'em the most distant date
    // possible, in case there are no timers:
    runUntil = [SBDate distantFuture];
    
    // Check for any timers which have expired:
    if ( (iMax = [self countOfTimersForMode:aMode]) ) {
      SBMutableArray*     timers = [_timers objectForKey:aMode];
      
      i = 0;
      while ( i < iMax ) {
        SBTimer*          theTimer = [[timers objectAtIndex:i] retain];
        
        if ( [theTimer isValid] ) {
          if ( [[theTimer fireDate] laterDate:now] == now ) {
            [theTimer fire];
          }
          if ( [theTimer isValid] ) {
            SBDate*   then = [theTimer fireDate];
            
            if ( [then laterDate:runUntil] == runUntil ) {
              then = [then retain];
              [runUntil release];
              runUntil = then;
            }
          }
        }
        if ( ! [theTimer isValid] ) {
          [timers removeObjectAtIndex:i];
          iMax--;
        } else {
          i++;
        }
        [theTimer release];
      }
    }
    
    // Get setup to poll for i/o on all files we're supposed to watch:
    fd_set      rfds, wfds, refds, wefds;
    int         maxFD;
    
    FD_ZERO(&rfds);
    FD_ZERO(&wfds);
    FD_ZERO(&refds);
    FD_ZERO(&wefds);
    if ( (maxFD = [self setupIOSelectForMode:aMode read:&rfds write:&wfds readError:&refds writeError:&wefds]) >= 0 ) {
      int               selectrc;
      struct timespec   timeout = { 0 , 0 };
      struct timespec*  timeoutPtr = &timeout;

      // Setup the timeout:
      if ( aDate ) {
        SBDate*           sooner = [aDate earlierDate:runUntil];
        SBTimeInterval*   ti = [sooner timeIntervalSinceDate:now];
        double            secondsToWait = [ti totalSecondsInTimeInterval];
        
        if ( (secondsToWait > 0.0) && (secondsToWait < LONG_MAX) ) {
          timeout.tv_sec = floor(secondsToWait); secondsToWait -= timeout.tv_sec;
          timeout.tv_nsec = floor(secondsToWait * 1e9);
        } else {
          timeoutPtr = NULL;
        }
      }
      
      // Do any writing first, on an immediate-poll:
      selectrc = pselect(maxFD + 1, NULL, &wfds, &wefds, timeoutPtr, NULL);
      if ( selectrc < 0 ) {
        switch ( errno ) {
          
          case EINTR: {
            // A signal was caught in the midst of the polling; return to
            // the caller now so it can react to something the signal may
            // have signified:
            break;
          }
          
          default: {
            [SBException raise:@"Unrecoverable pselect() error in SBRunLoop" format:"Errno = %d", errno];
            break;
          }
            
        }
      } else if ( selectrc ) {
        // Walk the error descriptors first:
        i = 0;
        while ( i <= maxFD ) {
          if ( FD_ISSET(i, &wefds) ) {
            id<SBFileDescriptorStream>  obj;
            int                         local_errno;
            socklen_t                   local_errno_size = sizeof(local_errno);
            
            getsockopt(i, SOL_SOCKET, SO_ERROR, &local_errno, &local_errno_size);
            if ( _outputSourceMap && (obj = __SBRunLoopObjectMapObjectForFD(_outputSourceMap, i)) )
              [obj fileDescriptorHasError:local_errno];
          }
          i++;
        }
        
        // Walk the output descriptors:
        i = 0;
        while ( i <= maxFD ) {
          if ( FD_ISSET(i, &wfds) ) {
            id<SBFileDescriptorStream>  obj;
            
            if ( _outputSourceMap && (obj = __SBRunLoopObjectMapObjectForFD(_outputSourceMap, i)) )
              [obj fileDescriptorReady];
          }
          i++;
        }
      }

      // Setup the timeout:
      timeout.tv_sec = timeout.tv_nsec = 0;
      timeoutPtr = &timeout;
      if ( aDate ) {
        SBDate*           sooner = [aDate earlierDate:runUntil];
        SBTimeInterval*   ti = [sooner timeIntervalSinceDate:now];
        double            secondsToWait = [ti totalSecondsInTimeInterval];
        
        if ( (secondsToWait > 0.0) && (secondsToWait < LONG_MAX) ) {
          timeout.tv_sec = floor(secondsToWait); secondsToWait -= timeout.tv_sec;
          timeout.tv_nsec = floor(secondsToWait * 1e9);
        } else {
          timeoutPtr = NULL;
        }
      }
      
      selectrc = pselect(maxFD + 1, &rfds, NULL, &refds, timeoutPtr, NULL);
      // Was there an error?
      if ( selectrc < 0 ) {
        switch ( errno ) {
          
          case EINTR: {
            // A signal was caught in the midst of the polling; return to
            // the caller now so it can react to something the signal may
            // have signified:
            break;
          }
          
          default: {
            [SBException raise:@"Unrecoverable pselect() error in SBRunLoop" format:"Errno = %d", errno];
            break;
          }
            
        }
      } else if ( selectrc ) {
        // Walk the error descriptors first:
        i = 0;
        while ( i <= maxFD ) {
          if ( FD_ISSET(i, &refds) ) {
            id<SBFileDescriptorStream>  obj;
            int                         local_errno;
            socklen_t                   local_errno_size = sizeof(local_errno);
            
            getsockopt(i, SOL_SOCKET, SO_ERROR, &local_errno, &local_errno_size);
            if ( _inputSourceMap && (obj = __SBRunLoopObjectMapObjectForFD(_inputSourceMap, i)) )
              [obj fileDescriptorHasError:local_errno];
            if ( _outputSourceMap && (obj = __SBRunLoopObjectMapObjectForFD(_outputSourceMap, i)) )
              [obj fileDescriptorHasError:local_errno];
          }
          i++;
        }
        
        // Walk the input descriptors:
        i = 0;
        while ( i <= maxFD ) {
          if ( FD_ISSET(i, &rfds) ) {
            id<SBFileDescriptorStream>  obj;
            
            if ( _inputSourceMap && (obj = __SBRunLoopObjectMapObjectForFD(_inputSourceMap, i)) )
              [obj fileDescriptorReady];
          }
          i++;
        }
      }
      rc = YES;
    }
    
    // Cleanup:
    [localPool release];
    _currentMode = oldMode;
    if ( fireDate ) {
      *fireDate = [runUntil autorelease];
    } else {
      [runUntil release];
    }
    
    return rc;
  }

//

  - (SBMutableArray*) messageQueue { return _messageQueue; }
  - (SBMutableArray*) timedMessageQueue { return _timedMessageQueue; }

//

  - (void) addMessageToQueue:(id)delayedMessage
     afterExtant:(BOOL)after
  {
    SBRunLoopQueuedMessage*   msg = (SBRunLoopQueuedMessage*)delayedMessage;
    SBUInteger                i = 0, iMax = [_messageQueue count];
    
    if ( iMax ) {
      SBUInteger              order = [msg order];
      
      if ( after ) {
        while ( i < iMax ) {
          if ( [[_messageQueue objectAtIndex:i] order] > order ) {
            [_messageQueue insertObject:msg atIndex:i];
            return;
          }
          i++;
        }
      } else {
        while ( i < iMax ) {
          if ( [[_messageQueue objectAtIndex:i] order] >= order ) {
            [_messageQueue insertObject:msg atIndex:i];
            return;
          }
          i++;
        }
      }
    }
    [_messageQueue addObject:msg];
  }

//

  - (void) addInputSource:(id)source
    forMode:(SBString*)aMode
  {
    if ( [source conformsTo:@protocol(SBFileDescriptorStream)] ) {
      SBMutableArray*     sources = [_inputSources objectForKey:aMode];
      
      if ( ! sources ) {
        if ( (sources = [[SBMutableArray alloc] init]) )
          [_inputSources setObject:sources forKey:aMode];
      }
      if ( sources && ! [sources containsObjectIdenticalTo:source] ) {
        [sources addObject:source];
      }
    }
  }
  
//

  - (void) removeInputSource:(id)source
  {
    if ( [_inputSources count] ) {
      SBEnumerator*   eSources = [_inputSources objectEnumerator];
      SBMutableArray* sources;
      
      while ( sources = [eSources nextObject] ) {
        if ( [sources containsObject:source] ) {
          [sources removeObjectIdenticalTo:source];
        }
      }
    }
  }

//

  - (void) removeInputSource:(id)source
    forMode:(SBString*)aMode
  {
    if ( ! aMode )
      return;
    
    SBMutableArray*   sources = [_inputSources objectForKey:aMode];
    
    if ( sources ) {
      [sources removeObjectIdenticalTo:source];
    }
  }

//

  - (void) addOutputSource:(id)source
    forMode:(SBString*)aMode
  {
    if ( [source conformsTo:@protocol(SBFileDescriptorStream)] ) {
      SBMutableArray*     sources = [_outputSources objectForKey:aMode];
      
      if ( ! sources ) {
        if ( (sources = [[SBMutableArray alloc] init]) )
          [_outputSources setObject:sources forKey:aMode];
      }
      if ( sources && ! [sources containsObject:source] ) {
        [sources addObject:source];
      }
    }
  }
  
//

  - (void) removeOutputSource:(id)source
  {
    if ( [_inputSources count] ) {
      SBEnumerator*   eSources = [_outputSources objectEnumerator];
      SBMutableArray* sources;
      
      while ( sources = [eSources nextObject] ) {
        if ( [sources containsObject:source] ) {
          [sources removeObjectIdenticalTo:source];
        }
      }
    }
  }

//

  - (void) removeOutputSource:(id)source
    forMode:(SBString*)aMode
  {
    if ( ! aMode )
      return;
    
    SBMutableArray*   sources = [_outputSources objectForKey:aMode];
    
    if ( sources ) {
      [sources removeObjectIdenticalTo:source];
    }
  }

//

  - (SBUInteger) countOfTimersForMode:(SBString*)aMode
  {
    SBUInteger        count = 0;
    SBArray*          a = [_timers objectForKey:aMode];
    
    if ( a )
      count = [a count];
    
    return count;
  }
  
//

  - (SBUInteger) countOfInputSourcesForMode:(SBString*)aMode
  {
    SBUInteger        count = 0;
    SBArray*          a = [_inputSources objectForKey:aMode];
    
    if ( a )
      count = [a count];
    
    return count;
  }
  
//

  - (SBUInteger) countOfOutputSourcesForMode:(SBString*)aMode
  {
    SBUInteger        count = 0;
    SBArray*          a = [_outputSources objectForKey:aMode];
    
    if ( a )
      count = [a count];
    
    return count;
  }

//

  - (int) setupIOSelectForMode:(SBString*)aMode
    read:(fd_set*)rfds
    write:(fd_set*)wfds
    readError:(fd_set*)refds
    writeError:(fd_set*)wefds
  {
    SBArray*          input = [_inputSources objectForKey:aMode];
    SBArray*          output = [_outputSources objectForKey:aMode];
    SBUInteger        inputCount = (input ? [input count] : 0);
    SBUInteger        outputCount = (output ? [output count] : 0);
    int               maxFD = -1;
    
    if ( inputCount ) {
      SBRunLoopObjectMap*   objMap = (SBRunLoopObjectMap*)_inputSourceMap;
      
      if ( ! objMap )
        objMap = __SBRunLoopObjectMapAlloc(inputCount);
      else if ( objMap->count < inputCount )
        objMap = __SBRunLoopObjectMapRealloc(objMap, inputCount);
      
      if ( objMap ) {
        // Fill-in the struct:
        SBUInteger      i = 0;
        
        objMap->count = 0;
        while ( i < inputCount ) {
          id<SBFileDescriptorStream>    source = [input objectAtIndex:i++];
          int                           fd = [source fileDescriptorForStream];
          
          if ( fd >= 0 ) {
            FD_SET(fd, rfds);
            FD_SET(fd, refds);
            __SBRunLoopObjectMapAdd(objMap, fd, source);
            if ( fd > maxFD )
              maxFD = fd;
          }
        }
      }
      _inputSourceMap = objMap;
    }
    
    if ( outputCount ) {
      SBRunLoopObjectMap*   objMap = (SBRunLoopObjectMap*)_outputSourceMap;
      
      if ( ! objMap )
        objMap = __SBRunLoopObjectMapAlloc(outputCount);
      else if ( objMap->count < outputCount )
        objMap = __SBRunLoopObjectMapRealloc(objMap, outputCount);
      
      if ( objMap ) {
        // Fill-in the struct:
        SBUInteger    i = 0;
        
        objMap->count = 0;
        while ( i < outputCount ) {
          id<SBFileDescriptorStream>    source = [output objectAtIndex:i++];
          int                           fd = [source fileDescriptorForStream];
          
          if ( fd >= 0 ) {
            FD_SET(fd, wfds);
            FD_SET(fd, wefds);
            __SBRunLoopObjectMapAdd(objMap, fd, source);
            if ( fd > maxFD )
              maxFD = fd;
          }
        }
      }
      _outputSourceMap = objMap;
    }
    
    return maxFD;
  }

@end

//
#pragma mark -
//

@implementation SBObject(SBObjectDelayedPerforming)

  - (void) performSelector:(SEL)aSelector
    withObject:(id)anArgument
    afterDelay:(SBTimeInterval*)delay
  {
    SBRunLoopQueuedMessage*   msg = [[SBRunLoopQueuedMessage alloc] initWithSelector:aSelector
                                        target:self argument:anArgument
                                        order:0
                                        modes:nil];
    SBMutableArray*           queue = [[SBRunLoop currentRunLoop] timedMessageQueue];
    
    if ( msg ) {
    	[queue addObject:msg];
      [msg setTimer:[SBTimer scheduledTimerWithTimeInterval:delay
							 target:msg
							 selector:@selector(fire)
							 userInfo:nil
							 repeats:NO]
        ];
      [msg release];
    }
  }

//

  - (void) performSelector:(SEL)aSelector
    withObject:(id)anArgument
    afterDelay:(SBTimeInterval*)delay
    inModes:(SBArray*)modes
  {
    SBUInteger                  i = 0, iMax = ( modes ? [modes count] : 0 );
    
    if ( iMax ) {
      SBRunLoop*                runloop = [SBRunLoop currentRunLoop];
      SBMutableArray*           queue = [runloop timedMessageQueue];
      SBRunLoopQueuedMessage*   msg = [[SBRunLoopQueuedMessage alloc] initWithSelector:aSelector
                                          target:self argument:anArgument
                                          order:0
                                          modes:modes];
      
      if ( msg ) {
        SBTimer*                timer = [SBTimer scheduledTimerWithTimeInterval:delay
                                                   target:msg
                                                   selector:@selector(fire)
                                                   userInfo:nil
                                                   repeats:NO];
        [queue addObject:msg];
        [msg setTimer:timer];
        [msg release];
        
        // Schedule in modes:
        while ( i < iMax )
          [runloop addTimer:timer forMode:[modes objectAtIndex:i++]];
      }
    }
  }

//

  + (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget
  {
    SBMutableArray*           queue = [[SBRunLoop currentRunLoop] timedMessageQueue];
    SBUInteger                i = 0, iMax = ( queue ? [queue count] : 0 );
    
    if ( iMax ) {
      while ( i < iMax ) {
        SBRunLoopQueuedMessage* msg = [queue objectAtIndex:i];
        
        if ( [msg matchesTarget:aTarget] ) {
          [msg invalidate];
          [queue removeObjectAtIndex:i];
          iMax--;
        } else {
          i++;
        }
      }
    }
  }
  
//

  + (void) cancelPreviousPerformRequestsWithTarget:(id)aTarget
    selector:(SEL)aSelector
    object:(id)anArgument
  {
    SBMutableArray*           queue = [[SBRunLoop currentRunLoop] timedMessageQueue];
    SBUInteger                i = 0, iMax = ( queue ? [queue count] : 0 );
    
    if ( iMax ) {
      while ( i < iMax ) {
        SBRunLoopQueuedMessage* msg = [queue objectAtIndex:i];
        
        if ( [msg matchesSelector:aSelector target:aTarget argument:anArgument] ) {
          [msg invalidate];
          [queue removeObjectAtIndex:i];
          iMax--;
        } else {
          i++;
        }
      }
    }
  }

@end
