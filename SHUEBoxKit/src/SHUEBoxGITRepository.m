//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxGITRepository.m
//
// SHUEBox GIT repositories.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxGITRepository.h"

#import "SBString.h"

@implementation SHUEBoxGITRepository

  - (SBString*) repositoryType
  {
    return @"GIT";
  }

//

  - (SBError*) setupHomeDirectory
  {
    //
    // Install the initial resources meant to be inside a Subversion repository:
    //
    return [[self parentCollaboration] installResource:@"git" withInstanceName:[self shortName]];
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
                  "RedirectMatch 301 \"^%S$\" \"%S/\"\n"
                  "ScriptAlias \"%S/\" \"/opt/local/git/1/libexec/git-core/git-http-backend/\"\n"
                  "<Location \"%S\">\n"
                  "  SetEnv GIT_PROJECT_ROOT \"%S\"\n"
                  "  SetEnv GIT_HTTP_EXPORT_ALL\n"
                  "  SetEnv REMOTE_USER=$REDIRECT_REMOTE_USER\n"
                  "  Order allow,deny\n"
                  "  Allow from all\n"
                  "  Satisfy all\n",
                  reposURI, reposURI,
                  reposURI,
                  reposURI,
                  reposHome
                ];
    if ( (anError = [super appendApacheHTTPSConfToString:confString]) == nil ) {
      [confString appendString:@"</Location>\n\n"];
    }
    return anError;
  }

@end
