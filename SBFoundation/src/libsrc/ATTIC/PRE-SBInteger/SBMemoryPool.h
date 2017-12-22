/*
// SBFoundation : ObjC Class Library for Solaris
// SBMemoryPool.h
//
// C pseudo class which provides memory pools.
//
// $Id$
*/

#ifndef __SBMEMORYPOOL_H__
#define __SBMEMORYPOOL_H__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/*!
  @header SBMemoryPool.h
  
  Rather than burden the C memory management facilities with many small allocations, a memory
  pool can be used to allocate one large memory segment and parcel-out space within that
  segment for the smaller items.
  
  An SBMemoryPool manages a collection of one or more large memory segments.  Each segment
  is treated as a stack -- subsequent allocations from a segment sit atop older allocations.
  Allocations are made by seeking the segment with the smallest available free region which
  satisfies the requested byte count.  If no current segment satisfies the request, a new
  large-memory segment will be allocated for the purpose.
  
  An SBMemoryPool can be restored to a fully unallocated state by means of the SBMemoryPoolDrain()
  function.  The function essentially just restores the initial state of each segment; no large-
  memory segments are free'd.  Thus, an SBMemoryPool monotonically increases in capacity; it will
  never decrease.
  
  The SBMemoryPoolRelease() function releases a reference to the object; once the number of
  references reaches zero, the object is destroyed.  At this time, all large-memory segments
  allocated by the object are free'd, as well.
*/


/*!
  @typedef SBMemoryPoolRef
  
  Opaque pointer to a memory pool object.
*/
typedef const struct _SBMemoryPool * SBMemoryPoolRef;

/*!
  @function SBMemoryPoolCreate
  
  Creates a new memory pool object.  The new object will grow itself by
  baseSize each time the pool is exhausted; if baseSize is less than 1024
  then 1024 is used in its stead.  Note that allocations > baseSize are
  possible, but trigger the automatic growth of the pool by the minimum integral
  multiple of baseSize that is large enough to contain the requested allocation
  size.
*/
SBMemoryPoolRef SBMemoryPoolCreate(size_t baseSize);
/*!
  @function SBMemoryPoolRetain
  
  Return a reference copy of the memory pool -- merely increments an internal
  counter that indicates to the object how many other entities are making use
  of it.
*/
SBMemoryPoolRef SBMemoryPoolRetain(SBMemoryPoolRef aMemPool);
/*!
  @function SBMemoryPoolDrain
  
  Reset the memory pool to a completely unallocated state.  Does not actually
  free the memory being used by the pool -- see SBMemoryPoolRelease.
  
  Basically, at the end of some sequence of processing this function can be
  called to reset the pool so that it can be reused rather than released and
  re-created.
*/
void SBMemoryPoolDrain(SBMemoryPoolRef aMemPool);
/*!
  @function SBMemoryPoolRelease
  
  Dispose of a memory pool object and all of the memory it is using.
*/
void SBMemoryPoolRelease(SBMemoryPoolRef aMemPool);
/*!
  @function SBMemoryPoolAlloc
  
  Attempt to allocate a chunk of memory of size bytes from the memory pool.
  Returns NULL if an error occurs.
*/
void* SBMemoryPoolAlloc(SBMemoryPoolRef aMemPool, size_t bytes);
/*!
  @function SBMemoryPoolCalloc
  
  Attempt to allocate a chunk of memory of size bytes from the memory pool.
  Returns NULL if an error occurs.
  
  The chunk is initialized to contain all zero bytes.
*/
void* SBMemoryPoolCalloc(SBMemoryPoolRef aMemPool, size_t bytes);
/*!
  @function SBMemoryPoolRealloc
  
  Attempt to re-size a previously-allocated chunk of memory.  This function
  should only really be called when the byte-size will _increase_.
  
  One special case exists:
  
    If *chunk was the last allocated chunk from a particular node of the pool, then
      - The class attempts to extend the allocation within the pool node
      - Failing that, a new allocation will be made and the old chunk will be
        recovered by the pool node

*/
int SBMemoryPoolRealloc(SBMemoryPoolRef aMemPool, void** chunk, size_t bytes);
/*!
  @function SBMemoryPoolFree
  
  Attempt to dispose of an allocated chunk of memory.  The only instance where this
  actually has some affect is:
  
    If *chunk was the last allocated chunk from a particular node of the pool, then
      - The chunk will be recovered by the pool node

*/
void SBMemoryPoolFree(SBMemoryPoolRef aMemPool, void* chunk);
/*!
  @function SBMemoryPoolSummarizeToStream
  
  Writes a terse, debug summary of the state of aMemPool to the stdio stream.
*/
void SBMemoryPoolSummarizeToStream(SBMemoryPoolRef aMemPool, FILE* stream);

#endif /* __SBMEMORYPOOL_H__ */
