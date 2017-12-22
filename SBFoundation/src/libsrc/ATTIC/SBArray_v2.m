//
// SBFoundation : ObjC Class Library for Solaris
// SBArray.m
//
// Basic object array.
//
// $Id$
//

#import "SBArray.h"
#import "SBArrayPrivate.h"
#import "SBString.h"


void
__SBArray_FnInsertionSort(
  id*                         array,
  unsigned int                left,
  unsigned int                right,
  SBArraySortComparator       comparator,
  void*                       context
)
{
  unsigned int      i = left + 1;
  
  while ( i <= right ) {
    id              target = array[i];
    unsigned int    j = i - 1;
    
    while ( j != (unsigned int)-1 ) {
      if ( comparator(array[j], target, context) == SBOrderDescending ) {
        array[j + 1] = array[j];
        j--;
      } else {
        break;
      }
    }
    array[j + 1] = target;
    i++;
  }
}

//

void
__SBArray_SelInsertionSort(
  id*                         array,
  unsigned int                left,
  unsigned int                right,
  SEL                         comparator
)
{
  unsigned int      i = left + 1;
  
  while ( i <= right ) {
    id              target = array[i];
    unsigned int    j = i - 1;
    
    while ( j != (unsigned int)-1 ) {
      if ( ((SBComparisonResult)[array[j] perform:comparator with:target]) == SBOrderDescending ) {
        array[j + 1] = array[j];
        j--;
      } else {
        break;
      }
    }
    array[j + 1] = target;
    i++;
  }
}

//
#pragma mark -
//

@interface SBArrayEnumerator : SBEnumerator
{
  id*             _storage;
  unsigned int    _count;
  int             _delta;
}

- (id) initWithStorage:(id*)storage count:(unsigned int)count;
- (id) initWithStorage:(id*)storage count:(unsigned int)count reverse:(BOOL)reverse;

@end

@implementation SBArrayEnumerator

  - (id) initWithStorage:(id*)storage
    count:(unsigned int)count
  {
    return [self initWithStorage:storage count:count reverse:NO];
  }
  
//

  - (id) initWithStorage:(id*)storage
    count:(unsigned int)count
    reverse:(BOOL)reverse
  {
    if ( self = [super init] ) {
      _count = count;
      if ( reverse ) {
        _storage = storage + count;
        _delta = -1;
      } else {
        _storage = storage;
        _delta = +1;
      }
    }
    return self;
  }

//

  - (id) nextObject
  {
    id      obj = nil;
    if ( _count ) {
      _count--;
      obj = *_storage;
      _storage += _delta;
    }
    return obj;
  }

@end

//
#pragma mark -
//

@implementation SBArray(SBArrayPrivate)

  - (id) initWithObject:(id)firstObject
    andVArgs:(va_list)vargs
  {
    if ( self = [self init] ) {
      while ( firstObject ) {
        [self addObject:firstObject];
        firstObject = va_arg(vargs, id);
      }
    }
    return self;
  }

//

  - (BOOL) growToCapacity:(unsigned int)capacityHint
  {
    id*       storage = NULL;
    
    /* Round up: */
    capacityHint = ((capacityHint / 8) + ((capacityHint % 8) != 0)) * 8;
    
    if ( _array )
      storage = (id*)realloc(_array, sizeof(id) * capacityHint);
    else
      storage = (id*)malloc(sizeof(id) * capacityHint );
    
    if ( storage ) {
      _array = storage;
      _capacity = capacityHint;
      return YES;
    }
    return NO;
  }

//

  - (void) addUnretainedObject:(id)object
  {
    if ( (_count == _capacity) && ! [self growToCapacity:_capacity + 1] )
      return;
    
    _array[_count++] = object;
  }
  
@end

//
#pragma mark -
//

@implementation SBArray

  + (SBArray*) array
  {
    return [[[SBArray alloc] init] autorelease];
  }
  
//

  + (SBArray*) arrayWithInitialCapacity:(unsigned int)capacity
  {
    return [[[SBArray alloc] initWithInitialCapacity:capacity] autorelease];
  }
  
//

  + (SBArray*) arrayWithObject:(id)initialObject
  {
    return [[[SBArray alloc] initWithObject:initialObject] autorelease];
  }
  
//

  + (SBArray*) arrayWithObjects:(id)initialObject,
    ...
  {
    SBArray*    anArray = nil;
    va_list     vargs;
    
    if ( initialObject ) {
      va_start(vargs, initialObject);
      anArray = [[[SBArray alloc] initWithObject:initialObject andVArgs:vargs] autorelease];
      va_end(vargs);
    }
    return anArray;
  }

//

  + (SBArray*) arrayWithArray:(SBArray*)anArray
  {
    return [[[SBArray alloc] initWithArray:anArray] autorelease];
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
    }
    return self;
  }
  
