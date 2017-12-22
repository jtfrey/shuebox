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

typedef SBComparisonResult (*SBArraySortComparator)(id obj1, id obj2, void* context);

/*!
  @class SBArray
  @discussion
  Instances of SBArray implement a simple array of objects.  The array exists as a simple C array, rather
  than as a linked list or other such "exotic" storage method.  At any time this C array may include MORE
  slots than are actually occupied by objects -- this is an attempt to maximize efficient use of malloc'ed
  memory and decrease the number of times calls to malloc() must be made to resize the C array.
*/
@interface SBArray : SBObject
{
  unsigned int      _capacity,_count;
  id*               _array;
}

/*!
  @method array
  
  Returns an autoreleased instance of SBArray which initially is empty.
*/
+ (SBArray*) array;
/*!
  @method arrayWithInitialCapacity:
  
  Returns an autoreleased instance of SBArray which initially contains
  enough "slots" to hold capacity objects.
*/
+ (SBArray*) arrayWithInitialCapacity:(unsigned int)capacity;
/*!
  @method arrayWithObject:
  
  Returns an autoreleased instance of SBArray which initially contains
  a reference to initialObject.
*/
+ (SBArray*) arrayWithObject:(id)initialObject;
/*!
  @method arrayWithObjects:,...
  
  Returns an autoreleased instance of SBArray which initially contains
  references to initialObject plus all objects following it.  The list
  of objects should be terminated with a sentinel value of "nil", e.g.
  
    [SBArray arrayWithObjects:obj1,obj2,obj3,nil];
*/
+ (SBArray*) arrayWithObjects:(id)initialObject,...;
/*!
  @method arrayWithArray:
  
  Returns an autoreleased instance of SBArray which initially contains
  references to all of the objects contained in anArray.
*/
+ (SBArray*) arrayWithArray:(SBArray*)anArray;

