//
// SBFoundation : ObjC Class Library for Solaris
// SBEnumerator.m
//
// Basic iterator.
//
// $Id$
//

#import "SBEnumerator.h"
#import "SBArray.h"

@implementation SBEnumerator

  - (id) nextObject
  {
    return nil;
  }

@end

@implementation SBEnumerator(SBExtendedEnumerator)

  - (SBArray*) allObjects
  {
    SBMutableArray*    objects = nil;
    id                 object;
    
    while ( object = [self nextObject] ) {
      if ( objects == nil )
        objects = [SBMutableArray array];
      [objects addObject:object];
    }
    return objects;
  }

@end
