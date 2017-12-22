//
// SBFoundation : ObjC Class Library for Solaris
// SBDictionary.m
//
// Hash tables.
//
// $Id$
//

#import "SBDictionary.h"
#import "SBArray.h"
#import "SBEnumerator.h"
#import "SBString.h"
#import "SBValue.h"
#import "SBKeyValueCoding.h"
#import "SBFileManager.h"

//
#pragma mark -
//

#define SBHashTableMultiplier            1.8

#define SBSmallBasicHashPairCapacity       8
#define SBSmallBasicHashTableCapacity     14

#define SBMediumBasicHashPairCapacity     24
#define SBMediumBasicHashTableCapacity    43

typedef struct _SBHashPair {
  id                  key;
  id                  object;
} SBHashPair;

typedef struct _SBBasicHashTable {
  unsigned int        freeWhenDone;
  unsigned int        keyCapacity;
  unsigned int        keyCount;
  id*                 keys;
  unsigned int        tableCapacity;
  SBHashPair*         table;
} SBBasicHashTable;

//

SBBasicHashTable*
SBBasicHashTableCreate(
  unsigned int      keyCount
)
{
  SBBasicHashTable* newTable = NULL;
  unsigned int      tableSize = SBHashTableMultiplier * keyCount;
  size_t            byteSize = sizeof(SBBasicHashTable) + keyCount * sizeof(id) + tableSize * sizeof(SBHashPair); 
  
  if ( (newTable = (SBBasicHashTable*)objc_calloc(1, byteSize)) ) {
    newTable->freeWhenDone = YES;
    newTable->keyCapacity = keyCount;
    newTable->tableCapacity = tableSize;
    
    newTable->keys = (id*)(((void*)newTable) + sizeof(SBBasicHashTable));
    newTable->table = (SBHashPair*)(newTable->keys + keyCount);
  }
  return newTable;
}

//

typedef struct _SBSingletonBasicHashTable {
  SBBasicHashTable    base;
  id                  key;
  SBHashPair          pair;
} SBSingletonBasicHashTable;

void
SBSingletonBasicHashTableInit(
  SBSingletonBasicHashTable*    aTable
)
{
  memset(aTable, 0, sizeof(SBSingletonBasicHashTable));
  
  aTable->base.keyCapacity = 1;
  aTable->base.tableCapacity = 1;
  aTable->base.keys = &aTable->key;
  aTable->base.table = &aTable->pair;
}

//

typedef struct _SBSmallBasicHashTable {
  SBBasicHashTable    base;
  id                  keys[SBSmallBasicHashPairCapacity];
  SBHashPair          pairs[SBSmallBasicHashTableCapacity];
} SBSmallBasicHashTable;

void
SBSmallBasicHashTableInit(
  SBSmallBasicHashTable*     aTable
)
{
  memset(aTable, 0, sizeof(SBSmallBasicHashTable));
  
  aTable->base.keyCapacity = SBSmallBasicHashPairCapacity;
  aTable->base.tableCapacity = SBSmallBasicHashTableCapacity;
  aTable->base.keys = &aTable->keys[0];
  aTable->base.table = &aTable->pairs[0];
}

//

typedef struct _SBMediumBasicHashTable {
  SBBasicHashTable    base;
  id                  keys[SBMediumBasicHashPairCapacity];
  SBHashPair          pairs[SBMediumBasicHashTableCapacity];
} SBMediumBasicHashTable;

void
SBMediumBasicHashTableInit(
  SBMediumBasicHashTable*    aTable
)
{
  memset(aTable, 0, sizeof(SBMediumBasicHashTable));
  
  aTable->base.keyCapacity = SBMediumBasicHashPairCapacity;
  aTable->base.tableCapacity = SBMediumBasicHashTableCapacity;
  aTable->base.keys = &aTable->keys[0];
  aTable->base.table = &aTable->pairs[0];
}

//

void
SBBasicHashTableDealloc(
  SBBasicHashTable*   aTable
)
{
  unsigned int      i;
  
  // Walk the table and drop any keys and objects stored therein:
  i = 0;
  while ( i < aTable->tableCapacity ) {
    if ( aTable->table[i].key ) {
      [aTable->table[i].key release];
      [aTable->table[i].object release];
    }
    i++;
  }
  
  if ( aTable->freeWhenDone ) {
    // Deallocate the table:
    objc_free(aTable);
  }
}

//

BOOL
SBBasicHashTableAddPair(
  SBBasicHashTable*   aTable,
  id                  key,
  id                  object
)
{
  // Full?
  if ( aTable->keyCount != aTable->keyCapacity ) {
    unsigned int      hash = [key hash];
    
    // Find the table index to use:
    hash = (hash % aTable->tableCapacity);
    while ( aTable->table[hash].key ) {
      if ( [aTable->table[hash].key isEqual:key] ) {
        object = [object retain];
        [aTable->table[hash].object release];
        aTable->table[hash].object = object;
        return YES;
      }
      if ( ++hash >= aTable->tableCapacity )
        hash = 0;
    }
    aTable->table[hash].key = [key copy];
    aTable->table[hash].object = [object retain];
    aTable->keys[aTable->keyCount++] = aTable->table[hash].key;
    
    return YES;
  }
  return NO;
}

//

SBHashPair*
SBBasicHashTableFindPairForKey(
  SBBasicHashTable*   aTable,
  id                  key
)
{
  if ( aTable->keyCount ) {
    unsigned int      hash = [key hash];
    unsigned int      startIdx;
    
    // Find the table index to start searching from:
    startIdx = ( hash = (hash % aTable->tableCapacity) );
    while ( aTable->table[hash].key ) {
      if ( [aTable->table[hash].key isEqual:key] )
        return &aTable->table[hash];
      if ( ++hash == aTable->tableCapacity )
        hash = 0;
      if ( hash == startIdx )
        break;
    }   
  }
  return NULL;
}

//
#pragma mark -
//

@interface SBNullDictionary : SBDictionary

@end

@interface SBConcreteDictionary : SBDictionary

- (SBBasicHashTable*) basicHashTable;
- (void) takeObject:(id)object forKey:(id)aKey;

@end

@interface SBSinglePairConcreteDictionary : SBConcreteDictionary
{
  SBSingletonBasicHashTable     _table;
}

@end

@interface SBSmallConcreteDictionary : SBConcreteDictionary
{
  SBSmallBasicHashTable      _table;
}

@end

@interface SBMediumConcreteDictionary : SBConcreteDictionary
{
  SBMediumBasicHashTable     _table;
}

@end

@interface SBLargeConcreteDictionary : SBConcreteDictionary
{
  SBBasicHashTable*     _table;
}

@end

@class SBConcreteMutableDictionary;

//
#pragma mark -
//

@interface SBSimpleDictionaryObjectEnumerator : SBEnumerator
{
  SBDictionary*     _parentDictionary;
  SBEnumerator*     _parentKeyEnum;
}

- (id) initWithDictionary:(SBDictionary*)aDictionary;

@end

@interface SBConcreteDictionaryKeyEnumerator : SBEnumerator
{
  id*               _keys;
  unsigned int      _i, _iMax;
}

- (id) initWithKeys:(id*)keys count:(unsigned int)count;

@end

@interface SBConcreteDictionaryObjectEnumerator : SBEnumerator
{
  SBHashPair*       _table;
  unsigned int      _i, _iMax;
}

- (id) initWithTable:(SBHashPair*)table count:(unsigned int)count;

@end

@implementation SBSimpleDictionaryObjectEnumerator

  - (id) initWithDictionary:(SBDictionary*)aDictionary
  {
    if ( self = [super init] ) {
      if ( (_parentDictionary = [aDictionary retain]) )
        _parentKeyEnum = [[aDictionary keyEnumerator] retain];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parentKeyEnum ) [_parentKeyEnum release];
    if ( _parentDictionary ) [_parentDictionary release];
    [super dealloc];
  }
  
//

  - (id) nextObject
  {
    id      nextKey;
    
    if ( _parentKeyEnum ) {
      if ( (nextKey = [_parentKeyEnum nextObject]) )
        return [_parentDictionary objectForKey:nextKey];
      [_parentKeyEnum release];
      _parentKeyEnum = nil;
    }
    return nil;
  }

