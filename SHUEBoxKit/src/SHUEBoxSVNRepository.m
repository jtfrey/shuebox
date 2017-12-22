//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxSVNRepository.m
//
// SHUEBox Subversion repositories.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxSVNRepository.h"

#import "SBString.h"

@implementation SHUEBoxSVNRepository

  - (SBString*) repositoryType
  {
    return @"Subversion";
  }

//

  - (SBError*) setupHomeDirectory
  {
    //
    // Install the initial resources meant to be inside a Subversion repository:
    //
    return [[self parentCollaboration] installResource:@"svn" withInstanceName:[self shortName]];
  }
  
//

  - (SBError*) appendApacheHTTPConfToString:(SBMutableString*)confString
  {
    const UChar*        reposURI = [[self uriString] utf16Characters];
    
    [confString appendFormat:
                  "RedirectMatch ^%S(/(.*))?$ https://shuebox.nss.udel.edu%S/$2\n\n",
                  reposURI,
                  reposURI
                ];
    return nil;
  }
  
//

  - (SBError*) appendApacheHTTPSConfToString:(SBMutableString*)confString
  {
    SBError*        anError = nil;
    const UChar*    reposHome = [[self homeDirectory] utf16Characters];
    const UChar*    reposURI = [[self uriString] utf16Characters];
    
    [confString appendFormat:
                  "<Location \"%S\">\n"
                  "  DAV svn\n"
                  "  SVNPath \"%S\"\n"
                  "  Order allow,deny\n"
                  "  Allow from all\n"
                  "  Satisfy all\n",
                  reposURI,
                  reposHome
                ];
    if ( (anError = [super appendApacheHTTPSConfToString:confString]) == nil ) {
      [confString appendString:@"</Location>\n\n"];
    }
    return anError;
  }

@end
