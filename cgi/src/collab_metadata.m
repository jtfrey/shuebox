//
// SHUEBox CGIs : CGI programs for SHUEBox's web interfaces
// collab_metadata.m
//
// SHUEBox collaboration admin interface.
//
// $Id$
//

#import "SBFoundation.h"
#import "SBPostgres.h"
#import "SBZFSFilesystem.h"
#import "SHUEBox.h"
#import "SHUEBoxCGI.h"
#import "SHUEBoxDictionary.h"
#import "SHUEBoxUser.h"
#import "SHUEBoxRole.h"
#import "SHUEBoxCollaboration.h"
#import "SHUEBoxRepository.h"

SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";

SBLogger* SBDefaultLogFile = nil;

UChar SBUnknownRemoteAddr[9] = { '?' , '.', '?' , '.', '?' , '.', '?' , '\0' };

UChar SBBlankCStr[1] = { 0x0000 };

//

void
sendRoleMemberList(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
  SHUEBoxRole*            theRole
)
{
  SBEnumerator*   eUser = [theRole roleMemberEnumerator];
  
  [theCGI appendFormatToResponseText:"<?xml version=\"1.0\" encoding=\"UTF-8\"?><role id=\"%lld\"%s%s><members>",
      [theRole shueboxRoleId],
      ( [theRole isLocked] ? " locked=\"yes\"" : "" ),
      ( [theRole isSystemOwned] ? " system=\"yes\"" : "" )
    ];
  
  if ( eUser ) {
    SHUEBoxUser*  user;
    
    while ( (user = [eUser nextObject]) ) {
      SBString*     fullName = [user fullName];
      
      [theCGI appendFormatToResponseText:"<user id=\"%lld\"%s><shortName>%S</shortName><fullName>%S</fullName></user>",
          [user shueboxUserId],
          ([user isGuestUser] ? " guest=\"yes\"" : "" ),
          [[user shortName] utf16Characters],
          ( (fullName && ! [fullName isNull]) ? [[fullName xmlSafeString] utf16Characters] : SBBlankCStr )
        ];      
    }
  }
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</members></role>\n"];
  [theCGI sendResponse];
}

//

void
sendRoleList(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration
)
{
  SBArray*        roles = [theCollaboration shueboxRoles];
  SBUInteger      i = 0, iMax;
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><roles>"];
  
  if ( roles && (iMax = [roles count]) ) {
    while ( i < iMax ) {
      SHUEBoxRole*  aRole = [roles objectAtIndex:i++];
      
      if ( aRole ) {
        SBString*           shortName = [aRole shortName];
        SBString*           description = [aRole description];
        
        [theCGI appendFormatToResponseText:"<role id=\"%lld\"%s%s><shortName>%S</shortName><description>%S</description></role>",
            [aRole shueboxRoleId],
            ( [aRole isLocked] ? " locked=\"yes\"" : "" ),
            ( [aRole isSystemOwned] ? " system=\"yes\"" : "" ),
            ( shortName ? [shortName utf16Characters] : SBBlankCStr ),
            ( (description && ! [description isNull]) ? [[description xmlSafeString] utf16Characters] : SBBlankCStr )
          ];
      }
    }
  }
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</roles>\n"];
  [theCGI sendResponse];
}

//

void
sendRoleDescription(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxRole*            theRole
)
{
  SHUEBoxRoleId       roleId = [theRole shueboxRoleId];
  SBString*           shortName = [theRole shortName];
  SBString*           description = [theRole description];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
  //
  // Basic summary:
  //
  [theCGI appendFormatToResponseText:"<role id=\"%lld\"%s%s><shortName>%S</shortName><description>%S</description>",
                roleId,
                ( [theRole isLocked] ? " locked=\"yes\"" : "" ),
                ( [theRole isSystemOwned] ? " system=\"yes\"" : "" ),
                ( shortName ? [shortName utf16Characters] : SBBlankCStr ),
                ( (description && ! [description isNull]) ? [[description xmlSafeString] utf16Characters] : SBBlankCStr )
              ];
  
  // Deeper response requested?
  SBString*           depth = [theCGI queryArgumentForKey:@"depth"];
  
  if ( depth && [depth isEqual:@"inf"] ) {
    SBEnumerator*     eUser = [theRole roleMemberEnumerator];
    
    [theCGI appendStringToResponseText:@"<members>"];
    
    if ( eUser ) {
      SHUEBoxUser*  user;
      
      while ( (user = [eUser nextObject]) ) {
        [theCGI appendFormatToResponseText:"<user id=\"" SBIntegerFormat "\"%s>%S</user>",
            [user shueboxUserId],
            ([user isGuestUser] ? " guest=\"yes\"" : "" ),
            [[user shortName] utf16Characters]
          ];      
      }
    }
    [theCGI appendStringToResponseText:@"</members>"];
  }
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</role>\n"];
  [theCGI sendResponse];
}

//

void
sendRepositoryRoleList(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxRepository*      theRepository
)
{
  SBEnumerator*   eRole = [theRepository roleGranteeEnumerator];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><roles>"];
  
  if ( eRole ) {
    SHUEBoxRole*  role;
    
    while ( (role = [eRole nextObject]) ) {
      [theCGI appendFormatToResponseText:"<role id=\"%lld\">%S</role>",
          [role shueboxRoleId],
          [[role shortName] utf16Characters]
        ];      
    }
  }
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</roles>\n"];
  [theCGI sendResponse];
}

//

