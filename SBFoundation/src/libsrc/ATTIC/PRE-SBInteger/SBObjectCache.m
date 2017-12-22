//
// SBFoundation : ObjC Class Library for Solaris
// SBObjectCache.h
//
// A generic class for caching object instances.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBObjectCache.h"
#import "SBString.h"
#import "SBDictionary.h"
#import "SBValue.h"
#import "SBEnumerator.h"
#import "SBNotification.h"

SBString* SBObjectCacheFlushNotification = @"flushAllObjectCaches";
SBString* SBObjectCacheCleanupNotification = @"cleanupAllObjectCaches";


typedef struct {
  int       used;
  id        object;
  time_t    expiration;
} SBObjectCacheLine;


#define CACHELINES ((SBObjectCacheLine*)_cacheLines)


@interface SBObjectCache(SBObjectCachePrivate)

- (BOOL) allocateCacheLines:(unsigned int)cacheSize;

- (void) updateCacheIndicesForLine:(unsigned int)cacheLineNum object:(id)object;
- (void) removeLineFromIndices:(unsigned int)cacheLineNum;

- (unsigned int) cacheLineOfObjectWithValue:(id)value forKey:(SBString*)key;
- (unsigned int) cacheLineOfObject:(id)object;
- (unsigned int) emptyCacheLine;

- (void) flushCacheNotification:(SBNotification*)notify;
- (void) cleanupCacheNotification:(SBNotification*)notify;

@end

@implementation SBObjectCache(SBObjectCachePrivate)

  - (BOOL) allocateCacheLines:(unsigned int)cacheSize
  {
    SBObjectCacheLine*    lines = (SBObjectCacheLine*)malloc( cacheSize * sizeof(SBObjectCacheLine) );
    
    if ( lines ) {
      _cacheSize = cacheSize;
      _cacheLines = (void*)lines;
      bzero(lines, cacheSize * sizeof(SBObjectCacheLine));
      return YES;
    }
    return NO;
  }
  
//

  - (void) updateCacheIndicesForLine:(unsigned int)cacheLineNum
    object:(id)object
  {
    if ( _cacheIndices ) {
      SBNumber*             lineNum = [SBNumber numberWithUnsignedInt:cacheLineNum];
      SBEnumerator*         eKey = [_cacheIndices keyEnumerator];
      SBString*             key;
      
      while ( key = [eKey nextObject] ) {
        SBMutableDictionary*  index = [_cacheIndices objectForKey:key];
        
        [index setObject:lineNum forKey:[object valueForKey:key]];
      }
    }
  }

//

  - (void) removeLineFromIndices:(unsigned int)cacheLineNum
  {
    if ( _cacheIndices ) {
      SBNumber*             lineNum = [SBNumber numberWithUnsignedInt:cacheLineNum];
      SBEnumerator*         eIndex = [_cacheIndices objectEnumerator];
      SBMutableDictionary*  index;
      
      while ( index = [eIndex nextObject] )
        [index removeObjectsWithObject:lineNum];
    }
  }

//

  - (unsigned int) cacheLineOfObjectWithValue:(id)value
    forKey:(SBString*)key
  {
    SBObjectCacheLine*    lines = CACHELINES;
    SBObjectCacheLine*    linesEnd = lines + _cacheSize;
    time_t                now = time(NULL);
    
    while ( lines < linesEnd ) {
      id      valueFromObj;
      
      if ( lines->expiration <= now ) {
        // Expired, get rid of it now:
        lines->used = 0;
        [lines->object release];
        [self removeLineFromIndices:(lines - CACHELINES)];
      }
      else if ( lines->used && (valueFromObj = [lines->object valueForKey:key]) && ([valueFromObj isEqual:value]) ) {
        return (lines - CACHELINES);
      }
      lines++;
    }
    return SBNotFound;
  }

//

  - (unsigned int) cacheLineOfObject:(id)object
  {
    SBObjectCacheLine*    lines = CACHELINES;
    SBObjectCacheLine*    linesEnd = lines + _cacheSize;
    time_t                now = time(NULL);
    
    while ( lines < linesEnd ) {
      if ( lines->expiration <= now ) {
        // Expired, get rid of it now:
        lines->used = 0;
        [lines->object release];
        [self removeLineFromIndices:(lines - CACHELINES)];
      }
      else if ( lines->used && [lines->object isEqual:object] ) {
        return (lines - CACHELINES);
      }
      lines++;
    }
    return SBNotFound;
  }

//

  - (unsigned int) emptyCacheLine
  {
    SBObjectCacheLine*    lines = CACHELINES;
    SBObjectCacheLine*    linesEnd = lines + _cacheSize;
    time_t                now = time(NULL);
    time_t                oldestTime = 0;
    SBObjectCacheLine*    oldest = NULL;
    
    while ( lines < linesEnd ) {
      if ( ! lines->used ) {
        return (lines - CACHELINES);
      }
      if ( lines->expiration <= now ) {
        // Expired, get rid of it now and re-use the line:
        lines->used = 0;
        [lines->object release];
        [self removeLineFromIndices:(lines - CACHELINES)];
        return (lines - CACHELINES);
      }
      else {
        if ( (oldestTime == 0) || (lines->expiration < oldestTime) ) {
          oldestTime = lines->expiration;
          oldest = lines;
        }
      }
      lines++;
    }
    if ( _evictOldestLineWhenFull && oldest ) {
      // Purge the oldest cache line and use its slot:
      oldest->used = 0;
      [oldest->object release];
      [self removeLineFromIndices:(oldest - CACHELINES)];
      return (oldest - CACHELINES);
    }
    return SBNotFound;
  }

