/*
// SBFoundation : ObjC Class Library for Solaris
// SBMemoryPool.m
//
// C pseudo class which provides memory pools.
//
// $Id$
*/

#include "SBMemoryPool.h"
#include <strings.h>

enum {
  kSBMemoryPoolFreeWhenDone = 1 << 0
};

#ifndef SBMEMORYPOOL_MIN_BASESIZE
#define SBMEMORYPOOL_MIN_BASESIZE   1024
#endif

/**/

typedef struct _SBMemoryPoolNode {
  struct _SBMemoryPoolNode*   link;
  unsigned int                flags;
  SBUInteger                  size;
  SBUInteger                  free;
  void*                       base;
  void*                       end;
  void*                       topAlloc;
  void*                       prevAlloc;
} SBMemoryPoolNode;

/**/

void
__SBMemoryPoolNodeInit(
  SBMemoryPoolNode*     aNode,
  SBUInteger            bytes,
  int                   flags
)
{
  aNode->link = NULL;
  aNode->flags = flags;
  aNode->size = bytes;
  aNode->free = bytes;
  aNode->base = ((void*)aNode) + sizeof(SBMemoryPoolNode);
  aNode->end = aNode->base + bytes;
  aNode->topAlloc = aNode->base;
  aNode->prevAlloc = NULL;
}

/**/

SBMemoryPoolNode*
__SBMemoryPoolNodeAlloc(
  SBMemoryPoolNode**    topNode,
  SBUInteger            bytes
)
{
  SBMemoryPoolNode*     newNode = NULL;
  
  if ( (newNode = malloc(bytes + sizeof(SBMemoryPoolNode))) ) {
    __SBMemoryPoolNodeInit(newNode, bytes, kSBMemoryPoolFreeWhenDone);
    newNode->link = *topNode; *topNode = newNode;
  }
  return newNode;
}

/**/

SBUInteger
__SBMemoryPoolNodeSize(
  SBUInteger            bytes
)
{
  return (bytes + sizeof(SBMemoryPoolNode));
}

/**/

void
__SBMemoryPoolNodeDrain(
  SBMemoryPoolNode*     aNode
)
{
  aNode->free = aNode->size;
  aNode->topAlloc = aNode->base;
  aNode->prevAlloc = NULL;
}

/**/

void
__SBMemoryPoolNodeFree(
  SBMemoryPoolNode*     aNode
)
{
  if ( aNode->flags & kSBMemoryPoolFreeWhenDone )
    free(aNode);
}

/**/

SBMemoryPoolNode*
__SBMemoryPoolNodeForAllocSize(
  SBMemoryPoolNode*     aNode,
  SBUInteger            bytes
)
{
  SBUInteger            freeInNode = 0;
  SBMemoryPoolNode*     theNode = NULL;
  
  /* Search for the node with the smallest free space that satisfies the required
     byte count: */
  while ( aNode ) {
    if ( (aNode->free >= bytes) && ((freeInNode == 0) || (aNode->free < freeInNode)) ) {
      theNode = aNode;
      freeInNode = aNode->free;
    }
    aNode = aNode->link;
  }
  return theNode;
}

/**/

void*
__SBMemoryPoolNodeAllocChunk(
  SBMemoryPoolNode*     aNode,
  SBUInteger            bytes
)
{
  void*       chunk = NULL;
  
#ifdef SBMemoryPoolAlignedAlloc
  bytes = SBMemoryPoolAlignedAlloc * ( bytes / SBMemoryPoolAlignedAlloc + ( bytes % SBMemoryPoolAlignedAlloc ? 1 : 0 ) );
#endif
  
  if ( aNode->free >= bytes ) {
    aNode->prevAlloc = chunk = aNode->topAlloc;
    
    aNode->topAlloc += bytes;
    aNode->free -= bytes;
  }
  return chunk;
}

/**/

SBMemoryPoolNode*
__SBMemoryPoolNodeForChunk(
  SBMemoryPoolNode*     aNode,
  void*                 chunk
)
{
  while ( aNode ) {
    if ( (chunk >= aNode->base) && (chunk <= aNode->end) )
      return aNode;
    aNode = aNode->link;
  }
  return NULL;
}

/**/
#pragma mark -
/**/

typedef struct _SBMemoryPool {
  unsigned int                refCount;
  SBUInteger                  basePoolSize;
  SBMemoryPoolNode*           pools;
} SBMemoryPool;

/**/

SBMemoryPoolRef
SBMemoryPoolCreate(
  SBUInteger      baseSize
)
{
  SBMemoryPool*   newPool = NULL;
  SBUInteger      bytes;
  SBUInteger      defaultBaseSize = SBMEMORYPOOL_MIN_BASESIZE;
  
  if ( baseSize < defaultBaseSize ) {
    baseSize = defaultBaseSize;
  } else {
    baseSize = ( ((baseSize % defaultBaseSize) == 0 ? 0 : 1) + (baseSize / defaultBaseSize) ) * defaultBaseSize;
  }
  
  bytes = sizeof(SBMemoryPool) + __SBMemoryPoolNodeSize(baseSize);
  
  if ( (newPool = malloc(bytes)) ) {
    newPool->refCount = 1;
    newPool->basePoolSize = baseSize;
    newPool->pools = ((void*)newPool) + sizeof(SBMemoryPool);
    
    /* Initialize the first pool: */
    __SBMemoryPoolNodeInit(newPool->pools, baseSize, 0);
  }
  return (SBMemoryPoolRef)newPool;
}

/**/

SBMemoryPoolRef
SBMemoryPoolRetain(
  SBMemoryPoolRef aMemPool
)
{
  ((SBMemoryPool*)aMemPool)->refCount++;
}

