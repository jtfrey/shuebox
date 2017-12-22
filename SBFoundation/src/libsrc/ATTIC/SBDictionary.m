//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBDictionary.m
//
// Basic object hash table.
//
// $Id$
//

#import "SBDictionary.h"
#import "SBArray.h"
#import "SBString.h"

//

#ifndef SBDICTIONARY_INITIAL_SLOTS
#define SBDICTIONARY_INITIAL_SLOTS      32
#endif

#ifndef SBDICTIONARY_INITIAL_POOL
#define SBDICTIONARY_INITIAL_POOL       24
#endif

//

typedef struct _SBDictionaryBucket {
  id                          key;
  id                          object;
  struct _SBDictionaryBucket* link;
} SBDictionaryBucket;

typedef struct _SBDictionaryBucketPool {
  unsigned int                count;
  SBDictionaryBucket*         pool;
  struct _SBDictionaryBucketPool* link;
} SBDictionaryBucketPool;

//

void*
__SBDictionaryBucketPoolAlloc(
  SBDictionaryBucketPool**  pools
)
{
  SBDictionaryBucketPool*   newPool = calloc(1,sizeof(SBDictionaryBucketPool) + SBDICTIONARY_INITIAL_POOL * sizeof(SBDictionaryBucket));
  
  if ( newPool ) {
    SBDictionaryBucket*   aBucket = (SBDictionaryBucket*)(((void*)newPool) + sizeof(SBDictionaryBucketPool));
    unsigned int          n = SBDICTIONARY_INITIAL_POOL;
    
    newPool->count = SBDICTIONARY_INITIAL_POOL;
    newPool->pool = aBucket;
    newPool->link = *pools;
    *pools = newPool;
    
    // Initialize the buckets:
    while ( --n > 0 ) {
      aBucket->link = aBucket + 1;
      aBucket++;
    }
    return newPool->pool;
  }
  return NULL;
}

//

SBDictionaryBucket*
__SBDictionaryBucketFindKey(
  SBDictionaryBucket*   aBucket,
  id                    key
)
{
  while ( aBucket ) {
    if ( [aBucket->key isEqual:key] )
      return aBucket;
    aBucket = aBucket->link;
  }
  return NULL;
}

//

SBDictionaryBucket*
__SBDictionaryBucketFindObject(
  SBDictionaryBucket*   aBucket,
  id                    object
)
{
  while ( aBucket ) {
    if ( [aBucket->object isEqual:object] )
      return aBucket;
    aBucket = aBucket->link;
  }
  return NULL;
}

//

void
__SBDictionaryBucketAppend(
  SBDictionaryBucket**  aBucket,
  SBDictionaryBucket*   droplet
)
{
  droplet->link = *aBucket;
  *aBucket = droplet;
}

//

SBDictionaryBucket*
__SBDictionaryBucketAlloc(
  SBDictionaryBucketPool**  pools,
  SBDictionaryBucket**      curPool
)
{
  SBDictionaryBucket*   newDroplet = NULL;
  
  // If no pool exists, create one:
  if ( *curPool == NULL ) {
    *curPool = __SBDictionaryBucketPoolAlloc(pools);
  }
  if ( *curPool ) {
    newDroplet = *curPool;
    *curPool = newDroplet->link;
    newDroplet->key = newDroplet->object = nil;
    newDroplet->link = NULL;
  }
  return newDroplet;
}

//

void
__SBDictionaryBucketDealloc(
  SBDictionaryBucket**  aBucket,
  SBDictionaryBucket**  aPool
)
{
  SBDictionaryBucket*   thisDroplet = *aBucket;
  SBDictionaryBucket*   nextDroplet;
  
  while ( thisDroplet ) {
    nextDroplet = thisDroplet->link;
    
    //  Release our key and value:
    if ( thisDroplet->key ) {
      [thisDroplet->key release];
      thisDroplet->key = nil;
    }
    if ( thisDroplet->object ) {
      [thisDroplet->object release];
      thisDroplet->object = nil;
    }
    thisDroplet->link = NULL;
    
    //  If a pool was provided, hand this node to it; otherwise, just
    //  deallocate it:
    if ( aPool )
      __SBDictionaryBucketAppend(aPool, thisDroplet);
      
    //  Next!!!
    thisDroplet = nextDroplet;
  }
  *aBucket = NULL;
}

//

