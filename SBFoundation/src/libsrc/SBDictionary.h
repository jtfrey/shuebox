//
// SBFoundation : ObjC Class Library for Solaris
// SBDictionary.h
//
// Hash tables.
//
// $Id$
//

#import "SBObject.h"

/*!
  @header SBDictionary.h
  @discussion
  SBDictionary represents the public interface to an entire cluster of classes devoted to the
  task of managing keyed collections of objects.  Where an SBArray uses a fixed range of integer
  indices to identify constituent values, an SBDictionary allows any SBFoundation object to act
  as the identifier for the values in the container.
  
  <b>Implementation Details</b>
  <blockquote>
    A little inside info, the actual class cluster under SBDictionary looks like this:
    <ul>
      <li>SBDictionary
        <ul>
          <li>SBNullDictionary</li>
          <li>SBConcreteDictionary
            <ul>
              <li>SBSinglePairConcreteDictionary</li>
              <li>SBSmallConcreteDictionary</li>
              <li>SBMediumConcreteDictionary</li>
              <li>SBLargeConcreteDictionary</li>
            </ul>
          </li>
          <li>SBMutableDictionary
            <ul>
              <li>SBConcreteMutableDictionary</li>
            </ul>
          </li>
        </ul>
      </li>
    </ul>
    There are two abstract subclasses of SBDictionary.  SBNullDictionary represents an immutable
    dictionary which contains no key-value pairs.
    
    The concrete implementations of SBDictionary (SBSinglePairConcreteDictionary, et al.) differ
    only in their capacity and how they store their constituent objects.  The single-pair, small,
    and medium types all include a static C data structure in their instance variable list, so no
    additional allocations are necessary beyond creating the array object itself.  These three
    classes have capacities of 1, 8, and 24 key-value pairs, respectively.  The
    SBLargeConcreteDictionary will handle any object capacity and allocates its storage space
    from the heap.
  </blockquote>
*/

@class SBArray, SBEnumerator;

/*!
  @class SBDictionary
  @abstract Immutable collection of keyed objects
  @discussion
  Instances of the SBDictionary class represent a collection of objects which are keyed by arbitrary
  objects.  The contents of the dictionary are accessed by means of the "key" objects &mdash; which
  are most often SBString objects.
  
  Subclasses of SBDictionary must <i>at least</i> implement the three primary methods:
  <ul>
    <li>- (SBUInteger) count</li>
    <li>- (id) objectForKey:(id)aKey</li>
    <li>- (SBEnumerator*) keyEnumerator;</li>
  </ul>
  Any subclass that implements these methods will automatically inherit functional versions
  of the methods in the SBExtendedDictionary category; the default implementations of these methods
  <i>only</i> make use of the three aforementioned primary methods (as well as each other).  Of
  course, subclasses can also override any of the methods in the SBExtendedDictionary category with
  their own optimal implementations.  Subclasses are responsible for providing their own object
  creation methods.
  
  SBDictionary instances are immutable -- their content cannot be modified after they are created.
  If you need a dictionary which allows objects to be added and removed, the SBMutableDictionary
  class is the solution.
  
  Objects added to an SBDictionary are always sent the retain message in order to obtain a
  reference copy.  Keys are always added to an SBDictionary by means of a "copy" message sent to the
  object; the "copy" message is meant to provide an unchanging duplicate of the original key &mdash; for
  classes with mutable/immutable variants, an immutable variant may actually return a reference
  copy.  In all other cases, a new object initialized to be identical to the original is returned.
  When a key-value pair is evicted from an SBDictionary both the key and value object are sent the
  "release" message.
  
  A given key can only have one value associated with it in an SBDictionary.  A value with a duplicate
  key overwrites any previous values.
*/
@interface SBDictionary : SBObject <SBMutableCopying>
/*!
  @method count
  @discussion
  Returns the number of key-value pairs in the receiver.
*/
- (SBUInteger) count;
/*!
  @method objectForKey:
  @discussion
  If the receiver contains a key-value pair for which the key is equivalent to aKey (by means of
  the isEqual: message), the associated value is returned.  Otherwise, returns nil.
*/
- (id) objectForKey:(id)aKey;
/*!
  @method keyEnumerator
  @discussion
  Returns an SBEnumerator object that iterates over the keys defined in the receiver.
*/
- (SBEnumerator*) keyEnumerator;

@end

