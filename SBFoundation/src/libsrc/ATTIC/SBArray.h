//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBArray.h
//
// Basic object array.
//
// $Id$
//

#import "SBObject.h"
#import "SBEnumerator.h"

/*!
  @class SBArray
  
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
