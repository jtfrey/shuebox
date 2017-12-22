//
// SBFoundation : ObjC Class Library for Solaris
// SBArray.h
//
// Basic object array.
//
// $Id$
//

#import "SBObject.h"
#import "SBEnumerator.h"

/*!
  @header SBArray.h
  @discussion
  SBArray represents the public interface to an entire cluster of classes devoted to the
  task of managing ordered, indexed collections of objects.
  
  <b>Implementation Details</b>
  <blockquote>
    A little inside info, the actual class cluster under SBArray looks like this:
    <ul>
      <li>SBArray
        <ul>
          <li>SBNullArray</li>
          <li>SBSubArray</li>
          <li>SBConcreteArray
            <ul>
              <li>SBTinyConcreteArray</li>
              <li>SBSmallConcreteArray</li>
              <li>SBMediumConcreteArray</li>
              <li>SBLargeConcreteArray</li>
              <li>SBConcreteArraySubArray</li>
            </ul>
          </li>
          <li>SBMutableArray
            <ul>
              <li>SBConcreteMutableArray</li>
            </ul>
          </li>
        </ul>
      </li>
    </ul>
    There are two abstract subclasses of SBArray.  SBNullArray represents an immutable
    array which contains no objects.  Since instances of SBArray are immutable, the
    SBSubArray class is returned by the subarrayWithRange: method; instances retain a
    reference to the parent array and call-through to the parent's objectAtIndex: method
    with an index altered according to the provided range.  SBMutableArray instances,
    being mutable, return an SBConcreteArray when sent the subarrayWithRange: message.
    
    The concrete implementations of SBArray (SBTinyConcreteArray, et al.) differ only in
    their capacity and how they store their constituent objects.  The tiny, small, and
    medium types all include a static C array in their instance variable list, so no
    additional allocations are necessary beyond creating the array object itself.  These
    three classes have capacities of 4, 8, and 16 objects, respectively.  The
    SBLargeConcreteArray will handle any object capacity and allocates its C array from
    the heap.
  </blockquote>
*/

/*!
  @typedef SBArraySortComparator
  @discussion
  Callback function used by the sortUsingFunction:context: method of SBMutableArray to compare
  two values from the array for ordering.
*/
typedef SBComparisonResult (*SBArraySortComparator)(id obj1, id obj2, void* context);

/*!
  @class SBArray
  @discussion
  Instances of the SBArray class (like many array types) represent a collection of objects which
  are keyed by integral indices.  The contents of the array are accessed by means of these indices;
  valid indices run from zero through one less than the number of objects in the array.
  
  Subclasses of SBArray must <i>at least</i> implement the two primary methods:
  <ul>
    <li>- (unsigned int) count</li>
    <li>- (id) objectAtIndex:(unsigned int) index</li>
  </ul>
  plus the following initializers:
  <ul>
    <li>- (id) init</li>
    <li>- (id) initWithObjects:count:</li>
  </ul>
  Any subclass that implements these methods will automatically inherit functional versions
  of the methods in the SBExtendedArray category; the default implementations of these methods
  <i>only</i> make use of the two aforementioned primary methods (as well as each other).  Of
  course, subclasses can also override any of the methods in the SBExtendedArray category with
  their own optimal implementations.  Subclasses are responsible for providing their own object
  creation methods.
  
  SBArray instances are immutable -- their content cannot be modified after they are created.
  If you need an array which allows objects to be added, removed, and reordered, the
  SBMutableArray class is the solution.
  
  Objects added to an SBArray are always sent the retain message in order to obtain a
  reference copy; when an object is evicted from an SBArray it is sent the release message.
*/
@interface SBArray : SBObject <SBMutableCopying>

/*!
  @method count
  
  Returns the number of objects stored in the receiver.
*/
- (unsigned int) count;
/*!
  @method objectAtIndex:
  
  Returns the object associated with a specific index in the receiver.
*/
- (id) objectAtIndex:(unsigned int)index;

@end