/*!
  @category SBDictionary(SBExtendedDictionary)
  @discussion
  Groups methods which extend the basic functionality of an SBDictionary.  All methods' default
  implementation is accessible by any proper subclass of SBDictionary.
*/
@interface SBDictionary(SBExtendedDictionary)
/*!
  @method containsKey:
  @discussion
  Returns YES if the receiver contains a key-value pair for which the key is equivalent (under
  the isEqual: method) to aKey.
*/
- (BOOL) containsKey:(id)aKey;
/*!
  @method containsObject:
  @discussion
  Returns YES if the receiver contains a key-value pair for which the value is equivalent (under
  the isEqual: method) to object.
*/
- (BOOL) containsObject:(id)object;
/*!
  @method allKeys
  @discussion
  Returns an array containing all of the keys (in arbitrary order) of the receiver's key-value
  pairs.
  
  Returns nil if the dictionary is empty.
*/
- (SBArray*) allKeys;
/*!
  @method allKeysForObject:
  @discussion
  Returns an array containing all of the keys (in arbitrary order) of the receiver's key-value
  pairs for which the value is equivalent (under the isEqual: method) to anObject.
  
  Returns nil if no matches are found.
*/
- (SBArray*) allKeysForObject:(id)anObject;
/*!
  @method allValues
  @discussion
  Returns an array containing all of the values (in arbitrary order) of the receiver's key-value
  pairs.
  
  Returns nil if the dictionary is empty.
*/
- (SBArray*) allValues;
/*!
  @method isEqualToDictionary:
  @discussion
  Returns YES if the receiver and otherDictionary have the same number of key-value pairs and
  all of the keys defined in the receiver are defined in otherDictionary with a value equivalent
  to that of the receiver (under the isEqual: method).
*/
- (BOOL) isEqualToDictionary:(SBDictionary*)otherDictionary;
/*!
  @method objectEnumerator
  @discussion
  Returns an SBEnumerator object that iterates over the values defined in the receiver.
*/
- (SBEnumerator*) objectEnumerator;
/*!
  @method objectsForKeys:
  @discussion
  Convenience method which invoked objectsForKeys:notFoundMarker: with the SBNull object as
  the marker for undefined keys.
*/
- (SBArray*) objectsForKeys:(SBArray*)keys;
/*!
  @method objectsForKeys:notFoundMarker:
  @discussion
  Given an array of keys, return an array of equal size which contains at each index the
  value associated with that key in the receiver.  At indices for which the key is not
  contained in the receiver, the "marker" object is substituted.
*/
- (SBArray*) objectsForKeys:(SBArray*)keys notFoundMarker:(id)marker;
/*!
  @method keysSortedUsingSelector:
  @discussion
  Akin to the allKeys method, this method returns the array of keys sorted according to the
  provided comparator selector.  Each key in the receiver must respond to the comparator
  selector; the selector must take a single argument and return SBComparisonResult:
  <pre>
    - (SBComparisonResult) compareWithObject:(id)otherObject;
  </pre>
*/
- (SBArray*) keysSortedUsingSelector:(SEL)comparator;
/*!
  @method makeObjectsPerformSelector:
  @discussion
  Send the specified message (aSelector) to all of the value objects in the receiver.  The
  message should be encoded and passed to this method using the \@selector() directive.
  
  The method should take no arguments, e.g.
  <pre>
    - (void) thisIsAnAppropriateMethod;
  </pre>
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector;
/*!
  @method makeObjectsPerformSelector:withObject:
  @discussion
  Send the specified message (aSelector) to all of the value objects in the receiver.  The
  message should be encoded and passed to this method using the \@selector() directive.
  
  The method should take a single object as its argument, e.g.
  <pre>
    - (void) thisIsAnAppropriateMethodToo:(id)argument;
  </pre>
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument;

@end

/*!
  @category SBDictionary(SBDictionaryCreation)
  @discussion
  Groups methods that create and initialize SBDictionary objects.
*/
@interface SBDictionary(SBDictionaryCreation)

