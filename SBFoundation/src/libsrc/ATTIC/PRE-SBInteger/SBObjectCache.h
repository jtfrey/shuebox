//
// SBFoundation : ObjC Class Library for Solaris
// SBObjectCache.h
//
// A generic class for caching object instances.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBMutableDictionary;

/*!
  @class SBObjectCache
  @abstract Generic object caching container
  @discussion
  An instance of SBObjectCache is used to retain a fixed number of reference copies of objects
  descendent from a specific Objective-C class.  Each cached reference is assigned an expiration
  time, after which the object will be sent a release message and will be dropped from the
  cache.  If the cache fills, the default behavior is to begin evicting objects by an "oldest
  first" policy; this behavior can be overridden so that addition of new objects will fail until
  an object in the cache explicitly expires.
  
  The SBObjectCache makes use of key-value coding (see SBKeyValueCoding.h) to locate a cached
  object:  consumer code requests a cached object by a key-value pair and the instance of
  SBObjectCache requests the value of that key from each cached object until it finds one with
  a matching value (under the isEqual: method).  This implies that searching the cache is a
  linear operation, O(n).  To accelerate the cache search, SBObjectCache allows consumer code
  to create indexes over a specific key.  Each index is a hash table which maps value to cache
  line under the specific key.
  
  SBObjectCache instances by default listen for the SBObjectCacheFlushNotification and
  SBObjectCacheCleanupNotification notifications broadcast via the default SBNotificationCenter
  and flush or cleanup their cache accordingly.  The flushAllObjectCaches and cleanupAllObjectCaches
  class methods will send these notifications, respectively, and trigger a "global" flush or
  cleanup.  Individual SBObjectCache instances can elect to ignore such "global" requests.
*/
@interface SBObjectCache : SBObject
{
  Class                 _cacheType;
  unsigned int          _cacheSize;
  void*                 _cacheLines;
  unsigned int          _cacheTTL;
  SBMutableDictionary*  _cacheIndices;
  BOOL                  _evictOldestLineWhenFull;
  BOOL                  _ignoresFlushNotifications;
  BOOL                  _ignoresCleanupNotifications;
}

