//
// SBFoundation : ObjC Class Library for Solaris
// SBAutoreleasePool.m
//
// Object pool for automatic release at some later time.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBAutoreleasePool.h"
#import "SBThread.h"

#ifndef INITIAL_AUTORELEASEPOOL_SIZE
#define INITIAL_AUTORELEASEPOOL_SIZE 512
#endif

typedef struct _SBAutoreleasePoolNode {
  struct _SBAutoreleasePoolNode*    link;
  SBUInteger                        capacity;
  SBUInteger                        count;
  id                                objects[0];
} SBAutoreleasePoolNode;

//

SBAutoreleasePoolNode*
__SBAutoreleasePoolNodeAlloc(
  SBUInteger        capacity
)
{
  SBAutoreleasePoolNode*    newNode = objc_malloc(sizeof(SBAutoreleasePoolNode) + capacity * sizeof(id));
  
  if ( newNode ) {
#ifdef SBAUTORELEASEPOOL_DEBUG
    fprintf(stderr, "SBAutoreleasePool:  new node %p (%u capacity)\n", newNode, capacity);
#endif
    newNode->link = NULL;
    newNode->capacity = capacity;
    newNode->count = 0;
  }
  return newNode;
}

//

void
__SBAutoreleasePoolNodeDrain(
  SBAutoreleasePoolNode*  aPoolNode
)
{
  SBUInteger        i = aPoolNode->count;
  
#ifdef SBAUTORELEASEPOOL_DEBUG
  fprintf(stderr, "SBAutoreleasePool:  draining node %p (%u objects)\n", aPoolNode, i);
#endif
  while ( i-- ) {
    [aPoolNode->objects[i] release];
  }
  aPoolNode->count = 0;
}

//
#pragma mark -
//

@interface SBAutoreleasePool(SBAutoreleasePoolPrivate)

- (void) reallyDealloc;
- (SBAutoreleasePool*) parent;
- (SBAutoreleasePool*) child;

@end

@implementation SBAutoreleasePool(SBAutoreleasePoolPrivate)

  - (void) reallyDealloc
  {
    SBAutoreleasePoolNode*    next;
    
#ifdef SBAUTORELEASEPOOL_DEBUG
    fprintf(stderr, "SBAutoreleasePool:  reallyDealloc %p\n", self);
#endif
    
    //
    // the "drain" method is invoked prior to calling reallyDealloc, so
    // _pool is empty:
    //
    while ( _poolHead ) {
      next = _poolHead->link;
#ifdef SBAUTORELEASEPOOL_DEBUG
      fprintf(stderr, "SBAutoreleasePool:  reallyDealloc, node %p\n", _poolHead);
#endif
      objc_free(_poolHead);
      _poolHead = next;
    }
    [super dealloc];
  }

//

  - (SBAutoreleasePool*) parent { return _parent; }
  - (SBAutoreleasePool*) child { return _child; }

@end

//

@implementation SBAutoreleasePool

  + (id) alloc
  {
    SBAutoreleaseState*       curThreadState = (&(([SBThread currentThread])->_autoreleaseState));
    SBAutoreleasePool*        newPool = nil;
    
    // Is there a pool available in the cache for this thread?
    if ( curThreadState->cache ) {
      newPool = curThreadState->cache;
      curThreadState->cache = newPool->_child;
      newPool->_parent = newPool->_child = nil;
#ifdef SBAUTORELEASEPOOL_DEBUG
      fprintf(stderr, "SBAutoreleasePool:  cached alloc %p\n", newPool);
#endif
    } else {
      newPool = class_create_instance(self);
#ifdef SBAUTORELEASEPOOL_DEBUG
      fprintf(stderr, "SBAutoreleasePool:  alloc %p\n", newPool);
#endif
    }
    return newPool;
  }

//

  - (id) init
  {
    SBAutoreleaseState*       curThreadState = (&(([SBThread currentThread])->_autoreleaseState));
    
    if ( ! _poolHead ) {
#ifdef SBAUTORELEASEPOOL_DEBUG
      fprintf(stderr, "SBAutoreleasePool:  init %p\n", self);
#endif
      if ( ! (self = [super init]) ) {
        return nil;
      }
      _pool = __SBAutoreleasePoolNodeAlloc(INITIAL_AUTORELEASEPOOL_SIZE);
    } else {
      SBAutoreleasePoolNode*    next = _poolHead->link;
      
#ifdef SBAUTORELEASEPOOL_DEBUG
      fprintf(stderr, "SBAutoreleasePool:  cached init %p\n", self);
#endif
      _pool = _poolHead;
      _pool->link = NULL;
      _pool->count = 0;
      _poolHead = next;
    }
    
    _objectCount = 0;
    
    // Setup thread state:
    _child = nil;
    if ( (_parent = curThreadState->current) )
      _parent->_child = self;
    curThreadState->current = self;
    
    return self;
  }
  
