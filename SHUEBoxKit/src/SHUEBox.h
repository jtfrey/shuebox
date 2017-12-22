//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBox.h
//
// Constants, etc.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBDateFormatter.h"
#import "SBError.h"

extern SBString* SHUEBoxErrorDomain;

/*!
  @enum SHUEBox Error Codes
*/
enum {
  kSHUEBoxOkay = 0,
  
  
  kSHUEBoxApacheManagerInvalidPath = 600,
  kSHUEBoxApacheManagerConfigFileFailure,
  kSHUEBoxApacheManagerApachectlFailure,
  
  kSHUEBoxPathManagerInvalidResource = 800,
  kSHUEBoxPathManagerResourceInstallFailed,
  
  kSHUEBoxRepositoryProvisionUnneccesary = 900,
  kSHUEBoxRepositoryProvisionFailed,
  kSHUEBoxRepositoryDestroyUnneccesary,
  kSHUEBoxRepositoryDestroyFailed,
  kSHUEBoxRepositoryAlreadyExists,
  kSHUEBoxRepositoryTypeMapFailed,
  kSHUEBoxRepositoryInvalidTypeId,
  kSHUEBoxRepositoryCreationFailed,
  
  kSHUEBoxCollaborationProvisionUnneccesary = 1000,
  kSHUEBoxCollaborationProvisionNoFilesystem,
  kSHUEBoxCollaborationProvisionNoMountpoint,
  kSHUEBoxCollaborationProvisionFailed,
  kSHUEBoxCollaborationProvisionWarning,
  kSHUEBoxCollaborationFilesystemError,
  kSHUEBoxCollaborationDestroyUnneccesary,
  kSHUEBoxCollaborationDestroyFailed,
  
  kSHUEBoxRoleAlreadyExists = 1100,
  kSHUEBoxRoleCreationFailed,
  
  kSHUEBoxUserRemovalFailed = 1200,
  kSHUEBoxCollaborationRemovalFailed,
  
  kSHUEBoxGuestConfirmationFailed = 1300,
  
  kSHUEBoxCGIInvalidRequest = 2000
};

//

@interface SBDateFormatter(SHUEBoxAdditions)

+ (SBDateFormatter*) iso8601DateFormatter;
+ (SBDateFormatter*) sqlDateFormatter;

@end
