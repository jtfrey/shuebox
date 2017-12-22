//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBCollaborationMaintenanceTask.h
//
// Handles collaboration-oriented tasks.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBMaintenanceTask.h"

@interface SBCollaborationMaintenanceTask : SBMaintenanceTask
{
  SEL         _performMaintenanceTaskSelector;
}

@end
