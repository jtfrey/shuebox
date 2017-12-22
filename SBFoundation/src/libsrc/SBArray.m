//
// SBFoundation : ObjC Class Library for Solaris
// SBArray.m
//
// Basic object array.
//
// $Id$
//

#import "SBArray.h"
#import "SBString.h"
#import "SBValue.h"

//

@interface SBArray(SBArrayPrivate)

+ (id) allocWithCapacity:(SBUInteger)capacity;
- (id) initWithCapacity:(SBUInteger)capacity;

@end

//
#pragma mark -
//

#define SBTinyConcreteArrayCapacity      4
#define SBSmallConcreteArrayCapacity    16
#define SBMediumConcreteArrayCapacity   48

/*!
  @class SBNullArray
  @discussion
  Direct subclass of SBArray which acts as a concrete, zero-element immutable
  array.
*/
@interface SBNullArray : SBArray

@end

/*!
  @class SBSubArray
  @discussion
  Used by SBArray and its (public) descendents to represent a sub-range of
  an immutable array.  Avoids duplicating storage by referencing the parent
  array and the index range within it.
  
  SBMutableArray handles sub-arrays by allocating a new SBArray containing
  the objects in the sub-range.
*/
@interface SBSubArray : SBArray
{
  SBArray*          _parentArray;
  SBRange           _range;
}

- (id) initWithParentArray:(SBArray*)array range:(SBRange)indices;

@end

/*!
  @class SBConcreteArray
  @discussion
  Concrete implementation of SBArray which uses a C array of id-typed values.
  This particular subclass is generic -- there are multiple subclasses of it
  which define particular array sizes.  GNU Objective-C doesn't allow for the
  addition of extra bytes to the object allocation call, otherwise we could
  always just add the id[] to the tail end of the allocated object.
*/
@interface SBConcreteArray : SBArray
{
  SBUInteger        _hash;
  SBUInteger        _count;
  BOOL              _hashIsCached;
}

- (id*) concreteStorage;

@end

@interface SBTinyConcreteArray : SBConcreteArray
{
  id                _array[SBTinyConcreteArrayCapacity];
}

@end

@interface SBSmallConcreteArray : SBConcreteArray
{
  id                _array[SBSmallConcreteArrayCapacity];
}

@end

@interface SBMediumConcreteArray : SBConcreteArray
{
  id                _array[SBMediumConcreteArrayCapacity];
}

@end

@interface SBLargeConcreteArray : SBConcreteArray
{
  id*               _array;
}

@end

/*!
  @class SBConcreteArraySubArray
  @discussion
  Class which handles sub-arrays of the immutable SBConcreteArray class cluster.
  Very similar to SBSubArray, but since the parent array is immutable this
  variant actually makes a local copy of the base pointer in the sub-range of
  the parent array's id[].
*/
@interface SBConcreteArraySubArray : SBConcreteArray
{
  SBConcreteArray*  _parentArray;
  id*               _array;
}

- (id) initWithParentArray:(SBConcreteArray*)array range:(SBRange)indices;

@end

/*!
  @typedef SBArrayBucket
  @discussion
  Concrete mutable arrays exist as zero or more "buckets" which wrap a C
  array of id-typed values.  Each "bucket" represents a range of array slots
  starting at some base index.
*/
typedef struct SBArrayBucket {
  struct SBArrayBucket*     fLink;
  struct SBArrayBucket*     pLink;
  SBUInteger                used;
  SBUInteger                available;
  id                        slots[1];
} SBArrayBucket;

/*!
  @class SBConcreteMutableArray
  @discussion
  Concrete implementation of SBMutableArray.  Contents of the array are
  stored in "buckets" which each contain a number of slots.  A "bucket"
  is defined as a node of a doubly-linked list, so adding a new "bucket"
  involves dynamically allocating a chuck of memory and linking it to tail
  of the existing list of "buckets" for the mutable array.  This circumvents
  the problems associated with using a single C array and realloc'ing it as
  it grows.
*/
@interface SBConcreteMutableArray : SBMutableArray
{
  SBUInteger        _count;
  SBUInteger        _capacity;
  SBUInteger        _hash;
  SBUInteger        _bucketCount;
  SBArrayBucket*    _topBucket;
  SBArrayBucket*    _buckets;
  struct {
    unsigned int    countIsCached : 1;
    unsigned int    hashIsCached : 1;
    unsigned int    fixedCapacity : 1;
  } _flags;
}

- (BOOL) addCapacity:(SBUInteger)capacity;

@end

//
#pragma mark -
//

@interface SBSimpleArrayEnumerator : SBEnumerator
{
  id                _parent;
  SBUInteger        _curIndex;
  SBUInteger        _finalIndex;
  SBInteger         _delta;
  struct {
    unsigned int    inited : 1;
    unsigned int    completed : 1;
  } _options;
}

- (id) initWithParentArray:(SBArray*)parent delta:(SBInteger)delta;

@end

@implementation SBSimpleArrayEnumerator

  - (id) initWithParentArray:(SBArray*)parent
    delta:(int)delta
  {
    if ( self = [super init] ) {
      _parent = [parent retain];
      _delta = delta;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _parent ) [_parent release];
    [super dealloc];
  }

//

  - (id) nextObject
  {
    id      obj = nil;
    
    if ( ! _options.inited ) {
      _curIndex = [_parent count];
      if ( _delta == -1 ) {
        _finalIndex = 0;
        _curIndex--;
      } else {
        _finalIndex = _curIndex - 1;
        _curIndex = 0;
      }
      _options.inited = YES;
      _options.completed = ( _curIndex < 0 ? YES : NO );
    }
    if ( ! _options.completed ) {
      obj = [_parent objectAtIndex:_curIndex];
      if ( _curIndex == _finalIndex ) {
        _options.completed = YES;
      } else {
        _curIndex += _delta;
      }
    }
    return obj;
  }

@end

//
#pragma mark -
//

static SBArray* __SBNullArray = nil;

@implementation SBArray

  + initialize
  {
    if ( __SBNullArray == nil ) {
      __SBNullArray = [[SBNullArray alloc] init];
    }
  }

//

  + (id) alloc
  {
    if ( self == [SBArray class] )
      return [SBLargeConcreteArray alloc];
    return [super alloc];
  }

//

  - (id) copy
  {
    return [self retain];
  }

//

  - (id) mutableCopy
  {
    return [[SBConcreteMutableArray alloc] initWithArray:self];
  }

//

  - (SBUInteger) count
  {
    return 0;
  }
  
//

  - (id) objectAtIndex:(SBUInteger)index
  {
    return nil;
  }

//
#pragma mark SBKeyValueCoding additions
//

  - (id) valueForKey:(SBString*)aKey
  {
    if ( [aKey isEqual:@"@count"] )
      return [SBNumber numberWithUnsignedInt:[self count]];
    return [super valueForKey:aKey];
  }

@end

@implementation SBArray(SBArrayPrivate)

  + (id) allocWithCapacity:(SBUInteger)capacity
  {
    if ( capacity <= SBTinyConcreteArrayCapacity ) {
      return [SBTinyConcreteArray alloc];
    }
    if ( capacity <= SBSmallConcreteArrayCapacity ) {
      return [SBSmallConcreteArray alloc];
    }
    if ( capacity <= SBMediumConcreteArrayCapacity ) {
      return [SBMediumConcreteArray alloc];
    }
    return [SBLargeConcreteArray alloc];
  }

//

  - (id) initWithCapacity:(SBUInteger)capacity
  {
    return [self init];
  }

@end

@implementation SBArray(SBArrayCreation)

  + (id) array
  {
    return __SBNullArray;
  }
  
//

  + (id) arrayWithObject:(id)initialObject
  {
    return [[[self allocWithCapacity:1] initWithObject:initialObject] autorelease];
  }
  
//

  + (id) arrayWithObjects:(id)initialObject,...
  {
    id              newArray;
    va_list         vargs;
    SBUInteger      count = 0;
    id              obj = initialObject;
    
    va_start(vargs, initialObject);
    while ( obj ) {
      count++;
      obj = va_arg(vargs, id);
    }
    va_end(vargs);
    
    if ( count ) {
      va_start(vargs, initialObject);
      newArray = [[[self allocWithCapacity:count] initWithObject:initialObject andArguments:vargs] autorelease];
      va_end(vargs);
    } else {
      newArray = [self array];
    }
    return newArray;
  }
  