/**/

void
SBMemoryPoolDrain(
  SBMemoryPoolRef aMemPool
)
{
  SBMemoryPoolNode*   node = aMemPool->pools;
  
  while ( node ) {
    __SBMemoryPoolNodeDrain(node);
    node = node->link;
  }
}

/**/

void
SBMemoryPoolRelease(
  SBMemoryPoolRef aMemPool
)
{
  if ( --((SBMemoryPool*)aMemPool)->refCount == 0 ) {
    SBMemoryPoolNode*   node = aMemPool->pools;
    
    while ( node ) {
      SBMemoryPoolNode* next = node->link;
      
      __SBMemoryPoolNodeFree(node);
      node = next;
    }
  }
  free((SBMemoryPool*)aMemPool);
}

/**/

void*
SBMemoryPoolAlloc(
  SBMemoryPoolRef aMemPool,
  SBUInteger          bytes
)
{
  SBMemoryPoolNode*   aNode;
  
  /* Can we get it from an extant pool node? */
  aNode = __SBMemoryPoolNodeForAllocSize(aMemPool->pools, bytes);
  if ( ! aNode ) {
    /* Allocate a new node: */
    SBUInteger        poolSize = aMemPool->basePoolSize;
    
    if ( poolSize < bytes ) {
      poolSize = 1 + (bytes / poolSize);
      poolSize *= aMemPool->basePoolSize;
    }
    aNode = __SBMemoryPoolNodeAlloc(
                  (SBMemoryPoolNode**)(&aMemPool->pools),
                  poolSize
                );
  }
  if ( aNode )
    return __SBMemoryPoolNodeAllocChunk(aNode, bytes);
  return NULL;
}

/**/

void*
SBMemoryPoolCalloc(
  SBMemoryPoolRef aMemPool,
  SBUInteger      bytes
)
{
  void*           newChunk = SBMemoryPoolAlloc(aMemPool, bytes);
  
  if ( newChunk )
    bzero(newChunk, bytes);
  return newChunk;
}

/**/

int
SBMemoryPoolRealloc(
  SBMemoryPoolRef aMemPool,
  void**          chunk,
  SBUInteger      bytes
)
{
  SBMemoryPoolNode*     aNode = __SBMemoryPoolNodeForChunk(aMemPool->pools, *chunk);
  SBMemoryPoolNode*     newNode;
  SBUInteger            poolSize;
  
  if ( aNode ) {
    if ( aNode->prevAlloc == *chunk ) {
      SBUInteger        origSize = (aNode->topAlloc - aNode->prevAlloc);
      
      if ( origSize < bytes ) {
        SBUInteger      delta = bytes - origSize;
        
        if ( delta <= aNode->free ) {
          /* Grow that previous allocation: */
          aNode->free -= delta;
          aNode->topAlloc += delta;
          return 1;
        } else {
          /* We'll need to re-allocate; but since we leave aNode pointing to something,
             we'll trigger a Free() on the chunk from this node once we've done
             the allocate-and-copy. */
        }
      } else if ( origSize > bytes ) {
        SBUInteger      delta = origSize - bytes;
        
        /* Shrink that previous allocation: */
        aNode->free += delta;
        aNode->topAlloc -= delta;
        return 1;
      } else {
        /* Same size, duh: */
        return 1;
      }
    } else {
      aNode = NULL;
    }
  }
  
  /* Need a new allocation entirely, darnit: */
  poolSize = aMemPool->basePoolSize;
  if ( poolSize < bytes ) {
    poolSize = 1 + (bytes / poolSize);
    poolSize *= aMemPool->basePoolSize;
  }
  newNode = __SBMemoryPoolNodeAlloc(
                (SBMemoryPoolNode**)(&aMemPool->pools),
                poolSize
              );
  if ( newNode ) {
    void*     newChunk = __SBMemoryPoolNodeAllocChunk(newNode, bytes);
    
    if ( newChunk ) {
      memcpy(newChunk, *chunk, bytes);
      *chunk = newChunk;
      
      /* If aNode was left non-NULL, then we can Free() the old chunk */
      if ( aNode ) {
        aNode->free += (aNode->topAlloc - aNode->prevAlloc);
        aNode->topAlloc = aNode->prevAlloc;
        aNode->prevAlloc = NULL;
      }
      
      return 1;
    }
  }
  return 0;
}

/**/

void
SBMemoryPoolFree(
  SBMemoryPoolRef aMemPool,
  void*           chunk
)
{
  SBMemoryPoolNode*     aNode = __SBMemoryPoolNodeForChunk(aMemPool->pools, chunk);
  
  if ( aNode && (aNode->prevAlloc == chunk) ) {
    aNode->free += (aNode->topAlloc - aNode->prevAlloc);
    aNode->topAlloc = aNode->prevAlloc;
    aNode->prevAlloc = NULL;
  }
}

/**/

void
SBMemoryPoolSummarizeToStream(
  SBMemoryPoolRef aMemPool,
  FILE*           stream
)
{
  SBMemoryPoolNode*     aNode = aMemPool->pools;
  
  fprintf(
      stream,
      "SBMemoryPool@%p[%u] ( baseSize = %ld ) {\n",
      aMemPool,
      aMemPool->refCount,
      aMemPool->basePoolSize
    );
  while ( aNode ) {
    fprintf(
        stream,
        "  node@%p ( flags = %02X | size = %ld | free = %ld )\n",
        aNode,
        aNode->flags,
        aNode->size,
        aNode->free
      );
    aNode = aNode->link;
  }
  fprintf(stream, "}\n");
}