@end

@implementation SBConcreteDictionaryKeyEnumerator

  - (id) initWithKeys:(id*)keys
    count:(unsigned int)count
  {
    if ( self = [super init] ) {
      _keys = keys;
      _i = 0;
      _iMax = count;
    }
    return self;
  }
  
//

  - (id) nextObject
  {
    if ( _i < _iMax )
      return _keys[_i++];
    return nil;
  }

@end

@implementation SBConcreteDictionaryObjectEnumerator
{
  SBHashPair*       _table;
  unsigned int      _i, _iMax;
}

  - (id) initWithTable:(SBHashPair*)table
    count:(unsigned int)count
  {
    if ( self = [super init] ) {
      _table = table;
      _i = 0;
      _iMax = count;
    }
    return self;
  }
  
//

  - (id) nextObject
  {
    while ( _i < _iMax ) {
      if ( _table[_i].key )
        return _table[_i++].object;
      _i++;
    }
    return nil;
  }

@end

//
#pragma mark -
//

@interface SBDictionary(SBDictionaryPrivate)

+ (id) allocWithCapacity:(unsigned int)capacity;
- (id) initWithCapacity:(unsigned int)capacity;

@end

@implementation SBDictionary(SBDictionaryPrivate)

  + (id) allocWithCapacity:(unsigned int)capacity
  {
    if ( capacity == 1 )
      return [SBSinglePairConcreteDictionary alloc];
    if ( capacity <= SBSmallBasicHashPairCapacity )
      return [SBSmallConcreteDictionary alloc];
    if ( capacity <= SBMediumBasicHashPairCapacity )
      return [SBMediumConcreteDictionary alloc];
    return [SBLargeConcreteDictionary alloc];
  }
  
//

  - (id) initWithCapacity:(unsigned int)capacity
  {
    return [self init];
  }

@end

@implementation SBDictionary

  + (id) alloc
  {
    if ( self == [SBDictionary class] )
      return [SBLargeConcreteDictionary alloc];
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
    return [[SBConcreteMutableDictionary alloc] initWithDictionary:self];
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( self == otherObject )
      return YES;
    if ( [otherObject isKindOf:[SBDictionary class]] )
      return [self isEqualToDictionary:(SBDictionary*)otherObject];
    return NO;
  }

//

  - (unsigned int) count
  {
    return 0;
  }

//

  - (id) objectForKey:(id)aKey
  {
    return nil;
  }
  
//

  - (SBEnumerator*) keyEnumerator
  {
    return nil;
  }

@end

//

@implementation SBDictionary(SBExtendedDictionary)

  - (BOOL) containsKey:(id)aKey
  {
    return ( [self objectForKey:aKey] != nil );
  }
  
//

  - (BOOL) containsObject:(id)object
  {
    SBEnumerator*   eObj = [self objectEnumerator];
    id              obj;
    
    while ( obj = [eObj nextObject] ) {
      if ( [obj isEqual:object] )
        return YES;
    }
    return NO;
  }

//

  - (SBArray*) allKeys
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBEnumerator*  eKey = [self keyEnumerator];
      id             keys[count];
        
      if ( eKey ) {
        unsigned int  i = 0;
        
        while ( i < count )
          keys[i++] = [eKey nextObject];
        
        aKeys = [SBArray arrayWithObjects:keys count:count];
      }
    }
    return aKeys;
  }

//

  - (SBArray*) allKeysForObject:(id)anObject
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBEnumerator*  eKey = [self keyEnumerator];
      id             keys[count];
        
      if ( eKey ) {
        unsigned int  i = 0;
        
        while ( keys[i] = [eKey nextObject] ) {
          if ( [keys[i] isEqual:anObject] )
            i++;
        }
        if ( i > 0 )
          aKeys = [SBArray arrayWithObjects:keys count:count];
      }
    }
    return aKeys;
  }

//

  - (SBArray*) allValues
  {
    SBArray*         aValues = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBEnumerator*  eKey = [self keyEnumerator];
      id             values[count];
        
      if ( eKey ) {
        unsigned int  i = 0;
        
        while ( i < count )
          values[i++] = [self objectForKey:[eKey nextObject]];
        
        aValues = [SBArray arrayWithObjects:values count:count];
      }
    }
    return aValues;
  }
  
//

  - (BOOL) isEqualToDictionary:(SBDictionary*)otherDictionary
  {
    if ( [self count] == [otherDictionary count] ) {
      SBEnumerator*   eKey = [self keyEnumerator];
      id              key;
      
      while ( key = [eKey nextObject] ) {
        if ( ! [[self objectForKey:key] isEqual:[otherDictionary objectForKey:key]] )
          break;
      }
      return ( key ? NO : YES );
    }
    return NO;
  }

//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBSimpleDictionaryObjectEnumerator alloc] initWithDictionary:self] autorelease];
  }

//

  - (SBArray*) objectsForKeys:(SBArray*)keys
  {
    return [self objectsForKeys:keys notFoundMarker:[SBNull null]];
  }
  - (SBArray*) objectsForKeys:(SBArray*)keys
    notFoundMarker:(id)marker
  {
    SBArray*          aValues = nil;
    unsigned int      count = [keys count];
    
    if ( count ) {
      id              values[count];
      unsigned int    i = 0;
      
      while ( i < count ) {
        id            obj = [self objectForKey:[keys objectAtIndex:i]];
        
        values[i++] = ( obj ? obj : marker );
      }
      aValues = [SBArray arrayWithObjects:values count:count];
    }
    return aValues;
  }
  
//

  - (SBArray*) keysSortedUsingSelector:(SEL)comparator
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBEnumerator*  eKey = [self keyEnumerator];
      id             keys[count];
        
      if ( eKey ) {
        unsigned int  i = 0;
        
        while ( i < count ) {
          id            key = [eKey nextObject];
          unsigned int  j = i;
          
          if ( i == 0 ) {
            keys[0] = key;
          } else {
            while ( j > 0 ) {
              if ( (SBComparisonResult)[keys[j - 1] perform:comparator with:key] == SBOrderDescending ) {
                keys[j] = keys[j - 1];
                j--;
              } else {
                break;
              }
            }
            keys[j] = key;
          }
          i++;
        }
        
        aKeys = [SBArray arrayWithObjects:keys count:count];
      }
    }
    return aKeys;
  }

//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    SBEnumerator*   eKey = [self keyEnumerator];
    id              key;
    
    while ( key = [eKey nextObject] )
      [[self objectForKey:key] perform:aSelector];
  }
  
//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    SBEnumerator*   eKey = [self keyEnumerator];
    id              key;
    
    while ( key = [eKey nextObject] )
      [[self objectForKey:key] perform:aSelector with:argument];
  }

@end

@implementation SBDictionary(SBDictionaryCreation)

  + (id) dictionary
  {
    static SBDictionary* __SBNullDictionary = nil;
    
    if ( __SBNullDictionary == nil )
      __SBNullDictionary = [[SBNullDictionary alloc] init];
    return __SBNullDictionary;
  }
  
//

  + (id) dictionaryWithObjects:(SBArray*)objects
    forKeys:(SBArray*)keys
  {
    return [[[self allocWithCapacity:[objects count]] initWithObjects:objects forKeys:keys] autorelease];
  }
  
//

  + (id) dictionaryWithObjects:(id *)objects
    forKeys:(id *)keys
    count:(unsigned)count
  {
    return [[[self allocWithCapacity:count] initWithObjects:objects forKeys:keys count:count] autorelease];
  }
  
//

  + (id) dictionaryWithObjectsAndKeys:(id)firstObject, ...
  {
    id              newDict = nil;
    va_list         vargs;
    unsigned int    count = 0;
    id              obj = firstObject;
    
    va_start(vargs, firstObject);
    while ( obj ) {
      obj = va_arg(vargs, id);
      if ( obj ) {
        count++;
        obj = va_arg(vargs, id);
      }
    }
    va_end(vargs);
    
    if ( count ) {
      va_start(vargs, firstObject);
      newDict = [[[self allocWithCapacity:count] initWithObject:firstObject andArguments:vargs] autorelease];
      va_end(vargs);
    } else {
      newDict = [self dictionary];
    }
    return newDict;
  }
  