//

  + (id) arrayWithObjects:(id*)initialObjects
    count:(SBUInteger)count
  {
    return [[[self allocWithCapacity:count] initWithObjects:initialObjects count:count] autorelease];
  }
  
//

  + (id) arrayWithArray:(SBArray*)anArray
  {
    return [[[self allocWithCapacity:[anArray count]] initWithArray:anArray] autorelease];
  }
  
//

  - (id) init
  {
    return [super init];
  }
  
//

  - (id) initWithObject:(id)initialObject
  {
    return [self initWithObjects:&initialObject count:1];
  }
  
//

  - (id) initWithObjects:(id)initialObject,...
  {
    va_list     vargs;
    
    va_start(vargs, initialObject);
    self = [self initWithObject:initialObject andArguments:vargs];
    va_end(vargs);
    
    return self;
  }
  
//

  - (id) initWithObjects:(id*)initialObjects
    count:(SBUInteger)count
  {
    return [self init];
  }
  
//

  - (id) initWithObject:(id)initialObject
    andArguments:(va_list)arguments
  {
    SBUInteger        count = 0;
    id                obj;
    
    if ( initialObject ) {
      va_list         argv;
      
      count++;
      // How many in the var arg list?
      va_copy(argv, arguments);
      while ( (obj = va_arg(argv, id)) )
        count++;
      va_end(argv);
      if ( count == 1 ) {
        // Single object only:
        self = [self initWithObjects:&initialObject count:1];
      } else {
        id            localObjList[24];
        id*           objList = localObjList;
        
        if ( count > 24 ) {
          objList = objc_malloc(count * sizeof(id));
        }
        if ( objList ) {
          id*         p = objList;
          
          *p++ = initialObject;
          while ( (obj = va_arg(argv, id)) )
            *p++ = obj;
          va_end(argv);
          self = [self initWithObjects:objList count:(p - objList)];
          if ( objList != localObjList )
            objc_free(objList);
        } else {
          [self release];
          self = nil;
        }
      }
    } else {
      [self release];
      self = nil;
    }
    return self;
  }
  
//

  - (id) initWithArray:(SBArray*)anArray
  {
    SBUInteger        count = [anArray count];
    
    if ( count ) {
      id              localObjList[24];
      id*             objList = localObjList;
      
      if ( count > 24 ) {
        objList = objc_malloc(count * sizeof(id));
      }
      if ( objList ) {
        [anArray getObjects:objList];
        self = [self initWithObjects:objList count:count];
        if ( objList != localObjList )
          objc_free(objList);
      } else {
        [self release];
        self = nil;
      }
    } else {
      // Empty array
      self = [self init];
    }
    return self;
  }
  
@end

@implementation SBArray(SBExtendedArray)

  - (id) firstObject
  {
    if ( [self count] )
      return [self objectAtIndex:0];
    return nil;
  }
  
//

  - (id) lastObject
  {
    SBUInteger      count = [self count];
      
    if ( count )
      return [self objectAtIndex:--count];
    return nil;
  }
  
//

  - (id) firstObjectInCommonWithArray:(SBArray*)otherArray
  {
    id        result = nil;
    
    // Walk our objects, doing a containsObject: against otherArray:
    SBUInteger        i = 0, iMax = [self count];
    
    while ( ! result && (i < iMax) ) {
      id              obj = [self objectAtIndex:i++];
      
      if ( [otherArray containsObject:obj] )
        result = obj;
    }
    return result;
  }
  
//

  - (void) getObjects:(id*)objects
  {
    [self getObjects:objects inRange:SBRangeCreate(0, [self count])];
  }
  - (void) getObjects:(id*)objects
    inRange:(SBRange)range
  {
    // Walk our objects, copying them into the objects array:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    
    if ( iMax > [self count] )
      iMax = [self count];
    
    while ( i < iMax )
      *objects++ = [self objectAtIndex:i++];
  }
  
//
      
  - (BOOL) containsObject:(id)anObject
  {
    return [self containsObject:anObject inRange:SBRangeCreate(0, [self count])];
  }
  - (BOOL) containsObject:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    
    if ( iMax > [self count] )
      iMax = [self count];
    
    while ( i < iMax ) {
      if ( [[self objectAtIndex:i++] isEqual:anObject] )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) containsObjectIdenticalTo:(id)anObject
  {
    return [self containsObjectIdenticalTo:anObject inRange:SBRangeCreate(0, [self count])];
  }
  - (BOOL) containsObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using == to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    
    if ( iMax > [self count] )
      iMax = [self count];
    
    while ( i < iMax ) {
      if ( [self objectAtIndex:i++] == anObject )
        return YES;
    }
    return NO;
  }
  
//
      
  - (SBUInteger) indexOfObject:(id)anObject
  {
    return [self indexOfObject:anObject inRange:SBRangeCreate(0, [self count])];
  }
  - (SBUInteger) indexOfObject:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    
    if ( iMax > [self count] )
      iMax = [self count];
    
    while ( i < iMax ) {
      if ( [[self objectAtIndex:i] isEqual:anObject] )
        return i;
      i++;
    }
    return SBNotFound;
  }
  
//

  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
  {
    return [self indexOfObjectIdenticalTo:anObject inRange:SBRangeCreate(0, [self count])];
  }
  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using == to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    
    if ( iMax > [self count] )
      iMax = [self count];
    
    while ( i < iMax ) {
      if ( [self objectAtIndex:i] == anObject )
        return i;
      i++;
    }
    return SBNotFound;
  }
  
//

  - (SBArray*) subarrayWithRange:(SBRange)range
  {
    return [[[SBSubArray alloc] initWithParentArray:self range:range] autorelease];
  }
  
//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBSimpleArrayEnumerator alloc] initWithParentArray:self delta:1] autorelease];
  }
  
//

  - (SBEnumerator*) reverseObjectEnumerator
  {
    return [[[SBSimpleArrayEnumerator alloc] initWithParentArray:self delta:-1] autorelease];
  }
  
//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    SBUInteger        i = 0, iMax = [self count];
    
    while ( i < iMax )
      [[self objectAtIndex:i++] perform:aSelector];
  }
  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    SBUInteger        i = 0, iMax = [self count];
    
    while ( i < iMax )
      [[self objectAtIndex:i++] perform:aSelector with:argument];
  }
  
//
  
  - (BOOL) isEqualToArray:(SBArray*)otherArray
  {
    BOOL        result = NO;
    
    // Condition 1:  Equal dimension:
    SBUInteger        myCount = [self count];
    
    if ( myCount == [otherArray count] ) {
      result = YES;
      if ( myCount ) {
        // Walk our elements:
        SBUInteger    i = 0;
        
        while ( result && (i < myCount) ) {
          if ( ! [[otherArray objectAtIndex:i] isEqual:[self objectAtIndex:i]] )
            result = NO;
          i++;
        }
      }
    }
    return result;
  }

//

  - (SBString*) componentsJoinedByString:(SBString*)separator
  {
    SBString*         concatString = nil;
    SBUInteger        i = 0, iMax = [self count];
      
    if ( iMax > 0 ) {
      SBMutableString*  workString = [[SBMutableString alloc] init];
      BOOL              appendSeparator = NO;
      
      while ( i < iMax ) {
        id        obj = [self objectAtIndex:i++];
        
        if ( [obj conformsTo:@protocol(SBStringValue)] ) {
          if ( appendSeparator )
            [workString appendString:separator];
          else
            appendSeparator = YES;
          [workString appendString:[obj stringValue]];
        }
      }
      if ( [workString length] > 0 )
        concatString = (SBString*)[workString autorelease];
      else
        [workString release];
    }
    return concatString;
  }

//

  - (void) writeToStream:(FILE*)stream
  {
    SBUInteger          i = 0, iMax = [self count];
    
    fputc('{', stream);
    while ( i < iMax ) {
      id        obj = [self objectAtIndex:i];
      
      if ( i > 0 )
        fprintf(stream, ", ");
      if ( [obj isKindOf:[SBString class]] ) {
        fputc('\'', stream);
        [(SBString*)obj writeToStream:stream];
        fputc('\'', stream);
      } else {
        fprintf(stream, "%s@%p", [obj name], obj);
      }
      i++;
    }
    fputc('}', stream);
  }

@end

//
#pragma mark -
//

@implementation SBNullArray

@end