//

  + (void) addObject:(id)anObject
  {
    SBThread*                 curThread = [SBThread currentThread];
    
    SBAssert(curThread, "No current thread defined??");
    
    SBAutoreleaseState*       curThreadState = (&((curThread)->_autoreleaseState));
    
    SBAssert(curThreadState, "No current state for thread???");
    if ( curThreadState->current ) {
      [curThreadState->current addObject:anObject];
    } else {
      SBAutoreleasePool*      tmpPool = [[SBAutoreleasePool alloc] init];
      
      [SBException raise:SBAutoreleaseException format:"No autorelease pool in place.  Thread = %p, object = %p.", [SBThread currentThread], (void*)anObject];
      [tmpPool release];
    }
  }
  
//

  - (void) addObject:(id)anObject
  {
    // Have we saturated the current node?
    if ( _pool->count == _pool->capacity ) {
      if ( _poolHead ) {
        SBAutoreleasePoolNode*      next = _poolHead->link;
        
#ifdef SBAUTORELEASEPOOL_DEBUG
        fprintf(stderr, "SBAutoreleasePool:  cached node %p\n", _poolHead);
#endif
        _poolHead->link = _pool;
        _poolHead->count = 0;
        _pool = _poolHead;
        _poolHead = next;
      } else {
        SBAutoreleasePoolNode*      next = __SBAutoreleasePoolNodeAlloc(_pool->capacity * 2);
        
        if ( next ) {
          next->link = _pool;
          _pool = next;
        } else {
          exit(ENOMEM);
        }
      }
    }
    _pool->objects[_pool->count++] = anObject;
    _objectCount++;
  }
  
//

  - (void) dealloc
  {
    SBAutoreleaseState*         curThreadState = (&(([SBThread currentThread])->_autoreleaseState));
    
    // If we have children, they must be dumped first:
    if ( _child )
      [_child dealloc];
    
    // Drain each of our pool nodes and attach them to the pool-of-pools chain:
    while ( _pool ) {
      SBAutoreleasePoolNode*    next = _pool->link;
      
      __SBAutoreleasePoolNodeDrain(_pool);
      _pool->link = _poolHead;
      _poolHead = _pool;
      _pool = next;
    }
    _objectCount = 0;
    
    // Set the thread to be using our parent as the current pool and be
    // sure that parent doesn't reference us as a child anymore:
    if ( (curThreadState->current = _parent) )
      _parent->_child = nil;
    
    // Special case if the thread itself is being deallocated:  fully destroy
    // pools for the thread:
    if ( curThreadState->threadInDealloc ) {
      // If we're at the top of the list of pools (no parent) then
      // it's our responsibility to actually dispose of the cached
      // SBAutoreleasePools for this thread:
      if ( ! _parent ) {
        while ( curThreadState->cache ) {
          SBAutoreleasePool*    next = curThreadState->cache->_child;
          
          [curThreadState->cache reallyDealloc];
          curThreadState->cache = next;
        }
      }
      [self reallyDealloc];
    } else {
      // Return us to the thread's cache of available pools:
      self->_child = curThreadState->cache;
      curThreadState->cache = self;
    }
    return;
    
    [super dealloc];
  }

//

  - (id) retain
  {
    // Please don't do it...
    return self;
  }
  
//

  - (void) release
  {
    [self dealloc];
  }

//

  - (id) autorelease
  {
    // Please don't do it...
    return self;
  }
  
//

  - (void) drain
  {
    // If we have children, they must be dumped first:
    if ( _child )
      [_child drain];
    
    // Drain each of our pool nodes and attach them to the pool-of-pools chain:
    while ( _pool ) {
      SBAutoreleasePoolNode*    next = _pool->link;
      
      __SBAutoreleasePoolNodeDrain(_pool);
      _pool->link = _poolHead;
      _poolHead = _pool;
      _pool = next;
    }
    _objectCount = 0;
  }

@end
