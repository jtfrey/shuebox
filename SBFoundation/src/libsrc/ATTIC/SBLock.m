//
// SBFoundation : ObjC Class Library for Solaris
// SBLock.m
//
// Wraps mutexes (both recursive and non-recursive) and condition variables.
//
// $Id$
//

#import "SBLock.h"

enum {
  kSBLockOptionMutexIsInited      = 1,
  kSBLockOptionCondIsInited       = 1 << 1,
  kSBLockOptionIsAcquired         = 1 << 2
};

@interface SBLock(SBLockPrivate)

- (BOOL) setInitialAttributes:(pthread_mutexattr_t*)attrs;

@end

@implementation SBLock(SBLockPrivate)

  - (BOOL) setInitialAttributes:(pthread_mutexattr_t*)attrs
  {
    return ( (pthread_mutexattr_settype(attrs, PTHREAD_MUTEX_NORMAL) == 0) ? YES : NO );
  }

@end

//
#pragma mark -
//

@implementation SBLock

  - (id) init
  {
    if ( self = [super init] ) {
      pthread_mutexattr_t   attrs;
      BOOL                  okay = NO;
      
      if ( pthread_mutexattr_init(&attrs) == 0 ) {
        if ( [self setInitialAttributes:&attrs] )
          okay = ( pthread_mutex_init(&_mutex, &attrs) == 0 ) ? YES : NO;
        pthread_mutexattr_destroy(&attrs);
      }
      if ( ! okay ) {
        [self release];
        self = nil;
      } else {
        _options = kSBLockOptionMutexIsInited;
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _options & kSBLockOptionMutexIsInited )
      pthread_mutex_destroy(&_mutex);
    [super dealloc];
  }
  
//

  - (BOOL) tryLock
  {
    if ( (_options & kSBLockOptionIsAcquired) == 0 ) {
      if ( pthread_mutex_trylock(&_mutex) == 0 ) {
        _reserved = pthread_self();
        _options |= kSBLockOptionIsAcquired;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) acquireLock
  {
    if ( (_options & kSBLockOptionIsAcquired) == 0 ) {
      if ( pthread_mutex_lock(&_mutex) == 0 ) {
        _reserved = pthread_self();
        _options |= kSBLockOptionIsAcquired;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) dropLock
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) ) {
      _options &= ~kSBLockOptionIsAcquired;
      if ( pthread_mutex_unlock(&_mutex) == 0 ) {
        return YES;
      }
      _options |= kSBLockOptionIsAcquired;
    }
    return NO;
  }
  
//

  - (BOOL) heldByCurrentThread
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) )
      return YES;
    return NO;
  }

@end

//
#pragma mark -
//

@implementation SBRecursiveLock

  - (BOOL) setInitialAttributes:(pthread_mutexattr_t*)attrs
  {
    return ( (pthread_mutexattr_settype(attrs, PTHREAD_MUTEX_RECURSIVE) == 0) ? YES : NO );
  }

@end

//
#pragma mark -
//

@implementation SBConditionLock

  - (id) init
  {
    if ( self = [super init] ) {
      pthread_mutexattr_t   attrs;
      BOOL                  okay = NO;
      
      if ( pthread_mutexattr_init(&attrs) == 0 ) {
        if ( pthread_mutexattr_settype(&attrs, PTHREAD_MUTEX_NORMAL) == 0 ) {
          if ( pthread_mutex_init(&_mutex, &attrs) == 0 ) {
            _options = kSBLockOptionMutexIsInited;
            if ( pthread_cond_init(&_cond, NULL) == 0 ) {
              _options |= kSBLockOptionCondIsInited;
              okay = YES;
            }
          }
        }
        pthread_mutexattr_destroy(&attrs);
      }
      if ( ! okay ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _options & kSBLockOptionMutexIsInited )
      pthread_mutex_destroy(&_mutex);
    if ( _options & kSBLockOptionCondIsInited )
      pthread_cond_destroy(&_cond);
    [super dealloc];
  }

//

  - (BOOL) acquireLock
  {
    if ( (_options & kSBLockOptionIsAcquired) == 0 ) {
      if ( pthread_mutex_lock(&_mutex) == 0 ) {
        _reserved = pthread_self();
        _options |= kSBLockOptionIsAcquired;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) dropLock
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) ) {
      _options &= ~kSBLockOptionIsAcquired;
      if ( pthread_mutex_unlock(&_mutex) == 0 ) {
        return YES;
      }
      _options |= kSBLockOptionIsAcquired;
    }
    return NO;
  }
  
//

  - (BOOL) heldByCurrentThread
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) )
      return YES;
    return NO;
  }
  
//

  - (BOOL) waitForCondition
  {
    BOOL      result = NO;
    
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) ) {
      _options &= ~kSBLockOptionIsAcquired;
      if ( pthread_cond_wait(&_cond, &_mutex) == 0 )
        result = YES;
      _reserved = pthread_self();
      _options |= kSBLockOptionIsAcquired;
    }
    return result;
  }
  
//

  - (BOOL) signalCondition
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) ) {
      if ( pthread_cond_signal(&_cond) == 0 )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) broadcastCondition
  {
    if ( (_options & kSBLockOptionIsAcquired) && pthread_equal(_reserved, pthread_self()) ) {
      if ( pthread_cond_broadcast(&_cond) == 0 )
        return YES;
    }
    return NO;
  }

@end