//

  - (id) initWithInitialCapacity:(unsigned int)capacity
  {
    if ( (self = [self init]) && ! [self growToCapacity:capacity] ) {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (id) initWithObject:(id)initialObject
  {
    if ( self = [self init] ) {
      [self addObject:initialObject];
    }
    return self;
  }

//

  - (id) initWithObjects:(id)initialObject,
    ...
  {
    if ( initialObject ) {
      va_list   vargs;
      
      va_start(vargs, initialObject);
      self = [self initWithObject:initialObject andVArgs:vargs];
      va_end(vargs);
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (id) initWithArray:(SBArray*)anArray
  {
    if ( self = [self init] ) {
      SBEnumerator*   eObj;
      id              obj;
      
      while ( obj = [eObj nextObject] )
        [self addObject:obj];
    }
    return self;
  }

//

  - (void) dealloc
  {
    [self removeAllObjects];
    [super dealloc];
  }
  
//

  - (id) copy
  {
    return [[SBArray alloc] initWithArray:self];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    unsigned int    i = 0;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        "  count: %u\n"
        "  capacity: %u\n"
        "  {\n",
        _count,
        _capacity
      );
    while ( i < _count ) {
      if ( [_array[i] isKindOf:[SBString class]] ) {
        fprintf(stream, "    %5u: `", i);
        [(SBString*)_array[i] writeToStream:stream];
        fprintf(stream, "`\n");
      } else {
        fprintf(stream, "    %5u: %s@%p\n", i, [_array[i] name], _array[i]);
      }
      i++;
    }
    fprintf(stream,"  }\n");
  }
  
//

  - (unsigned int) count
  {
    return _count;
  }
  
//

  - (id) objectAtIndex:(unsigned int)index
  {
    return _array[index];
  }

//

  - (void) addObject:(id)object
  {
    if ( (_count == _capacity) && ! [self growToCapacity:_capacity + 1] )
      return;
    
    _array[_count++] = [object retain];
  }
  
//

  - (void) removeObject:(id)object
  {
    unsigned int      i = 0, iMax = _count;
    
    while ( i < iMax ) {
      if ( [object isEqual:_array[i]] ) {
        unsigned int  j;
        
        [_array[i] release];
        j = i;
        iMax = --_count;
        while ( j < iMax ) {
          _array[j] = _array[j + 1];
          j++;
        }
      }
      i++;
    }
  }
  
//

  - (void) removeObjectIdenticalTo:(id)object
  {
    unsigned int      i = 0, iMax = _count;
    
    while ( i < iMax ) {
      if ( _array[i] == object ) {
        unsigned int  j;
        
        [_array[i] release];
        j = i;
        iMax = --_count;
        while ( j < iMax ) {
          _array[j] = _array[j + 1];
          j++;
        }
      }
      i++;
    }
  }
  
//

  - (void) removeAllObjects
  {
    if ( _count ) {
      while ( _count-- ) {
        [_array[_count] release];
      }
      _count = 0;
    }
  }
  
//

  - (void) removeLastObject
  {
    if ( _count )
      [_array[--_count] release];
  }
  
//

  - (void) insertObject:(id)object
    atIndex:(unsigned int)index
  {
    unsigned int      iMax = _count;
    
    if ( (_count == _capacity) && ! [self growToCapacity:_capacity + 1] )
      return;
    
    if ( index > _count )
      index = _count;
    
    while ( iMax > index ) {
      _array[iMax] = _array[iMax - 1];
      iMax--;
    }
    _array[index] = [object retain];
    _count++;
  }
  
//

  - (void) removeObjectAtIndex:(unsigned int)index
  {
    if ( index < _count ) {
      unsigned int      iMax = --_count;
      
      [_array[index] release];
      while ( index < iMax ) {
        _array[index] = _array[index + 1];
        index++;
      }
    }
  }
  
//

  - (void) replaceObject:(id)object
    atIndex:(unsigned int)index
  {
    if ( index < _count ) {
      [_array[index] release];
      _array[index] = [object retain];
    }
  }

//

  - (BOOL) containsObject:(id)object
  {
    if ( [self indexOfObject:object] != SBNotFound )
      return YES;
    return NO;
  }

//

  - (BOOL) containsObjectIdenticalTo:(id)object
  {
    if ( [self indexOfObjectIdenticalTo:object] != SBNotFound )
      return YES;
    return NO;
  }

//

  - (unsigned int) indexOfObject:(id)object
  {
    unsigned int    i = 0;
    
    while ( i < _count ) {
      if ( [object isEqual:_array[i]] )
        return i;
      i++;
    }
    return SBNotFound;
  }
  
//

  - (unsigned int) indexOfObjectIdenticalTo:(id)object
  {
    unsigned int    i = 0;
    
    while ( i < _count ) {
      if ( _array[i] == object )
        return i;
      i++;
    }
    return SBNotFound;
  }

//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBArrayEnumerator alloc] initWithStorage:_array count:_count] autorelease];
  }

//

  - (SBEnumerator*) reverseObjectEnumerator
  {
    return [[[SBArrayEnumerator alloc] initWithStorage:_array count:_count reverse:YES] autorelease];
  }

//

  - (void) sortUsingFunction:(SBArraySortComparator)comparator
    context:(void *)context
  {
    if ( _count > 1 )
      __SBArray_FnInsertionSort(_array, 0, _count - 1, comparator, context);
  }

//

  - (void) sortUsingSelector:(SEL)comparator
  {
    if ( _count > 1 )
      __SBArray_SelInsertionSort(_array, 0, _count - 1, comparator);
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    unsigned int      i = 0;
    
    while ( i < _count )
      [_array[i++] perform:aSelector];
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    unsigned int      i = 0;
    
    while ( i < _count )
      [_array[i++] perform:aSelector with:argument];
  }

@end

//
#pragma mark -
//

@implementation SBArray(SBArrayAsStack)

  - (void) pushObject:(id)anObject
  {
    [self addObject:anObject];
  }
  
//

  - (id) popObject
  {
    id                obj = nil;
    unsigned int      index = [self count];
    
    if ( index-- ) {
      obj = [self objectAtIndex:index];
      [self removeLastObject];
    }
    return obj;
  }

@end
