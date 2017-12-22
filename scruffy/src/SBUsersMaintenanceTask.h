//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBUsersMaintenanceTask.h
//
// Handles user-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBMaintenanceTask.h"

@interface SBUsersMaintenanceTask : SBMaintenanceTask
{
  SEL         _performMaintenanceTaskSelector;
}

@end