void
__SBDictionaryBucketDeallocDroplet(
  SBDictionaryBucket**  aBucket,
  SBDictionaryBucket*   aDroplet,
  SBDictionaryBucket**  aPool
)
{
  SBDictionaryBucket*     thisDroplet = *aBucket;
  SBDictionaryBucket*     lastDroplet = NULL;
  
  while ( thisDroplet ) {
    if ( thisDroplet == aDroplet ) {
      SBDictionaryBucket* nextDroplet = thisDroplet->link;
      
      //  Release our key and value:
      if ( thisDroplet->key ) {
        [thisDroplet->key release];
        thisDroplet->key = nil;
      }
      if ( thisDroplet->object ) {
        [thisDroplet->object release];
        thisDroplet->object = nil;
      }
      thisDroplet->link = NULL;
      
      //  Unlink from the chain:
      if ( lastDroplet ) {
        lastDroplet->link = nextDroplet;
      } else {
        *aBucket = nextDroplet;
      }
    
      //  If a pool was provided, hand this node to it; otherwise, just
      //  deallocate it:
      if ( aPool )
        __SBDictionaryBucketAppend(aPool, thisDroplet);
      
      break;
    }
    lastDroplet = thisDroplet;
    thisDroplet = thisDroplet->link;
  }
}

//
#pragma mark -
//

@interface SBDictionaryKeyEnumerator : SBEnumerator
{
  SBDictionaryBucket**  _buckets;
  SBDictionaryBucket*   _droplet;
  unsigned int          _bucketNum,_bucketMax;
}

- (id) initWithBuckets:(SBDictionaryBucket**)buckets count:(unsigned int)count;

- (id) nextKeyAndObject:(id*)object;

@end

@implementation SBDictionaryKeyEnumerator

  - (id) initWithBuckets:(SBDictionaryBucket**)buckets
    count:(unsigned int)count
  {
    if ( self = [super init] ) {
      _bucketMax = count;
      if ( (_buckets = buckets) ) {
        while ( (_bucketNum < _bucketMax) && ((_droplet = _buckets[_bucketNum]) == NULL) )
          _bucketNum++;
      }
    }
    return self;
  }
  
//

  - (id) nextObject
  {
    id      object = nil;
    
    if ( _droplet ) {
      object = _droplet->key;
      if ( (_droplet = _droplet->link) == NULL ) {
        while ( (++_bucketNum < _bucketMax) && ((_droplet = _buckets[_bucketNum]) == NULL) );
      }
    }
    return object;
  }
  
//

  - (id) nextKeyAndObject:(id*)object
  {
    id      key = nil;
    
    if ( _droplet ) {
      key = _droplet->key;
      *object = _droplet->object;
      if ( (_droplet = _droplet->link) == NULL ) {
        while ( (++_bucketNum < _bucketMax) && ((_droplet = _buckets[_bucketNum]) == NULL) );
      }
    }
    return key;
  }

@end

//
#pragma mark -
//

@interface SBDictionaryObjectEnumerator : SBDictionaryKeyEnumerator

@end

@implementation SBDictionaryObjectEnumerator

  - (id) nextObject
  {
    id      object = nil;
    
    if ( _droplet ) {
      object = _droplet->object;
      if ( (_droplet = _droplet->link) == NULL ) {
        while ( (++_bucketNum < _bucketMax) && ((_droplet = _buckets[_bucketNum]) == NULL) );
      }
    }
    return object;
  }

@end

//
#pragma mark -
//

@interface SBDictionary(SBDictionaryPrivate)

- (id) initWithObject:(id)firstObject andVArgs:(va_list)vargs;
- (unsigned int) poolCount;

@end

@implementation SBDictionary(SBDictionaryPrivate)

  - (id) initWithObject:(id)firstObject
    andVArgs:(va_list)vargs
  {
    if ( self = [self init] ) {
      id        key;
      
      while ( firstObject && (key = va_arg(vargs, id)) ) {
        [self setObject:firstObject forKey:key];
        firstObject = va_arg(vargs, id);
      }
    }
    return self;
  }

//

  - (unsigned int) poolCount
  {
    unsigned int          count = 0;
    SBDictionaryBucket*   pool = (SBDictionaryBucket*)_pool;
    
    while ( pool ) {
      count++;
      pool = pool->link;
    }
    return count;
  }

@end

//
#pragma mark -
//

@implementation SBDictionary

  + (id) dictionary
  {
    return [[[SBDictionary alloc] init] autorelease];
  }
  