//

  - (id) initWithObjects:(SBArray*)objects
    forKeys:(SBArray*)keys
  {
    return [self init];
  }
  
//

  - (id) initWithObjects:(id*)objects
    forKeys:(id*)keys
    count:(unsigned int)count
  {
    return [self init];
  }

//

  - (id) initWithObjectsAndKeys:(id)firstObject, ...
  {
    va_list         vargs;
    
    va_start(vargs, firstObject);
    self = [self initWithObject:firstObject andArguments:vargs];
    va_end(vargs);
    
    return self;
  }
  
//

  - (id) initWithObject:(id)firstObject
    andArguments:(va_list)arguments
  {
    return [self init];
  }
  
//

  - (id) initWithDictionary:(SBDictionary*)otherDictionary
  {
    return [self init];
  }

//

  + (id) dictionaryWithDictionary:(SBDictionary*)dict
  {
    return [[[self allocWithCapacity:[dict count]] initWithDictionary:dict] autorelease];
  }
  
//

  + (id) dictionaryWithObject:(id)object forKey:(id)aKey
  {
    return [[[self allocWithCapacity:1] initWithObjects:&object forKeys:&aKey count:1] autorelease];
  }
  
//

  - (id) initWithDictionary:(SBDictionary*)otherDictionary
    copyItems:(BOOL)aBool
  {
    return [self init];
  }

@end

//
#pragma mark -
//

@implementation SBNullDictionary

@end

//

@implementation SBConcreteDictionary : SBDictionary

  - (id) initWithObjects:(SBArray*)objects
    forKeys:(SBArray*)keys
  {
    unsigned int      i = 0, iMax = [objects count];
    
    if ( iMax > [keys count] )
      iMax = [keys count];
    
    if ( self = [self initWithCapacity:iMax] ) {
      while ( i < iMax ) {
        [self takeObject:[objects objectAtIndex:i] forKey:[keys objectAtIndex:i]];
        i++;
      }
    }
    return self;
  }
  
//

  - (id) initWithObjects:(id *)objects
    forKeys:(id *)keys
    count:(unsigned)count
  {
    unsigned int      i = 0;
    
    if ( self = [self initWithCapacity:count] ) {
      while ( i < count ) {
        [self takeObject:objects[i] forKey:keys[i]];
        i++;
      }
    }
    return self;
  }