@implementation SBSubArray

  - (id) initWithParentArray:(SBArray*)array
    range:(SBRange)indices
  {
    if ( self = [super init] ) {
      SBUInteger      count = [array count];
      
      _parentArray = [array retain];
      
      if ( indices.start >= count ) {
        _range = SBEmptyRange;
      } else {
        if ( SBRangeMax(indices) > count )
          indices.length = count - indices.start;
        _range = indices;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parentArray ) [_parentArray release];
    [super dealloc];
  }

//

  - (SBUInteger) count
  {
    return _range.length;
  }

//

  - (id) objectAtIndex:(SBUInteger)i
  {
    if ( i < _range.length )
      return [_parentArray objectAtIndex:(_range.start + i)];
    return nil;
  }

@end

//
#pragma mark -
//

/*
 * Note that since this is a concrete implementation of the immutable array, we need do object locking
 * only w.r.t. alternate SBArray objects entering a method.
 *
 */
@implementation SBConcreteArray

  - (id) initWithObjects:(id*)initialObjects
    count:(SBUInteger)count
  {
    if ( self = [self initWithCapacity:count] ) {
      id*       array = [self concreteStorage];
      
      _count = count;
      while ( count-- )
        *array++ = [*initialObjects++ retain];
    }
    return self;
  }
  
//

  - (id) initWithObject:(id)initialObject
    andArguments:(va_list)arguments
  {
    id              obj = initialObject;
    SBUInteger      count = 0;
    
    if ( obj ) {
      va_list       vcopy;
      
      va_copy(vcopy, arguments);
      while ( obj ) {
        count++;
        obj = va_arg(vcopy, id);
      }
    }
    if ( self = [self initWithCapacity:count] ) {
      id*       array = [self concreteStorage];
      
      while ( initialObject ) {
        *array++ = [initialObject retain];
        _count++;
        initialObject = va_arg(arguments, id);
      }
    }
    return self;
  }
  
//

  - (id) initWithArray:(SBArray*)anArray
  {
    SBUInteger      i = 0, iMax = [anArray count];
    
    if ( self = [super initWithCapacity:iMax] ) {
      id*           array = [self concreteStorage];
      
      while ( i < iMax )
        *array++ = [[anArray objectAtIndex:i++] retain];
      _count = iMax;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    id*             array = [self concreteStorage];
    SBUInteger      i = 0;
    
    while ( i < _count )
      [array[i++] release];
    [super dealloc];
  }

//

  - (SBUInteger) hash
  {
    if ( ! _hashIsCached ) {
      SBUInteger      i = 0;
      id*             array = [self concreteStorage];
      
      _hash = 0xcafebabe;
      while ( i < _count )
        _hash += [array[i++] hash];
    }
    return _hash;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " {\n"
                    "  count = " SBUIntegerFormat "\n"
                    "  hash = %08x\n",
                _count,
                [self hash]
              );
    
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count ) {
      if ( [array[i] isKindOf:[SBString class]] ) {
        fprintf(stream, "    " SBUIntegerFormat ": `", i);
        [(SBString*)array[i] writeToStream:stream];
        fprintf(stream, "`\n");
      } else {
        fprintf(stream, "    "  SBUIntegerFormat ": %s@%p\n", i, [array[i] name], array[i]);
      }
      i++;
    }
    fprintf(stream,"}\n");
  }

//

  - (SBUInteger) count
  {
    return _count;
  }

//

  - (id*) concreteStorage
  {
    return NULL;
  }

//

  - (id) firstObject
  {
    if ( _count )
      return ([self concreteStorage])[0];
    return nil;
  }
  
//

  - (id) lastObject
  {
    if ( _count )
      return ([self concreteStorage])[_count - 1];
    return nil;
  }
  
//

  - (id) firstObjectInCommonWithArray:(SBArray*)otherArray
  {
    // Walk our objects, doing a containsObject: against otherArray:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( (i < _count) ) {
      if ( [otherArray containsObject:array[i]] )
        return array[i];
      i++;
    }
    return nil;
  }
  
//

  - (void) getObjects:(id*)objects
  {
    // Walk our objects, copying into objects:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count )
      *objects++ = array[i++];
  }
  - (void) getObjects:(id*)objects
    inRange:(SBRange)range
  {
    // Walk our objects, copying them objects:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    id*               array = [self concreteStorage];
    
    if ( iMax > _count )
      iMax = _count;
    
    while ( i < iMax )
      *objects++ = array[i++];
  }
  
//
      
  - (BOOL) containsObject:(id)anObject
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count )
      if ( [array[i++] isEqual:anObject] )
        return YES;
    return NO;
  }
  - (BOOL) containsObject:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    id*               array = [self concreteStorage];
    
    if ( iMax > _count )
      iMax = _count;
    
    while ( i < iMax )
      if ( [array[i++] isEqual:anObject] )
        return YES;
    return NO;
  }
  
//
      
  - (BOOL) containsObjectIdenticalTo:(id)anObject
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count )
      if ( array[i++] == anObject )
        return YES;
    return NO;
  }
  - (BOOL) containsObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    id*               array = [self concreteStorage];
    
    if ( iMax > _count )
      iMax = _count;
    
    while ( i < iMax )
      if ( array[i++] == anObject )
        return YES;
    return NO;
  }
  
//
      
  - (SBUInteger) indexOfObject:(id)anObject
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count ) {
      if ( [array[i] isEqual:anObject] )
        return i;
      i++;
    }
    return SBNotFound;
  }
  - (SBUInteger) indexOfObject:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    id*               array = [self concreteStorage];
    
    if ( iMax > _count )
      iMax = _count;
      
    while ( i < iMax ) {
      if ( [array[i] isEqual:anObject] )
        return i;
      i++;
    }
    return SBNotFound;
  }
  
//
      
  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count ) {
      if ( array[i] == anObject )
        return i;
      i++;
    }
    return SBNotFound;
  }
  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    // Walk our objects, using isEqual to search for a match:
    SBUInteger        i = range.start, iMax = SBRangeMax(range);
    id*               array = [self concreteStorage];
    
    if ( iMax > _count )
      iMax = _count;
      
    while ( i < iMax ) {
      if ( array[i] == anObject )
        return i;
      i++;
    }
    return SBNotFound;
  }
  
//

  - (SBArray*) subarrayWithRange:(SBRange)range
  {
    return [[[SBConcreteArraySubArray alloc] initWithParentArray:self range:range] autorelease];
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count )
      [array[i++] perform:aSelector];
  }
  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    // Walk our objects, comparing as we go:
    SBUInteger        i = 0;
    id*               array = [self concreteStorage];
    
    while ( i < _count )
      [array[i++] perform:aSelector with:argument];
  }
  
//
  
  - (BOOL) isEqualToArray:(SBArray*)otherArray
  {
    BOOL        result = NO;
    
    if ( [otherArray isKindOf:[SBConcreteArray class]] ) {
      //
      // Special case if we're BOTH SBConcreteArray instances -- we can grab the otherArray's
      // C array and walk over it!
      //
      // Condition 1:  Equal dimension:
      //
      if ( _count == [otherArray count] ) {
        result = YES;
        if ( _count ) {
          // Walk our elements:
          SBUInteger      i = 0;
          id*             myArray = [self concreteStorage];
          id*             itsArray = [(SBConcreteArray*)otherArray concreteStorage];
          
          while ( result && (i < _count) ) {
            if ( ! [itsArray[i] isEqual:myArray[i]] )
              result = NO;
            i++;
          }
        }
      }
    } else {
      // Condition 1:  Equal dimension:
      if ( _count == [otherArray count] ) {
        result = YES;
        if ( _count ) {
          // Walk our elements:
          SBUInteger      i = 0;
          id*             array = [self concreteStorage];
          
          while ( result && (i < _count) ) {
            if ( ! [[otherArray objectAtIndex:i] isEqual:array[i]] )
              result = NO;
            i++;
          }
        }
      }
    }
    return result;
  }
  
@end

@implementation SBTinyConcreteArray

  - (id) objectAtIndex:(SBUInteger)index
  {
    return _array[index];
  }

//

  - (id*) concreteStorage
  {
    return _array;
  }

@end

@implementation SBSmallConcreteArray

  - (id) objectAtIndex:(SBUInteger)index
  {
    return _array[index];
  }

//

  - (id*) concreteStorage
  {
    return _array;
  }

@end

