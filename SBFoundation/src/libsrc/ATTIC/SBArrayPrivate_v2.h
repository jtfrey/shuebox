//
// SBFoundation : ObjC Class Library for Solaris
// SBArray.h
//
// Private (internal to the class cluster) method for SBArray.
//
// $Id$
//

@interface SBArray(SBArrayPrivate)

- (id) initWithObject:(id)firstObject andVArgs:(va_list)vargs;
- (BOOL) growToCapacity:(unsigned int)capacityHint;

- (void) addUnretainedObject:(id)object;

@end