//

  - (id) initWithObject:(id)firstObject
    andArguments:(va_list)arguments
  {
    va_list       argCopy;
    id            obj = firstObject;
    unsigned int  count = 0;
    
    //  Count the pairs:
    va_copy(argCopy, arguments);
    while ( obj ) {
      obj = va_arg(argCopy, id);
      if ( obj ) {
        count++;
        obj = va_arg(argCopy, id);
      }
    }
    
    if ( self = [self initWithCapacity:count] ) {
      id          key;
      
      obj = firstObject;
      while ( obj ) {
        key = va_arg(arguments, id);
        if ( key ) {
          [self takeObject:obj forKey:key];
          obj = va_arg(arguments, id);
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithDictionary:(SBDictionary*)otherDictionary
  {
    if ( self = [self initWithCapacity:[otherDictionary count]] ) {
      SBEnumerator*     eKey = [otherDictionary keyEnumerator];
      id                key;
      
      while ( key = [eKey nextObject] )
        [self takeObject:[otherDictionary objectForKey:key] forKey:key];
    }
    return self;
  }

//

  - (void) dealloc
  {
    SBBasicHashTableDealloc([self basicHashTable]);
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBBasicHashTable*     myTable = [self basicHashTable];
    unsigned int          i = 0;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " ( capacity: keys = %u | table = %u ) {\n",
        myTable->keyCapacity,
        myTable->tableCapacity
      );
    while ( i < myTable->tableCapacity ) {
      id      key, object;
      
      if ( (key = myTable->table[i].key) ) {
        if ( [key isKindOf:[SBString class]] ) {
          fprintf(stream, "    \'");
          [(SBString*)key writeToStream:stream];
          fprintf(stream, "\' = ");
        } else if ( [key isKindOf:[SBNumber class]] ) {
          fprintf(stream, "    ");
          [(SBNumber*)key writeToStream:stream];
          fprintf(stream, " = ");
        } else {
          fprintf(stream, "    %s@%p = ", [key name], key);
        }
        
        object = myTable->table[i].object;
        
        if ( [object isKindOf:[SBString class]] ) {
          fprintf(stream, "\'");
          [(SBString*)object writeToStream:stream];
          fprintf(stream, "\'\n");
        } else if ( [object isKindOf:[SBNumber class]] ) {
          [(SBNumber*)object writeToStream:stream];
          fputc('\n', stream);
        } else if ( [object isKindOf:[SBArray class]] ) {
          [(SBArray*)object writeToStream:stream];
          fputc('\n', stream);
        } else {
          fprintf(stream, "%s@%p\n", [object name], object);
        }
      }
      i++;
    }
    fprintf(stream, "}\n");
  }

//

  - (SBBasicHashTable*) basicHashTable
  {
    return NULL;
  }

//

  - (void) takeObject:(id)object
    forKey:(id)aKey
  {
    SBBasicHashTableAddPair([self basicHashTable], aKey, object);
  }
  
//
#pragma mark SBDictionary methods
//

  - (unsigned int) count
  {
    return ([self basicHashTable])->keyCount;
  }

//

  - (id) objectForKey:(id)aKey
  {
    SBHashPair*     match = SBBasicHashTableFindPairForKey([self basicHashTable], aKey);
    
    return ( match ? match->object : nil );
  }

//

  - (SBEnumerator*) keyEnumerator
  {
    SBBasicHashTable*   myTable = [self basicHashTable];
    
    return [[[SBConcreteDictionaryKeyEnumerator alloc] initWithKeys:myTable->keys count:myTable->keyCount] autorelease];
  }

//
#pragma mark SBExtendedDictionary methods
//

  - (SBEnumerator*) objectEnumerator
  {
    SBBasicHashTable*   myTable = [self basicHashTable];
    
    return [[[SBConcreteDictionaryObjectEnumerator alloc] initWithTable:myTable->table count:myTable->tableCapacity] autorelease];
  }

@end

//

@implementation SBSinglePairConcreteDictionary

  - (id) init
  {
    if ( self = [super init] ) {
      SBSingletonBasicHashTableInit(&_table);
    }
    return self;
  }

//

  - (SBBasicHashTable*) basicHashTable
  {
    return &_table.base;
  }

//

  - (unsigned int) count
  {
    return _table.base.keyCount;
  }
  
//

  - (id) objectForKey:(id)aKey
  {
    if ( _table.base.keyCount && [_table.key isEqual:aKey] )
      return _table.pair.object;
    return nil;
  }

@end

//

@implementation SBSmallConcreteDictionary

  - (id) init
  {
    if ( self = [super init] ) {
      SBSmallBasicHashTableInit(&_table);
    }
    return self;
  }
  
//

  - (SBBasicHashTable*) basicHashTable
  {
    return &_table.base;
  }

@end

//

@implementation SBMediumConcreteDictionary

  - (id) init
  {
    if ( self = [super init] ) {
      SBMediumBasicHashTableInit(&_table);
    }
    return self;
  }
  
//

  - (SBBasicHashTable*) basicHashTable
  {
    return &_table.base;
  }

@end

//

@implementation SBLargeConcreteDictionary

  - (id) init
  {
    return [self initWithCapacity:1];
  }

//

  - (id) initWithCapacity:(unsigned int)capacity
  {
    if ( self = [super init] ) {
      _table = SBBasicHashTableCreate(capacity);
      if ( ! _table ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (SBBasicHashTable*) basicHashTable
  {
    return _table;
  }

@end

//
#pragma mark -
//

@implementation SBMutableDictionary

  + (id) alloc
  {
    if ( self == [SBMutableDictionary class] )
      return [SBConcreteMutableDictionary alloc];
    return [super alloc];
  }

//

  + (id) allocWithCapacity:(unsigned int)capacity
  {
    return [self alloc];
  }

//

  + (id) dictionary
  {
    return [[[SBConcreteMutableDictionary alloc] init] autorelease];
  }

//

  - (id) copy
  {
    return [[SBDictionary allocWithCapacity:[self count]] initWithDictionary:self];
  }

//

  - (void) setObject:(id)anObject
    forKey:(id)aKey
  {
  }
  
//

  - (void) removeObjectForKey:(id)aKey
  {
  }
  
@end

@implementation SBMutableDictionary(SBExtendedMutableDictionary)

  - (void) addElementsFromDictionary:(SBDictionary*)otherDictionary
  {
    SBEnumerator*       eKey = [otherDictionary keyEnumerator];
    id                  key;
    
    while ( key = [eKey nextObject] )
      [self setObject:[otherDictionary objectForKey:key] forKey:key];
  }
  
//

  - (void) removeAllObjects
  {
    SBArray*            keys = [self allKeys];
    unsigned int        i = 0, iMax = [keys count];
    
    while ( i < iMax )
      [self removeObjectForKey:[keys objectAtIndex:i++]];
  }
  
//

  - (void) removeObjectsWithObject:(id)object
  {
    SBArray*            keys = [self allKeys];
    unsigned int        i = 0, iMax = [keys count];
    
    while ( i < iMax ) {
      id                key = [keys objectAtIndex:i++];
      
      if ( [[self objectForKey:key] isEqual:object] )
        [self removeObjectForKey:key];
    }
  }

//

  - (void) removeObjectsForKeys:(SBArray*)keyArray
  {
    unsigned int        i = 0, iMax = [keyArray count];
    
    while ( i < iMax )
      [self removeObjectForKey:[keyArray objectAtIndex:i++]];
  }
  
//

  - (void) setDictionary:(SBDictionary*)otherDictionary
  {
    [self removeAllObjects];
    [self addElementsFromDictionary:otherDictionary];
  }

@end

@implementation SBMutableDictionary(SBMutableDictionaryCreation)

  + (id) dictionaryWithFixedCapacity:(unsigned int)maxItems
  {
    return [[[self alloc] initWithFixedCapacity:maxItems] autorelease];
  }
  
//

  - (id) initWithFixedCapacity:(unsigned int)maxItems
  {
    return [self init];
  }

@end


//
#pragma mark -
//

typedef struct _SBMutableHashPair {
  id                              key;
  id                              object;
  struct _SBMutableHashPair*      link;
} SBMutableHashPair;

//

SBMutableHashPair*
SBMutableHashPairFindKey(
  SBMutableHashPair*    aPair,
  id                    key
)
{
  while ( aPair ) {
    if ( [aPair->key isEqual:key] )
      return aPair;
    aPair = aPair->link;
  }
  return NULL;
}

//

SBMutableHashPair*
SBMutableHashPairFindObject(
  SBMutableHashPair*    aPair,
  id                    object
)
{
  while ( aPair ) {
    if ( [aPair->object isEqual:object] )
      return aPair;
    aPair = aPair->link;
  }
  return NULL;
}

//

typedef struct _SBMutableHashPairPool {
  unsigned int                    pairCapacity;
  SBMutableHashPair*              pairs;
  unsigned int                    tableCapacity;
  SBMutableHashPair**             table;
  struct _SBMutableHashPairPool*  link;
} SBMutableHashPairPool;

//

BOOL
SBMutableHashPairPoolAlloc(
  SBMutableHashPairPool**   topPool,
  unsigned int              pairCapacity
)
{
  SBMutableHashPairPool*    newPool = NULL;
  size_t                    bytes = sizeof(SBMutableHashPairPool);
  unsigned int              tableCapacity = SBHashTableMultiplier * pairCapacity;
  
  //  Account for the number of pairs we're looking to create:
  bytes += pairCapacity * sizeof(SBMutableHashPair);
  
  //  Account for the added table space:
  bytes += tableCapacity * sizeof(SBMutableHashPair*);
  
  //  Allocate the pool:
  newPool = (SBMutableHashPairPool*)objc_calloc(1, bytes);
  
  if ( newPool ) {
    SBMutableHashPair*      pairs = (SBMutableHashPair*)(((void*)newPool) + sizeof(SBMutableHashPairPool));
    SBMutableHashPair**     table = (SBMutableHashPair**)(pairs + pairCapacity);
    
    newPool->pairCapacity = pairCapacity;
    newPool->pairs = pairs;
    newPool->tableCapacity = tableCapacity;
    newPool->table = table;
    
    if ( *topPool )
      (*topPool)->link = newPool;
    *topPool = newPool;
      
    
    // Initialize the buckets:
    while ( --pairCapacity > 0 ) {
      pairs->link = pairs + 1;
      pairs++;
    }
    return YES;
  }
  return NO;
}

//

SBMutableHashPair*
SBMutableHashPairPoolAllocPair(
  SBMutableHashPairPool*    topPool
)
{
  SBMutableHashPair*        pair = topPool->pairs;
  
  if ( pair ) {
    topPool->pairs = pair->link;
    pair->link = NULL;
  }
  return pair;
}

//

void
SBMutableHashPairPoolDeallocPair(
  SBMutableHashPairPool*    topPool,
  SBMutableHashPair*        pair
)
{
  if ( pair->key ) {
    [pair->key release];
    pair->key = nil;
  }
  if ( pair->object ) {
    [pair->object release];
    pair->object = nil;
  }
  pair->link = topPool->pairs;
  topPool->pairs = pair;
}

//

static inline
SBMutableHashPair**
SBMutableHashPairPoolFindTableIndex(
  SBMutableHashPairPool*    pools,
  unsigned int              index
)
{
  while ( pools ) {
    if ( index < pools->tableCapacity )
      return (pools->table + index);
    index -= pools->tableCapacity;
    pools = pools->link;
  }
  return NULL;
}

//
#pragma mark -
//

@interface SBConcreteMutableDictionaryEnumerator : SBEnumerator
{
  SBMutableHashPairPool*        _pool;
  SBMutableHashPair*            _pair;
  unsigned int                  _i, _iMax;
  BOOL                          _doKeys;
}

- (id) initWithBasePool:(SBMutableHashPairPool*)pool doKeys:(BOOL)doKeys;

@end

@implementation SBConcreteMutableDictionaryEnumerator

  - (id) initWithBasePool:(SBMutableHashPairPool*)pool
    doKeys:(BOOL)doKeys
  {
    if ( self = [super init] ) {
      _pool = pool;
      _i = 0;
      _iMax = ( pool ? pool->tableCapacity : 0 );
      _doKeys = doKeys;
    }
    return self;
  }

//

  - (id) nextObject
  {
    id      result = nil;
    
    while ( _pool ) {
      if ( ! _pair ) {
        while ( _i < _iMax ) {
          if ( _pool->table[_i] ) {
            _pair = _pool->table[_i];
            break;
          }
          _i++;
        }
        if ( ! _pair ) {
          _pool = _pool->link;
          _i = 0;
          _iMax = ( _pool ? _pool->tableCapacity : 0 );
          continue;
        }
      }
      result = ( _doKeys ? _pair->key : _pair->object );
      _pair = _pair->link;
      if ( ! _pair ) {
        _i++;
      }
      break;
    }
    return result;
  }

@end

//
#pragma mark -
//

@interface SBConcreteMutableDictionary : SBMutableDictionary
{
  SBMutableHashPairPool*        _pools;
  SBMutableHashPairPool*        _topPool;
  unsigned int                  _count;
  unsigned int                  _pairCapacity;
  unsigned int                  _tableCapacity;
  unsigned int                  _hash;
  struct {
    short unsigned int  collisions;
    short unsigned int  nonCollisions;
  } _stats;
  struct {
    unsigned int        countIsCached : 1;
    unsigned int        capacityIsCached : 1;
    unsigned int        hashIsCached : 1;
    unsigned int        fixedCapacity : 1;
  } _flags;
}

- (void) calculateCapacities;
- (unsigned int) pairCapacity;
- (unsigned int) tableCapacity;
- (BOOL) increaseCapacity;

@end

@implementation SBConcreteMutableDictionary

  - (id) init
  {
    if ( self = [super init] ) {
      _flags.countIsCached = _flags.capacityIsCached = YES;
    }
    return self;
  }

//

  - (id) initWithCapacity:(unsigned int)capacity
  {
    if ( self = [self init] ) {
      if ( SBMutableHashPairPoolAlloc(&_topPool, capacity) ) {
        _pools = _topPool;
        _flags.capacityIsCached = NO;
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithFixedCapacity:(unsigned int)maxItems
  {
    if ( self = [self initWithCapacity:maxItems] ) {
      _flags.fixedCapacity = YES;
    }
    return self;
  }

//

  - (id) initWithObjects:(SBArray*)objects
    forKeys:(SBArray*)keys
  {
    unsigned int      i = 0, iMax = [objects count];
    
    if ( iMax > [keys count] )
      iMax = [keys count];
    
    if ( self = [self initWithCapacity:iMax + 8] ) {
      while ( i < iMax ) {
        [self setObject:[objects objectAtIndex:i] forKey:[keys objectAtIndex:i]];
        i++;
      }
    }
    return self;
  }
  
//

  - (id) initWithObjects:(id *)objects
    forKeys:(id *)keys
    count:(unsigned)count
  {
    unsigned int      i = 0;
    
    if ( self = [self initWithCapacity:count + 8] ) {
      while ( i < count ) {
        [self setObject:objects[i] forKey:keys[i]];
        i++;
      }
    }
    return self;
  }

//

  - (id) initWithObject:(id)firstObject
    andArguments:(va_list)arguments
  {
    va_list       argCopy;
    id            obj = firstObject;
    unsigned int  count = 0;
    
    //  Count the pairs:
    va_copy(argCopy, arguments);
    while ( obj ) {
      obj = va_arg(argCopy, id);
      if ( obj ) {
        count++;
        obj = va_arg(argCopy, id);
      }
    }
    
    if ( self = [self initWithCapacity:count + 8] ) {
      id          key;
      
      obj = firstObject;
      while ( obj ) {
        key = va_arg(arguments, id);
        if ( key ) {
          [self setObject:obj forKey:key];
          obj = va_arg(arguments, id);
        }
      }
    }
    return self;
  }
  
//

  - (id) initWithDictionary:(SBDictionary*)otherDictionary
  {
    if ( self = [self initWithCapacity:[otherDictionary count] + 8] ) {
      SBEnumerator*     eKey = [otherDictionary keyEnumerator];
      id                key;
      
      while ( key = [eKey nextObject] )
        [self setObject:[otherDictionary objectForKey:key] forKey:key];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    // Walk each pool's table, releasing any key-value pairs then scrubbing
    // the pool itself:
    while ( _pools ) {
      unsigned int      i = 0, iMax = _pools->tableCapacity;
      
      while ( i < iMax ) {
        if ( _pools->table[i] ) {
          SBMutableHashPair*    pair = _pools->table[i];
          
          while ( pair ) {
            [pair->key release];
            [pair->object release];
            pair = pair->link;
          }
        }
        i++;
      }
      
      SBMutableHashPairPool*    nextPool = _pools->link;
      
      objc_free(_pools);
      _pools = nextPool;
    }
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBMutableHashPairPool*      pool = _pools;
    unsigned int                additions = _stats.collisions + _stats.nonCollisions;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " (\n"
        "  count: %u\n"
        "  capacity:\n"
        "    keys = %u\n"
        "    table = %u\n"
        "  stats:\n"
        "    collisions = %hu\n"
        "    rate = %0.1lf%%\n"
        ") {\n",
        [self count],
        [self pairCapacity],
        [self tableCapacity],
        _stats.collisions,
        ( additions ? (100.0 * (float)_stats.collisions / (float)additions) : 0.0 )
      );
    while ( pool ) {
      unsigned int    i = 0, iMax = pool->tableCapacity;
      
      while ( i < iMax ) {
        if ( pool->table[i] ) {
          SBMutableHashPair*    pair = pool->table[i];
          
          while ( pair ) {
            if ( (pair->key) ) {
              if ( [pair->key isKindOf:[SBString class]] ) {
                fprintf(stream, "    \'");
                [(SBString*)pair->key writeToStream:stream];
                fprintf(stream, "\' = ");
              } else if ( [pair->key isKindOf:[SBNumber class]] ) {
                fprintf(stream, "    ");
                [(SBNumber*)pair->key writeToStream:stream];
                fprintf(stream, " = ");
              } else {
                fprintf(stream, "    %s@%p = ", [pair->key name], pair->key);
              }
              
              if ( [pair->object isKindOf:[SBString class]] ) {
                fprintf(stream, "\'");
                [(SBString*)pair->object writeToStream:stream];
                fprintf(stream, "\'\n");
              } else if ( [pair->object isKindOf:[SBNumber class]] ) {
                [(SBNumber*)pair->object writeToStream:stream];
                fputc('\n', stream);
              } else if ( [pair->object isKindOf:[SBArray class]] ) {
                [(SBArray*)pair->object writeToStream:stream];
                fputc('\n', stream);
              } else {
                fprintf(stream, "%s@%p\n", [pair->object name], pair->object);
              }
            }
            pair = pair->link;
          }
        }
        i++;
      }
      pool = pool->link;
    }
    fprintf(stream, "}\n");
  }

//

  - (void) calculateCapacities
  {
    SBMutableHashPairPool*      pool = _pools;
    
    _pairCapacity = _tableCapacity = 0;
    while ( pool ) {
      _pairCapacity += pool->pairCapacity;
      _tableCapacity += pool->tableCapacity;
      pool = pool->link;
    }
    _flags.capacityIsCached = YES;
  }
  
//

  - (unsigned int) pairCapacity
  {
    if ( ! _flags.capacityIsCached )
      [self calculateCapacities];
    return _pairCapacity;
  }
  - (unsigned int) tableCapacity
  {
    if ( ! _flags.capacityIsCached )
      [self calculateCapacities];
    return _tableCapacity;
  }

//

  - (BOOL) increaseCapacity
  {
    unsigned int    delta = [self count];
    
    if ( _flags.fixedCapacity )
      return NO;
    
    if ( SBMutableHashPairPoolAlloc(&_topPool, ( delta ? delta : 32 ) ) ) {
      if ( ! _pools ) {
        // Fresh start:
        _pools = _topPool;
        _pairCapacity += _topPool->pairCapacity;
        _tableCapacity += _topPool->tableCapacity;
        _flags.countIsCached = _flags.capacityIsCached = YES;
        return YES;
      }
      if ( _flags.capacityIsCached ) {
        _pairCapacity += _topPool->pairCapacity;
        _tableCapacity += _topPool->tableCapacity;
      }
      
      // We need to pull all key-value pairs out of the table and reindex them now:
      SBMutableHashPair*        basePair = NULL;
      SBMutableHashPair*        lastPair = NULL;
      SBMutableHashPairPool*    pool = _pools;
      
      // Re-link all pairs in the old table into a single chain:
      while ( pool != _topPool ) {
        unsigned int            i = 0, iMax = pool->tableCapacity;
        
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            if ( basePair == NULL )
              basePair = pool->table[i];
            else
              lastPair->link = pool->table[i];
              
            lastPair = pool->table[i];
            while ( lastPair && lastPair->link )
              lastPair = lastPair->link;
              
            pool->table[i] = NULL;
          }
          i++;
        }
        pool = pool->link;
      }
      
      // Now that "basePair" points to the chain of key-value pairs, just re-add them
      // using the new table capacity:
      unsigned int              newCapacity = [self tableCapacity];
      
      _stats.collisions = _stats.nonCollisions = 0;
      
      while ( basePair ) {
        unsigned int            index = [basePair->key hash] % newCapacity;
        SBMutableHashPair**     tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
        
        if ( tableSlot ) {
          if ( *tableSlot ) {
            SBMutableHashPair*  pair = *tableSlot;
            
            // Find the end of this index's chain:
            while ( pair && pair->link )
              pair = pair->link;
            
            // Append the pair:
            pair->link = basePair;
            basePair = basePair->link;
            pair->link->link = NULL;
            
            _stats.collisions++;
          } else {
            // First item at this index:
            *tableSlot = basePair;
            basePair = basePair->link;
            (*tableSlot)->link = NULL;
            
            _stats.nonCollisions++;
          }
        } else {
          // Should NEVER get here:
          exit(1);
        }
      }
      
      return YES;
    }
    return NO;
  }

//
#pragma mark SBDictionary methods
//

  - (unsigned int) count
  {
    if ( ! _flags.countIsCached ) {
      SBMutableHashPairPool*    pool = _pools;
      
      _count = 0;
      while ( pool ) {
        SBMutableHashPair*    pair = pool->pairs;
        
        while ( pair ) {
          if ( pair->key )
            _count++;
          pair = pair->link;
        }
        pool = pool->link;
      }
    }
    return _count;
  }
  
//

  - (id) objectForKey:(id)aKey
  {
    if ( _pools ) {
      unsigned int          index = [aKey hash] % [self tableCapacity];
      SBMutableHashPair**   tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
      
      if ( tableSlot && *tableSlot ) {
        SBMutableHashPair*  pair = *tableSlot;
        
        do {
          if ( [pair->key isEqual:aKey] )
            return pair->object;
          pair = pair->link;
        } while ( pair );
      }
    }
    return nil;
  }
  
//

  - (SBEnumerator*) keyEnumerator
  {
    return [[[SBConcreteMutableDictionaryEnumerator alloc] initWithBasePool:_pools doKeys:YES] autorelease];
  }
  
//
#pragma mark SBExtendedDictionary methods
//

  - (BOOL) containsKey:(id)aKey
  {
    if ( _pools ) {
      unsigned int          index = [aKey hash] % [self tableCapacity];
      SBMutableHashPair**   tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
      
      if ( tableSlot && *tableSlot ) {
        SBMutableHashPair*  pair = *tableSlot;
        
        while ( pair ) {
          if ( [pair->key isEqual:aKey] )
            return YES;
          pair = pair->link;
        }
      }
    }
    return NO;
  }
  
//

  - (BOOL) containsObject:(id)object
  {
    SBMutableHashPairPool*    pool = _pools;
    
    while ( pool ) {
      unsigned int      i = 0, iMax = pool->tableCapacity;
      
      while ( i < iMax ) {
        if ( pool->table[i] ) {
          SBMutableHashPair*  pair = pool->table[i];
          
          while ( pair ) {
            if ( [pair->object isEqual:object] )
              return YES;
            pair = pair->link;
          }
        }
        i++;
      }
      pool = pool->link;
    }
    return NO;
  }
  
//

  - (SBArray*) allKeys
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBMutableHashPairPool*    pool = _pools;
      id                        keys[count];
      unsigned int              k = 0;
      
      while ( pool ) {
        unsigned int      i = 0, iMax = pool->tableCapacity;
        
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            SBMutableHashPair*  pair = pool->table[i];
            
            while ( pair ) {
              keys[k++] = pair->key;
              pair = pair->link;
            }
          }
          i++;
        }
        pool = pool->link;
      }
      if ( k )
        aKeys = [SBArray arrayWithObjects:keys count:k];
    }
    return aKeys;
  }
  
//

  - (SBArray*) allKeysForObject:(id)anObject
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBMutableHashPairPool*    pool = _pools;
      id                        keys[count];
      unsigned int              k = 0;
      
      while ( pool ) {
        unsigned int      i = 0, iMax = pool->tableCapacity;
        
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            SBMutableHashPair*  pair = pool->table[i];
            
            while ( pair ) {
              if ( [pair->object isEqual:anObject] )
                keys[k++] = pair->key;
              pair = pair->link;
            }
          }
          i++;
        }
        pool = pool->link;
      }
      
      if ( k )
        aKeys = [SBArray arrayWithObjects:keys count:k];
    }
    return aKeys;
  }
  