@implementation SBMediumConcreteArray

  - (id) objectAtIndex:(SBUInteger)index
  {
    return _array[index];
  }

//

  - (id*) concreteStorage
  {
    return _array;
  }

@end

@implementation SBLargeConcreteArray : SBConcreteArray

  - (id) initWithCapacity:(SBUInteger)capacity
  {
    if ( self = [super initWithCapacity:capacity] ) {
      _array = (id*)objc_malloc(capacity * sizeof(id));
      if ( ! _array ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    id*     array = _array;
    
    [super dealloc];
    if ( array ) objc_free(array);
  }

//

  - (id) objectAtIndex:(SBUInteger)index
  {
    return _array[index];
  }

//

  - (id*) concreteStorage
  {
    return _array;
  }

@end

@implementation SBConcreteArraySubArray : SBConcreteArray

  - (id) initWithParentArray:(SBConcreteArray*)array
    range:(SBRange)indices
  {
    if ( self = [super init] ) {
      _parentArray = [array retain];
      _array = [array concreteStorage];
      _count = [array count];
      
      if ( indices.start >= _count ) {
        _count = 0;
      } else {
        if ( SBRangeMax(indices) > _count )
          indices.length = _count - indices.start;
        
        _array += indices.start;
        _count = indices.length;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parentArray ) [_parentArray release];
    [super dealloc];
  }

//

  - (id) objectAtIndex:(SBUInteger)index
  {
    return _array[index];
  }

//

  - (id*) concreteStorage
  {
    return _array;
  }

@end

//
#pragma mark -
//

@interface SBMutableArrayEnumerator : SBEnumerator
{
  SBArrayBucket*      _bucket;
  id*                 _bSlot;
  id*                 _eSlot;
}

- (id) initWithArrayBucket:(SBArrayBucket*)bucket;

@end

@interface SBMutableArrayReverseEnumerator : SBMutableArrayEnumerator

@end

@implementation SBMutableArrayEnumerator

  - (id) initWithArrayBucket:(SBArrayBucket*)bucket
  {
    if ( self = [super init] ) {
      _bucket = bucket;
      _bSlot = bucket->slots;
      _eSlot = _bSlot + bucket->used;
    }
    return self;
  }
  
//

  - (id) nextObject
  {
    id      obj = nil;
    
    if ( _bucket ) {
      obj = *_bSlot++;
      
      if ( _bSlot == _eSlot ) {
        if ( (_bucket = _bucket->fLink) ) {
          _bSlot = _bucket->slots;
          _eSlot = _bSlot + _bucket->used;
        }
      }
    }
    return obj;
  }

@end

@implementation SBMutableArrayReverseEnumerator

  - (id) nextObject
  {
    id      obj = nil;
    
    if ( _bucket ) {
      if ( _eSlot == _bSlot ) {
        if ( (_bucket = _bucket->pLink) ) {
          _bSlot = _bucket->slots;
          _eSlot = _bSlot + _bucket->used;
        }
      }
      _eSlot--;
      obj = *_eSlot;
    }
    return obj;
  }

@end

//
#pragma mark -
//

void
__SBMutableArray_General_InsertionSortWithFn(
  SBMutableArray*             array,
  SBUInteger                  left,
  SBUInteger                  right,
  SBArraySortComparator       comparator,
  void*                       context
)
{
  SBUInteger        i = left + 1;
  
  while ( i <= right ) {
    id              iTarget = [array objectAtIndex:i];
    SBUInteger      j = i - 1;
    
    while ( j != SBUIntegerMax ) {
      id            jTarget = [array objectAtIndex:j];
      
      if ( comparator(jTarget, iTarget, context) == SBOrderDescending ) {
        [array exchangeObjectAtIndex:j withObjectAtIndex:(j + 1)];
        j--;
      } else {
        break;
      }
    }
    i++;
  }
}

//

void
__SBMutableArray_General_InsertionSortWithSel(
  SBMutableArray*             array,
  SBUInteger                  left,
  SBUInteger                  right,
  SEL                         comparator
)
{
  SBUInteger        i = left + 1;
  
  while ( i <= right ) {
    id              iTarget = [array objectAtIndex:i];
    SBUInteger      j = i - 1;
    
    while ( j != SBUIntegerMax ) {
      id            jTarget = [array objectAtIndex:j];
      
      if ( ((SBComparisonResult)[jTarget perform:comparator with:iTarget]) == SBOrderDescending ) {
        [array exchangeObjectAtIndex:j withObjectAtIndex:(j + 1)];
        j--;
      } else {
        break;
      }
    }
    i++;
  }
}

@implementation SBMutableArray

  + (id) allocWithCapacity:(SBUInteger)capacity
  {
    return [SBConcreteMutableArray alloc];
  }

//

  + (id) alloc
  {
    if ( self == [SBMutableArray class] )
      return [SBConcreteMutableArray alloc];
    return [super alloc];
  }

//

  + (id) array
  {
    return [[[self alloc] init] autorelease];
  }
  
//

  - (id) copy
  {
    return [[SBArray allocWithCapacity:[self count]] initWithArray:self];
  }

//

  - (SBArray*) subarrayWithRange:(SBRange)range
  {
    SBUInteger        count = [self count];
    
    if ( range.start < count ) {
      if ( SBRangeMax(range) > count )
        range.length = count - range.start;
      
      if ( range.length ) {
        id            objs[range.length];
        
        [self getObjects:objs];
        
        return [SBArray arrayWithObjects:objs count:range.length];
      }
    }
    return [SBArray array];
  }
  
//

  - (void) addObject:(id)object
  {
    [self insertObject:object atIndex:0];
  }
  
//

  - (void) insertObject:(id)object
    atIndex:(SBUInteger)index
  {
  }
  
//

  - (void) removeObjectAtIndex:(SBUInteger)index
  {
  }
  
//

  - (void) removeLastObject
  {
    SBUInteger      count = [self count];
    
    if ( count )
      [self removeObjectAtIndex:count - 1];
  }
  
//

  - (void) replaceObject:(id)object
    atIndex:(SBUInteger)index
  {
    if ( index < [self count] ) {
      [self removeObjectAtIndex:index];
      [self insertObject:object atIndex:index];
    }
  }

@end

@implementation SBMutableArray(SBMutableArrayCreation)

  + (id) arrayWithFixedCapacity:(SBUInteger)maxCapacity
  {
    return [[[self alloc] initWithFixedCapacity:maxCapacity] autorelease];
  }
  
//

  - (id) initWithFixedCapacity:(SBUInteger)maxCapacity
  {
    return [super init];
  }

@end

@implementation SBMutableArray(SBExtendedMutableArray)

  - (void) addObjectsFromArray:(SBArray*)otherArray
  {
    SBUInteger        i = 0, iMax = [otherArray count];
    
    while ( i < iMax )
      [self addObject:[otherArray objectAtIndex:i++]];
  }
  
//

  - (void) exchangeObjectAtIndex:(SBUInteger)index1
    withObjectAtIndex:(SBUInteger)index2
  {
    if ( (index1 != index2) && (index1 < [self count]) && (index2 < [self count]) ) {
      id    obj1 = [[self objectAtIndex:index1] retain];
      id    obj2 = [[self objectAtIndex:index2] retain];
      
      [self replaceObject:obj1 atIndex:index2];
      [self replaceObject:obj2 atIndex:index1];
      
      [obj1 release];
      [obj2 release];
    }
  }
  
//

  - (void) removeAllObjects
  {
    SBUInteger      count = [self count];
    
    while ( count-- )
      [self removeLastObject];
  }
  
//

  - (void) removeObject:(id)anObject
  {
    [self removeObject:anObject inRange:SBRangeCreate(0,[self count])];
  }
  - (void) removeObject:(id)anObject
    inRange:(SBRange)range
  {
    SBUInteger      count = [self count];
    
    if ( range.start >= count )
      return;
    if ( SBRangeMax(range) > count )
      range.length = count - range.start;
    
    while ( range.length-- ) {
      if ( [[self objectAtIndex:range.start] isEqual:anObject] ) {
        [self removeObjectAtIndex:range.start];
      } else {
        range.start++;
      }
    }
  }
  
//

  - (void) removeObjectIdenticalTo:(id)anObject
  {
    [self removeObjectIdenticalTo:anObject inRange:SBRangeCreate(0,[self count])];
  }
  - (void) removeObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    SBUInteger      count = [self count];
    
    if ( range.start >= count )
      return;
    if ( SBRangeMax(range) > count )
      range.length = count - range.start;
    
    while ( range.length-- ) {
      if ( [self objectAtIndex:range.start] == anObject ) {
        [self removeObjectAtIndex:range.start];
        // There's only one possible way to satisfy the conditional, so we can
        // return immediately:
        return;
      } else {
        range.start++;
      }
    }
  }
  
//

  - (void) removeObjectsFromIndices:(SBUInteger*)indices
    numIndices:(SBUInteger)count
  {
    SBUInteger        hiIdx = 0, hiIdxVal = 0;
    SBUInteger        i, iMax = count;
    BOOL              inSeq = YES;
    
    if ( count == 0 )
      return;
      
    // Find the largest index:
    i = count;
    while ( i-- ) {
      if ( indices[i] > hiIdxVal ) {
        hiIdx = i;
        hiIdxVal = indices[i];
      }
      if ( (i < count - 1) && inSeq ) {
        if ( ! (indices[i] < indices[i + 1]) ) {
          inSeq = NO;
        }
      }
    }
    
    if ( inSeq ) {
      // They were sorted, hooray!
      i = count;
      while ( i-- )
        [self removeObjectAtIndex:i];
    } else {
      // Now we can start removing objects:
      do {
        SBUInteger      newHiIdx = 0, newHiIdxVal = 0;
        
        [self removeObjectAtIndex:hiIdx];
        count--;
        
        // Locate the _next highest_ index by starting at the last index
        // and loop back toward zero then forward:
        i = hiIdx;
        while ( i-- ) {
          if ( (indices[i] > newHiIdxVal) && (indices[i] < hiIdxVal) ) {
            newHiIdx = i;
            newHiIdxVal = indices[i];
          }
        }
        if ( hiIdx != count ) {
          i = hiIdx + 1;
          while ( i < count ) {
            if ( (indices[i] > newHiIdxVal) && (indices[i] < hiIdxVal) ) {
              newHiIdx = i;
              newHiIdxVal = indices[i];
            }
            i++;
          }
        }
      } while ( count );
    }
  }
  
//

  - (void) removeObjectsInArray:(SBArray*)otherArray
  {
    SBUInteger        i = 0, iMax = [otherArray count];
    
    while ( i < iMax )
      [self removeObject:[otherArray objectAtIndex:i++]];
  }
  
//

  - (void) removeObjectsInRange:(SBRange)range
  {
    SBUInteger      count = [self count];
    
    if ( range.start >= count )
      return;
    if ( SBRangeMax(range) > count )
      range.length = count - range.start;
    
    while ( range.length-- )
      [self removeObjectAtIndex:range.start];
  }
  
//

  - (void) replaceObjectsInRange:(SBRange)range
    withObjectsFromArray:(SBArray*)otherArray
  {
    [self replaceObjectsInRange:range withObjectsFromArray:otherArray range:SBRangeCreate(0,[otherArray count])];
  }
  
//

  - (void) replaceObjectsInRange:(SBRange)range
    withObjectsFromArray:(SBArray*)otherArray
    range:(SBRange)otherRange
  {
    SBUInteger      count = [self count];
    
    if ( range.start >= count )
      return;
    if ( SBRangeMax(range) > count )
      range.length = count - range.start;
    
    [self removeObjectsInRange:range];
    
    count = [otherArray count];
    
    if ( otherRange.start >= count )
      return;
    if ( SBRangeMax(otherRange) > count )
      otherRange.length = count - otherRange.start;
    
    while ( otherRange.length-- )
      [self insertObject:[otherArray objectAtIndex:otherRange.start++] atIndex:range.start++];
  }
  
//

  - (void) setArray:(SBArray*)otherArray
  {
    [self removeAllObjects];
    [self addObjectsFromArray:otherArray];
  }

//

  - (void) sortUsingFunction:(SBArraySortComparator)comparator
    context:(void *)context
  {
    SBUInteger        count = [self count];
    
    if ( count > 1 )
      __SBMutableArray_General_InsertionSortWithFn(self, 0, count - 1, comparator, context);
  }
  
//

  - (void) sortUsingSelector:(SEL)comparator
  {
    SBUInteger        count = [self count];
    
    if ( count > 1 )
      __SBMutableArray_General_InsertionSortWithSel(self, 0, count - 1, comparator);
  }

@end

//
#pragma mark -
//

SBArrayBucket*
SBArrayBucketAlloc(
  SBUInteger    capacity
)
{
  SBArrayBucket*  aBucket = (SBArrayBucket*)objc_malloc( sizeof(SBArrayBucket) + (capacity - 1) * sizeof(id) );
  
  if ( aBucket ) {
    aBucket->fLink = NULL;
    aBucket->pLink = NULL;
    aBucket->used = 0;
    aBucket->available = capacity;
  }
  return aBucket;
}

//

void
SBArrayBucketDealloc(
  SBArrayBucket*      aBucket
)
{
  SBUInteger      i = 0;
  
  while ( i < aBucket->used )
    [aBucket->slots[i++] release];
  objc_free(aBucket);
}

//

BOOL
SBArrayBucketFindSlot(
  SBArrayBucket*            baseBucket,
  SBArrayBucket**           foundBucket,
  SBUInteger  *             index
)
{
  SBUInteger        idx = *index;
  
  while ( baseBucket && baseBucket->used ) {
    if ( idx < baseBucket->used ) {
      *foundBucket = baseBucket;
      *index = idx;
      return YES;
    }
    idx -= baseBucket->used;
    baseBucket = baseBucket->fLink;
  }
  return NO;
}

//

void
__SBMutableArray_Bucket_InsertionSortWithFn(
  SBArrayBucket*              buckets,
  SBUInteger                  left,
  SBUInteger                  right,
  SBArraySortComparator       comparator,
  void*                       context
)
{
  SBArrayBucket*    bucket = buckets;
  SBUInteger        i = left + 1;
  SBUInteger        passes = right - left;
  
  // Locate the appropriate bucket:
  if ( SBArrayBucketFindSlot(buckets, &bucket, &i) ) {
    SBUInteger      backPasses = 1;
    
    while ( passes-- ) {
      SBArrayBucket*  jBucket = bucket;
      SBArrayBucket*  jLastBucket = NULL;
      id              target = bucket->slots[i];
      SBUInteger      j = backPasses, jIndex = i - 1;
        
      while ( j-- ) {
        if ( jIndex == SBUIntegerMax ) {
          jLastBucket = jBucket;
          jBucket = jBucket->pLink;
          jIndex = jBucket->used - 1;
          if ( comparator(jBucket->slots[jIndex], target, context) == SBOrderDescending ) {
            jLastBucket->slots[0] = jBucket->slots[jIndex];
          } else {
            break;
          }
        } else {
          if ( comparator(jBucket->slots[jIndex], target, context) == SBOrderDescending ) {
            jBucket->slots[jIndex + 1] = jBucket->slots[jIndex];
            jIndex--;
          } else {
            break;
          }
        }
      }
      if ( jLastBucket )
        jLastBucket->slots[0] = target;
      else
        jBucket->slots[jIndex + 1] = target;
      i++;
      backPasses++;
      if ( i >= bucket->used ) {
        bucket = bucket->fLink;
        i = 0;
      }
    }
  }
}

//

void
__SBMutableArray_Bucket_InsertionSortWithSel(
  SBArrayBucket*              buckets,
  SBUInteger                  left,
  SBUInteger                  right,
  SEL                         comparator
)
{
  SBArrayBucket*    bucket = buckets;
  SBUInteger        i = left + 1;
  SBUInteger        passes = right - left;
  
  // Locate the appropriate bucket:
  if ( SBArrayBucketFindSlot(buckets, &bucket, &i) ) {
    SBUInteger      backPasses = 1;
    
    while ( passes-- ) {
      SBArrayBucket*  jBucket = bucket;
      SBArrayBucket*  jLastBucket = NULL;
      id              target = bucket->slots[i];
      SBUInteger      j = backPasses, jIndex = i - 1;
        
      while ( j-- ) {
        if ( jIndex == SBUIntegerMax ) {
          jLastBucket = jBucket;
          jBucket = jBucket->pLink;
          jIndex = jBucket->used - 1;
          if ( ((SBComparisonResult)[jBucket->slots[jIndex] perform:comparator with:target]) == SBOrderDescending ) {
            jLastBucket->slots[0] = jBucket->slots[jIndex];
          } else {
            break;
          }
        } else {
          if ( ((SBComparisonResult)[jBucket->slots[jIndex] perform:comparator with:target]) == SBOrderDescending ) {
            jBucket->slots[jIndex + 1] = jBucket->slots[jIndex];
            jIndex--;
          } else {
            break;
          }
        }
      }
      if ( jLastBucket )
        jLastBucket->slots[0] = target;
      else
        jBucket->slots[jIndex + 1] = target;
      i++;
      backPasses++;
      if ( i >= bucket->used ) {
        bucket = bucket->fLink;
        i = 0;
      }
    }
  }
}


//

@implementation SBConcreteMutableArray

  - (id) initWithCapacity:(SBUInteger)capacity
  {
    if ( self = [super initWithCapacity:capacity] ) {
      _buckets = _topBucket = SBArrayBucketAlloc(capacity);
      if ( ! _buckets ) {
        [self release];
        self = nil;
      } else {
        _bucketCount = 1;
        _capacity = capacity;
      }
    }
    return self;
  }

//

  - (id) initWithFixedCapacity:(SBUInteger)capacity
  {
    if ( self = [self initWithCapacity:capacity] ) {
      _flags.fixedCapacity = YES;
    }
    return self;
  }

//

  - (id) initWithObject:(id)initialObject
  {
    if ( self = [self init] )
      [self addObject:initialObject];
    return self;
  }
  
//

  - (id) initWithObjects:(id*)initialObjects
    count:(SBUInteger)count
  {
    if ( self = [self init] ) {
      while ( count-- )
        [self addObject:*initialObjects++];
    }
    return self;
  }
  
//

  - (id) initWithObject:(id)initialObject
    andArguments:(va_list)arguments
  {
    if ( self = [self init] ) {
      while ( initialObject ) {
        [self addObject:initialObject];
        initialObject = va_arg(arguments, id);
      }
    }
    return self;
  }
  
//

  - (id) initWithArray:(SBArray*)anArray
  {
    if ( self = [self init] )
      [self addObjectsFromArray:anArray];
    return self;
  }

//

  - (void) dealloc
  {
    SBArrayBucket*      bucket = _buckets;
    
    while ( bucket ) {
      SBArrayBucket*    nextBucket = bucket->fLink;
      
      SBArrayBucketDealloc(bucket);
      bucket = nextBucket;
    }
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " {\n"
                    "  count = " SBUIntegerFormat "\n"
                    "  capacity = " SBUIntegerFormat "\n"
                    "  hash = %08x\n"
                    "  buckets = " SBUIntegerFormat "\n",
                [self count],
                _capacity,
                [self hash],
                _bucketCount              );
    
    SBArrayBucket*      bucket = _buckets;
    SBUInteger          I = 0;
    
    while ( bucket ) {
      SBUInteger        i = 0;
      
      fprintf(stream,"%c [ %p <- %p -> %p ] " SBUIntegerFormat " / " SBUIntegerFormat " slots used\n", ( bucket == _topBucket ? '*' : ' ' ), bucket->pLink, bucket, bucket->fLink, bucket->used, bucket->used + bucket->available);
      while ( i < bucket->used ) {
        if ( [bucket->slots[i] isKindOf:[SBString class]] ) {
          fprintf(stream, "    " SBUIntegerFormat ": `", I);
          [(SBString*)bucket->slots[i] writeToStream:stream];
          fprintf(stream, "`\n");
        } else {
          fprintf(stream, "    " SBUIntegerFormat ": %s@%p\n", I, [bucket->slots[i] name], bucket->slots[i]);
        }
        I++;
        i++;
      }
      bucket = bucket->fLink;
    }
    fprintf(stream,"}\n");
  }

//

  - (SBUInteger) hash
  {
    if ( ! _flags.hashIsCached ) {
      SBArrayBucket*    bucket = _buckets;
      
      _hash = 0xcafebabe;
      while ( bucket && bucket->used ) {
        SBUInteger      i = 0;
        
        while ( i < bucket->used )
          _hash += [bucket->slots[i++] hash];
        bucket = bucket->fLink;
      }
      _flags.hashIsCached = YES;
    }
    return _hash;
  }

//

  - (SBUInteger) count
  {
    if ( ! _flags.countIsCached ) {
      SBArrayBucket*    bucket = _buckets;
      
      _count = 0;
      while ( bucket && bucket->used ) {
        _count += bucket->used;
        bucket = bucket->fLink;
      }
      _flags.countIsCached = YES;
    }
    return _count;
  }
  
//

  - (id) objectAtIndex:(SBUInteger)index
  {
    SBArrayBucket*      bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      if ( index < bucket->used )
        return bucket->slots[index];
      index -= bucket->used;
      bucket = bucket->fLink;
    }
    return nil;
  }
  
