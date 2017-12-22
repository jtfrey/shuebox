//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxWebRepository.h
//
// SHUEBox web site and web resource repositories.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxWebRepository.h"

#import "SBString.h"

@implementation SHUEBoxWebRepository

  - (SBString*) repositoryType
  {
    return @"Web Site";
  }

//

  - (SBString*) homeDirectory
  {
    if ( ! _homeDirectory ) {
      SBString*       collabHome = [[self parentCollaboration] homeDirectory];
      
      if ( collabHome )
        _homeDirectory = [[collabHome stringByAppendingPathComponent:@"www"] retain];
    }
    return _homeDirectory;
  }

//

  - (SBError*) setupHomeDirectory
  {
    //
    // Install the web site resources:
    //
    return [[self parentCollaboration] installResource:@"www" withInstanceName:@"www"];
  }
  
//

  - (SBError*) appendApacheHTTPConfToString:(SBMutableString*)confString
  {
    const UChar*    reposHome = [[self homeDirectory] utf16Characters];
    const UChar*    shortName = [[[self parentCollaboration] shortName] utf16Characters];
    
    [confString appendFormat:
                  "Alias /%S \"%S\"\n"
                  "<Directory \"%S\">\n"
                  "  Options FollowSymLinks\n"
                  "  AllowOverride None\n"
                  "  Order Deny,Allow\n"
                  "  Allow from all\n"
                  "</Directory>\n"
                  "RedirectMatch ^/%S/web-resources(/(.*))?$ https://shuebox.nss.udel.edu/%S/web-resources/$2\n\n",
                  shortName,
                  reposHome,
                  reposHome,
                  shortName,
                  shortName
                ];
    return nil;
  }
  
//

  - (SBError*) appendApacheHTTPSConfToString:(SBMutableString*)confString
  {
    const UChar*    reposHome = [[self homeDirectory] utf16Characters];
    const UChar*    shortName = [[[self parentCollaboration] shortName] utf16Characters];
    
    [confString appendFormat:
                  "Alias /%S/web-resources \"%S/resources\"\n"
                  "<Directory \"%S/resources\">\n"
                  "  DAV On\n"
                  "  Options Indexes\n"
                  "  AllowOverride None\n"
                  "  Order allow,deny\n"
                  "  Allow from all\n"
                  "  AuthSHUEBoxCollaborationId \"%S\"\n"
                  "  AuthSHUEBoxRepositoryId \"web-resources\"\n"
                  "  <Limit GET>\n"
                  "     Require shuebox-collab-user\n"
                  "   </Limit>\n"
                  "   <LimitExcept GET>\n"
                  "     Require shuebox-repo-user\n"
                  "   </LimitExcept>\n"
                  "  Satisfy all\n"
                  "</Directory>\n\n",
                  shortName,
                  reposHome,
                  reposHome,
                  shortName
                ];
    return nil;
  }

@end
