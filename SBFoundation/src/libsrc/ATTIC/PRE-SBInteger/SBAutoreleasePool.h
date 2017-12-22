//
// SBFoundation : ObjC Class Library for Solaris
// SBAutoreleasePool.h
//
// Object pool for automatic release at some later time.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @class SBAutoreleasePool
  @discussion
    An SBAutoreleasePool is used in conjunction with the autorelease method of
    SBObject to retain references to objects which have been send the autorelease
    message.  When at some later time the SBAutoreleasePool instance is released,
    all of the objects added to it are also sent the release message.
    
    Multiple SBAutoreleasePools can be created, with the most recent pool acting
    as the current.  In stack-like fashion, when an instance is released, the
    instance previous to it becomes the current.
    
    SBAutoreleasePool allocation is per-thread.  If you use SBThread to create and
    execute in a thread, that thread has it's own autorelease state and you must
    create/destroy SBAutoreleasePool instances as necessary within the thread itself.
*/
@interface SBAutoreleasePool : SBObject
{
  SBAutoreleasePool*              _parent;
  SBAutoreleasePool*              _child;
  struct _SBAutoreleasePoolNode*  _pool;
  struct _SBAutoreleasePoolNode*  _poolHead;
  unsigned int                    _objectCount;
}

/*!
  @method addObject:
  @discussion
    Add anObject to the current thread's current autorelease pool.
*/
+ (void) addObject:(id)anObject;

/*!
  @method addObject:
  @discussion
    Add anObject to this autorelease pool.
*/
- (void) addObject:(id)anObject;

/*!
  @method drain
  @discussion
    Send all objects retained by the receiver the release message and
    remove them from its pool.  Can be used to avoid having to reallocate
    an SBAutoreleasePool within a loop structure, for example.
*/
- (void) drain;

@end