//

  - (BOOL) addCapacity:(SBUInteger)capacity
  {
    SBArrayBucket*      newBucket;
    
    // Round up to 32 slot boundary:
    capacity = 32 * ( ((capacity % 32) != 0) + (capacity / 32 ) );
    
    // Allocate a new bucket:
    if ( (newBucket = SBArrayBucketAlloc(capacity)) ) {
      if ( _topBucket ) {
        _topBucket->fLink = newBucket;
        newBucket->pLink = _topBucket;
      } else {
        _buckets = newBucket;
      }
      _topBucket = newBucket;
      _capacity += capacity;
      _bucketCount++;
      return YES;
    }
    return NO;
  }

//

  - (id) firstObject
  {
    if ( _buckets && _buckets->used )
      return _buckets->slots[0];
    return nil;
  }
  
//

  - (id) lastObject
  {
    if ( _topBucket ) {
      if ( _topBucket->used )
        return _topBucket->slots[ _topBucket->used - 1 ];
      else
        return _topBucket->pLink->slots[ _topBucket->pLink->used - 1 ];
    }
    return nil;
  }
  
//

  - (id) firstObjectInCommonWithArray:(SBArray*)otherArray
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots ) {
        if ( [otherArray containsObject:*bSlots] )
          return *bSlots;
        bSlots++;
      }
      bucket = bucket->fLink;
    }
    return nil;
  }
  
