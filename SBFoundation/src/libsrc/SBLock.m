//
// SBFoundation : ObjC Class Library for Solaris
// SBLock.m
//
// Wraps mutexes (both recursive and non-recursive) and condition variables.
//
// $Id$
//

#import "SBLock.h"
#import "SBException.h"

SBString*   SBLockException = @"SBLockException";
SBString*   SBConditionLockException = @"SBConditionLockException";
SBString*   SBRecursiveLockException = @"SBRecursiveLockException";

//

@interface SBLock(SBLockPrivate)

- (pthread_mutex_t*) nativeMutex;
- (SBThread*) owner;
- (BOOL) setMutexAttributes:(pthread_mutexattr_t*)attributes;
- (SBString*) stringForExceptions;

@end

@implementation SBLock(SBLockPrivate)

  - (pthread_mutex_t*) nativeMutex { return &_mutex; }
  - (SBThread*) owner { return _owner; }
  - (BOOL) setMutexAttributes:(pthread_mutexattr_t*)attributes
  {
    return NO;
  }
  - (SBString*) stringForExceptions { return SBLockException; }

@end

//

@implementation SBLock

  - (id) init
  {
    if ( (self = [super init]) ) {
      pthread_mutexattr_t     attrs, *attrsPtr = &attrs;
      
      if ( ! [self setMutexAttributes:attrsPtr] )
        attrsPtr = NULL;
      if ( pthread_mutex_init(&_mutex, attrsPtr) ) {
        [self release];
        self = nil;
      } else {
        _mutexReady = YES;
      }
      if ( attrsPtr )
        pthread_mutexattr_destroy(attrsPtr);
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _identifier )
      [_identifier release];
    if ( _mutexReady )
      pthread_mutex_destroy(&_mutex);
    [super dealloc];
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

  - (BOOL) hasBeenAcquiredByCurrentThread
  {
    return ( (_owner == [SBThread currentThread]) ? YES : NO );
  }

//

  - (void) lock
  {
    SBThread*     currentThread = [SBThread currentThread];
    
    // currentThread of nil implies that we're just starting-up a new thread,
    // so it's not possible for it to have the lock!!
    if ( ! currentThread || (_owner != currentThread) ) {
      if ( pthread_mutex_lock(&_mutex) )
        [SBException raise:[self stringForExceptions] format:"Failed to lock mutex"];
      _owner = [SBThread currentThread];
    } else
      [SBException raise:[self stringForExceptions] format:"Thread attempted to recursively lock"];
  }
  
//

  - (void) unlock
  {
    if ( pthread_mutex_unlock(&_mutex) )
      [SBException raise:[self stringForExceptions] format:"Failed to unlock mutex"];
    _owner = nil;
  }
  
//

  - (BOOL) tryLock
  {
    SBThread*     currentThread = [SBThread currentThread];
    
    // currentThread of nil implies that we're just starting-up a new thread,
    // so it's not possible for it to have the lock!!
    if ( ! currentThread || (_owner != currentThread) ) {
      if ( ! pthread_mutex_trylock(&_mutex) ) {
        _owner = [SBThread currentThread];
        return YES;
      }
    } else {
      [SBException raise:[self stringForExceptions] format:"Thread attempted to recursively lock"];
    }
    return NO;
  }

@end

//

@implementation SBRecursiveLock

  - (SBString*) stringForExceptions { return SBRecursiveLockException; }

//
  - (BOOL) setMutexAttributes:(pthread_mutexattr_t*)attributes
  {
    pthread_mutexattr_init(attributes);
    pthread_mutexattr_settype(attributes, PTHREAD_MUTEX_RECURSIVE);
    return YES;
  }
  
//

  - (void) lock
  {
    if ( pthread_mutex_lock(&_mutex) )
      [SBException raise:[self stringForExceptions] format:"Failed to lock mutex"];
    _owner = [SBThread currentThread];
  }
  
//

  - (void) unlock
  {
    if ( pthread_mutex_unlock(&_mutex) )
      [SBException raise:[self stringForExceptions] format:"Failed to unlock mutex"];
    _owner = nil;
  }
  
//

  - (BOOL) tryLock
  {
    if ( pthread_mutex_trylock(&_mutex) ) {
      _owner = [SBThread currentThread];
      return YES;
    }
    return NO;
  }

@end

//

@implementation SBConditionLock

  - (SBString*) stringForExceptions { return SBConditionLockException; }
  
//

  - (id) init
  {
    return [self initWithConditionValue:0];
  }
  
//

  - (id) initWithConditionValue:(SBInteger)conditionValue
  {
    if ( (self = [super init]) ) {
      _conditionValue = conditionValue;
      if ( pthread_cond_init(&_condition, NULL) ) {
        [self release];
        self = nil;
      } else {
        _conditionReady = YES;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _conditionReady )
      pthread_cond_destroy(&_condition);
    [super dealloc];
  }

//

  - (SBInteger) conditionValue { return _conditionValue; }
  
//

  - (void) lockOnConditionValue:(SBInteger)conditionValue
  {
    pthread_mutex_t*      mutex = [self nativeMutex];
    SBThread*             currentThread = [SBThread currentThread];
    
    // currentThread of nil implies that we're just starting-up a new thread,
    // so it's not possible for it to have the lock!!
    if ( ! currentThread || (_owner != currentThread) ) {
      if ( ! pthread_mutex_lock(mutex) ) {
        _owner = [SBThread currentThread];
        // Wait for the condition to arise:
        while ( _conditionValue != conditionValue ) {
          _owner = nil;
          if ( pthread_cond_wait(&_condition, mutex) == -1 )
            break;
        }
        _owner = [SBThread currentThread];
      } else {
        [SBException raise:[self stringForExceptions] format:"Failed to lock mutex"];
      }
    } else {
      [SBException raise:[self stringForExceptions] format:"Thread attempted to recursively lock"];
    }
  }
  
//

  - (BOOL) tryLockOnConditionValue:(SBInteger)conditionValue
  {
    SBThread*             currentThread = [SBThread currentThread];
    
    if ( [self tryLock] && (! currentThread || (_owner == currentThread)) ) {
      // We definitely have the lock, check the condition:
      if ( _conditionValue == conditionValue )
        return YES;
      [self unlock];
    }
    return NO;
  }
  
//

  - (void) unlockWithConditionValue:(SBInteger)conditionValue
  {
    pthread_mutex_t*      mutex = [self nativeMutex];
    SBThread*             currentThread = [SBThread currentThread];
    
    // currentThread of nil implies that we're just starting-up a new thread,
    // so it's not possible for it to have the lock!!
    if ( _owner && (_owner != currentThread) )
      [SBException raise:[self stringForExceptions] format:"Unlock attempted on another thread's lock"];
    
    _conditionValue = conditionValue;
    if ( ! pthread_cond_broadcast(&_condition) ) {
      if ( pthread_mutex_unlock(mutex) )
        [SBException raise:[self stringForExceptions] format:"Failed to unlock mutex"];
      _owner = nil;
    } else {
      [SBException raise:[self stringForExceptions] format:"Condition broadcast failed"];
    }
  }

@end

