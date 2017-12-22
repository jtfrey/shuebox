//
// SBFoundation : ObjC Class Library for Solaris
// SBPIDFile.h
//
// Helper functions for managing a PID file.
//
// $Id$
//

#import "SBObject.h"

/*!
  @function SBGetPIDFileBasePath
  @discussion
    Returns the base directory into which relative-path PID files should be written.
*/
SBString* SBGetPIDFileBasePath(void);

/*!
  @function SBSetPIDFileBasePath
  @discussion
    Set the base directory into which relative-path PID files should be written.
*/
void SBSetPIDFileBasePath(SBString* path);

/*!
  @function SBSetPIDFile
  
  Attempt to establish a PID file at the given path.  If the file is empty or
  does not exist the call will be successful and return YES; the file will
  contain the pid until a call to SBDropPIDFile().  If unsuccessful, NO is
  returned.
*/
BOOL SBAcquirePIDFile(SBString* pidFile);

/*!
  @function SBGetPIDFromFile
  
  Attempts to read a pid from the given pidFile.  Returns -1 if any error
  occurs.
*/
pid_t SBGetPIDFromFile(SBString* pidFile);

/*!
  @function SBDropPIDFile
  
  Attempts to drop the pid stored in the pidFile.
*/
void SBDropPIDFile(SBString* pidFile);