//

  - (void) flushCacheNotification:(SBNotification*)notify
  {
    [self flushCache];
  }
  
//

  - (void) cleanupCacheNotification:(SBNotification*)notify
  {
    [self cleanupCache];
  }

@end

//
#pragma mark -
//

@implementation SBObjectCache

  + (void) flushAllObjectCaches
  {
    [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBObjectCacheFlushNotification object:nil];
  }
  
//

  + (void) cleanupAllObjectCaches
  {
    [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBObjectCacheCleanupNotification object:nil];
  }

//

  - (id) initWithBaseClass:(Class)baseClass
  {
    return [self initWithBaseClass:baseClass size:32];
  }

//

  - (id) initWithBaseClass:(Class)baseClass
    size:(unsigned int)cacheSize
  {
    if ( self = [self init] ) {
      if ( ! [self allocateCacheLines:cacheSize] ) {
        [self release];
        self = nil;
      } else {
        _cacheType = baseClass;
        _evictOldestLineWhenFull = YES;
        _cacheTTL = 300;
        
        _ignoresFlushNotifications = _ignoresCleanupNotifications = YES;
        [self setIgnoresFlushNotifications:NO];
        [self setIgnoresCleanupNotifications:NO];
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    [self flushCache];
    if ( _cacheLines ) free(_cacheLines);
    if ( _cacheIndices ) [_cacheIndices release];
    [super dealloc];
  }

//

  - (BOOL) evictOldestLineWhenFull
  {
    return _evictOldestLineWhenFull;
  }
  - (void) setEvictOldestLineWhenFull:(BOOL)evict
  {
    _evictOldestLineWhenFull = evict;
  }

//

  - (unsigned int) defaultSecondsToLive
  {
    return _cacheTTL;
  }
  - (void) setDefaultSecondsToLive:(unsigned int)seconds
  {
    _cacheTTL = seconds;
  }

//

  - (BOOL) ignoresFlushNotifications
  {
    return _ignoresFlushNotifications;
  }
  - (void) setIgnoresFlushNotifications:(BOOL)shouldIgnore
  {
    if ( shouldIgnore != _ignoresFlushNotifications ) {
      if ( shouldIgnore ) {
        [[SBNotificationCenter defaultNotificationCenter] removeObserver:self identifier:SBObjectCacheFlushNotification object:nil];
      } else {
        [[SBNotificationCenter defaultNotificationCenter] addObserver:self selector:@selector(flushCacheNotification:) identifier:SBObjectCacheFlushNotification object:nil];
      }
      _ignoresFlushNotifications = shouldIgnore;
    }
  }

//

  - (BOOL) ignoresCleanupNotifications
  {
    return _ignoresCleanupNotifications;
  }
  - (void) setIgnoresCleanupNotifications:(BOOL)shouldIgnore
  {
    if ( shouldIgnore != _ignoresCleanupNotifications ) {
      if ( shouldIgnore ) {
        [[SBNotificationCenter defaultNotificationCenter] removeObserver:self identifier:SBObjectCacheCleanupNotification object:nil];
      } else {
        [[SBNotificationCenter defaultNotificationCenter] addObserver:self selector:@selector(cleanupCacheNotification:) identifier:SBObjectCacheCleanupNotification object:nil];
      }
      _ignoresCleanupNotifications = shouldIgnore;
    }
  }

//

  - (id) cachedObjectForKey:(SBString*)key
    value:(id)value
  {
    unsigned int    i;
    
    // Try an index first:
    if ( _cacheIndices ) {
      SBMutableDictionary*  index = [_cacheIndices objectForKey:key];
      
      if ( index ) {
        SBNumber*     lineNum = [index objectForKey:value];
        
        if ( lineNum )
          return CACHELINES[ [lineNum unsignedIntValue] ].object;
      }
    }
    
    // Walk the cache itself, see if there's a match:
    if ( (i = [self cacheLineOfObjectWithValue:value forKey:key]) != SBNotFound )
      return CACHELINES[i].object;
      
    return NULL;
  }

//

  - (BOOL) addObjectToCache:(id)object
  {
    return [self addObjectToCache:object secondsToLive:_cacheTTL];
  }
  
//

  - (BOOL) addObjectToCache:(id)object
    secondsToLive:(int)seconds
  {
    BOOL    wasCached = NO;
    
    if ( [object isKindOf:_cacheType] ) {
      unsigned int      lineNum = [self cacheLineOfObject:object];
      
      if ( lineNum != SBNotFound ) {
        if ( seconds <= 0 ) {
          // Expire now!!!
          CACHELINES[lineNum].used = 0;
          [CACHELINES[lineNum].object release];
          [self removeLineFromIndices:lineNum];
        } else {
          // Already cached, update the expiration time:
          CACHELINES[lineNum].expiration = (time(NULL) + seconds);
          wasCached = YES;
        }
      }
      else {
        // Find an empty cache line:
        lineNum = [self emptyCacheLine];
        if ( lineNum != SBNotFound ) {
          CACHELINES[lineNum].used = 1;
          CACHELINES[lineNum].object = [object retain];
          CACHELINES[lineNum].expiration = (time(NULL) + seconds);
          [self updateCacheIndicesForLine:lineNum object:object];
          wasCached = YES;
        }
      }
    }
    return wasCached;
  }
  
//

  - (void) evictObjectFromCache:(id)object
  {
    unsigned int      lineNum = [self cacheLineOfObject:object];
    
    if ( lineNum != SBNotFound ) {
      CACHELINES[lineNum].used = 0;
      [CACHELINES[lineNum].object release];
      [self removeLineFromIndices:lineNum];
    }
  }

//

  - (void) createCacheIndexForKey:(SBString*)key
  {
    if ( ! _cacheIndices ) {
      _cacheIndices = [[SBMutableDictionary alloc] init];
    }
    if ( _cacheIndices ) {
      if ( ! [_cacheIndices containsKey:key] ) {
        SBMutableDictionary*      index = [[SBMutableDictionary alloc] init];
        unsigned int              i = 0;
        time_t                    now = time(NULL);
        
        while ( i < _cacheSize ) {
          if ( CACHELINES[i].expiration <= now ) {
            // Expired, get rid of it now:
            CACHELINES[i].used = 0;
            [CACHELINES[i].object release];
            [self removeLineFromIndices:i];
          }
          else if ( CACHELINES[i].used ) {
            [index setObject:[SBNumber numberWithUnsignedInt:i] forKey:[CACHELINES[i].object valueForKey:key]];
          }
          i++;
        }
        [_cacheIndices setObject:index forKey:key];
        [index release];
      }
    }
  }
  
//

  - (void) dropCacheIndexForKey:(SBString*)index
  {
    if ( _cacheIndices )
      [_cacheIndices removeObjectForKey:index];
  }

//

  - (void) dropAllIndices
  {
    if ( _cacheIndices ) {
      [_cacheIndices release];
      _cacheIndices = nil;
    }
  }

//

  - (void) flushCache
  {
    SBObjectCacheLine*    lines = CACHELINES;
    SBObjectCacheLine*    linesEnd = lines + _cacheSize;
    time_t                now = time(NULL);
    
    while ( lines < linesEnd ) {
      if ( lines->used ) {
        lines->used = 0;
        [lines->object release];
      }
      lines++;
    }
    if ( _cacheIndices ) {
      SBEnumerator*         eIndex = [_cacheIndices objectEnumerator];
      SBMutableDictionary*  index;
      
      while ( index = [eIndex nextObject] )
        [index removeAllObjects];
    }
  }
  
//

  - (void) cleanupCache
  {
    SBObjectCacheLine*    lines = CACHELINES;
    SBObjectCacheLine*    linesEnd = lines + _cacheSize;
    time_t                now = time(NULL);
    
    while ( lines < linesEnd ) {
      if ( lines->used && (lines->expiration <= now) ) {
        // Expired, get rid of it now:
        lines->used = 0;
        [lines->object release];
        [self removeLineFromIndices:(lines - CACHELINES)];
      }
      lines++;
    }
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  cache-size:                   %u\n"
        "  evict-on-full:                %s\n"
        "  ignore-flush-notifications:   %s\n"
        "  ignore-cleanup-notifications: %s\n"
        "  has-indices:                  %s\n"
        "  cache: {\n",
        _cacheSize,
        ( _evictOldestLineWhenFull ? "yes" : "no" ),
        ( _ignoresFlushNotifications ? "yes" : "no" ),
        ( _ignoresCleanupNotifications ? "yes" : "no" ),
        ( _cacheIndices ? "yes" : "no" )
      );
    
    unsigned int      i = 0;
    time_t            now = time(NULL);
    
    while ( i < _cacheSize ) {
      if ( CACHELINES[i].used )
        fprintf(
            stream,
            "           %-04d : (%ld) %s@%p[%d]\n",
            i,
            CACHELINES[i].expiration - now,
            [CACHELINES[i].object name],
            CACHELINES[i].object,
            [CACHELINES[i].object referenceCount]
          );
      else
        fprintf(
            stream,
            "           %-04d : [empty]\n",
            i
          );
      i++;
    }
    fprintf(stream, "  }\n");
    if ( _cacheIndices ) {
      SBEnumerator*   eKey = [_cacheIndices keyEnumerator];
      SBString*       key;
      
      fprintf(stream, "  indices: {\n");
      while ( key = [eKey nextObject] ) {
        fprintf(stream, "           ");
        [key writeToStream:stream];
        fprintf(stream, ": ");
        [[_cacheIndices objectForKey:key] summarizeToStream:stream];
      }
    }
    fprintf(stream, "}\n");
  }

@end
