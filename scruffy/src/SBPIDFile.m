//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBPIDFile.m
//
// PID file helpers.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBPIDFile.h"
#import "SBString.h"

#ifndef RUN_DIR
#define RUN_DIR "/var/run"
#endif

static SBString* SBDefaultPIDFile = @RUN_DIR"/scruffy.pid";

BOOL
SBAcquirePIDFile(
  SBString*   pidFile
)
{
  BOOL      result = NO;
  
  if ( pidFile == nil )
    pidFile = SBDefaultPIDFile;
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "rx");
    
    if ( fptr ) {
      int   thePid;
      
      if ( fscanf(fptr, "%d", &thePid) == 1 ) {
        fclose(fptr);
        fptr = NULL;
      } else {
        fclose(fptr);
        fptr = fopen(pidFile_utf8, "wx");
      }
    } else {
      fptr = fopen(pidFile_utf8, "wx");
    }
    if ( fptr ) {
      fprintf(fptr, "%d", getpid());
      fclose(fptr);
      result = YES;
    }
  SBSTRING_AS_UTF8_END
  
  return result;
}

//

pid_t
SBGetPIDFromFile(
  SBString*   pidFile
)
{
  pid_t     result = 0;
  
  if ( pidFile == nil )
    pidFile = SBDefaultPIDFile;
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "rx");
    
    if ( fptr ) {
      int   thePid;
      
      if ( fscanf(fptr, "%d", &thePid) == 1 )
        result = (pid_t)thePid;
      fclose(fptr);
    }
  SBSTRING_AS_UTF8_END
  
  return result;
}

//

void
SBDropPIDFile(
  SBString*   pidFile
)
{
  if ( pidFile == nil )
    pidFile = SBDefaultPIDFile;
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "rx");
    
    if ( fptr ) {
      fclose(fptr);
      fptr = fopen(pidFile_utf8, "wx");
      fclose(fptr);
    }
  SBSTRING_AS_UTF8_END
}