/*!
  @category SBArray(SBArrayCreation)
  @discussion
  Groups methods that create and initialize SBArray objects.
*/
@interface SBArray(SBArrayCreation)

/*!
  @method array
  
  Returns an autoreleased instance that contains no objects.
*/
+ (id) array;
/*!
  @method arrayWithObject:
  
  Returns an autoreleased instance that contains initialObject.
*/
+ (id) arrayWithObject:(id)initialObject;
/*!
  @method arrayWithObjects:,...
  
  Returns an autoreleased instance that contains initialObject plus all objects following it
  in the argument list.  The list of objects should be terminated with a sentinel value of
  "nil", e.g.
  <pre>
    [SBArray arrayWithObjects:obj1,obj2,obj3,nil];
  </pre>
*/
+ (id) arrayWithObjects:(id)initialObject,...;
/*!
  @method arrayWithObjects:count:
  
  Returns an autoreleased instance that contains the objects contained in initialObjects &mdash;
  a C array of object pointers (type "id").
*/
+ (id) arrayWithObjects:(id*)initialObjects count:(unsigned int)count;
/*!
  @method arrayWithArray:
  
  Returns an autoreleased instance that contains all of the objects contained in anArray.
*/
+ (id) arrayWithArray:(SBArray*)anArray;
/*!
  @method init
  
  Initialize a newly-allocated empty array.
*/
- (id) init;
/*!
  @method initWithObject:
  
  Initialize a newly-allocated instance to contain a reference to initialObject.
*/
- (id) initWithObject:(id)initialObject;
/*!
  @method initWithObjects:,...
  
  Initialize a newly-allocated instance to contain references to initialObject
  plus all objects following it in the argument list.  The list of objects should
  be terminated with a sentinel value of "nil", e.g.
  <pre>
    [[SBArray alloc] initWithObjects:obj1,obj2,obj3,nil];
  </pre>
*/
- (id) initWithObjects:(id)initialObject,...;
/*!
  @method initWithObject:andArguments:
  
  Initialize a newly-allocated instance to contain references to initialObject
  plus all objects contained in the variable argument list "arguments."  The
  objects in "arguments" should be terminated with a sentinel value of "nil"
  as described for initWithObjects:... .
*/
- (id) initWithObject:(id)initialObject andArguments:(va_list)arguments;
/*!
  @method initWithObjects:count:
  
   Initialize a newly-allocated instance to contain references to the objects
   contained in initialObjects &mdash; a C array of object pointers (type "id").
*/
- (id) initWithObjects:(id*)initialObjects count:(unsigned int)count;
/*!
  @method initWithArray:
  
  Initialize a newly-allocated instance to contain references to all of the objects
  contained in anArray.
*/
- (id) initWithArray:(SBArray*)anArray;

@end

/*!
  @category SBArray(SBExtendedArray)
  @discussion
  Groups methods that extend the basic functionality of SBArray.  All methods' default
  implementation is accessible by any proper subclass of SBArray.
*/
@interface SBArray(SBExtendedArray)

