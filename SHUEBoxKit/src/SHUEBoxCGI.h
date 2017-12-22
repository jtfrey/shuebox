//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxCGI.h
//
// Basic framework for a SHUEBox CGI.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBox.h"
#import "SBCGI.h"
#import "SBXMLDocument.h"

@class SBDateFormatter;
@class SHUEBoxCollaboration, SHUEBoxRepository, SHUEBoxUser, SHUEBoxRole;

typedef enum {
  kSHUEBoxCGITargetUndefined            = 0,
  kSHUEBoxCGITargetLoginHelper,
  kSHUEBoxCGITargetSuperuserConsole,
  kSHUEBoxCGITargetUserData,
  kSHUEBoxCGITargetGuestAccountConfirm,
  kSHUEBoxCGITargetCollaboration,
  kSHUEBoxCGITargetCollaborationRepository,
  kSHUEBoxCGITargetCollaborationRepositoryRole,
  kSHUEBoxCGITargetCollaborationRole,
  kSHUEBoxCGITargetCollaborationRoleMember,
  kSHUEBoxCGITargetCollaborationMember,
  kSHUEBoxCGITargetKeepAlive
} SHUEBoxCGITarget;
  

@interface SHUEBoxCGI : SBCGI
{
  id                        _database;
  //
  SHUEBoxUser*              _remoteSHUEBoxUser;
  //
  SHUEBoxCGITarget          _target;
  BOOL                      _targetsAreLoaded;
  SHUEBoxCollaboration*     _targetCollaboration;
  SHUEBoxRepository*        _targetRepository;
  SHUEBoxUser*              _targetSHUEBoxUser;
  SHUEBoxRole*              _targetSHUEBoxRole;
  SHUEBoxUser*              _targetSHUEBoxRoleMember;
  SBString*                 _targetConfirmationCode;
  //
  SBError*                  _lastError;
}

- (id) initWithDatabase:(id)database;

- (SHUEBoxUser*) remoteSHUEBoxUser;

- (SBString*) textDocumentFromStdin;
- (SBXMLDocument*) xmlDocumentFromStdin;

- (SHUEBoxCGITarget) target;

- (SHUEBoxCollaboration*) targetCollaboration;
- (SHUEBoxRepository*) targetRepository;
- (SHUEBoxUser*) targetSHUEBoxUser;
- (SHUEBoxRole*) targetSHUEBoxRole;
- (SHUEBoxUser*) targetSHUEBoxRoleMember;
- (SBString*) targetConfirmationCode;

- (SBError*) lastError;

- (void) sendErrorDocument:(SBString*)title description:(SBString*)description forError:(SBError*)anError;

@end