/*!
  @method dictionary
  @discussion
  Returns a newly-allocated, autoreleased dictionary containing no key-value pairs.
*/
+ (id) dictionary;
/*!
  @method dictionaryWithDictionary:
  @discussion
  Returns a newly-allocated, autoreleased dictionary which constains the key-value pairs in
  dict.
*/
+ (id) dictionaryWithDictionary:(SBDictionary*)dict;
/*!
  @method dictionaryWithObject:forKey:
  @discussion
  Returns a newly-allocated, autoreleased dictionary which contains the provided key-value pair.
*/
+ (id) dictionaryWithObject:(id)object forKey:(id)aKey;
/*!
  @method dictionaryWithObjects:forKeys:
  
  Returns a newly-allocated, autoreleased dictionary which contains one or more key-value
  pairs.  The keys and objects are taken in pairs from the objects and keys arrays; the
  object at index 0 in keys is matched with the object at index 0 in objects, etc.
*/
+ (id) dictionaryWithObjects:(SBArray*)objects forKeys:(SBArray*)keys;
/*!
  @method dictionaryWithObjects:forKeys:count:
  
  Returns a newly-allocated, autoreleased dictionary which contains one or more key-value
  pairs.  The keys and objects arguments both point to C arrays holding count objects:
  objects[0] and keys[0] form the first key-value pair, etc.
*/
+ (id) dictionaryWithObjects:(id*)objects forKeys:(id*)keys count:(unsigned)count;
/*!
  @method dictionaryWithObjectsAndKeys:,...
  @discussion
  Returns a newly-allocated, autoreleased dictionary which intially contains the key-value
  pairs provided as a variable-length argument list.  The list must be terminated by a nil
  value, and key-value pairs should appear in reverse order -- object and then the
  key:
  <pre>
    aDictionary = [SBDictionary dictionaryWithObjectsAndKeys:obj1,key1,obj2,key2,nil];
  </pre>
*/
+ (id) dictionaryWithObjectsAndKeys:(id)firstObject, ...;
/*!
  @method initWithObjects:forKeys:
  
  Initializes a dictionary to contain one or more key-value pairs.  The keys and objects are
  taken in pairs from the objects and keys arrays; the object at index 0 in keys is matched
  with the object at index 0 in objects, etc.
*/
- (id) initWithObjects:(SBArray*)objects forKeys:(SBArray*)keys;
/*!
  @method initWithObjects:forKeys:count:
  
  Initializes a dictionary to contain one or more key-value pairs.  The keys and objects
  arguments both point to C arrays holding count objects: objects[0] and keys[0] form the
  first key-value pair, etc.
*/
- (id) initWithObjects:(id *)objects forKeys:(id *)keys count:(unsigned)count;
/*!
  @method initWithObjectsAndKeys:,...
  @discussion
  Initializes a dictionary to contain the key-value pairs provided as a variable-length argument
  list.  The list must be terminated by a nil value, and key-value pairs should appear in reverse
  order -- object and then the key:
  <pre>
    aDictionary = [[SBDictionary alloc] initWithObjectsAndKeys:obj1,key1,obj2,key2,nil];
  </pre>
*/
- (id) initWithObjectsAndKeys:(id)firstObject, ...;
/*!
  @method initWithObject:andArguments:
  @discussion
  Initializes a dictionary to contain the key-value pairs provided as a variable-length argument
  list.  The list must be terminated by a nil value, and key-value pairs should appear in reverse
  order -- object and then the key.
  
  This method sits behind the initWithObjectsAndKeys:,... method and is public for the sake of
  allowing other variable argument list functions to create dictionaries.
*/
- (id) initWithObject:(id)firstObject andArguments:(va_list)arguments;
/*!
  @method initWithDictionary:
  @discussion
  Initializes a dictionary to contain the key-value pairs defined in otherDictionary.
*/
- (id) initWithDictionary:(SBDictionary*)otherDictionary;

@end

/*!
  @class SBMutableDictionary
  @abstract Mutable collection of keyed objects
  @discussion
  Instances of SBMutableDictionary represent a collection of objects, keyed by objects just
  as SBDictionary is.  The only difference is that a mutable dictionary can be modified after it
  is initialized:  key-value pairs can be added and removed.
  
  Subclasses of SBMutableDictionary must <i>at least</i> implement the following primary methods:
  <ul>
    <li>- (void) setObject:(id)anObject forKey:(id)aKey;</li>
    <li>- (void) removeObjectForKey:(id)aKey;</li>
  </ul>
  Any subclass that implements these two methods will automatically inherit functional versions
  of the methods in the SBExtendedMutableDictioary category; the default implementations of these methods
  <i>only</i> make use of the aforementioned primary methods (as well as each other).  Of
  course, subclasses can also override any of the methods in the SBExtendedMutableDictioary category
  with their own optimal implementations.  Subclasses are responsible for providing their own object
  creation methods.
*/
@interface SBMutableDictionary : SBDictionary
/*!
  @method setObject:forKey:
  @discussion
  Add a new key-value pair to the receiver.  If aKey already exists, the old
  value object associated with it will be replaced by anObject.
  
  If the receiver is a fixed-capacity mutable dictionary and the capacity has been reached, the
  method has no effect on the receiver.
*/
- (void) setObject:(id)anObject forKey:(id)aKey;
/*!
  @method removeObjectForKey:
  @discussion
  If aKey exists in the receiver, remove that key-value pair.
*/
- (void) removeObjectForKey:(id)aKey;