/*!
  @method firstObject
  
  Returns the object with index zero, or nil if the array contains no objects.
*/
- (id) firstObject;
/*!
  @method firstObject
  
  Returns the object at the final index in the array, or nil if the array contains
  no objects.
*/
- (id) lastObject;
/*!
  @method firstObjectInCommonWithArray:
  
  Starting from the zero-index object in the receiver, iterate upward until one of
  its objects matches the objects contained in otherArray.  Returns the first match
  that is found; if no match is found, returns nil.
*/
- (id) firstObjectInCommonWithArray:(SBArray*)otherArray;
/*!
  @method getObjects:
  
  Copies all of the objects contained in the receiver to the "objects" C array.  The C
  array must be at least as large as the number of objects in the receiver, as determined
  by the "count" method.
*/
- (void) getObjects:(id*)objects;
/*!
  @method getObjects:inRange:
  
  Copies a specific range of the objects contained in the receiver to the "objects" C array.
  The C array must be at least as large as the range in question.
*/
- (void) getObjects:(id*)objects inRange:(SBRange)range;
/*!
  @method containsObject:
  
  Returns YES if the receiver contains an object that is equivalent to anObject.  The objects
  are compared using the isEqual: method.
*/
- (BOOL) containsObject:(id)anObject;
/*!
  @method containsObject:inRange:
  
  Returns YES if the specific range of objects in the receiver contains an object that is
  equivalent to anObject.  The objects are compared using the isEqual: method.
*/
- (BOOL) containsObject:(id)anObject inRange:(SBRange)range;
/*!
  @method containsObjectIdenticalTo:
  
  Returns YES if the receiver contains an object that is equivalent to anObject.  The objects
  are compared using pointer comparison.
*/
- (BOOL) containsObjectIdenticalTo:(id)anObject;
/*!
  @method containsObjectIdenticalTo:inRange:
  
  Returns YES if the specific range of objects in the receiver contains an object that is
  equivalent to anObject.  The objects are compared using pointer comparison.
*/
- (BOOL) containsObjectIdenticalTo:(id)anObject inRange:(SBRange)range;
/*!
  @method indexOfObject:
  
  Returns the index of the first object in the receiver which is equivalent to anObject.  The
  objects are compared using the isEqual: method.
*/
- (unsigned int) indexOfObject:(id)anObject;
/*!
  @method indexOfObject:inRange:
  
  Returns the index of the first object in the receiver in the specific range of objects which
  is equivalent to anObject.  The objects are compared using the isEqual: method.
*/
- (unsigned int) indexOfObject:(id)anObject inRange:(SBRange)range;
/*!
  @method indexOfObjectIdenticalTo:
  
  Returns the index of the first object in the receiver which is equivalent to anObject.  The
  objects are compared using pointer comparison.
*/
- (unsigned int) indexOfObjectIdenticalTo:(id)anObject;
/*!
  @method indexOfObjectIdenticalTo:inRange:
  
  Returns the index of the first object in the receiver in the specific range of objects which
  is equivalent to anObject.  The objects are compared using pointer comparison.
*/
- (unsigned int) indexOfObjectIdenticalTo:(id)anObject inRange:(SBRange)range;
/*!
  @method subarrayWithRange:
  
  Returns a new array which contains all of the objects in the receiver which fall within range.
*/
- (SBArray*) subarrayWithRange:(SBRange)range;
/*!
  @method objectEnumerator
  
  Returns an SBEnumerator object which iterates over the objects in the receiver, from the first
  to the last index.
*/
- (SBEnumerator*) objectEnumerator;
/*!
  @method reverseObjectEnumerator
  
  Returns an SBEnumerator object which iterates over the objects in the receiver, from the last
  to the first index.
*/
- (SBEnumerator*) reverseObjectEnumerator;
/*!
  @method makeObjectsPerformSelector:
  
  Send the specified message (aSelector) to all of the objects in the receiver.  The message
  should be encoded and passed to this method using the \@selector() directive.
  
  The method should take no arguments, e.g.
  <pre>
    - (void) thisIsAnAppropriateMethod;
  </pre>
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector;
/*!
  @method makeObjectsPerformSelector:withObject:
  
  Send the specified message (aSelector) to all of the objects in the receiver with one argument
  included in the invocation.  The message should be encoded and passed to this method using the
  \@selector() directive.
  
  The method should take a single object as its argument, e.g.
  <pre>
    - (void) thisIsAnAppropriateMethodToo:(id)argument;
  </pre>
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument;
/*!
  @method isEqualToArray:
  
  Returns YES if the receiver and otherArray have the same number of objects and the objects at
  each index are equivalent under the isEqual: method.
*/
- (BOOL) isEqualToArray:(SBArray*)otherArray;
/*!
  @method componentsJoinedByString:
  
  For all elements of the receiver array which conform to the SBStringValue protocol, create a list
  of those string values concatenated by the given separator string.
*/
- (SBString*) componentsJoinedByString:(SBString*)separator;
/*!
  @method writeToStream:
  
  Writes a brief description to the given stream.
*/
- (void) writeToStream:(FILE*)stream;

