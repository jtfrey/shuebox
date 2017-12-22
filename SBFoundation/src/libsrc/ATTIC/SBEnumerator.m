//
// scruffy : maintenance scheduler daemon for SHUEBox
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

//

  - (SBArray*) allObjects
  {
    SBArray*    objects = nil;
    id          object;
    
    while ( object = [self nextObject] ) {
      if ( objects == nil )
        objects = [SBArray array];
      [objects addObject:object];
    }
    return objects;
  }

@end
