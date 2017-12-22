//
// SBFoundation : ObjC Class Library for Solaris
// SBStringPrivate.h
//
// Private (framework-only) interfaces to SBString.
//
// $Id$
//

@interface SBString(SBStringPrivate)

- (id) initWithByteCapacity:(size_t)byteCapacity;
- (size_t) byteLength;
- (BOOL) growToByteLength:(size_t)newSize;
- (void) replaceCharactersInRange:(SBRange)range withCharacters:(UChar*)altChars length:(size_t)altLen;

@end