//

  - (void) getObjects:(id*)objects
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      memcpy(objects, bucket->slots, bucket->used * sizeof(id));
      objects += bucket->used;
      
      bucket = bucket->fLink;
    }
  }
  - (void) getObjects:(id*)objects
    inRange:(SBRange)range
  {
    SBArrayBucket*    bucket;
    
    // Find the starting index:
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Begin copying 
      while ( bucket && bucket->used && range.length ) {
        SBUInteger      count = bucket->used - range.start;
        
        //  Full length or range length?
        count = ( count < range.length ? count : range.length );
        memcpy(objects, bucket->slots + range.start, count * sizeof(id));
        objects += count;
        
        //  Adjust the range to account for what we just added:
        range.length -= count;
        range.start = 0;
        
        //  Next bucket:
        bucket = bucket->fLink;
      }
    }
  }

//

  - (BOOL) containsObject:(id)anObject
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots ) {
        if ( [*bSlots++ isEqual:anObject] )
          return YES;
      }
      bucket = bucket->fLink;
    }
    return NO;
  }
  - (BOOL) containsObject:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*    bucket;
    
    // Find the starting index:
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Begin comparing: 
      while ( bucket && bucket->used && range.length ) {
        SBUInteger      count = bucket->used - range.start;
        id*             bSlots = bucket->slots + range.start;
        
        //  Full length or range length?
        count = ( count < range.length ? count : range.length );
        while ( count-- ) {
          if ( [*bSlots++ isEqual:anObject] )
            return YES;
        }
        
        //  Adjust the range to account for what we just added:
        range.length -= count;
        range.start = 0;
        
        //  Next bucket:
        bucket = bucket->fLink;
      }
    }
    return NO;
  }

//

  - (BOOL) containsObjectIdenticalTo:(id)anObject
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots ) {
        if ( *bSlots++ == anObject )
          return YES;
      }
      bucket = bucket->fLink;
    }
    return NO;
  }
  - (BOOL) containsObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*    bucket;
    
    // Find the starting index:
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Begin comparing:
      while ( bucket && bucket->used && range.length ) {
        SBUInteger      count = bucket->used - range.start;
        id*             bSlots = bucket->slots + range.start;
        
        //  Full length or range length?
        count = ( count < range.length ? count : range.length );
        while ( count-- ) {
          if ( *bSlots++ == anObject )
            return YES;
        }
        
        //  Adjust the range to account for what we just added:
        range.length -= count;
        range.start = 0;
        
        //  Next bucket:
        bucket = bucket->fLink;
      }
    }
    return NO;
  }