//

  + (id) dictionaryWithObject:(id)object
    forKey:(id)key
  {
    return [[[SBDictionary alloc] initWithObjects:&object forKeys:&key count:1] autorelease];
  }
  
//

  + (id) dictionaryWithObjects:(id*)objects
    forKeys:(id*)keys
    count:(unsigned int)count
  {
    return [[[SBDictionary alloc] initWithObjects:objects forKeys:keys count:count] autorelease];
  }
  
//

  + (id) dictionaryWithObjectsAndKeys:(id)firstObject,...
  {
    id        object;
    va_list   vargs;
    
    va_start(vargs, firstObject);
    object = [[[SBDictionary alloc] initWithObject:firstObject andVArgs:vargs] autorelease];
    va_end(vargs);
    
    return object;
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
      if ( (_buckets = calloc(SBDICTIONARY_INITIAL_SLOTS, sizeof(SBDictionaryBucket*))) ) {
        _bucketCount = SBDICTIONARY_INITIAL_SLOTS;
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithObjects:(id*)objects
    forKeys:(id*)keys
    count:(unsigned int)count
  {
    if ( self = [self init] ) {
      while ( count-- > 0 ) {
        if ( objects[count] && keys[count] ) {
          [self setObject:objects[count] forKey:keys[count]];
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithObjectsAndKeys:(id)firstObject,...
  {
    va_list     vargs;
    
    va_start(vargs, firstObject);
    self = [self initWithObject:firstObject andVArgs:vargs];
    va_end(vargs);
    
    return self;
  }

//

  - (void) dealloc
  {
    if ( _bucketCount ) {
      while ( _bucketCount-- > 0 ) {
        __SBDictionaryBucketDealloc(((SBDictionaryBucket**)_buckets) + _bucketCount, NULL);
      }
      free(_buckets);
    }
    while ( _pools ) {
      void*     nextPool = ((SBDictionaryBucketPool*)_pools)->link;
      
      free( ((SBDictionaryBucketPool*)_pools)->pool );
      _pools = nextPool;
    }
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBDictionaryKeyEnumerator*     eKey = (SBDictionaryKeyEnumerator*)[self keyEnumerator];
    id                             key, object;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        "  count: %u\n"
        "  bucket-count: %u\n"
        "  add-count: %u (%u collisions)\n"
        "  {\n",
        _count,
        _bucketCount,
        _totalAdd, _collisions
      );
    while ( key = [eKey nextKeyAndObject:&object] ) {
      if ( [key isKindOf:[SBString class]] ) {
        fprintf(stream, "    \'");
        [(SBString*)key writeToStream:stderr];
        fprintf(stream, "\' = ");
      } else {
        fprintf(stream, "    %s@%p = ", [key name], key);
      }
      
      if ( [object isKindOf:[SBString class]] ) {
        fprintf(stream, "\'");
        [(SBString*)object writeToStream:stderr];
        fprintf(stream, "\'\n");
      } else {
        fprintf(stream, "%s@%p\n", [object name], object);
      }
    }
    fprintf(stream,"  }\n");
  }

//

  - (unsigned int) count
  {
    return _count;
  }
  
//

  - (id) objectForKey:(id)key
  {
    if ( key && _bucketCount && _count ) {
      unsigned int          hash = [key hash];
      unsigned int          bucketNum = hash % _bucketCount;
      SBDictionaryBucket*   foundBucket = __SBDictionaryBucketFindKey(((SBDictionaryBucket**)_buckets)[bucketNum], key);
      
      if ( foundBucket ) {
        return foundBucket->object;
      }
    }
    return nil;
  }
  
//

  - (void) setObject:(id)object
    forKey:(id)key
  {
    if ( _bucketCount ) {
      unsigned int          bucketNum = [key hash] % _bucketCount;
      SBDictionaryBucket*   foundBucket = __SBDictionaryBucketFindKey(((SBDictionaryBucket**)_buckets)[bucketNum], key);
      
      if ( foundBucket ) {
        // Replace the object associate with the key:
        [foundBucket->object release];
        foundBucket->object = [object retain];
        // No change to stats
      } else {
        foundBucket = __SBDictionaryBucketAlloc(
                            (SBDictionaryBucketPool**)(&_pools),
                            (SBDictionaryBucket**)(&_pool)
                          );
        if ( foundBucket ) {
          foundBucket->key = [key copy];
          foundBucket->object = [object retain];
          
          // If there was already something in this bucket chain, then increase the collision count:
          if ( ((SBDictionaryBucket**)_buckets)[bucketNum] != NULL )
            _collisions++;
          __SBDictionaryBucketAppend(((SBDictionaryBucket**)_buckets) + bucketNum, foundBucket);
          _count++;
          _totalAdd++;
        }
      }
    }
  }

//

  - (void) removeObjectForKey:(id)key
  {
    if ( _bucketCount && _count) {
      unsigned int          bucketNum = [key hash] % _bucketCount;
      SBDictionaryBucket*   foundBucket = __SBDictionaryBucketFindKey(((SBDictionaryBucket**)_buckets)[bucketNum], key);
      
      if ( foundBucket ) {
        __SBDictionaryBucketDeallocDroplet(
            ((SBDictionaryBucket**)_buckets) + bucketNum,
            foundBucket,
            (SBDictionaryBucket**)(&_pool)
          );
        _count--;
      }
    }
  }

//

  - (void) removeAllObjects
  {
    if ( _bucketCount && _count ) {
      unsigned int          bucketNum = 0;
      
      while ( bucketNum < _bucketCount ) {
        if ( ((SBDictionaryBucket**)_buckets)[bucketNum] ) {
          __SBDictionaryBucketDealloc(
              ((SBDictionaryBucket**)_buckets) + bucketNum,
              (SBDictionaryBucket**)(&_pool)
            );
        }
        bucketNum++;
      }
      _count = 0;
      _collisions = _totalAdd = 0;
    }
  }

//

  - (BOOL) containsKey:(id)key
  {
    if ( _bucketCount && _count ) {
      unsigned int          bucketNum = [key hash] % _bucketCount;
      SBDictionaryBucket*   foundBucket = __SBDictionaryBucketFindKey(((SBDictionaryBucket**)_buckets)[bucketNum], key);
      
      if ( foundBucket )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) containsObject:(id)object
  {
    if ( _bucketCount && _count ) {
      unsigned int          bucketNum = 0;
      
      while ( bucketNum < _bucketCount ) {
        SBDictionaryBucket* foundBucket = __SBDictionaryBucketFindObject(
                                              ((SBDictionaryBucket**)_buckets)[bucketNum],
                                              object
                                            );
        
        if ( foundBucket )
          return YES;
        bucketNum++;
      }
    }
    return NO;
  }

//

  - (SBEnumerator*) keyEnumerator
  {
    return [[[SBDictionaryKeyEnumerator alloc] initWithBuckets:(SBDictionaryBucket**)_buckets count:_bucketCount] autorelease];
  }
  
//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBDictionaryObjectEnumerator alloc] initWithBuckets:(SBDictionaryBucket**)_buckets count:_bucketCount] autorelease];
  }

//

  - (SBArray*) allKeys
  {
    SBArray*        keyArray = nil;
    
    if ( _bucketCount && _count ) {
      unsigned int  bucketNum = 0;
      
      keyArray = [[[SBArray alloc] init] autorelease];
      while ( bucketNum < _bucketCount ) {
        SBDictionaryBucket*     theBucket = ((SBDictionaryBucket**)_buckets)[bucketNum];
        
        while ( theBucket ) {
          // Walk the link list, adding all keys to the array:
          [keyArray addObject:theBucket->key];
          theBucket = theBucket->link;
        }
        bucketNum++;
      }
    }
    return keyArray;
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    if ( _bucketCount && _count ) {
      unsigned int  bucketNum = 0;
      
      while ( bucketNum < _bucketCount ) {
        SBDictionaryBucket*     theBucket = ((SBDictionaryBucket**)_buckets)[bucketNum];
        
        while ( theBucket ) {
          // Walk the link list, sending the message to all objects in the list:
          [theBucket->object perform:aSelector];
          theBucket = theBucket->link;
        }
        bucketNum++;
      }
    }
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    if ( _bucketCount && _count ) {
      unsigned int  bucketNum = 0;
      
      while ( bucketNum < _bucketCount ) {
        SBDictionaryBucket*     theBucket = ((SBDictionaryBucket**)_buckets)[bucketNum];
        
        while ( theBucket ) {
          // Walk the link list, sending the message to all objects in the list:
          [theBucket->object perform:aSelector with:argument];
          theBucket = theBucket->link;
        }
        bucketNum++;
      }
    }
  }

@end