@end

/*!
  @category SBMutableDictionary(SBExtendedMutableDictionary)
  @discussion
  Groups methods which extend the basic functionality of an SBMutableDictionary.  All methods' default
  implementation is accessible by any proper subclass of SBMutableDictionary.
*/
@interface SBMutableDictionary(SBExtendedMutableDictionary)
/*!
  @method addElementsFromDictionary:
  @discussion
  Add all of the key-value pairs defined in otherDictionary to the receiver.  For any keys in
  otherDictionary which are already present in the receiver, the value from otherDictionary will
  overwrite the existing value in the receiver.
  
  If the receiver is a fixed-capacity mutable dictionary and the capacity is reached, the remaining
  key-value pairs from otherDictionary are not added.
*/
- (void) addElementsFromDictionary:(SBDictionary*)otherDictionary;
/*!
  @method removeAllObjects
  @discussion
  Remove all key-value pairs in the receiver; the result will be an empty dictionary.
*/
- (void) removeAllObjects;
/*!
  @method removeObjectsWithObject:
  @discussion
  Remove all key-value pairs in the receiver which have a value that matches (under the isEqual:
  method) object.
*/
- (void) removeObjectsWithObject:(id)object;
/*!
  @method removeObjectsForKeys:
  @discussion
  Remove any key-value pairs in the receiver which have a key that matches (under the isEqual:
  method) an object in keyArray.
*/
- (void) removeObjectsForKeys:(SBArray*)keyArray;
/*!
  @method setDictionary:
  @discussion
  Removes all key-value pairs from the receiver and adds all key-value pairs from otherDictionary.
  If the receiver is a fixed-capacity mutable dictionary and the capacity is reached, the remaining
  key-value pairs from otherDictionary are not added.
*/
- (void) setDictionary:(SBDictionary*)otherDictionary;

@end

/*!
  @method SBMutableDictionary(SBMutableDictionaryCreation)
  @discussion
  Groups methods which create SBMutableDictionary objects.  SBMutableDictionary also inherits and
  implements all of the creation methods of SBDictionary.
*/
@interface SBMutableDictionary(SBMutableDictionaryCreation)
/*!
  @method dictionaryWithFixedCapacity:
  @discussion
  Returns a newly-initialized, autoreleased mutable dictionary that can store at most maxItems
  key-value pairs.
*/
+ (id) dictionaryWithFixedCapacity:(SBUInteger)maxItems;
/*!
  @method initWithFixedCapacity:
  @discussion
  Initializes a mutable dictionary that can store at most maxItems key-value pairs.
*/
- (id) initWithFixedCapacity:(SBUInteger)maxItems;

@end

/*!
  @category SBDictionary(SBStringPairFiles)
  @discussion
  Methods for creating dictionaries from files containing string-oriented key-value pairs.
*/
@interface SBDictionary(SBStringPairFiles)

/*!
  @method dictionaryWithStringPairFile:
  @discussion
  Returns an newly-created, autoreleased dictionary which contains the key-value pairs contained
  in the file specified by path.  Both key and value objects will be SBString instances.
  
  Returns nil if the file could not be read or if there are no key-value pairs in the file.
*/
+ (id) dictionaryWithStringPairFile:(SBString*)path;

@end

/*!
  @category SBMutableDictionary(SBStringPairFiles)
  @discussion
  Methods for augmenting a mutable dictionary using string-oriented key-value pairs contained
  in a file.
*/
@interface SBMutableDictionary(SBStringPairFiles)

/*!
  @method addElementsFromStringPairFile:
  @discussion
  Attempts to read key-value pairs from the file specified by path.  Both key and value objects will
  be instances of SBString.
  
  Returns the number of pairs added.
*/
- (SBUInteger) addElementsFromStringPairFile:(SBString*)path;

/*!
  @method addUniqueElementsFromStringPairFile:
  @discussion
  Attempts to read key-value pairs from the file specified by path.  Both key and value objects will
  be instances of SBString.  Only assigns incoming key-value pairs for which the key is NOT already
  defined in the receiver.
  
  Returns the number of pairs added.
*/
- (SBUInteger) addUniqueElementsFromStringPairFile:(SBString*)path;

@end