void
sendRepositoryList(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration
)
{
  SBArray*        repos = [theCollaboration repositories];
  SBUInteger      i = 0, iMax;
	SBString*				baseURI = [theDatabase stringForFullDictionaryKey:@"system:base-uri-authority"];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><repositories>"];
  
  if ( repos && (iMax = [repos count]) ) {
    while ( i < iMax ) {
      SHUEBoxRepository*  repo = [repos objectAtIndex:i++];
      
      [theCGI appendFormatToResponseText:"<repository id=\"" SBIntegerFormat "\" type=\"" SBIntegerFormat "\"%s><shortName>%S</shortName>",
          [repo reposId],
          [repo repositoryTypeId],
          ( [repo canBeRemoved] ? "" : " immutable=\"yes\"" ),
          [[repo shortName] utf16Characters]
        ];
			if ( baseURI ) {
				SBString*				uriPath = [repo uriString];
				
				if ( uriPath ) {
					[theCGI appendFormatToResponseText:"<baseURI>%S%S</baseURI>", [baseURI utf16Characters], [uriPath utf16Characters]];
				}			
			}
			[theCGI appendFormatToResponseText:"</repository>"];
    }
  }
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</repositories>\n"];
  [theCGI sendResponse];
}

//

void
sendRepositoryDescription(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxRepository*      theRepository
)
{
  SBInteger           reposId = [theRepository reposId];
  SBString*           shortName = [theRepository shortName];
  SBString*           description = [theRepository description];
  SBDate*             created = [theRepository creationTimestamp];
  SBDate*             provisioned = [theRepository provisionedTimestamp];
  SBDate*             modified = [theRepository modificationTimestamp];
  SBDate*             removeAfter = [theRepository removalTimestamp];
  SBDateFormatter*    dateFormatter = [SBDateFormatter iso8601DateFormatter];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
  //
  // Basic summary:
  //
  [theCGI appendFormatToResponseText:"<repository id=\"" SBIntegerFormat "\" type=\"" SBIntegerFormat "\"%s><shortName>%S</shortName><description>%S</description>",
                reposId,
                [theRepository repositoryTypeId],
                ( [theRepository canBeRemoved] ? "" : " immutable=\"yes\"" ),
                ( shortName ? [shortName utf16Characters] : SBBlankCStr ),
                ( (description && ! [description isNull]) ? [[description xmlSafeString] utf16Characters] : SBBlankCStr )
              ];
	
	//
	// URI
	//
	SBString*					baseURI = [theDatabase stringForFullDictionaryKey:@"system:base-uri-authority"];
	
	if ( baseURI ) {
		SBString*				uriPath = [theRepository uriString];
		
		if ( uriPath ) {
			[theCGI appendFormatToResponseText:"<baseURI>%S%S</baseURI>", [baseURI utf16Characters], [uriPath utf16Characters]];
		}
	}
  
  if ( created )
    [theCGI appendFormatToResponseText:"<created>%S</created>", [[dateFormatter stringFromDate:created] utf16Characters]];
  if ( provisioned )
    [theCGI appendFormatToResponseText:"<provisioned>%S</provisioned>", [[dateFormatter stringFromDate:provisioned] utf16Characters]];
  if ( modified )
    [theCGI appendFormatToResponseText:"<modified>%S</modified>", [[dateFormatter stringFromDate:modified] utf16Characters]];
  if ( removeAfter )
    [theCGI appendFormatToResponseText:"<removeAfter>%S</removeAfter>", [[dateFormatter stringFromDate:removeAfter] utf16Characters]];
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</repository>\n"];
  [theCGI sendResponse];
}

//

void
sendCollaborationDescription(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration
)
{
  SBInteger           collabId = [theCollaboration collabId];
  SBString*           shortName = [theCollaboration shortName];
  SBString*           description = [theCollaboration description];
  SBDate*             created = [theCollaboration creationTimestamp];
  SBDate*             provisioned = [theCollaboration provisionedTimestamp];
  SBDate*             modified = [theCollaboration modificationTimestamp];
  SBDate*             removeAfter = [theCollaboration removalTimestamp];
  SBDateFormatter*    dateFormatter = [SBDateFormatter iso8601DateFormatter];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
  //
  // Basic summary:
  //
  [theCGI appendFormatToResponseText:"<collaboration id=\"" SBIntegerFormat "\" administrator=\"%s\"><shortName>%S</shortName><description>%S</description>",
                collabId,
								( [theCollaboration userIsAdministrator:[theCGI remoteSHUEBoxUser]] ? "yes" : "no" ),
                ( shortName ? [shortName utf16Characters] : SBBlankCStr ),
                ( (description && ! [description isNull]) ? [[description xmlSafeString] utf16Characters] : SBBlankCStr )
              ];
	
	//
	// URI
	//
	SBString*					baseURI = [theDatabase stringForFullDictionaryKey:@"system:base-uri-authority"];
	
	if ( baseURI ) {
		SBString*				uriPath = [theCollaboration uriString];
		
		if ( uriPath ) {
			[theCGI appendFormatToResponseText:"<baseURI>%S%S</baseURI>", [baseURI utf16Characters], [uriPath utf16Characters]];
		}
	}
  
  // Quota/reservation stuff:
  SBUInteger    megabytes;
  
  if ( (megabytes = [theCollaboration megabytesQuota]) ) {
    SBZFSFilesystem*  filesystem = [theCollaboration filesystem];
    
    if ( filesystem )
      [theCGI appendFormatToResponseText:"<quota used=\"%.1f\">" SBUIntegerFormat "</quota>", 
          [filesystem inUsePercentage],
          megabytes
        ];
  }
  if ( (megabytes = [theCollaboration megabytesReserved]) ) {
    [theCGI appendFormatToResponseText:"<reservation>" SBUIntegerFormat "</reservation>", 
        megabytes
      ];
  }
  
  if ( created )
    [theCGI appendFormatToResponseText:"<created>%S</created>", [[dateFormatter stringFromDate:created] utf16Characters]];
  if ( provisioned )
    [theCGI appendFormatToResponseText:"<provisioned>%S</provisioned>", [[dateFormatter stringFromDate:provisioned] utf16Characters]];
  if ( modified )
    [theCGI appendFormatToResponseText:"<modified>%S</modified>", [[dateFormatter stringFromDate:modified] utf16Characters]];
  if ( removeAfter )
    [theCGI appendFormatToResponseText:"<removeAfter>%S</removeAfter>", [[dateFormatter stringFromDate:removeAfter] utf16Characters]];
  
  //
  // All done!
  //
  [theCGI appendStringToResponseText:@"</collaboration>\n"];
  [theCGI sendResponse];
}

