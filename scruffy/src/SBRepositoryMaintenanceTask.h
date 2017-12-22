//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBRepositoryMaintenanceTask.h
//
// Handles repository-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBMaintenanceTask.h"

@interface SBRepositoryMaintenanceTask : SBMaintenanceTask
{
  SEL         _performMaintenanceTaskSelector;
}

@end