//

  - (SBUInteger) indexOfObject:(id)anObject
  {
    SBArrayBucket*    bucket = _buckets;
    SBUInteger        baseIndex = 0;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots ) {
        if ( [*bSlots isEqual:anObject] )
          return (baseIndex + (bSlots - bucket->slots));
        bSlots++;
      }
      baseIndex += bucket->used;
      bucket = bucket->fLink;
    }
    return SBNotFound;
  }
  - (SBUInteger) indexOfObject:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*    bucket;
    SBUInteger        baseIndex = range.start;
    
    // Find the starting index:
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Indexing must be relative to the zeroeth element of the chosen
      // bucket:
      baseIndex -= range.start;
      // Begin comparing:
      while ( bucket && bucket->used && range.length ) {
        SBUInteger      count = bucket->used - range.start;
        id*             bSlots = bucket->slots + range.start;
        
        //  Full length or range length?
        count = ( count < range.length ? count : range.length );
        while ( count-- ) {
          if ( [*bSlots isEqual:anObject] )
            return (baseIndex + (bSlots - bucket->slots));
          bSlots++;
        }
        
        //  Adjust the range to account for what we just added:
        range.length -= count;
        range.start = 0;
        baseIndex += bucket->used;
        
        //  Next bucket:
        bucket = bucket->fLink;
      }
    }
    return SBNotFound;
  }
  
//

  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
  {
    SBArrayBucket*    bucket = _buckets;
    SBUInteger        baseIndex = 0;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots ) {
        if ( *bSlots == anObject )
          return (baseIndex + (bSlots - bucket->slots));
        bSlots++;
      }
      baseIndex += bucket->used;
      bucket = bucket->fLink;
    }
    return SBNotFound;
  }
  - (SBUInteger) indexOfObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*    bucket;
    SBUInteger        baseIndex = range.start;
    
    // Find the starting index:
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Indexing must be relative to the zeroeth element of the chosen
      // bucket:
      baseIndex -= range.start;
      // Begin comparing:
      while ( bucket && bucket->used && range.length ) {
        SBUInteger      count = bucket->used - range.start;
        id*             bSlots = bucket->slots + range.start;
        
        //  Full length or range length?
        count = ( count < range.length ? count : range.length );
        while ( count-- ) {
          if ( *bSlots == anObject )
            return (baseIndex + (bSlots - bucket->slots));
          bSlots++;
        }
        
        //  Adjust the range to account for what we just added:
        range.length -= count;
        range.start = 0;
        baseIndex += bucket->used;
        
        //  Next bucket:
        bucket = bucket->fLink;
      }
    }
    return SBNotFound;
  }
  
//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBMutableArrayEnumerator alloc] initWithArrayBucket:_buckets] autorelease];
  }
  
//

  - (SBEnumerator*) reverseObjectEnumerator
  {
    return [[[SBMutableArrayReverseEnumerator alloc] initWithArrayBucket:_buckets] autorelease];
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots )
        [*bSlots++ perform:aSelector];
      bucket = bucket->fLink;
    }
  }
  
//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    SBArrayBucket*    bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      id*             bSlots = bucket->slots;
      id*             eSlots = bSlots + bucket->used;
      
      while ( bSlots < eSlots )
        [*bSlots++ perform:aSelector with:argument];
      bucket = bucket->fLink;
    }
  }
  
//

  - (BOOL) isEqualToArray:(SBArray*)otherArray
  {
    BOOL        result = NO;
    
    SBArrayBucket*    bucket = _buckets;
    SBUInteger        i = 0;
    
    // Condition 1:  Equal dimension:
    if ( [self count] == [otherArray count] ) {
      // Walk our elements:
      result = YES;
      while ( result && bucket && bucket->used ) {
        id*             bSlots = bucket->slots;
        id*             eSlots = bSlots + bucket->used;
        
        while ( bSlots < eSlots ) {
          if ( ! [*bSlots++ isEqual:[otherArray objectAtIndex:i++]] ) {
            result = NO;
            break;
          }
        }
        bucket = bucket->fLink;
      }
    }
    return result;
  }

//

  - (void) addObject:(id)object
  {
    SBArrayBucket*      bucket = _topBucket;
    
    if ( ! bucket ) {
      if ( _flags.fixedCapacity || ! [self addCapacity:1] )
        return;
      bucket = _topBucket;
    } else if ( bucket->available == 0 ) {
      if ( bucket->fLink ) {
        // Another bucket already exists, make it the top now:
        _topBucket = bucket = bucket->fLink;
      } else {
        // Attempt to allocate another bucket:
        if ( _flags.fixedCapacity || ! [self addCapacity:bucket->used] )
          return;
        bucket = _topBucket;
      }
    }
    bucket->slots[bucket->used++] = [object retain];
    bucket->available--;
    
    _flags.hashIsCached = NO;
    
    if ( _flags.countIsCached )
      _count++;
  }
  
//

  - (void) insertObject:(id)object
    atIndex:(SBUInteger)index
  {
    SBArrayBucket*    bucket = _buckets;
    
    if ( ! _topBucket ) {
      if ( _flags.fixedCapacity || ! [self addCapacity:1] )
        return;
      bucket = _buckets;
    } else if ( _topBucket->available == 0 ) {
      if ( _topBucket->fLink ) {
        // Another bucket already exists, make it the top now:
        _topBucket = _topBucket->fLink;
      } else {
        // Attempt to allocate another bucket:
        if ( _flags.fixedCapacity || ! [self addCapacity:bucket->used] )
          return;
      }
    }
    
    // Step forward to the bucket that contains the index we want; note that
    // we use <= because an insertion at the index just past the length of
    // the array is acceptable!
    while ( bucket ) {
      if ( (index <= bucket->used) && (bucket->available > 0) )
        break;
      index -= bucket->used;
      bucket = bucket->fLink;
    }
    
    // If bucket is non-null, then we're ready to roll:
    if ( bucket ) {
      id      exchangeObj = [object retain];
      
      do {
        if ( index < bucket->used ) {
          if ( bucket->available ) {
            // Slots are available; just shift and assign:
            if ( bucket->used ) memmove(bucket->slots + index + 1, bucket->slots + index, (bucket->used - index) * sizeof(id));
            bucket->slots[index] = exchangeObj;
            bucket->used++;
            bucket->available--;
            exchangeObj = nil;
            break;
          } else {
            id        tmpObj = bucket->slots[bucket->used - 1];
            
            // Hang onto the object that'll fall off the end, shift, and assign:
            memmove(bucket->slots + index + 1, bucket->slots + index, (bucket->used - index - 1) * sizeof(id));
            bucket->slots[index] = exchangeObj;
            exchangeObj = tmpObj;
            // No net change in used/available for this bucket
          }
        } else {
          // Insert at the tail end of the fill for the bucket chain can
          // exit immediately:
          bucket->slots[index] = exchangeObj;
          bucket->used++;
          bucket->available--;
          break;
        }
        bucket = bucket->fLink;
        index = 0;
      } while ( bucket );
      
      _flags.hashIsCached = NO;
    
      if ( _flags.countIsCached )
        _count++;
    }
  }
  
//

  - (void) removeObjectAtIndex:(SBUInteger)index
  {
    SBArrayBucket*    bucket = _buckets;
    
    // Step forward to the bucket that contains the index we want:
    while ( bucket ) {
      if ( index < bucket->used )
        break;
      index -= bucket->used;
      bucket = bucket->fLink;
    }
    
    // If bucket is non-null, then we're ready to roll:
    if ( bucket && bucket->used ) {
      SBArrayBucket*  prevBucket = NULL;
      
      [bucket->slots[index] release]; bucket->slots[index] = NULL;
      
      if ( bucket->used == 1 ) {
        bucket->used--;
        bucket->available++;
        _topBucket = bucket;
      } else {
        do {
          // If there's a previous bucket then shift the first element from this bucket back to
          // its final slot:
          if ( prevBucket && bucket->used ) {
            prevBucket->slots[prevBucket->used] = bucket->slots[0];    bucket->slots[0] = NULL;
            prevBucket->used++;
            prevBucket->available--;
            bucket->used--;
            bucket->available++;
          }
          // If this bucket still has something in it, then shift its contents:
          if ( bucket->used ) {
            memmove(bucket->slots + index, bucket->slots + index + 1, (bucket->used - index) * sizeof(id));
            bucket->used--;
            bucket->available++;
          }
          _topBucket = bucket;
          prevBucket = bucket;
          
          bucket = bucket->fLink;
          index = 0;
        } while ( bucket && bucket->used );
      }
      
      _flags.hashIsCached = NO;
      
      if ( _flags.countIsCached )
        _count--;
    }
  }
  