//
#if 0
#pragma mark -
#endif
//

BOOL
processRoleCreationRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
	SBXMLElement*             element
)
{
  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  SBString*       roleShortName = nil;
  SBString*       roleDescription = nil;
  SBError*        error = nil;
  
  while ( xmlNode ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Description:
      //
      if ( [nodeName isEqual:@"description"] ) {
        roleDescription = [element stringForTextContainingNode];
      }
      //
      // Shortname:
      //
      else if ( [nodeName isEqual:@"shortName"] ) {
        roleShortName = [element stringForTextContainingNode];
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  if ( ! roleShortName ) {
    [theCGI sendErrorDocument:@"Invalid role creation request" description:@"A role name was not provided." forError:nil];
    errorEncountered = YES;
  } else {
    SHUEBoxRole*          newRole = [SHUEBoxRole createRoleWithCollaboration:theCollaboration
                                                            shortName:roleShortName
                                                            description:roleDescription
                                                            error:&error
                                                          ];
    if ( ! newRole ) {
      [theCGI sendErrorDocument:@"Unable to create role" description:@"An error occurred while creating the role" forError:error];
      errorEncountered = YES;
    } else {
      sendRoleDescription(theDatabase, theCGI, newRole);
      [SBDefaultLogFile writeFormatToLog:"+ created role `%S` for collab id " SBIntegerFormat,
          [roleShortName utf16Characters],
          [theCollaboration collabId]
        ];
    }
  }  
  
  return errorEncountered;
}

//

BOOL
processRoleUpdateRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
  SHUEBoxRole*              theRole,
	SBXMLElement*             element
)
{
  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  
  while ( xmlNode && ! errorEncountered ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Description update?
      //
      if ( [nodeName isEqual:@"description"] ) {
        SBString*	newDescription = [element stringForTextContainingNode];
        
        if ( newDescription ) {
          [theRole setDescription:newDescription];
          [SBDefaultLogFile writeFormatToLog:"+ setting description `%S` for role %lld (collab id " SBIntegerFormat ")",
              [newDescription utf16Characters],
              [theRole shueboxRoleId],
              [theCollaboration collabId]
            ];
        }
      }
      
      //
      // Short name update?
      //
      else if ( [nodeName isEqual:@"shortName"] ) {
        SBString*	newShortName = [element stringForTextContainingNode];
        
        if ( newShortName && ! [[theRole shortName] isEqual:newShortName] ) {
          if ( ! [theCollaboration shueboxRoleWithName:newShortName] ) {
            [theRole setShortName:newShortName];
            [SBDefaultLogFile writeFormatToLog:"+ setting name `%S` for role %lld (collab id " SBIntegerFormat ")",
                [newShortName utf16Characters],
                [theRole shueboxRoleId],
                [theCollaboration collabId]
              ];
          } else {
            [theCGI sendErrorDocument:@"Unable to rename role" description:[SBString stringWithFormat:"A role already exists with the name `%S`.", [newShortName utf16Characters]] forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid role rename request" description:@"An empty role name is not acceptable." forError:nil];
          errorEncountered = YES;
        }
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  
  return errorEncountered;
}

//

BOOL
processMultiOpRoleMembershipRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
  SHUEBoxRole*              theRole,
	SBXMLElement*             element
)
{
  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  
  while ( xmlNode && ! errorEncountered ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Remove user?
      //
      if ( [nodeName isEqual:@"remove"] ) {
        SBXMLElement*   userElement = (SBXMLElement*)[element firstChildOfKind:kSBXMLNodeKindElement];
        
        while ( userElement ) {
          if ( [[userElement nodeName] isEqual:@"user"] ) {
            // Does it have a user id?
            SBNumber*   userId = [userElement numberAttributeForName:@"id"];
            
            if ( userId ) {
              SHUEBoxUser*  theUser = [theCollaboration shueboxUserWithId:[userId integerValue]];
              
              if ( theUser && [theRole isMember:theUser] ) {
                [theRole removeMember:theUser];
                [SBDefaultLogFile writeFormatToLog:"+ removed user %lld from role %lld (collab id " SBIntegerFormat ")",
                      [theUser shueboxUserId],
                      [theRole shueboxRoleId],
                      [theCollaboration collabId]
                    ];
              }
            }
          }
          while ( (userElement = (SBXMLElement*)[userElement nextSiblingNode]) && ([userElement nodeKind] != kSBXMLNodeKindElement) );
        }
      }

      //
      // Add user?
      //
      else if ( [nodeName isEqual:@"add"] ) {
        SBXMLElement*   userElement = (SBXMLElement*)[element firstChildOfKind:kSBXMLNodeKindElement];
        
        while ( userElement ) {
          if ( [[userElement nodeName] isEqual:@"user"] ) {
            // Does it have a user id?
            SBNumber*   userId = [userElement numberAttributeForName:@"id"];
            
            if ( userId ) {
              SHUEBoxUser*  theUser = [theCollaboration shueboxUserWithId:[userId integerValue]];
              
              if ( theUser && ! [theRole isMember:theUser] ) {
                [theRole addMember:theUser];
                [SBDefaultLogFile writeFormatToLog:"+ added user %lld to role %lld (collab id " SBIntegerFormat ")",
                      [theUser shueboxUserId],
                      [theRole shueboxRoleId],
                      [theCollaboration collabId]
                    ];
              }
            }
          }
          while ( (userElement = (SBXMLElement*)[userElement nextSiblingNode]) && ([userElement nodeKind] != kSBXMLNodeKindElement) );
        }
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  
  return errorEncountered;
}

//

BOOL
processRepositoryCreationRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
  SBInteger                 reposTypeId,
	SBXMLElement*             element
)
{
  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  SBString*       reposShortName = nil;
  SBString*       reposDescription = nil;
  SBError*        error = nil;
  
  while ( xmlNode ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Description:
      //
      if ( [nodeName isEqual:@"description"] ) {
        reposDescription = [element stringForTextContainingNode];
      }
      //
      // Shortname:
      //
      else if ( [nodeName isEqual:@"shortName"] ) {
        reposShortName = [element stringForTextContainingNode];
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  if ( ! reposShortName ) {
    [theCGI sendErrorDocument:@"Invalid repository creation request" description:@"A repository name was not provided." forError:nil];
    errorEncountered = YES;
  } else {
    SHUEBoxRepository*      newRepo = [SHUEBoxRepository createRepositoryWithCollaboration:theCollaboration
                                                            reposTypeId:reposTypeId
                                                            shortName:reposShortName
                                                            description:reposDescription
                                                            error:&error
                                                          ];
    if ( ! newRepo ) {
      [theCGI sendErrorDocument:@"Unable to create repository" description:@"An error occurred while creating the repository" forError:error];
      errorEncountered = YES;
    } else {
      sendRepositoryDescription(theDatabase, theCGI, newRepo);
    }
  }  
  
  return errorEncountered;
}

//

BOOL
processRepositoryUpdateRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
  SHUEBoxRepository*        theRepository,
	SBXMLElement*             element
)
{
  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  
  while ( xmlNode && ! errorEncountered ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Description update?
      //
      if ( [nodeName isEqual:@"description"] ) {
        SBString*	newDescription = [element stringForTextContainingNode];
        
        if ( newDescription ) {
          [theRepository setDescription:newDescription];
          [SBDefaultLogFile writeFormatToLog:"+ setting description `%S` for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
              [newDescription utf16Characters],
              [theRepository reposId],
              [theRepository parentCollabId]
            ];
        }
      }

      //
      // Modifying the removal timestamp?
      //
      else if ( [nodeName isEqual:@"removeAfter"] ) {
        SBString* removalDateString = [element stringForTextContainingNode];
        SBDate*   removeDate = nil;
        BOOL      ok = YES;
        
        if ( removalDateString ) {
          SBDateFormatter*  dateFormatter = [SBDateFormatter iso8601DateFormatter];
          
          removeDate = [dateFormatter dateFromString:removalDateString];
          if ( ! removeDate ) {
            [theCGI sendErrorDocument:@"Invalid removal date" description:@"An error occurred while attempting to parse the date for removal." forError:nil];
            errorEncountered = YES;
            ok = NO;
          }
        }
        if ( removeDate ) {
          [SBDefaultLogFile writeFormatToLog:"+ setting removal date to %S for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
              [removalDateString utf16Characters],
              [theRepository reposId],
              [theRepository parentCollabId]
            ];
          [theRepository setRemovalTimestamp:removeDate];
        } else if ( ok && [theRepository removalTimestamp] ) {
          [SBDefaultLogFile writeFormatToLog:"+ clearing removal date for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
              [theRepository reposId],
              [theRepository parentCollabId]
            ];
          [theRepository setRemovalTimestamp:nil];
        }
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  
  return errorEncountered;
}

//

BOOL
processMultiOpRepositoryRoleRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
  SHUEBoxRepository*        theRepository,
	SBXMLElement*             element
)
{

  SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  
  while ( xmlNode && ! errorEncountered ) {
    // Element?
    if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
      SBXMLElement* element = (SBXMLElement*)xmlNode;
      SBString*     nodeName = [xmlNode nodeName];
      
      //
      // Remove role?
      //
      if ( [nodeName isEqual:@"remove"] ) {
        SBXMLElement*   roleElement = (SBXMLElement*)[element firstChildOfKind:kSBXMLNodeKindElement];
        
        while ( roleElement ) {
          if ( [[roleElement nodeName] isEqual:@"role"] ) {
            // Does it have a role id?
            SBNumber*   roleId = [roleElement numberAttributeForName:@"id"];
            
            if ( roleId ) {
              SHUEBoxRole*  theRole = [theCollaboration shueboxRoleWithId:[roleId integerValue]];
              
              if ( theRole && [theRepository roleHasAccess:theRole] ) {
                [theRepository denyRoleAccess:theRole];
                [SBDefaultLogFile writeFormatToLog:"+ removed role %lld from ACL for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
                      [theRole shueboxRoleId],
                      [theRepository reposId],
                      [theCollaboration collabId]
                    ];
              }
            }
          }
          while ( (roleElement = (SBXMLElement*)[roleElement nextSiblingNode]) && ([roleElement nodeKind] != kSBXMLNodeKindElement) );
        }
      }

      //
      // Add role?
      //
      else if ( [nodeName isEqual:@"add"] ) {
        SBXMLElement*   roleElement = (SBXMLElement*)[element firstChildOfKind:kSBXMLNodeKindElement];
        
        while ( roleElement ) {
          if ( [[roleElement nodeName] isEqual:@"role"] ) {
            // Does it have a role id?
            SBNumber*   roleId = [roleElement numberAttributeForName:@"id"];
            
            if ( roleId ) {
              SHUEBoxRole*  theRole = [theCollaboration shueboxRoleWithId:[roleId integerValue]];
              
              if ( theRole && ! [theRepository roleHasAccess:theRole] ) {
                [theRepository grantRoleAccess:theRole];
                [SBDefaultLogFile writeFormatToLog:"+ added role %lld to ACL for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
                      [theRole shueboxRoleId],
                      [theRepository reposId],
                      [theCollaboration collabId]
                    ];
              }
            }
          }
          while ( (roleElement = (SBXMLElement*)[roleElement nextSiblingNode]) && ([roleElement nodeKind] != kSBXMLNodeKindElement) );
        }
      }
    }
    xmlNode = [xmlNode nextSiblingNode];
  }
  
  return errorEncountered;
}

//

BOOL
processCollaborationUpdateRequest(
  id                        theDatabase,
  SHUEBoxCGI*               theCGI,
  SHUEBoxCollaboration*     theCollaboration,
	SBXMLElement*             element
)
{
	SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  
	//
	// Let's walk the child nodes:
	//
	while ( xmlNode && ! errorEncountered ) {
		// Element?
		if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
			SBString*		nodeName = [xmlNode nodeName];
			
			element = (SBXMLElement*)xmlNode;
			
			//
			// Description update?
			//
			if ( [nodeName isEqual:@"description"] ) {
				SBString*	newDescription = [element stringForTextContainingNode];
				
				if ( newDescription ) {
					[theCollaboration setDescription:newDescription];
					[SBDefaultLogFile writeFormatToLog:"+ setting description `%S` for collaboration " SBIntegerFormat, [newDescription utf16Characters], [theCollaboration collabId]];
				}
			}
      
      //
      // Modifying the removal timestamp?
      //
      else if ( [nodeName isEqual:@"removeAfter"] ) {
        SBString* removalDateString = [element stringForTextContainingNode];
        SBDate*   removeDate = nil;
        BOOL      ok = YES;
        
        if ( removalDateString ) {
          SBDateFormatter*  dateFormatter = [SBDateFormatter iso8601DateFormatter];
          
          removeDate = [dateFormatter dateFromString:removalDateString];
          if ( ! removeDate ) {
            [theCGI sendErrorDocument:@"Invalid removal date" description:@"An error occurred while attempting to parse the date for removal." forError:nil];
            errorEncountered = YES;
            ok = NO;
          }
        }
        if ( removeDate ) {
          [SBDefaultLogFile writeFormatToLog:"+ setting collaboration removal date to %S", [removalDateString utf16Characters]];
          [theCollaboration setRemovalTimestamp:removeDate];
        } else if ( ok && [theCollaboration removalTimestamp] ) {
          [SBDefaultLogFile writeFormatToLog:"+ clearing collaboration removal date"];
          [theCollaboration setRemovalTimestamp:nil];
        }
      }
		}
		xmlNode = [xmlNode nextSiblingNode];
	}
  
  return errorEncountered;
}

//
#if 0
#pragma mark -
#endif
//

void
handleKeepAlive(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI
)
{
  //
  // All we do is return a near-empty document; Apache will refresh the auth cookie for us.  The
  // web component ignores the document anyway.
  //
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><ok/>"];
  [theCGI sendResponse];
}

//

void
handleUserRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
	SHUEBoxUser*						theUser
)
{
	BOOL            errorEncountered = NO;
  
  //
  // We react to a GET, PUT, POST, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      if ( theUser ) {
        // Consider the request a check for user membership in this collaboration.  Just respond with user's basic
        // description:
        SBString*     fullName = [theUser fullName];
        
        [theCGI appendFormatToResponseText:"<?xml version=\"1.0\" encoding=\"UTF-8\"?><user id=\"%lld\"%s><shortName>%S</shortName><fullName>%S</fullName></user>\n",
            [theUser shueboxUserId],
            ([theUser isGuestUser] ? " guest=\"yes\"" : "" ),
            [[theUser shortName] utf16Characters],
            ( fullName ? [[fullName xmlSafeString] utf16Characters] : SBBlankCStr )
          ];   
        [theCGI sendResponse];
      } else {
        // A search request, perhaps?
        SBDictionary*   queryArgs = [theCGI queryArguments];
        
        if ( queryArgs ) {
          SBEnumerator* eKey = [queryArgs keyEnumerator];
          SBString*     key;
          
          printf(
              "Content-type: text/plain\r\n\r\n"
              "Normally, this query URL would return for you a list of matching SHUEBox/UD users.  Unfortunately, that's not implemented yet.\r\n\r\n"
            );
          while ( (key = [eKey nextObject]) ) {
            SBString*   value = [queryArgs objectForKey:key];
            
            [key writeToStream:stdout];
            printf(" = ");
            if ( value )
              [value writeToStream:stdout];
            printf("\n");
          }
        } else {
          // Get the "everyone" role and send it's membership:
          SHUEBoxRole*    everyone = [theCollaboration everyoneSHUEBoxRole];
          
          if ( everyone ) {
            sendRoleMemberList(theDatabase, theCGI, theCollaboration, everyone);
          } else {
            [theCGI sendErrorDocument:@"Server error" description:@"An error occurred while fetching the `everyone` group for this collaboration." forError:nil];
          }
        }
      }
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }
    
  }
}

//

void
handleRoleMembershipRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
  SHUEBoxRole*            theRole,
	SHUEBoxUser*						theUser
)
{
	BOOL            errorEncountered = NO;
  
  //
  // We react to a GET, PUT, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      if ( ! theUser )
        sendRoleMemberList(theDatabase, theCGI, theCollaboration, theRole);
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }
    
    case kSBHTTPMethodPUT: {
      if ( [theRole isLocked] ) {
        [theCGI sendErrorDocument:@"Role membership locked" description:@"The membership of that role cannot be modified." forError:nil];
        errorEncountered = YES;
      }
      // Add a user to a role:
      else if ( theUser ) {
        if ( ! [theRole isMember:theUser] ) {
          [theRole addMember:theUser];
          [SBDefaultLogFile writeFormatToLog:"+ added user %lld to role %lld (collab id " SBIntegerFormat ")",
                [theUser shueboxUserId],
                [theRole shueboxRoleId],
                [theCollaboration collabId]
              ];
        } else {
          // User is already a member of the role, so in a sense...success!
          sendRoleMemberList(theDatabase, theCGI, theCollaboration, theRole);
          return;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No user specified for addition to role." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodPOST: {
      // For combined add/remove operations:
      SBXMLDocument*		multiOpDoc = [theCGI xmlDocumentFromStdin];
              
      if ( multiOpDoc ) {
        //
        // Valid document?
        //
        if ( [multiOpDoc isNamedDocument:@"multiOp"] ) {
          SBXMLElement*	xmlElement = [multiOpDoc rootElement];
          
          errorEncountered = processMultiOpRoleMembershipRequest(theDatabase, theCGI, theCollaboration, theRole, xmlElement);
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `multiOp` document." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodDELETE: {
      if ( [theRole isLocked] ) {
        [theCGI sendErrorDocument:@"Role membership locked" description:@"The membership of that role cannot be modified." forError:nil];
        errorEncountered = YES;
      }
      // Remove a user to a role:
      else if ( theUser ) {
        if ( [theRole isMember:theUser] ) {
          [theRole removeMember:theUser];
          [SBDefaultLogFile writeFormatToLog:"+ removed user %lld from role %lld (collab id " SBIntegerFormat ")",
                [theUser shueboxUserId],
                [theRole shueboxRoleId],
                [theCollaboration collabId]
              ];
        } else {
          // User is not a member of the role, so in a sense...success!
          sendRoleMemberList(theDatabase, theCGI, theCollaboration, theRole);
          return;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No user specified for removal from role." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
  }
  
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theRole hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theRole commitModifications] ) {
        sendRoleMemberList(theDatabase, theCGI, theCollaboration, theRole);
        [SBDefaultLogFile writeFormatToLog:"changes successful for role %lld (collab id " SBIntegerFormat ") [%S|%S]",
            [theRole shueboxRoleId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the role." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for role %lld (collab id " SBIntegerFormat ") [%S|%S]",
            [theRole shueboxRoleId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the role." forError:nil];
    }
  }
}

//

void
handleRoleRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
  SHUEBoxRole*            theRole
)
{
	BOOL            errorEncountered = NO;
  
	//
  // We react to a GET, PUT, POST, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      if ( theRole )
        sendRoleDescription(theDatabase, theCGI, theRole);
      else
        sendRoleList(theDatabase, theCGI, theCollaboration);
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }

    case kSBHTTPMethodPUT: {
      //
      // Create a new role:
      //
      if ( theRole ) {
        [theCGI sendErrorDocument:@"Invalid request" description:@"The PUT method cannot be used on an existing role." forError:nil];
        errorEncountered = YES;
      } else {
        SBXMLDocument*		roleCreateDoc = [theCGI xmlDocumentFromStdin];
              
        if ( roleCreateDoc ) {
          //
          // Valid document?
          //
          if ( [roleCreateDoc isNamedDocument:@"role"] ) {
            SBXMLElement*	xmlElement = [roleCreateDoc rootElement];
            
            errorEncountered = processRoleCreationRequest(theDatabase, theCGI, theCollaboration, xmlElement);
          } else {
            [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `role` document." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
          errorEncountered = YES;
        }
      }
      break;
    }

    case kSBHTTPMethodPOST: {
      //
      // Update a role:
      //
      if ( theRole ) {
        if ( ! [theRole isSystemOwned] ) {
          SBXMLDocument*		roleUpdateDoc = [theCGI xmlDocumentFromStdin];
                
          if ( roleUpdateDoc ) {
            //
            // Valid document?
            //
            if ( [roleUpdateDoc isNamedDocument:@"role"] ) {
              SBXMLElement*	xmlElement = [roleUpdateDoc rootElement];
              
              errorEncountered = processRoleUpdateRequest(theDatabase, theCGI, theCollaboration, theRole, xmlElement);
            } else {
              [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `role` document." forError:nil];
              errorEncountered = YES;
            }
          } else {
            [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Immutable role" description:@"The role name/description cannot be modified." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No role indicated?." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodDELETE: {
      //
      // Delete a role:
      //
      if ( theRole ) {
        if ( ! [theRole isSystemOwned] ) {
          if ( [theRole removeFromParentCollaboration] ) {
            sendRoleList(theDatabase, theCGI, theCollaboration);
            return;
          } else {
            [theCGI sendErrorDocument:@"Server error" description:@"The role could not be removed from the database." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Immutable role" description:@"The role name/description cannot be removed." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No role indicated?." forError:nil];
        errorEncountered = YES;
      }
      break;
    }

  }
  
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theRole hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theRole commitModifications] ) {
        sendRoleDescription(theDatabase, theCGI, theRole);
        [SBDefaultLogFile writeFormatToLog:"changes successful for role %lld (collab id " SBIntegerFormat ") [%S|%S]",
            [theRole shueboxRoleId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the role." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for role %lld (collab id " SBIntegerFormat ") [%S|%S]",
            [theRole shueboxRoleId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the role." forError:nil];
    }
  }
}

//

void
handleRepositoryRoleRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
  SHUEBoxRepository*      theRepository,
  SHUEBoxRole*            theRole
)
{
	BOOL            errorEncountered = NO;
  
  //
  // We react to a GET, PUT, POST, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      if ( ! theRole )
        sendRepositoryRoleList(theDatabase, theCGI, theRepository);
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }
    
    case kSBHTTPMethodPUT: {
      // Add a role to a repository's ACL:
      if ( theRole ) {
        if ( ! [theRepository roleHasAccess:theRole] ) {
          [theRepository grantRoleAccess:theRole];
          [SBDefaultLogFile writeFormatToLog:"+ added role %lld to ACL for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
                [theRole shueboxRoleId],
                [theRepository reposId],
                [theCollaboration collabId]
              ];
        } else {
          // Role is already a member of the repository ACL, so in a sense...success!
          sendRepositoryRoleList(theDatabase, theCGI, theRepository);
          return;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No role specified for addition to repository ACL." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodPOST: {
      // For combined add/remove operations:
      SBXMLDocument*		multiOpDoc = [theCGI xmlDocumentFromStdin];
              
      if ( multiOpDoc ) {
        //
        // Valid document?
        //
        if ( [multiOpDoc isNamedDocument:@"multiOp"] ) {
          SBXMLElement*	xmlElement = [multiOpDoc rootElement];
          
          errorEncountered = processMultiOpRepositoryRoleRequest(theDatabase, theCGI, theCollaboration, theRepository, xmlElement);
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `multiOp` document." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodDELETE: {
      // Remove a role from a repository's ACL:
      if ( theRole ) {
        if ( [theRepository roleHasAccess:theRole] ) {
          [theRepository denyRoleAccess:theRole];
          [SBDefaultLogFile writeFormatToLog:"+ removed role %lld from ACL for repository " SBIntegerFormat " (collab id " SBIntegerFormat ")",
                [theRole shueboxRoleId],
                [theRepository reposId],
                [theCollaboration collabId]
              ];
        } else {
          // Role is not a member of the repository ACL, so in a sense...success!
          sendRepositoryRoleList(theDatabase, theCGI, theRepository);
          return;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No role specified for removal from repository ACL." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
  }
  
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theRepository hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theRepository commitModifications] ) {
        sendRepositoryRoleList(theDatabase, theCGI, theRepository);
        [SBDefaultLogFile writeFormatToLog:"changes successful for repository " SBIntegerFormat " (collab id " SBIntegerFormat ") [%S|%S]",
            [theRepository reposId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the repository role membership." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for repository " SBIntegerFormat " (collab id " SBIntegerFormat ") [%S|%S]",
            [theRepository reposId],
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the repository role membership." forError:nil];
    }
  }
}

//

void
handleRepositoryRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration,
  SHUEBoxRepository*      theRepository
)
{
	BOOL            errorEncountered = NO;
  
  //
  // We react to a GET, PUT, POST, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      if ( theRepository )
        sendRepositoryDescription(theDatabase, theCGI, theRepository);
      else
        sendRepositoryList(theDatabase, theCGI, theCollaboration);
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }
    
    case kSBHTTPMethodPUT: {
      //
      // Create a new repository:
      //
      if ( theRepository ) {
        [theCGI sendErrorDocument:@"Invalid request" description:@"The PUT method cannot be used on an existing repository." forError:nil];
        errorEncountered = YES;
      } else {
        SBXMLDocument*		reposCreateDoc = [theCGI xmlDocumentFromStdin];
              
        if ( reposCreateDoc ) {
          //
          // Valid document?
          //
          if ( [reposCreateDoc isNamedDocument:@"repository"] ) {
            SBXMLElement*	xmlElement = [reposCreateDoc rootElement];
            SBNumber*     reposType = [xmlElement numberAttributeForName:@"type"];
            BOOL					valid = NO;

            if ( reposType ) {
              valid = YES;
              errorEncountered = processRepositoryCreationRequest(theDatabase, theCGI, theCollaboration, [reposType integerValue], xmlElement);
            }
            if ( ! valid ) {
              [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a valid `repository` document." forError:nil];
              errorEncountered = YES;
            }
          } else {
            [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `repository` document." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
          errorEncountered = YES;
        }
      }
      break;
    }
    
    case kSBHTTPMethodPOST: {
      if ( theRepository ) {
        SBXMLDocument*		reposUpdateDoc = [theCGI xmlDocumentFromStdin];
              
        if ( reposUpdateDoc ) {
          //
          // Valid document?
          //
          if ( [reposUpdateDoc isNamedDocument:@"repository"] ) {
            SBXMLElement*	xmlElement = [reposUpdateDoc rootElement];
            SBNumber*     reposId = [xmlElement numberAttributeForName:@"id"];
            BOOL					valid = NO;

            if ( reposId && ([reposId integerValue] == [theRepository reposId]) ) {
              //
              // Okay, we've validated the incoming XML document.  Now react to its directives:
              //
              valid = YES;
              errorEncountered = processRepositoryUpdateRequest(theDatabase, theCGI, theCollaboration, theRepository, xmlElement);
            }
            if ( ! valid ) {
              [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a valid `repository` document." forError:nil];
              errorEncountered = YES;
            }
          } else {
            [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `repository` document." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No repository indicated?." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
  }
  
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theRepository hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theRepository commitModifications] ) {
        sendRepositoryDescription(theDatabase, theCGI, theRepository);
        [SBDefaultLogFile writeFormatToLog:"changes successful for repository " SBIntegerFormat " (collab id " SBIntegerFormat ") [%S|%S]",
            [theRepository reposId],
            [theRepository parentCollabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the user information." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for repository " SBIntegerFormat " (collab id " SBIntegerFormat ") [%S|%S]",
            [theRepository reposId],
            [theRepository parentCollabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the repository information." forError:nil];
    }
  }
}

//

void
handleCollaborationRequest(
  id                      theDatabase,
  SHUEBoxCGI*             theCGI,
  SHUEBoxCollaboration*   theCollaboration
)
{
	BOOL            errorEncountered = NO;
  
  //
  // We react to a GET, POST, and DELETE:
  //
  switch ( [theCGI requestMethod] ) {
  
    case kSBHTTPMethodGET: {
      sendCollaborationDescription(theDatabase, theCGI, theCollaboration);
      //
      // Shortcut out of here to avoid the "commit changes" stuff:
      //
      return;
    }
    
    case kSBHTTPMethodPOST: {
      SBXMLDocument*		updateDoc = [theCGI xmlDocumentFromStdin];
      
      if ( updateDoc ) {
        //
        // Valid document?
        //
        if ( [updateDoc isNamedDocument:@"collaboration"] ) {
          SBXMLElement*	xmlElement = [updateDoc rootElement];
          SBNumber*     collabId = [xmlElement numberAttributeForName:@"id"];
          BOOL					valid = NO;
                  
          if ( collabId && ([collabId integerValue] == [theCollaboration collabId]) ) {
            //
            // Okay, we've validated the incoming XML document.  Now react to its directives:
            //
            valid = YES;
            errorEncountered = processCollaborationUpdateRequest(theDatabase, theCGI, theCollaboration, xmlElement);
          }
          if ( ! valid ) {
            [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a valid `collaboration` document." forError:nil];
            errorEncountered = YES;
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `collaboration` document." forError:nil];
          errorEncountered = YES;
        }
      } else {
        [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
        errorEncountered = YES;
      }
      break;
    }
    
    case kSBHTTPMethodDELETE: {
      [SBDefaultLogFile writeFormatToLog:"+ setting removal date to NOW for collaboration " SBIntegerFormat,
          [theCollaboration collabId]
        ];
      [theCollaboration setRemovalTimestamp:[SBDate date]];
      break;
    }
    
    default: {
      [theCGI sendErrorDocument:@"Invalid request" description:@"The request method is not supported for collaborations." forError:nil];
      errorEncountered = YES;
      break;
    }
  
  }
  
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theCollaboration hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theCollaboration commitModifications] ) {
        
        sendCollaborationDescription(theDatabase, theCGI, theCollaboration);
        [SBDefaultLogFile writeFormatToLog:"changes successful for collaboration " SBIntegerFormat " [%S|%S]",
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the collaboration information." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for collaboration " SBIntegerFormat " [%S|%S]",
            [theCollaboration collabId],
            ( remoteUser ? [remoteUser utf16Characters] : SBBlankCStr ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the collaboration information." forError:nil];
    }
  }
}

//
#if 0
#pragma mark -
#endif
//

int
main()
{
  SBAutoreleasePool*    pool = [[SBAutoreleasePool alloc] init];
	
#ifdef LOG_DIR
	const char*						logDir = LOG_DIR;
	
	[SBLogger setBaseLoggingPath:[SBString stringWithUTF8String:logDir]];
#endif
	SBDefaultLogFile = [[SBLogger loggerWithFileAtPath:@"collab_metadata.log"] retain];
	
  SBPostgresDatabase*   theDatabase = [[SBPostgresDatabase alloc] initWithConnectionString:SBDefaultDatabaseConnStr];
  
  if ( theDatabase ) {
    SHUEBoxCGI*         theCGI = [[SHUEBoxCGI alloc] initWithDatabase:theDatabase];
    
    if ( theCGI ) {
      SHUEBoxCGITarget  theTarget = [theCGI target];
      SBError*          theError = [theCGI lastError];
      
      if ( theError ) {
        [theCGI sendErrorDocument:@"Invalid request" description:@"The request could not be interpreted by this CGI." forError:theError];
      } else {
        switch ( theTarget ) {
          case kSHUEBoxCGITargetCollaboration:
          case kSHUEBoxCGITargetCollaborationRepository:
          case kSHUEBoxCGITargetCollaborationRepositoryRole:
          case kSHUEBoxCGITargetCollaborationRole:
          case kSHUEBoxCGITargetCollaborationRoleMember:
          case kSHUEBoxCGITargetCollaborationMember: {
            SHUEBoxCollaboration*   theCollaboration = [theCGI targetCollaboration];
            
            if ( theCollaboration ) {
              //
              // Got a collaboration, where do we go from here:
              //
              switch ( theTarget ) {
              
                case kSHUEBoxCGITargetCollaboration: {
                  handleCollaborationRequest(theDatabase, theCGI, theCollaboration);
                  break;
                }
              
                case kSHUEBoxCGITargetCollaborationRepository: {
                  handleRepositoryRequest(theDatabase, theCGI, theCollaboration, [theCGI targetRepository]);
                  break;
                }
                
                case kSHUEBoxCGITargetCollaborationRepositoryRole: {
                  handleRepositoryRoleRequest(theDatabase, theCGI, theCollaboration, [theCGI targetRepository], [theCGI targetSHUEBoxRole]);
                  break;
                }
                
                case kSHUEBoxCGITargetCollaborationRole: {
                  handleRoleRequest(theDatabase, theCGI, theCollaboration, [theCGI targetSHUEBoxRole]);
                  break;
                }
                
                case kSHUEBoxCGITargetCollaborationRoleMember: {
                  handleRoleMembershipRequest(theDatabase, theCGI, theCollaboration, [theCGI targetSHUEBoxRole], [theCGI targetSHUEBoxRoleMember]);
                  break;
                }
                
                case kSHUEBoxCGITargetCollaborationMember: {
                  handleUserRequest(theDatabase, theCGI, theCollaboration, [theCGI targetSHUEBoxUser]);
                  break;
                }
                
              }
            } else {
              [theCGI sendErrorDocument:@"No such collaboration" description:@"The collaboration associated with the URL could not be loaded." forError:nil];
            }
            break;
          }
          
          case kSHUEBoxCGITargetKeepAlive: {
            handleKeepAlive(theDatabase, theCGI);
            break;
          }
          
          default:
            [theCGI sendErrorDocument:@"Invalid request" description:[SBString stringWithFormat:"The implied request target is not handled by this CGI: %S", [[theCGI pathInfo] utf16Characters]] forError:nil];
            break;
        }
      }
      [theCGI release];
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"The request could not be interpreted by this CGI." forError:nil];
    }
    [theDatabase release];
  } else {
		[SBDefaultLogFile writeFormatToLog:"Unable to establish connection to database!"];
	}
  
  fflush(stdout);
  [pool release];
  return 0;
}