//

  - (SBArray*) allValues
  {
    SBArray*         aValues = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBMutableHashPairPool*    pool = _pools;
      id                        values[count];
      unsigned int              k = 0;
      
      while ( pool ) {
        unsigned int      i = 0, iMax = pool->tableCapacity;
        
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            SBMutableHashPair*  pair = pool->table[i];
            
            while ( pair ) {
              values[k++] = pair->object;
              pair = pair->link;
            }
          }
          i++;
        }
        pool = pool->link;
      }
      
      if ( k )
        aValues = [SBArray arrayWithObjects:values count:k];
    }
    return aValues;
  }
  
//

  - (BOOL) isEqualToDictionary:(SBDictionary*)otherDictionary
  {
    if ( [self count] == [otherDictionary count] ) {
      if ( [self count] == 0 ) {
        // Both are empty:
        return YES;
      }
      if ( _pools ) {
        SBMutableHashPairPool*    pool = _pools;
        
        while ( pool ) {
          unsigned int            i = 0, iMax = pool->tableCapacity;
          
          while ( i < iMax ) {
            if ( pool->table[i] ) {
              SBMutableHashPair*  pair = pool->table[i];
              
              while ( pair ) {
                if ( ! [pair->object isEqual:[otherDictionary objectForKey:pair->key]] )
                  return NO;
                pair = pair->link;
              }
            }
            i++;
          }
          pool = pool->link;
        }
        return YES;
      }
    }
    return NO;
  }
  
