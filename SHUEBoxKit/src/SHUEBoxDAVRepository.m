//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxDAVRepository.m
//
// SHUEBox WebDAV repositories.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxDAVRepository.h"

#import "SBString.h"

@implementation SHUEBoxDAVRepository

  - (SBString*) repositoryType
  {
    return @"WebDAV";
  }

//

  - (SBError*) setupHomeDirectory
  {
    //
    // Install the initial resources meant to be inside a WebDAV repository:
    //
    return [[self parentCollaboration] installResource:@"dav" withInstanceName:[self shortName]];
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
                  "Alias %S \"%S\"\n"
                  "<Directory \"%S\">\n"
                  "  DAV On\n"
                  "  Options Indexes\n"
                  "  AllowOverride None\n"
                  "  Order allow,deny\n"
                  "  Allow from all\n"
                  "  Satisfy all\n",
                  reposURI,
                  reposHome,
                  reposHome
                ];
    if ( (anError = [super appendApacheHTTPSConfToString:confString]) == nil ) {
      [confString appendString:@"</Directory>\n\n"];
    }
    return anError;
  }

@end
