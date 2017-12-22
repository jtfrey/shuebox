//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBPIDFile.h
//
// PID file helpers.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @function SBSetPIDFile
  
  Attempt to establish a PID file at the given path.  If the file is empty or
  does not exist the call will be successful and return YES; the file will
  contain the pid until a call to SBDropPIDFile().  If unsuccessful, NO is
  returned.
  
  If pidFile is nil, the default PID file is selected.
*/
BOOL SBAcquirePIDFile(SBString* pidFile);
/*!
  @function SBGetPIDFromFile
  
  Attempts to read a pid from the given pidFile.  Returns non-zero if
  successful.
  
  If pidFile is nil, the default PID file is selected.
*/
pid_t SBGetPIDFromFile(SBString* pidFile);
/*!
  @function SBDropPIDFile
  
  Attempts to drop the pid stored in the pidFile.
*/
void SBDropPIDFile(SBString* pidFile);
