//
// SBFoundation : ObjC Class Library for Solaris
// SBDictionary.h
//
// Basic object hash table.
//
// $Id$
//

#import "SBObject.h"
#import "SBEnumerator.h"

@class SBArray;

/*!
  @class SBDictionary
  @discussion
  Instances of SBDictionary implement a simple hash table data structure; the table
  starts out as a 32-slot list of buckets, with incoming key-object pairs mapped
  via the modulo of the result of their "hash" instance method.  Each slot starts as
  a NULL pointer and as keyed objects are mapped to it, a linked list grows therein
  containing all key-object pairs that have been mapped to that slot.
  
  A pool of link list nodes is maintained by the instance, such that as key-value
  pairs are added, new nodes are allocated en-masse (24 at a time in contiguous
  memory).  Removal of key-object pairs returns nodes to the pool to be recycled as
  additional key-object pairs are subsequently added.
  
  Key and object enumerators can be retrieved for iteration over these respective
  contents of the dictionary.
  
  The class maintains minimal statistics for hash collisions; eventually, this
  data could be used to automatically expand the bucket list into a new, larger
  slot-count bucket list when the collision rate becomes appreciable.  Thanks to the
  programming w.r.t. the node pool, this should be relatively simple to implement.
  
  As key-value pairs are added, the value is sent a retain message while the key
  is sent a copy message (this preserves a key's identity over time, e.g. if a
  SBMutableString is used as a key it could be altered after being used to key
  a value in an SBDictionary).  Both the key and value are send a release
  message when they are removed.
*/
@interface SBDictionary : SBObject
{
  unsigned int      _count;
  unsigned int      _bucketCount;
  void**            _buckets;
  void**            _pools;
  void*             _pool;
  unsigned int      _totalAdd,_collisions;
}

/*!
  @method dictionary
  
  Returns an autoreleased instance which initially contains no key-value pairs.
*/
+ (id) dictionary;
/*!
  @method dictionaryWithObject:forKey:
  
  Returns an autoreleased instance which initially contains the provided key-value
  pair.
*/
+ (id) dictionaryWithObject:(id)object forKey:(id)key;
/*!
  @method dictionaryWithObjects:forKeys:count:
  
  Returns an autoreleased instance which initially contains one or more key-value
  pairs.  The keys and objects arguments both point to arrays holding count
  objects:  objects[0] and keys[0] form the first key-value pair, etc.
*/
+ (id) dictionaryWithObjects:(id*)objects forKeys:(id*)keys count:(unsigned int)count;
/*!
  @method dictionaryWithObjectsAndKeys:,...
  
  Returns an autoreleased instance which intially contains the key-value pairs
  provided as a variable-length argument list.  The list must be terminated by a nil
  value, and key-value pairs should appear in reverse order -- object and then the
  key:
  <pre>
    aDictionary = [SBDictionary dictionaryWithObjectsAndKeys:obj1,key1,obj2,key2,nil];
  </pre>
*/
+ (id) dictionaryWithObjectsAndKeys:(id)firstObject,...;
/*!
  @method init
  
  Initializes an SBDictionary which initially contains no key-value pairs.
*/
- (id) init;
/*!
  @method initWithObjects:forKeys:count:
  
  Initializes an SBDictionary which initially contains one or more key-value
  pairs.  The keys and objects arguments both point to arrays holding count
  objects:  objects[0] and keys[0] form the first key-value pair, etc.
*/
- (id) initWithObjects:(id*)objects forKeys:(id*)keys count:(unsigned int)count;
/*!
  @method initWithObjectsAndKeys:,...
  
  Initializes an SBDictionary which intially contains the key-value pairs
  provided as a variable-length argument list.  The list must be terminated by a nil
  value, and key-value pairs should appear in reverse order -- object and then the
  key:
  <pre>
    aDictionary = [[SBDictionary alloc] initWithObjectsAndKeys:obj1,key1,obj2,key2,nil];
  </pre>
*/
- (id) initWithObjectsAndKeys:(id)firstObject,...;
/*!
  @method count
  
  Returns the number of key-object pairs in the receiver.
*/
- (unsigned int) count;
/*!
  @method objectForKey:
  
  Returns the object associated with the given key, or nil if the key does not
  exist in the receiver.
*/
- (id) objectForKey:(id)key;
/*!
  @method setObject:forKey:
  
  Add a new key-object pair to the receiver.  If the key already exists, the old
  object associated with it will be replaced by the new object.
*/
- (void) setObject:(id)object forKey:(id)key;
/*!
  @method removeObjectForKey:
  
  If the given key exists in the receiver, remove that key-object pair.
*/
- (void) removeObjectForKey:(id)key;
/*!
  @method removeAllObjects
  
  Remove all key-object pairs in the receiver.
*/
- (void) removeAllObjects;
/*!
  @method containsKey:
  
  Returns YES if the receiver contains a key-object pair with the given key.
*/
- (BOOL) containsKey:(id)key;
/*!
  @method containsObject:
  
  Returns YES if the receiver contains a key-object pair with the given object.
*/
- (BOOL) containsObject:(id)object;
/*!
  @method keyEnumerator
  
  Returns an enumerator object that can be used to iterate over the keys defined
  in the receiver.
*/
- (SBEnumerator*) keyEnumerator;
/*!
  @method objectEnumerator
  
  Returns an enumerator object that can be used to iterate over the keyed objects
  stored in the receiver.
*/
- (SBEnumerator*) objectEnumerator;
/*!
  @method allKeys
  
  Returns an array containing all of the keys in the receiver.
*/
- (SBArray*) allKeys;
/*!
  @method makeObjectsPerformSelector:
  
  Send the message encoded in "aSelector" to all of the objects in the receiver.
  The selector should take no arguments and have a void return type.
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector;
/*!
  @method makeObjectsPerformSelector:withObject:
  
  Send the message encoded in "aSelector" to all of the objects in the receiver.
  The selector should take one argument (of type id) and have a void return type.
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument;

@end