//

  - (SBEnumerator*) objectEnumerator
  {
    return [[[SBConcreteMutableDictionaryEnumerator alloc] initWithBasePool:_pools doKeys:NO] autorelease];
  }

//

  - (SBArray*) objectsForKeys:(SBArray*)keys
    notFoundMarker:(id)marker
  {
    SBArray*          aValues = nil;
    unsigned int      count = [keys count];
    
    if ( count && _pools ) {
      SBMutableHashPairPool*    pool = _pools;
      id                        values[count];
      unsigned int              i = 0;
      
      // Initialize to all slots "not found":
      while ( i < count )
        values[i++] = marker;
      
      // Walk the table:
      while ( pool ) {
        unsigned int            iMax = pool->tableCapacity;
        
        i = 0;
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            SBMutableHashPair*  pair = pool->table[i];
            
            while ( pair ) {
              unsigned int      j = [keys indexOfObject:pair->key];
              
              if ( j != SBNotFound )
                values[j] = pair->object;
              pair = pair->link;
            }
          }
          i++;
        }
        pool = pool->link;
      }
      aValues = [SBArray arrayWithObjects:values count:count];
    }
    return aValues;
  }

//

  - (SBArray*) keysSortedUsingSelector:(SEL)comparator
  {
    SBArray*         aKeys = nil;
    unsigned int     count = [self count];
    
    if ( count ) {
      SBMutableHashPairPool*    pool = _pools;
      id                        keys[count];
      unsigned int              k = 0;
      
      while ( pool ) {
        unsigned int      i = 0, iMax = pool->tableCapacity;
        
        while ( i < iMax ) {
          if ( pool->table[i] ) {
            SBMutableHashPair*  pair = pool->table[i];
            
            while ( pair ) {
              unsigned int  j = k;
          
              if ( k == 0 ) {
                keys[0] = pair->key;
              } else {
                while ( j > 0 ) {
                  if ( (SBComparisonResult)[keys[j - 1] perform:comparator with:pair->key] == SBOrderDescending ) {
                    keys[j] = keys[j - 1];
                    j--;
                  } else {
                    break;
                  }
                }
                keys[j] = pair->key;
              }
              k++;
              pair = pair->link;
            }
          }
          i++;
        }
        pool = pool->link;
      }
      
      if ( k )
        aKeys = [SBArray arrayWithObjects:keys count:k];
    }
    return aKeys;
  }
  
//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
  {
    SBMutableHashPairPool*    pool = _pools;
    
    while ( pool ) {
      unsigned int      i = 0, iMax = pool->tableCapacity;
      
      while ( i < iMax ) {
        if ( pool->table[i] ) {
          SBMutableHashPair*  pair = pool->table[i];
          
          while ( pair ) {
            [pair->object perform:aSelector];
            pair = pair->link;
          }
        }
        i++;
      }
      pool = pool->link;
    }
  }
  