@end

/*!
  @class SBMutableArray
  @discussion
  Instances of SBMutableArray represent a collection of objects, keyed by integral indices just
  as SBArray is.  The only difference is that a mutable array can be modified after it is
  initialized:  objects can be added, removed, and moved.
  
  Subclasses of SBMutableArray must <i>at least</i> implement the following primary methods:
  <ul>
    <li>- (void) insertObject:(id)object atIndex:(unsigned int)index;</li>
    <li>- (void) removeObjectAtIndex:(unsigned int)index;</li>
    <li>- (void) addObject:(id)object;</li>
    <li>- (void) removeLastObject;</li>
    <li>- (void) replaceObject:(id)object atIndex:(unsigned int)index;</li>
  </ul>
  Any subclass that implements these five methods will automatically inherit functional versions
  of the methods in the SBExtendedMutableArray category; the default implementations of these methods
  <i>only</i> make use of the aforementioned primary methods (as well as each other).  Of
  course, subclasses can also override any of the methods in the SBExtendedMutableArray category with
  their own optimal implementations.  Subclasses are responsible for providing their own object
  creation methods.
*/
@interface SBMutableArray : SBArray

/*!
  @method insertObject:atIndex:
  
  Attempts to insert a new object into the receiver array at the specified index.  If the array has
  a fixed capacity which has been reached, the object is not added.  If the provided index lies
  outside the range of zero up to and including the number of objects in the array already, then
  the object will be added at the end of the array.
*/
- (void) insertObject:(id)object atIndex:(unsigned int)index;
/*!
  @method removeObjectAtIndex:
  
  If the provided index lies within the range of valid indices in the receiver, the object at
  that index will be removed and all objects at indices above it will shift down accordingly.
*/
- (void) removeObjectAtIndex:(unsigned int)index;
/*!
  @method addObject:
  
  Attempts to add "object" at the next highest index in the receiver array.  If the array has a
  fixed capacity which has been reached, the object is not added.
*/
- (void) addObject:(id)object;
/*!
  @method removeLastObject
  
  If the receiver contains at least one object, remove the object at the highest defined index.
*/
- (void) removeLastObject;
/*!
  @method replaceObject:atIndex:
  
  If the provided index lies within the range of valid indices in the receiver, the object at
  that index will be removed and replaced with "object".
*/
- (void) replaceObject:(id)object atIndex:(unsigned int)index;

@end

/*!
  @category SBMutableArray(SBMutableArrayCreation)
  @discussion
  Groups methods which create and initialize SBMutableArray objects.
  
  SBMutableArray also implements the object creation and initialization methods of SBArray.
*/
@interface SBMutableArray(SBMutableArrayCreation)

/*!
  @method arrayWithFixedCapacity:
  
  Returns an autoreleased instance which can hold <i>at most</i> maxCapacity objects.
*/
+ (id) arrayWithFixedCapacity:(unsigned int)maxCapacity;
/*!
  @method initWithFixedCapacity:
  
  Initializes a mutable array that can hold <i>at most</i> maxCapacity objects.
*/
- (id) initWithFixedCapacity:(unsigned int)maxCapacity;

@end

/*!
  @category SBMutableArray(SBExtendedMutableArray)
  @discussion
  Groups methods which extend the basic functionality of SBMutableArray.  All methods'
  default implementation is accessible by any proper subclass of SBMutableArray.
*/
@interface SBMutableArray(SBExtendedMutableArray)

