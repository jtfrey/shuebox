//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBArray.h
//
// Basic object array.
//
// $Id$
//

@interface SBArray(SBArrayPrivate)

- (id) initWithObject:(id)firstObject andVArgs:(va_list)vargs;
- (BOOL) growToCapacity:(unsigned int)capacityHint;

- (void) addUnretainedObject:(id)object;

@end
