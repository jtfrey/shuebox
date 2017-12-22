//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxAuthCookie.h
//
// Support for the authentication cookie.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBHTTPCookie.h"

@class SHUEBoxUser, SBInetAddress;

@interface SHUEBoxAuthCookie : SBHTTPCookie
{
  SHUEBoxUser*      _remoteUser;
  SBInetAddress*    _remoteAddress;
}

- (id) initWithApacheEnvironmentAndDatabase:(id)database;

- (id) initWithUser:(SHUEBoxUser*)user inetAddress:(SBInetAddress*)inetAddress;

- (SHUEBoxUser*) remoteUser;
- (SBInetAddress*) remoteAddress;

@end