//

  - (void) makeObjectsPerformSelector:(SEL)aSelector
    withObject:(id)argument
  {
    SBMutableHashPairPool*    pool = _pools;
    
    while ( pool ) {
      unsigned int      i = 0, iMax = pool->tableCapacity;
      
      while ( i < iMax ) {
        if ( pool->table[i] ) {
          SBMutableHashPair*  pair = pool->table[i];
          
          while ( pair ) {
            [pair->object perform:aSelector with:argument];
            pair = pair->link;
          }
        }
        i++;
      }
      pool = pool->link;
    }
  }
  
//
#pragma mark SBMutableDictionary methods
//

  - (void) setObject:(id)anObject
    forKey:(id)aKey
  {
    unsigned int            hash = [aKey hash];
    
    if ( _pools ) {
      // Does the key already occur in the table?
      unsigned int          index = hash % [self tableCapacity];
      SBMutableHashPair**   tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
      
      if ( tableSlot && *tableSlot ) {
        SBMutableHashPair*  pair = *tableSlot;
        
        do {
          if ( [pair->key isEqual:aKey] ) {
            // Replace this key-value pair:
            aKey = [aKey copy];
            anObject = [anObject retain];
            [pair->key release]; pair->key = aKey;
            [pair->object release]; pair->object = anObject;
            return;
          }
          pair = pair->link;
        } while ( pair );
      }
    }
    
    // Are we at capacity?
    if ( [self pairCapacity] == [self count] ) {
      if ( ! [self increaseCapacity] )
        return;
    }
    
    // Add the pair:
    unsigned int          index = hash % [self tableCapacity];
    SBMutableHashPair**   tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
    SBMutableHashPair*    newPair = SBMutableHashPairPoolAllocPair(_topPool);
    
    if ( newPair && tableSlot ) {
      newPair->key = [aKey copy];
      newPair->object = [anObject retain];
      newPair->link = NULL;
      
      if ( *tableSlot ) {
        SBMutableHashPair*  pair = *tableSlot;
        
        // Find the end of this index's chain:
        while ( pair && pair->link )
          pair = pair->link;
        
        // Append the pair:
        pair->link = newPair;
        
        _stats.collisions++;
      } else {
        // First item at this index:
        *tableSlot = newPair;
        _stats.nonCollisions++;
      }
      if ( _flags.countIsCached ) {
        _count++;
      }
    } else {
      exit(1);
    }
  }
  
//

  - (void) removeObjectForKey:(id)aKey
  {
    if ( _pools ) {
      unsigned int          index = [aKey hash] % [self tableCapacity];
      SBMutableHashPair**   tableSlot = SBMutableHashPairPoolFindTableIndex(_pools, index);
      
      if ( tableSlot && *tableSlot ) {
        SBMutableHashPair*  pair = *tableSlot;
        SBMutableHashPair*  prevPair = NULL;
        
        do {
          if ( [pair->key isEqual:aKey] ) {
            // Redo linking of anything behind us in the chain:
            if ( prevPair ) {
              prevPair->link = pair->link;
              
              // Update collision info:
              _stats.collisions--;
            } else {
              *tableSlot = pair->link;
              
              if ( pair->link ) {
                // Update collision info:
                _stats.collisions--;
              }
            }
            // Scrub the pair and re-attach it to the _topPool for recycling:
            SBMutableHashPairPoolDeallocPair(_topPool, pair);
            
            // Update cached count:
            if ( _flags.countIsCached )
              _count--;
              
            return;
          }
          prevPair = pair;
          pair = pair->link;
        } while ( pair );
      }
    }
  }

//
#pragma mark SBExtendedMutableDictionary methods
//

  - (void) removeAllObjects
  {
    SBMutableHashPairPool*    pool = _pools;
    
    // Walk each pools tables', scrubbing pairs as we go:
    while ( pool ) {
      unsigned int        i = 0, iMax = pool->tableCapacity;
      
      while ( i < iMax ) {
        if ( pool->table[i] ) {
          SBMutableHashPair*  pair = pool->table[i];
          
          pool->table[i] = NULL;
          do {
            SBMutableHashPair*  nextPair = pair->link;
            
            // Scrub the pair and re-attach it to the _topPool for recycling:
            SBMutableHashPairPoolDeallocPair(_topPool, pair);
            pair = nextPair;
          } while ( pair );
        }
        i++;
      }
      pool = pool->link;
    }
    
    _count = _stats.collisions = _stats.nonCollisions = 0;
    _flags.countIsCached = YES;
  }
  
//

  - (void) removeObjectsForKeys:(SBArray*)keyArray
  {
    unsigned int        i = 0, iMax = [keyArray count];
    
    while ( i < iMax )
      [self removeObjectForKey:[keyArray objectAtIndex:i++]];
  }

@end

//
#pragma mark -
//

unsigned int
SBDictionaryCountStringPairs(
  FILE*     fptr
)
{
  unsigned int      pairCount = 0;
  char*             line;
  size_t            lineLen;
  
  // Count the number of pairs in the file:
  while ( line = fgetln(fptr, &lineLen) ) {
    // Drop leading whitespace:
    while ( lineLen && isspace(*line) ) {
      line++;
      lineLen--;
    }
    // Quote?
    if ( *line == '\'' ) {
      line++; lineLen--;
    } else {
      continue;
    }
    // Find the end quote:
    while ( lineLen && (*line != '\'') ) {
      line++; lineLen--;
      
      if ( lineLen && (*line == '\'') ) {
        // Special case, a double quote:
        line++; lineLen--;
        if ( lineLen && (*line == '\'') ) {
          line++; lineLen--;
        } else {
          line--; lineLen++;
        }
      }
    }
    //  If we ended with a quote, then validate the rest of the line:
    if ( *line == '\'' ) {
      line++; lineLen--;
      while ( lineLen && ( *line != '\'' ) ) {
        line++; lineLen--;
      }
      if ( *line == '\'' ) {
        line++; lineLen--;
        // Find the end quote:
        while ( lineLen && (*line != '\'') ) {
          line++; lineLen--;
          
          if ( lineLen && (*line == '\'') ) {
            // Special case, a double quote:
            line++; lineLen--;
            if ( lineLen && (*line == '\'') ) {
              line++; lineLen--;
            } else {
              line--; lineLen++;
            }
          }
        }
        if ( *line == '\'' )
          pairCount++;
      }
    }
  }
  rewind(fptr);
  return pairCount;
}

unsigned int
SBDictionaryAssignStringPairs(
  FILE*           fptr,
  unsigned int    maxPairs,
  SBString**      keys,
  SBString**      values
)
{
  unsigned int      pairIndex = 0;
  char*             line;
  size_t            lineLen;
  
  // Count the number of pairs in the file:
  while ( (pairIndex < maxPairs) && (line = fgetln(fptr, &lineLen)) ) {
    char*           base = line;
    unsigned int    keyStart = 0, keyEnd = 0;
    unsigned int    valStart = 0, valEnd = 0;
    
    // Drop leading whitespace:
    while ( lineLen && isspace(*line) ) {
      line++;
      lineLen--;
      keyStart++;
    }
    // Quote?
    if ( *line == '\'' ) {
      line++; lineLen--;
      keyStart++;
    } else {
      continue;
    }
    // Find the end quote:
    keyEnd = keyStart;
    while ( lineLen && (*line != '\'') ) {
      line++; lineLen--;
      keyEnd++;
      
      if ( lineLen && (*line == '\'') ) {
        // Special case, a double quote:
        line++; lineLen--;
        keyEnd++;
        if ( lineLen && (*line == '\'') ) {
          line++; lineLen--;
          keyEnd++;
          if ( lineLen ) {
            // Shift the remaining stuff down to eliminate the double quote:
            memmove(line - 1, line, lineLen);
          }
        } else {
          line--; lineLen++;
          keyEnd--;
        }
      }
    }
    //  If we ended with a quote, then validate the rest of the line:
    if ( *line == '\'' ) {
      line++; lineLen--;
      valStart = keyEnd + 1;
      
      while ( lineLen && ( *line != '\'' ) ) {
        line++; lineLen--;
        valStart++;
      }
      if ( *line == '\'' ) {
        line++; lineLen--;
        valEnd = ++valStart;
        
        // Find the end quote:
        while ( lineLen && (*line != '\'') ) {
          line++; lineLen--;
          valEnd++;
          
          if ( lineLen && (*line == '\'') ) {
            // Special case, a double quote:
            line++; lineLen--;
            valEnd++;
            if ( lineLen && (*line == '\'') ) {
              line++; lineLen--;
              valEnd++;
              if ( lineLen ) {
                // Shift the remaining stuff down to eliminate the double quote:
                memmove(line - 1, line, lineLen);
              }
            } else {
              line--; lineLen++;
              valEnd--;
            }
          }
        }
        if ( *line == '\'' ) {
          keys[pairIndex] = [SBString stringWithUTF8String:(base + keyStart) length:(keyEnd - keyStart)];
          values[pairIndex] = [SBString stringWithUTF8String:(base + valStart) length:(valEnd - valStart)];
          pairIndex++;
        }
      }
    }
  }
  rewind(fptr);
  return pairIndex;
}