/*!
  @method flushAllObjectCaches
  @discussion
  Broadcast the SBObjectCacheFlushNotification via the default SBNotificationCenter; all
  SBObjectCache instances not set to ignore the notification will immediately flush all
  objects from themselves.
*/
+ (void) flushAllObjectCaches;
/*!
  @method cleanupAllObjectCaches
  @discussion
  Broadcast the SBObjectCacheCleanupNotification via the default SBNotificationCenter; all
  SBObjectCache instances not set to ignore the notification will immediately evict any
  expired objects from themselves.
*/
+ (void) cleanupAllObjectCaches;
/*!
  @method initWithBaseClass:
  @discussion
  Initialize a newly-allocated SBObjectCache with the default number of cache lines (32).
  All objects added to the cache must be of a class descendent from the given baseClass.
  
  Returns nil if the cache lines could not be allocated.
*/
- (id) initWithBaseClass:(Class)baseClass;
/*!
  @method initWithBaseClass:size:
  @discussion
  Initialize a newly-allocated SBObjectCache with the specified number of cache lines.
  All objects added to the cache must be of a class descendent from the given baseClass.
  
  Returns nil if the cache lines could not be allocated.
*/
- (id) initWithBaseClass:(Class)baseClass size:(unsigned int)cacheSize;
/*!
  @method evictOldestLineWhenFull
  @discussion
  Returns YES if the receiver will evict the oldest cached object to make room for
  newly-added objects when no cache lines are free (the default behavior).
*/
- (BOOL) evictOldestLineWhenFull;
/*!
  @method setEvictOldestLineWhenFull:
  @discussion
  If evict is NO, then disable the default behavior of evicting the oldest object
  from the cache to make room for newly-added objects when no cache lines are free.
  Instead, no new objects will be added until an existing cache line explicitly
  expires.
*/
- (void) setEvictOldestLineWhenFull:(BOOL)evict;
/*!
  @method defaultSecondsToLive
  @discussion
  Returns the receiver's default time-to-live (in whole seconds) for cached objects.
  The default value for this attribute is 300 seconds (5 minutes).
*/
- (unsigned int) defaultSecondsToLive;
/*!
  @method setDefaultSecondsToLive:
  @discussion
  Modifies the default time-to-live (in whole seconds) which should be applied to
  objects entering the cache henceforth.
*/
- (void) setDefaultSecondsToLive:(unsigned int)seconds;
/*!
  @method ignoresFlushNotifications
  @discussion
  Returns YES if the receiver will not flush all objects from itself when the
  SBObjectCacheFlushNotification is broadcast via the default SBNotificationCenter.
  
  Default is NO.
*/
- (BOOL) ignoresFlushNotifications;
/*!
  @method setIgnoresFlushNotifications:
  @discussion
  If shouldIgnore is YES, then the receiver will not respond to "global" flush
  notifications broadcast via the default SBNotificationCenter.
  
  By default, SBObjectCache instances do not ignore "global" flush
  notifications.
*/
- (void) setIgnoresFlushNotifications:(BOOL)shouldIgnore;
/*!
  @method ignoresCleanupNotifications
  @discussion
  Returns YES if the receiver will not evict all expired objects from itself when the
  SBObjectCacheCleanupNotification is broadcast via the default SBNotificationCenter.
  
  Default is NO.
*/
- (BOOL) ignoresCleanupNotifications;
/*!
  @method setIgnoresCleanupNotifications:
  @discussion
  If shouldIgnore is YES, then the receiver will not respond to "global" cleanup
  notifications broadcast via the default SBNotificationCenter.
  
  By default, SBObjectCache instances do not ignore "global" cleanup
  notifications.
*/
- (void) setIgnoresCleanupNotifications:(BOOL)shouldIgnore;
/*!
  @method cachedObjectForKey:value:
  @discussion
  Attempt to locate a cached object which has the given value associated with the
  specified key under key-value coding.  If the receiver contains an index for
  the given key, the index will be consulted; if not, the cache lines are walked
  and the first object with a matching value (under the isEqual: method) is
  returned.
*/
- (id) cachedObjectForKey:(SBString*)key value:(id)value;
/*!
  @method addObjectToCache:
  @discussion
  Attempts to add object to the cache with the receiver's default time-to-live.
  
  If the object is already present in the receiver's cache then its expiration
  is extended accordingly.
  
  If the object does not make it into the cache for any reason, NO is returned.
  Otherwise, YES is returned and object is sent the retain message.
*/
- (BOOL) addObjectToCache:(id)object;
/*!
  @method addObjectToCache:secondsToLive:
  @discussion
  Attempts to add object to the cache using an explicit time-to-live (in seconds)
  versus the receiver's default time-to-live.  Note that a negative value can
  be supplied for seconds, in which case object if already in the receiver's cache
  will be evicted immediately.
  
  If the object is already present in the receiver's cache and a positive
  time-to-live was specified, then its expiration is extended accordingly.
  
  If the object does not make it into the cache for any reason, NO is returned.
  Otherwise, YES is returned and object is sent the retain message.
*/
- (BOOL) addObjectToCache:(id)object secondsToLive:(int)seconds;
/*!
  @method evictObjectFromCache:
  @discussion
  Attempts to evict the given object from the receiver's cache if present.  When
  evicted, the cached object is sent the release message.
*/
- (void) evictObjectFromCache:(id)object;
/*!
  @method createCacheIndexForKey:
  @discussion
  Creates an index of the value of key (via key-value coding) for each object in
  the cache.  This index will be consulted by cachedObjectForKey:value: in
  preference to the standard linear search of the cached objects.
*/
- (void) createCacheIndexForKey:(SBString*)key;
/*!
  @method dropCacheIndexForKey:
  @discussion
  If an index exists in the receiver for the specified key, remove it.  The
  cachedObjectForKey:value: method will revert to performing a linear search of
  the cache with respect to the key in question.
*/
- (void) dropCacheIndexForKey:(SBString*)index;
/*!
  @method dropAlIndices
  @discussion
  Remove all indices created for the receiver.  Linear search of the cache will
  be used in all instances (at least until new indices are requested).
*/
- (void) dropAllIndices;
/*!
  @method flushCache
  @discussion
  Evict all objects from the receiver's cache.
*/
- (void) flushCache;
/*!
  @method cleanupCache
  @discussion
  Evict from the receiver's cache any objects whose expiration has passed.
*/
- (void) cleanupCache;

@end

/*!
  @constant SBObjectCacheFlushNotification
  @discussion
  Notification sent to request that all listening instances of SBObjectCache immediately
  flush themselves.
*/
extern SBString* SBObjectCacheFlushNotification;
/*!
  @constant SBObjectCacheCleanupNotification
  @discussion
  Notification sent to request that all listening instances of SBObjectCache immediately
  evict expired objects from themselves.
*/
extern SBString* SBObjectCacheCleanupNotification;
