//
// SBFoundation : ObjC Class Library for Solaris
// SBPIDFile.m
//
// Helper functions for managing a PID file.
//
// $Id$
//

#import "SBPIDFile.h"
#import "SBString.h"

static SBString* __SBPIDFileBasePath = nil;

SBString*
SBGetPIDFileBasePath(void)
{
  return __SBPIDFileBasePath;
}

//

void
SBSetPIDFileBasePath(
  SBString*   path
)
{
  if ( path ) path = [path copy];
  if ( __SBPIDFileBasePath ) [__SBPIDFileBasePath release];
  __SBPIDFileBasePath = path;
}

//

BOOL
SBAcquirePIDFile(
  SBString*   pidFile
)
{
  BOOL        result = NO;
  
  if ( pidFile == nil )
    return NO;
  
  // Relative path?  Append to base path:
  if ( [pidFile isRelativePath] ) {
    if ( __SBPIDFileBasePath )
      pidFile = [__SBPIDFileBasePath stringByAppendingPathComponent:pidFile];
    else
      pidFile = [@"/var/run" stringByAppendingPathComponent:pidFile];
  }
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "r");
    
    if ( fptr ) {
      int   thePid;
      
      if ( fscanf(fptr, "%d", &thePid) == 1 ) {
        fclose(fptr);
        fptr = NULL;
      } else {
        fclose(fptr);
        fptr = fopen(pidFile_utf8, "w");
      }
    } else {
      fptr = fopen(pidFile_utf8, "w");
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
  pid_t     result = -1;
  
  if ( pidFile == nil )
    return NO;
  
  // Relative path?  Append to base path:
  if ( [pidFile isRelativePath] ) {
    if ( __SBPIDFileBasePath )
      pidFile = [__SBPIDFileBasePath stringByAppendingPathComponent:pidFile];
    else
      pidFile = [@"/var/run" stringByAppendingPathComponent:pidFile];
  }
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "r");
    
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
    return;
  
  // Relative path?  Append to base path:
  if ( [pidFile isRelativePath] ) {
    if ( __SBPIDFileBasePath )
      pidFile = [__SBPIDFileBasePath stringByAppendingPathComponent:pidFile];
    else
      pidFile = [@"/var/run" stringByAppendingPathComponent:pidFile];
  }
  
  SBSTRING_AS_UTF8_BEGIN(pidFile)
    FILE*   fptr = fopen(pidFile_utf8, "r");
    
    if ( fptr ) {
      fclose(fptr);
      fptr = fopen(pidFile_utf8, "w");
      fclose(fptr);
    }
  SBSTRING_AS_UTF8_END
}
