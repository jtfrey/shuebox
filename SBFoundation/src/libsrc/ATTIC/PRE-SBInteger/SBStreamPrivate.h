//
// SBFoundation : ObjC Class Library for Solaris
// SBStreamPrivate.h
//
// Private interfaces to SBStream classes.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

@protocol SBFileDescriptorStream

- (id) initWithFileDescriptor:(int)fd closeWhenDone:(BOOL)closeWhenDone;
- (unsigned int) flagsForStream;
- (int) fileDescriptorForStream;
- (void) fileDescriptorReady;
- (void) fileDescriptorHasError:(int)errno;

@end