/*!
  @method addObjectsFromArray:
  
  Attempt to append all of the objects contained in otherArray to the receiver.  If the
  receiver has a fixed capacity, objects are added until that capacity is reached (or all
  objects from otherArray have been added).  The objects are added in the same sequence as
  they occur in otherArray.
*/
- (void) addObjectsFromArray:(SBArray*)otherArray;
/*!
  @method exchangeObjectAtIndex:withObjectAtIndex:
  
  Exchange the position of two objects in the receiver.  Useful for in-situ sorting, for
  example (indeed the default sortUsingFunction: and sortUsingSelector: implementations
  make use of this method).
*/
- (void) exchangeObjectAtIndex:(unsigned int)index1 withObjectAtIndex:(unsigned int)index2;
/*!
  @method removeAllObjects
  
  Evict all objects from the receiver array.
*/
- (void) removeAllObjects;
/*!
  @method removeObject:
  
  Locates the first occurrence of an object equivalent to anObject in the receiver and
  removes it from the array.  Equivalence is established using the isEqual: method.
*/
- (void) removeObject:(id)anObject;
/*!
  @method removeObject:inRange:
  
  Similar to removeObject: but restricts the index range over which the search for an
  equivalent object is performed.
*/
- (void) removeObject:(id)anObject inRange:(SBRange)range;
/*!
  @method removeObjectIdenticalTo:
  
  Locates the first occurrence of an object equivalent to anObject in the receiver and
  removes it from the array.  Equivalence is established using pointer comparison.
*/
- (void) removeObjectIdenticalTo:(id)anObject;
/*!
  @method removeObjectIdenticalTo:inRange:
  
  Similar to removeObjectIdenticalTo: but restricts the index range over which the search
  for an equivalent object is performed.
*/
- (void) removeObjectIdenticalTo:(id)anObject inRange:(SBRange)range;
/*!
  @method removeObjectsFromIndices:numIndices:
  
  Given a C array of indices, remove the objects in the receiver array that occur at
  those indices.  The "indices" C array should contain unique indices only -- a
  repeated index will yield undefined behavior.
  
  This method functions most efficiently if the constituent values of the "indices" array
  are sorted in ascending order.
*/
- (void) removeObjectsFromIndices:(unsigned int*)indices numIndices:(unsigned int)count;
/*!
  @method removeObjectsInArray:
  
  Remove any objects in the receiver array that are also present (via the containsObject:
  method) in otherArray.
*/
- (void) removeObjectsInArray:(SBArray*)otherArray;
/*!
  @method removeObjectsInRange:
  
  Remove all objects in the given index range of the receiver.
*/
- (void) removeObjectsInRange:(SBRange)range;
/*!
  @method replaceObjectsInRange:withObjectsFromArray:
  
  Remove all objects in the given range of indices in the receiver and replace them with all
  of the objects contained in otherArray.
*/
- (void) replaceObjectsInRange:(SBRange)range withObjectsFromArray:(SBArray*)otherArray;
/*!
  @method replaceObjectsInRange:withObjectsFromArray:range:
  
  Remove all objects in the given range of indices in the receiver and replace them with the
  objects in the provided range (otherRange) of indices in otherArray.
*/
- (void) replaceObjectsInRange:(SBRange)range withObjectsFromArray:(SBArray*)otherArray range:(SBRange)otherRange;
/*!
  @method setArray:
  
  Remove all objects from the receiver array and add the objects contained in otherArray.  The
  objects from otherArray will enter the receiver array in the same order as they occur in
  otherArray.
*/
- (void) setArray:(SBArray*)otherArray;
/*!
  @method sortUsingFunction:context:
  
  Sorts the objects in the receiver array in ascending order as defined by the comparison function
  (comparator).
  
  The comparator function's arguments are two objects to compare and the context parameter, context.
  The function should return SBOrderAscending if the first object is smaller than the second,
  SBOrderDescending if the first object is larger than the second, and SBOrderSame if the two objects
  are equal.
*/
- (void) sortUsingFunction:(SBArraySortComparator)comparator context:(void *)context;
/*!
  @method sortUsingSelector:
  
  Sorts the objects in the receiver array in ascending order as determined by sending the "comparator"
  message to the objects.
  
  The comparator message is sent to each object in the receiver and has as its single argument another
  object in the array.  The comparator method should return SBOrderAscending if the receiver is smaller
  than the argument, SBOrderDescending if the receiver is larger than the argument, and SBOrderSame
  if the receiver and argument are equal.
*/
- (void) sortUsingSelector:(SEL)comparator;

@end
