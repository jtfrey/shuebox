//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBEnumerator.h
//
// Basic iterator.
//
// $Id$
//

#import "SBObject.h"

@class SBArray;

/*!
  @class SBEnumerator
  
  SBEnumerator is an abstract class with no concrete implementation -- only
  concrete implementations of (private) subclasses.  Instances of this
  class cluster are used to iterate over the elements of collections
  objects (e.g. arrays, dictionaries).
*/
@interface SBEnumerator : SBObject

/*!
  @method nextObject
  
  Return the next object in the collection.  Returns nil when no the full complement
  has been iterated.
*/
- (id) nextObject;
/*!
  @method allObjects
  
  Returns an array containing all of the objects remaining un-iterated by the receiver.
*/
- (SBArray*) allObjects;

@end