/*!
  @method init
  
  Initialize a newly-allocated empty array.
*/
- (id) init;
/*!
  @method initWithInitialCapacity:
  
  Initialize a newly-allocated array to contain enough "slots" to hold
  capacity objects.
*/
- (id) initWithInitialCapacity:(unsigned int)capacity;
/*!
  @method initWithObject:
  
  Initialize a newly-allocated array to contain a reference to initialObject.
*/
- (id) initWithObject:(id)initialObject;
/*!
  @method initWithObjects:,...
  
  Initialize a newly-allocated array to contain references to initialObject
  plus all objects following it.  The list of objects should be terminated
  with a sentinel value of "nil", e.g.
  
    [[SBArray alloc] initWithObjects:obj1,obj2,obj3,nil];
    
*/
- (id) initWithObjects:(id)initialObject,...;
/*!
  @method initWithArray:
  
  Initialize a newly-allocated array to contain references to all of the objects
  contained in anArray.
*/
- (id) initWithArray:(SBArray*)anArray;

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
/*!
  @method addObject:
  
  Append an object to the receiver's array; the "object" is sent a "retain" message
  when it is added.
*/
- (void) addObject:(id)object;
/*!
  @method removeObject:
  
  Remove the first instance of an object matching "object" (by means of isEqual:) in
  the receiver's array.
*/
- (void) removeObject:(id)object;
/*!
  @method removeObjectIdenticalTo:
  
  Remove the first instance of an object matching "object" (by means of pointer comparison)
  in the receiver's array.
*/
- (void) removeObjectIdenticalTo:(id)object;
/*!
  @method removeAllObjects
  
  Purge all objects from the receiver's array.
*/
- (void) removeAllObjects;
/*!
  @method removeLastObject
  
  Purge the trailing object from the receiver's array.
*/
- (void) removeLastObject;
/*!
  @method insertObject:atIndex:
  
  Add "object" to the receiver's array at the specified "index" in the array; any extant
  objects at that index and higher are shifted up by one index position.
*/
- (void) insertObject:(id)object atIndex:(unsigned int)index;
/*!
  @method removeObjectAtIndex:
  
  Remove the object at the specified "index" in the array; any extant objects above that
  index are shifted down by one index position.
*/
- (void) removeObjectAtIndex:(unsigned int)index;
/*!
  @method replaceObject:atIndex:
  
  Convenience method that combines removing the object at "index" and inserting "object"
  at that same "index".
*/
- (void) replaceObject:(id)object atIndex:(unsigned int)index;
/*!
  @method containsObject:
  
  Locate the first instance of an object matching "object" (by means of isEqual:) in
  the receiver's array and return that index.  Returns NO if the object was
  not found in the receiver's array.
*/
- (BOOL) containsObject:(id)object;
/*!
  @method containsObjectIdenticalTo:
  
  Locate the first instance of an object matching "object" (by means of pointer comparison)
  in the receiver's array and return that index.  Returns NO if the object was
  not found in the receiver's array.
*/
- (BOOL) containsObjectIdenticalTo:(id)object;
/*!
  @method indexOfObject:
  
  Locate the first instance of an object matching "object" (by means of isEqual:) in
  the receiver's array and return that index.  Returns "SBNotFound" if the object was
  not found in the receiver's array.
*/
- (unsigned int) indexOfObject:(id)object;
/*!
  @method indexOfObjectIdenticalTo:
  
  Locate the first instance of an object matching "object" (by means of pointer comparison)
  in the receiver's array and return that index.  Returns "SBNotFound" if the object was
  not found in the receiver's array.
*/
- (unsigned int) indexOfObjectIdenticalTo:(id)object;
/*!
  @method objectEnumerator
  
  Returns an SBEnumerator that will iterate over the objects in the receiver's array, from low
  index to high.  The contents of the receiver should NOT be altered whilst using the
  SBEnumerator!
*/
- (SBEnumerator*) objectEnumerator;
/*!
  @method reverseObjectEnumerator
  
  Returns an SBEnumerator that will iterate over the objects in the receiver's array, from high
  index to low.  The contents of the receiver should NOT be altered whilst using the
  SBEnumerator!
*/
- (SBEnumerator*) reverseObjectEnumerator;
/*!
  @method sortUsingFunction:context:
  
  Sort the receiver's objects using the provided comparator function to establish the relationship
  between values.
  <pre>
    int myStringSort(id s1, id s2, void* context)
    {
      return [s1 compare:s2 options:SBStringCaseInsensitiveSearch | SBStringForcedOrderingSearch];
    }
  </pre>
  The comparator function should return values from the SBComparisonResult enumeration indicating
  the ordering of the two objects.
*/
- (void) sortUsingFunction:(SBArraySortComparator)comparator context:(void *)context;
/*!
  @method sortUsingSelector:
  
  Sort the receiver's objects by sending them the provided comparator selector.  The selector
  should model a method like SBString's compare: method:
  <pre>
    - (SBComparisonResult) compare:(SBString*)otherString;
  </pre>
  The comparator method should return values from the SBComparisonResult enumeration indicating
  the ordering of the two objects.
*/
- (void) sortUsingSelector:(SEL)comparator;
/*!
  @method makeObjectsPerformSelector:
  
  Send the message encoded in "aSelector" to all of the objects in the receiver's array.
  The selector should take zero arguments and have a void return type.
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector;
/*!
  @method makeObjectsPerformSelector:withObject:
  
  Send the message encoded in "aSelector" to all of the objects in the receiver's array.
  The selector should take one argument (of type id) and have a void return type.
*/
- (void) makeObjectsPerformSelector:(SEL)aSelector withObject:(id)argument;

@end


/*!
  @category SBArray(SBArrayAsStack)
  @discussion
  Convenience methods to treat an SBArray as an object stack.
*/
@interface SBArray(SBArrayAsStack)

/*!
  @method pushObject:
  
  Add an object to the top of the array; really just equivalent to addObject:.
*/
- (void) pushObject:(id)anObject;
/*!
  @method popObject
  
  Removes and returns the object at the top of the array.  Returns nil if no
  objects remain.
*/
- (id) popObject;

@end
