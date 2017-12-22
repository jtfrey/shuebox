//
// SBFoundation : ObjC Class Library for Solaris
// SBOrderedSet.m
//
// Single-occupancy, sorted, mutable array.
//
// $Id$
//

#import "SBOrderedSet.h"

static inline SBUInteger
__SBOrderedSetIndexOfObjectWithSelector(
	SBMutableArray*	objects,
	id              object,
  SEL             selector,
	SBUInteger*			insertIdx
)
{
	SBUInteger            min = 0, mid, max = [objects count];
	SBComparisonResult		cmp;
	
	if ( max == 0 ) {
		// Special case, there's nothing to do!
		if ( insertIdx )
			*insertIdx = 0;
		return SBNotFound;
	}
  
	max--;
	
	do {
		mid = min + (max - min) / 2;
		cmp = (SBComparisonResult)[[objects objectAtIndex:mid] perform:selector with:object];
		if ( cmp == SBOrderSame )
			return mid;
		if ( cmp == SBOrderAscending ) {
			min = mid + 1;
		} else if ( mid > 0 ) {
			max = mid - 1;
    } else {
      mid = 0;
      break;
    }
	} while ( min <= max );
	
	if ( insertIdx ) {
		// Where should it be inserted in the array?
		if ( cmp == SBOrderAscending )
			*insertIdx = mid + 1;
		else
			*insertIdx = mid;
	}
	return SBNotFound;
}

//

static inline SBUInteger
__SBOrderedSetIndexOfObjectWithComparator(
	SBMutableArray*         objects,
	id                      object,
  SBOrderedSetComparator  comparator,
	SBUInteger*             insertIdx
)
{
	SBUInteger            min = 0, mid, max = [objects count];
	SBComparisonResult		cmp;
	
	if ( max == 0 ) {
		// Special case, there's nothing to do!
		if ( insertIdx )
			*insertIdx = 0;
		return SBNotFound;
	}
  
	max--;
	
	do {
		mid = min + (max - min) / 2;
		cmp = comparator([objects objectAtIndex:mid], object);
		if ( cmp == SBOrderSame )
			return mid;
		if ( cmp == SBOrderAscending ) {
			min = mid + 1;
		} else if ( mid > 0 ) {
			max = mid - 1;
    } else {
      mid = 0;
      break;
    }
	} while ( min <= max );
	
	if ( insertIdx ) {
		// Where should it be inserted in the array?
		if ( cmp == SBOrderAscending )
			*insertIdx = mid + 1;
		else
			*insertIdx = mid;
	}
	return SBNotFound;
}

//

@implementation SBOrderedSet

  - (id) initWithSelector:(SEL)selector
  {
    if ( (self = [super init]) ) {
      _selector = selector;
    }
    return self;
  }

//

  - (id) initWithComparator:(SBOrderedSetComparator)comparator
  {
    if ( (self = [super init]) ) {
      _comparator = comparator;
    }
    return self;
  }

//

  - (id) initWithArray:(SBArray*)array
    andSelector:(SEL)selector
  {
    if ( (self = [self initWithSelector:selector]) )
      [self addObjectsFromArray:array];
    return self;
  }

//

  - (id) initWithArray:(SBArray*)array
    andComparator:(SBOrderedSetComparator)comparator
  {
    if ( (self = [self initWithComparator:comparator]) )
      [self addObjectsFromArray:array];
    return self;
  }

//

  - (void) dealloc
  {
    if ( _objects ) [_objects release];
    
    [super dealloc];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " {\n");
    if ( _objects )
      [_objects summarizeToStream:stream];
    fprintf(stream,"}\n");
  }

//

  - (SBUInteger) count
  {
    if ( _objects )
      return [_objects count];
    return 0;
  }
  
//

  - (id) objectAtIndex:(SBUInteger)index
  {
    if ( _objects )
      return [_objects objectAtIndex:index];
    return nil;
  }
  
//

  - (SBEnumerator*) objectEnumerator
  {
    if ( _objects )
      return [_objects objectEnumerator];
    return nil;
  }
  - (SBEnumerator*) reverseObjectEnumerator
  {
    if ( _objects )
      return [_objects reverseObjectEnumerator];
    return nil;
  }

//

  - (SBUInteger) indexOfObject:(id)object
  {
    if ( _objects ) {
      if ( _selector )
        return __SBOrderedSetIndexOfObjectWithSelector(_objects, object, _selector, NULL);
      if ( _comparator )
        return __SBOrderedSetIndexOfObjectWithComparator(_objects, object, _comparator, NULL);
    }
    return SBNotFound;
  }

//

  - (BOOL) containsObject:(id)object
  {
    if ( _objects ) {
      SBUInteger      i = SBNotFound;
      
      if ( _selector )
        i = __SBOrderedSetIndexOfObjectWithSelector(_objects, object, _selector, NULL);
      if ( _comparator )
        i = __SBOrderedSetIndexOfObjectWithComparator(_objects, object, _comparator, NULL);
      
      if ( i != SBNotFound )
        return YES;
    }
    return NO;
  }
  
//

  - (void) addObject:(id)object
  {
    if ( ! _objects ) {
      _objects = [[SBMutableArray alloc] init];
      [_objects addObject:object];
    } else {
      SBUInteger      insertIdx;
      SBUInteger      i = SBNotFound;
      
      if ( _selector )
        i = __SBOrderedSetIndexOfObjectWithSelector(_objects, object, _selector, &insertIdx);
      else if ( _comparator )
        i = __SBOrderedSetIndexOfObjectWithComparator(_objects, object, _comparator, &insertIdx);
      else
        return;
      
      if ( i != SBNotFound ) {
        // Replace object at index i:
        [_objects replaceObject:object atIndex:i];
      } else {
        // Insert object at index i:
        [_objects insertObject:object atIndex:insertIdx];
      }
    }
  }
  
//

  - (void) addObjectsFromSet:(SBOrderedSet*)otherSet
  {
    if ( otherSet->_objects )
      [self addObjectsFromArray:otherSet->_objects];
  }

//

  - (void) addObjectsFromArray:(SBArray*)anArray
  {
    SBUInteger    i = 0, iMax= [anArray count];
    
    while ( i < iMax )
      [self addObject:[anArray objectAtIndex:i++]];
  }

//

  - (void) removeObject:(id)object
  {
    if ( _objects ) {
      SBUInteger      i = SBNotFound;
      
      if ( _selector )
        i = __SBOrderedSetIndexOfObjectWithSelector(_objects, object, _selector, NULL);
      if ( _comparator )
        i = __SBOrderedSetIndexOfObjectWithComparator(_objects, object, _comparator, NULL);
      
      if ( i != SBNotFound )
        [_objects removeObjectAtIndex:i];
    }
  }
  
//

  - (void) removeObjectAtIndex:(SBUInteger)index
  {
    if ( _objects )
      [_objects removeObjectAtIndex:index];
  }

//

  - (void) removeObjectsInSet:(SBOrderedSet*)otherSet
  {
    if ( otherSet->_objects )
      [self removeObjectsInArray:otherSet->_objects];
  }

//

  - (void) removeObjectsInArray:(SBArray*)anArray
  {
    SBUInteger    i = 0, iMax= [anArray count];
    
    while ( i < iMax )
      [self removeObject:[anArray objectAtIndex:i++]];
  }

//

  - (void) removeAllObjects
  {
    if ( _objects )
      [_objects removeAllObjects];
  }

@end
