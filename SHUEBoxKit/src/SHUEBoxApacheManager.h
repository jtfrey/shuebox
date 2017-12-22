//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxApacheManager.h
//
// Manages interactions with the Apache web server software.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"

@class SBString, SBMutableString, SBError, SHUEBoxCollaboration;

@protocol SHUEBoxApacheConf

- (SBError*) appendApacheHTTPConfToString:(SBMutableString*)confString;
- (SBError*) appendApacheHTTPSConfToString:(SBMutableString*)confString;

@end


@interface SHUEBoxApacheManager : SBObject
{
  BOOL        _delayRestarts;
  int         _restart;
}

+ (id) shueboxApacheManager;

- (SBError*) writeConfiguration:(SBString*)config forCollaboration:(SHUEBoxCollaboration*)collaboration isHTTPS:(BOOL)isHTTPS;
- (SBError*) removeConfigurationForCollaboration:(SHUEBoxCollaboration*)collaboration isHTTPS:(BOOL)isHTTPS;

- (SBError*) hardRestart;
- (SBError*) gracefulRestart;

- (uid_t) apacheUserId;
- (gid_t) apacheGroupId;

- (BOOL) delayRestarts;
- (void) setDelayRestarts:(BOOL)delayRestarts;

@end
