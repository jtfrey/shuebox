//
// SBFoundation : ObjC Class Library for Solaris
// SBRunLoopPrivate.h
//
// Private interfaces to SBRunLoop.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

@interface SBRunLoop(SBRunLoopPrivate)

- (BOOL) runMode:(SBString*)aMode beforeDate:(SBDate*)aDate nextTimerFiresAt:(SBDate**)fireDate;

- (SBMutableArray*) messageQueue;
- (void) addMessageToQueue:(id)delayedMessage afterExtant:(BOOL)after;

- (SBMutableArray*) timedMessageQueue;

- (void) addInputSource:(id)source forMode:(SBString*)aMode;
- (void) removeInputSource:(id)source;
- (void) removeInputSource:(id)source forMode:(SBString*)aMode;

- (void) addOutputSource:(id)source forMode:(SBString*)aMode;
- (void) removeOutputSource:(id)source;
- (void) removeOutputSource:(id)source forMode:(SBString*)aMode;

- (SBUInteger) countOfTimersForMode:(SBString*)aMode;
- (SBUInteger) countOfInputSourcesForMode:(SBString*)aMode;
- (SBUInteger) countOfOutputSourcesForMode:(SBString*)aMode;

- (int) setupIOSelectForMode:(SBString*)aMode read:(fd_set*)rfds write:(fd_set*)wfds readError:(fd_set*)refds writeError:(fd_set*)wefds;

@end
