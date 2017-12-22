//
// SHUEBox CGIs : CGI programs for SHUEBox's web interfaces
// userdata.m
//
// SHUEBox user self-service admin interface.
//
// $Id$
//

#import "SBFoundation.h"
#import "SBCGI.h"

SBLogger* SBDefaultLogFile = nil;

UChar SBUnknownRemoteAddr[9] = { '?' , '.', '?' , '.', '?' , '.', '?' , '\0' };

//

int
main()
{
  SBAutoreleasePool*    pool = [[SBAutoreleasePool alloc] init];
	
#ifdef LOG_DIR
	const char*						logDir = LOG_DIR;
	
	[SBLogger setBaseLoggingPath:[SBString stringWithUTF8String:logDir]];
#endif
	SBDefaultLogFile = [[SBLogger loggerWithFileAtPath:@"demo.log"] retain];
  
  SBCGI*         theCGI = [[SBCGI alloc] init];
    
  if ( theCGI ) {
    SBDictionary*     args = [theCGI queryArguments];
    
    [theCGI appendStringToResponseText:@"CGI arguments:\n\n"];
    if ( ( args ? [args count] : 0 ) ) {
      SBEnumerator*   eKeys = [args keyEnumerator];
      SBString*       k;
      
      while ( (k = [eKeys nextObject]) ) {
        SBString*     v = [args objectForKey:k];
        
        [theCGI appendStringToResponseText:k];
        [theCGI appendStringToResponseText:@" = "];
        [theCGI appendStringToResponseText:v];
        [theCGI appendStringToResponseText:@"\n"];
      }
    }
    [theCGI sendResponse];
    [theCGI release];
  }
  
  fflush(stdout);
  [pool release];
  return 0;
}
