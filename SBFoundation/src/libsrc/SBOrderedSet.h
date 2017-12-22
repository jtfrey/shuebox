//
// SBFoundation : ObjC Class Library for Solaris
// SBOrderedSet.h
//
// Single-occupancy, sorted, mutable array.
//
// $Id$
//

#import "SBObject.h"
#import "SBArray.h"

/*!
  @typedef SBOrderedSetComparator
  @discussion
    Type of a function that is used to order two objects.  The function
    should return an SBComparisonResult indicative of the order of
    extObject w.r.t. objectFromSet.  E.g. if extObject should occur after
    objectFromSet, the function should return SBOrderedAscending.
*/
typedef SBComparisonResult (*SBOrderedSetComparator)(id objectFromSet, id extObject);

/*!
  @class SBOrderedSet
  @discussion
    An SBOrderedSet is a mutable array of objects.  Objects are kept sorted
    in that array by means of a sorting method or function.  Objects that sort
    equivalent to an object already in the array replace that object (making
    the array single-occupancy w.r.t. object values).
*/
@interface SBOrderedSet : SBObject
{
  SBMutableArray*         _objects;
  SBOrderedSetComparator  _comparator;
  SEL                     _selector;
}

/*!
  @method initWithSelector:
  @discussion
    The receiver is initialized to an empty set.  Object ordering is established
    by means of a selector corresponding to an instance method that is prototyped
    as:
    
      - (SBComparisonResult) compareToObject:(id)otherObject
    
*/
- (id) initWithSelector:(SEL)selector;
/*!
  @method initWithComparator:
  @discussion
    The receiver is initialized to an empty set.  Object ordering is established
    by means of a comparator function (see SBOrderedSetComparator).
*/
- (id) initWithComparator:(SBOrderedSetComparator)comparator;
/*!
  @method initWithArray:andSelector:
  @discussion
    The receiver is initialized to initially contain the objects in array.  Object
    ordering is established by means of a selector corresponding to an instance method
    that is prototyped as:
    
      - (SBComparisonResult) compareToObject:(id)otherObject
    
*/
- (id) initWithArray:(SBArray*)array andSelector:(SEL)selector;
/*!
  @method initWithArray:andComparator:
  @discussion
    The receiver is initialized to initially contain the objects in array.  Object
    ordering is established by means of a comparator function (see SBOrderedSetComparator).
*/
- (id) initWithArray:(SBArray*)array andComparator:(SBOrderedSetComparator)comparator;
/*!
  @method count
  @discussion
    Returns the number of objects contained in the receiver's array.
*/
- (SBUInteger) count;
/*!
  @method objectAtIndex:
  @discussion
    Returns the object at the given index in the receiver's array.
*/
- (id) objectAtIndex:(SBUInteger)index;
/*!
  @method objectEnumerator
  @discussion
    Returns an SBEnumerator that iterates over the objects in the receiver's array from first to
    last.  Do not attempt to modify the receiver while using the enumerator!
*/
- (SBEnumerator*) objectEnumerator;
/*!
  @method reverseObjectEnumerator
  @discussion
    Returns an SBEnumerator that iterates over the objects in the receiver's array from last to
    first.  Do not attempt to modify the receiver while using the enumerator!
*/
- (SBEnumerator*) reverseObjectEnumerator;

/*!
  @method indexOfObject:
  @discussion
    If object is present in the receiver's array, returns its index.  Equality is established
    using the selector or comparator function associated with the receiver.
  
    SBNotFound is returned if object was not present.
*/
- (SBUInteger) indexOfObject:(id)object;
/*!
  @method containsObject:
  @discussion
    Similar to indexOfObject:, but returns YES if the object was present.
*/
- (BOOL) containsObject:(id)object;
/*!
  @method addObject:
  @discussion
    Attempts to insert object into the receiver's array.  If the receiver's selector/comparator
    function indicates that object already exists in the array, it is replaced with the incoming
    object.
*/
- (void) addObject:(id)object;
/*!
  @method addObjectsFromSet:
  @discussion
    Attempts to insert the objects contained in otherSet into the receiver's array.  Behaves
    similar to "n" invocations of the addObject: method.
*/
- (void) addObjectsFromSet:(SBOrderedSet*)otherSet;
/*!
  @method addObjectsFromArray:
  @discussion
    Attempts to insert the objects contained in anArray into the receiver's array.  Behaves
    similar to "n" invocations of the addObject: method.
*/
- (void) addObjectsFromArray:(SBArray*)anArray;
/*!
  @method removeObject:
  @discussion
    If object is present in the receiver's array, remove it.  Equality is established using
    the receiver's selector/comparator function.
*/
- (void) removeObject:(id)object;
/*!
  @method removeObjectAtIndex:
  @discussion
    Remove the object present at index in the receiver's array.
*/
- (void) removeObjectAtIndex:(SBUInteger)index;
/*!
  @method removeObjectsInSet:
  @discussion
    All objects in otherSet which are found in the receiver's array are removed from the
    receiver's array.  Equality is established using the receiver's selector/comparator function.
*/
- (void) removeObjectsInSet:(SBOrderedSet*)otherSet;
/*!
  @method removeObjectsInArray:
  @discussion
    All objects in anArray which are found in the receiver's array are removed from the
    receiver's array.  Equality is established using the receiver's selector/comparator function.
*/
- (void) removeObjectsInArray:(SBArray*)anArray;
/*!
  @method removeAllObjects
  @discussion
    Remove all objects from the receiver's array.
*/
- (void) removeAllObjects;

@end