unsigned int
SBMutableDictionaryAddStringPairs(
  FILE*                 fptr,
  SBMutableDictionary*  aDict
)
{
  unsigned int      count = 0;
  char*             line;
  size_t            lineLen;
  
  // Count the number of pairs in the file:
  while ( (line = fgetln(fptr, &lineLen)) ) {
    char*           base = line;
    unsigned int    keyStart = 0, keyEnd = 0;
    unsigned int    valStart = 0, valEnd = 0;
    
    // Drop leading whitespace:
    while ( lineLen && isspace(*line) ) {
      line++;
      lineLen--;
      keyStart++;
    }
    // Quote?
    if ( *line == '\'' ) {
      line++; lineLen--;
      keyStart++;
    } else {
      continue;
    }
    // Find the end quote:
    keyEnd = keyStart;
    while ( lineLen && (*line != '\'') ) {
      line++; lineLen--;
      keyEnd++;
      
      if ( lineLen && (*line == '\'') ) {
        // Special case, a double quote:
        line++; lineLen--;
        keyEnd++;
        if ( lineLen && (*line == '\'') ) {
          line++; lineLen--;
          keyEnd++;
          if ( lineLen ) {
            // Shift the remaining stuff down to eliminate the double quote:
            memmove(line - 1, line, lineLen);
          }
        } else {
          line--; lineLen++;
          keyEnd--;
        }
      }
    }
    //  If we ended with a quote, then validate the rest of the line:
    if ( *line == '\'' ) {
      line++; lineLen--;
      valStart = keyEnd + 1;
      
      while ( lineLen && ( *line != '\'' ) ) {
        line++; lineLen--;
        valStart++;
      }
      if ( *line == '\'' ) {
        line++; lineLen--;
        valEnd = ++valStart;
        
        // Find the end quote:
        while ( lineLen && (*line != '\'') ) {
          line++; lineLen--;
          valEnd++;
          
          if ( lineLen && (*line == '\'') ) {
            // Special case, a double quote:
            line++; lineLen--;
            valEnd++;
            if ( lineLen && (*line == '\'') ) {
              line++; lineLen--;
              valEnd++;
              if ( lineLen ) {
                // Shift the remaining stuff down to eliminate the double quote:
                memmove(line - 1, line, lineLen);
              }
            } else {
              line--; lineLen++;
              valEnd--;
            }
          }
        }
        if ( *line == '\'' ) {
          [aDict setObject:[SBString stringWithUTF8String:(base + valStart) length:(valEnd - valStart)]
                  forKey:[SBString stringWithUTF8String:(base + keyStart) length:(keyEnd - keyStart)]
              ];
          count++;
        }
      }
    }
  }
  rewind(fptr);
  return count;
}

unsigned int
SBMutableDictionaryAddUniqueStringPairs(
  FILE*                 fptr,
  SBMutableDictionary*  aDict
)
{
  unsigned int      count = 0;
  char*             line;
  size_t            lineLen;
  
  // Count the number of pairs in the file:
  while ( (line = fgetln(fptr, &lineLen)) ) {
    char*           base = line;
    unsigned int    keyStart = 0, keyEnd = 0;
    unsigned int    valStart = 0, valEnd = 0;
    
    // Drop leading whitespace:
    while ( lineLen && isspace(*line) ) {
      line++;
      lineLen--;
      keyStart++;
    }
    // Quote?
    if ( *line == '\'' ) {
      line++; lineLen--;
      keyStart++;
    } else {
      continue;
    }
    // Find the end quote:
    keyEnd = keyStart;
    while ( lineLen && (*line != '\'') ) {
      line++; lineLen--;
      keyEnd++;
      
      if ( lineLen && (*line == '\'') ) {
        // Special case, a double quote:
        line++; lineLen--;
        keyEnd++;
        if ( lineLen && (*line == '\'') ) {
          line++; lineLen--;
          keyEnd++;
          if ( lineLen ) {
            // Shift the remaining stuff down to eliminate the double quote:
            memmove(line - 1, line, lineLen);
          }
        } else {
          line--; lineLen++;
          keyEnd--;
        }
      }
    }
    //  If we ended with a quote, then validate the rest of the line:
    if ( *line == '\'' ) {
      line++; lineLen--;
      valStart = keyEnd + 1;
      
      while ( lineLen && ( *line != '\'' ) ) {
        line++; lineLen--;
        valStart++;
      }
      if ( *line == '\'' ) {
        line++; lineLen--;
        valEnd = ++valStart;
        
        // Find the end quote:
        while ( lineLen && (*line != '\'') ) {
          line++; lineLen--;
          valEnd++;
          
          if ( lineLen && (*line == '\'') ) {
            // Special case, a double quote:
            line++; lineLen--;
            valEnd++;
            if ( lineLen && (*line == '\'') ) {
              line++; lineLen--;
              valEnd++;
              if ( lineLen ) {
                // Shift the remaining stuff down to eliminate the double quote:
                memmove(line - 1, line, lineLen);
              }
            } else {
              line--; lineLen++;
              valEnd--;
            }
          }
        }
        if ( *line == '\'' ) {
          SBString*     key = [SBString stringWithUTF8String:(base + keyStart) length:(keyEnd - keyStart)];
          
          if ( ! [aDict containsKey:key] ) {
            [aDict setObject:[SBString stringWithUTF8String:(base + valStart) length:(valEnd - valStart)]
                    forKey:key
                ];
            count++;
          }
        }
      }
    }
  }
  rewind(fptr);
  return count;
}

@implementation SBDictionary(SBStringPairFiles)

  + (id) dictionaryWithStringPairFile:(SBString*)path
  {
    FILE*             fptr;
    
    if ( fptr = [[SBFileManager sharedFileManager] openPath:path asCFileStreamWithMode:"r"] ) {
      unsigned int    pairs = SBDictionaryCountStringPairs(fptr);
      
      if ( pairs ) {
        SBString*     keys[pairs];
        SBString*     values[pairs];
        
        pairs = SBDictionaryAssignStringPairs(fptr, pairs, keys, values);
        fclose(fptr);
        
        return [SBDictionary dictionaryWithObjects:values forKeys:keys count:pairs];
      }
    }
    return nil;
  }

@end

@implementation SBMutableDictionary(SBStringPairFiles)

  - (unsigned int) addElementsFromStringPairFile:(SBString*)path
  {
    FILE*             fptr;
    unsigned int      count = 0;
    
    if ( fptr = [[SBFileManager sharedFileManager] openPath:path asCFileStreamWithMode:"r"] ) {
      count = SBMutableDictionaryAddStringPairs(fptr, self);
      fclose(fptr);
    }
    return count;
  }
  
//

  - (unsigned int) addUniqueElementsFromStringPairFile:(SBString*)path
  {
    FILE*             fptr;
    unsigned int      count = 0;
    
    if ( fptr = [[SBFileManager sharedFileManager] openPath:path asCFileStreamWithMode:"r"] ) {
      count = SBMutableDictionaryAddUniqueStringPairs(fptr, self);
      fclose(fptr);
    }
    return count;
  }

@end

