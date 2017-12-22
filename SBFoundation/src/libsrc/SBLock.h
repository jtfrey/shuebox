//
// SBFoundation : ObjC Class Library for Solaris
// SBLock.h
//
// Wraps mutexes (both recursive and non-recursive) and condition variables.
//
// $Id$
//

#import "SBThread.h"

/*!
  @constant SBLockException
  @discussion
    Identifier of exceptions raised by the SBLock class.
*/
extern SBString* SBLockException;
/*!
  @constant SBConditionLockException
  @discussion
    Identifier of exceptions raised by the SBConditionLock class.
*/
extern SBString* SBConditionLockException;
/*!
  @constant SBRecursiveLockException
  @discussion
    Identifier of exceptions raised by the SBRecursiveLock class.
*/
extern SBString* SBRecursiveLockException;

/*!
  @class SBLock
  @discussion
    An SBLock represents a mutual exclusion lock.  The lock can be held
    by only one thread of execution and is not recursive; a thread sending
    a second lock message to an SBLock for which it already holds the lock
    will raise an exception.
    
    All exceptions generated by this class are identified by the string
    constant SBLockException.
*/
@interface SBLock : SBObject
{
  SBString*               _identifier;
  pthread_mutex_t         _mutex;
  BOOL                    _mutexReady;
  SBThread*               _owner;
}

/*!
  @method identifier
  @discussion
    Returns an SBString which the receiver uses to identify itself.  Instances
    have no identifier by default.
*/  
- (SBString*) identifier;

/*!
  @method setIdentifier:
  @discussion
    Set the SBString by which the receiver identifies itself.
*/
- (void) setIdentifier:(SBString*)identifier;

/*!
  @method hasBeenAcquiredByCurrentThread
  @discussion
    Returns YES if the current thread of execution holds the lock on the
    receiver's mutex.
*/
- (BOOL) hasBeenAcquiredByCurrentThread;

/*!
  @method lock
  @discussion
    Acquire the lock on the receiver's mutex.  Will raise an exception
    if the current thread already holds the lock or if the act of
    locking the mutex fails.
*/
- (void) lock;

/*!
  @method unlock
  @discussion
    Release the lock on the receiver's mutex.  Will raise an exception
    if the current thread does not hold the lock or if the act of
    unlocking the mutex fails.
*/
- (void) unlock;

/*!
  @method tryLock
  @discussion
    Attempt to immediately acquire the lock on the receiver's mutex.
    Returns YES if the current thread acquires the lock, NO if any
    error occurs or if the lock is currently held by another thread. 
*/
- (BOOL) tryLock;

@end

/*!
  @class SBRecursiveLock
  @discussion
    An SBRecursiveLock represents a mutual exclusion lock for which the
    holding thread can repeatedly (but in a balanced fashion) send the
    lock and unlock messages.  For example, a thread which sends three
    lock messages to the receiver must balance with tree unlock messages
    before the lock will again be free for another thread to hold.
    
    All exceptions generated by this class are identified by the string
    constant SBRecursiveLockException.
*/
@interface SBRecursiveLock : SBLock

@end

/*!
  @class SBConditionLock
  @discussion
    An SBConditionLock conditionally acquires a mutex lock based upon the
    value of an integer variable.  This class is useful when one thread must
    monitor a state variable and perform an action only after that state
    variable reaches a specific value.  Rather than checking the value on
    a periodic interval (or pegging the CPU in a while loop) an SBConditionLock
    puts the thread to sleep until another thread changes the state variable
    to the desired value.
    
    All exceptions generated by this class are identified by the string
    constant SBConditionLockException.
*/
@interface SBConditionLock : SBLock
{
  pthread_cond_t          _condition;
  BOOL                    _conditionReady;
  SBInteger               _conditionValue;
}

/*!
  @method initWithConditionValue:
  @discussion
    Initialize the receiver to have the provided initial value to its
    condition variable.
*/
- (id) initWithConditionValue:(SBInteger)conditionValue;

/*!
  @method conditionValue
  @discussion
    Returns the current value of the receiver's condition variable.
*/
- (SBInteger) conditionValue;

/*!
  @method lockOnConditionValue:
  @discussion
    The current thread is suspended until it can again acquire the lock
    when the receiver's condition variable equals conditionValue.
*/
- (void) lockOnConditionValue:(SBInteger)conditionValue;
/*!
  @method tryLockOnConditionValue:
  @discussion
    If the current thread can immediately acquire the lock on the receiver's
    mutex and the receiver's condition variable equals conditionValue, YES
    is returned.  Otherwise returns NO.
*/
- (BOOL) tryLockOnConditionValue:(SBInteger)conditionValue;

/*!
  @method unlockWithConditionValue:
  @discussion
    If the current thread holds the lock on the receiver's mutex, then the
    value of the receiver's condition variable is set to conditionValue and
    that lock is dropped.  Any other thread waiting on the receiver's
    condition variable may then reacquire the lock.
*/
- (void) unlockWithConditionValue:(SBInteger)conditionValue;

@end