//

  - (void) removeLastObject
  {
    if ( _topBucket ) {
      if ( (_topBucket->used == 0) && (_topBucket != _buckets) ) {
        // Drop back to the previous bucket since the top is already
        // empty:
        SBArrayBucket*    bucket = _buckets;
        
        while ( bucket ) {
          if ( bucket->fLink == _topBucket ) {
            _topBucket = bucket;
            break;
          }
          bucket = bucket->fLink;
        }
      }
      if ( _topBucket->used ) {
        [_topBucket->slots[--_topBucket->used] release];
        _topBucket->available++;
        
        _flags.hashIsCached = NO;
      
        if ( _flags.countIsCached )
          _count--;
      }
    }
  }
  
//

  - (void) replaceObject:(id)object
    atIndex:(SBUInteger)index
  {
    SBArrayBucket*      bucket = _buckets;
    
    while ( bucket && bucket->used ) {
      if ( index < bucket->used ) {
        object = [object retain];
        [bucket->slots[index] release];
        bucket->slots[index] = object;
        
        _flags.hashIsCached = NO;
        
        break;
      }
      index -= bucket->used;
      bucket = bucket->fLink;
    }
  }

//

  - (void) addObjectsFromArray:(SBArray*)otherArray
  {
    SBArrayBucket*      bucket = _topBucket;
    SBUInteger          i = 0, iMax = [otherArray count];
    
    if ( iMax ) {
      if ( ! bucket ) {
        if ( _flags.fixedCapacity || ! [self addCapacity:1] )
          return;
        bucket = _topBucket;
      }
      
      _flags.hashIsCached = NO;
      
      while ( i < iMax ) {
        if ( bucket->available == 0 ) {
          if ( bucket->fLink ) {
            // Another bucket already exists, make it the top now:
            _topBucket = bucket = bucket->fLink;
          } else {
            // Attempt to allocate another bucket:
            if ( _flags.fixedCapacity || ! [self addCapacity:bucket->used] )
              return;
            bucket = _topBucket;
          }
        }
        bucket->slots[bucket->used++] = [[otherArray objectAtIndex:i++] retain];
        bucket->available--;
        if ( _flags.countIsCached )
          _count++;
      }
    }
  }
  
//

  - (void) exchangeObjectAtIndex:(SBUInteger)index1
    withObjectAtIndex:(SBUInteger)index2
  {
    SBArrayBucket*      bucket1 = _buckets;
    
    if ( index1 > index2 ) {
      SBUInteger        tmpIndex = index1;
      index1 = index2;
      index2 = tmpIndex;
    }
    
    // Find the bucket and slot for index1:
    while ( bucket1 ) {
      if ( index1 < bucket1->used )
        break;
      index1 -= bucket1->used;
      index2 -= bucket1->used;
      bucket1 = bucket1->fLink;
    }
    if ( bucket1 ) {
      SBArrayBucket*    bucket2 = bucket1;
      
      while ( bucket2 ) {
        if ( index2 < bucket2->used )
          break;
        index2 -= bucket2->used;
        bucket2 = bucket2->fLink;
      }
      if ( bucket2 ) {
        // Ready for exchange:
        id        tmpObj = bucket1->slots[index1];
        
        bucket1->slots[index1] = bucket2->slots[index2];
        bucket2->slots[index2] = tmpObj;
        
        _flags.hashIsCached = NO;
      }
    }
  }

//

  - (void) removeAllObjects
  {
    SBArrayBucket*      bucket = _topBucket;
    
    while ( bucket ) {
      while ( bucket->used ) {
        [bucket->slots[--bucket->used] release];
        bucket->available++;
      }
      bucket = bucket->pLink;
    }
    _topBucket = _buckets;
    _flags.hashIsCached = _flags.countIsCached = NO;
  }

//

  - (void) removeObject:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*      bucket = _buckets;
    SBUInteger          index = range.start;
    
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Now zip through the range's length checking for matches:
      while ( bucket && range.length-- ) {
        if ( [bucket->slots[range.start] isEqual:anObject] ) {
          [self removeObjectAtIndex:index];
        } else {
          index++;
          range.start++;
          if ( range.start > bucket->used ) {
            range.start = 0;
            bucket = bucket->fLink;
          }
        }
      }
    }
  }
  
//

  - (void) removeObjectIdenticalTo:(id)anObject
    inRange:(SBRange)range
  {
    SBArrayBucket*      bucket = _buckets;
    SBUInteger          index = range.start;
    
    if ( SBArrayBucketFindSlot(_buckets, &bucket, &range.start) ) {
      // Now zip through the range's length checking for matches:
      while ( bucket && range.length-- ) {
        if ( bucket->slots[range.start] == anObject ) {
          [self removeObjectAtIndex:index];
        } else {
          index++;
          range.start++;
          if ( range.start > bucket->used ) {
            range.start = 0;
            bucket = bucket->fLink;
          }
        }
      }
    }
  }
  
//

  - (void) removeObjectsInArray:(SBArray*)otherArray
  {
    SBArrayBucket*      bucket = _buckets;
    SBUInteger          i = 0, iPrime = 0;
    
    while ( bucket && bucket->used ) {
      if ( [otherArray containsObject:bucket->slots[iPrime]] ) {
        [self removeObjectAtIndex:i];
      } else {
        i++;
        iPrime++;
        if ( iPrime >= bucket->used ) {
          iPrime = 0;
          bucket = bucket->fLink;
        }
      }
    }
  }
  
//

  - (void) setArray:(SBArray*)otherArray
  {
    SBUInteger          i = 0, iMax = [otherArray count];
    
    if ( iMax ) {
      SBArrayBucket*    bucket;
      unsigned          iPrime = 0, iPrimeMax;
      
      // Will we grow?
      if ( iMax > [self count] ) {
        if ( _flags.fixedCapacity || ! [self addCapacity:(iMax - [self count])] )
          return;
      }
      
      _topBucket = bucket = _buckets;
      iPrimeMax = bucket->used + bucket->available;
      
      while ( bucket && (i < iMax) ) {
        if ( iPrime == iPrimeMax ) {
          if ( (bucket = bucket->fLink) ) {
            _topBucket = bucket;
            iPrimeMax = bucket->used + bucket->available;
            iPrime = 0;
          }
        }
        if ( bucket ) {
          if ( iPrime < bucket->used ) {
            [bucket->slots[iPrime] release];
          } else {
            bucket->used++;
            bucket->available--;
          }
          bucket->slots[iPrime++] = [[otherArray objectAtIndex:i++] retain];
        }
      }
      
      // Release anything that extends beyond the new bounds:
      iPrimeMax = bucket->used;
      while ( bucket && iPrimeMax && bucket->used ) {
        if ( iPrime == iPrimeMax ) {
          if ( (bucket = bucket->fLink) ) {
            iPrimeMax = bucket->used;
            iPrime = 0;
          }
        }
        if ( bucket ) {
          if ( iPrime < iPrimeMax ) {
            [bucket->slots[iPrime++] release];
            bucket->used--;
            bucket->available++;
          } else {
            break;
          }
        }
      }
      
      _flags.hashIsCached = NO;
      _flags.countIsCached = YES;
      _count = iMax;
    }
  }

//

  - (void) sortUsingFunction:(SBArraySortComparator)comparator
    context:(void *)context
  {
    SBUInteger        count = [self count];
    
    if ( count > 1 )
      __SBMutableArray_Bucket_InsertionSortWithFn(_buckets, 0, count - 1, comparator, context);
  }
  
//

  - (void) sortUsingSelector:(SEL)comparator
  {
    SBUInteger        count = [self count];
    
    if ( count > 1 )
      __SBMutableArray_Bucket_InsertionSortWithSel(_buckets, 0, count - 1, comparator);
  }

@end
