//
// SHUEBox CGIs : CGI programs for SHUEBox's web interfaces
// userdata.m
//
// SHUEBox user self-service admin interface.
//
// $Id$
//

#import "SBFoundation.h"
#import "SBPostgres.h"
#import "SHUEBox.h"
#import "SHUEBoxCGI.h"
#import "SHUEBoxUser.h"
#import "SHUEBoxCollaboration.h"
#import "SHUEBoxDictionary.h"

SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";

SBLogger* SBDefaultLogFile = nil;

UChar SBUnknownRemoteAddr[9] = { '?' , '.', '?' , '.', '?' , '.', '?' , '\0' };

//

void
sendUserDescription(
  id              theDatabase,
  SHUEBoxCGI*     theCGI,
  SHUEBoxUser*    theUser
)
{
  SHUEBoxUserId       uid = [theUser shueboxUserId];
  SBString*           shortName = [theUser shortName];
  SBString*           fullName = [theUser fullName];
  SBDate*             created = [theUser creationTimestamp];
  SBDate*             modified = [theUser modificationTimestamp];
  SBDate*             lastAuth = [theUser lastAuthenticated];
  SBDate*             removeAfter = [theUser removalTimestamp];
  SBDateFormatter*    dateFormatter = [SBDateFormatter iso8601DateFormatter];
  
  [theCGI appendStringToResponseText:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"];
  //
  // Basic summary:
  //
  [theCGI appendFormatToResponseText:"<user id=\"%lld\"%s><shortName>%S</shortName><fullName>%S</fullName>",
                (long long int)uid,
                ( [theUser isGuestUser] ? " guest=\"yes\"" : " native=\"yes\"" ),
                ( shortName ? [shortName utf16Characters] : (const UChar*)"" ),
                ( fullName ? [[fullName xmlSafeString] utf16Characters] : (const UChar*)"" )
              ];
  if ( created )
    [theCGI appendFormatToResponseText:"<created>%S</created>", [[dateFormatter stringFromDate:created] utf16Characters]];
  if ( modified )
    [theCGI appendFormatToResponseText:"<modified>%S</modified>", [[dateFormatter stringFromDate:modified] utf16Characters]];
  if ( lastAuth )
    [theCGI appendFormatToResponseText:"<lastAuth>%S</lastAuth>", [[dateFormatter stringFromDate:lastAuth] utf16Characters]];
  if ( removeAfter )
    [theCGI appendFormatToResponseText:"<removeAfter>%S</removeAfter>", [[dateFormatter stringFromDate:removeAfter] utf16Characters]];
  
  //
  // Lookup collaboration memberships:
  //
#if 0
  SBPostgresQueryResult*    queryResult = [theDatabase executeQuery:[SBString stringWithFormat:
                                                  "SELECT collabId, shortName, description, collaboration.isAdmin(collabId, %lld)"
                                                  "  FROM collaboration.definition"
                                                  "  WHERE collabId IN (SELECT collabId FROM collaboration.member"
                                                  "    WHERE userId = %lld)",
                                                  (long long int)uid,
                                                  (long long int)uid
                                                ]
                                              ];
  SBUInteger                iMax;
  
  if ( queryResult && (iMax = [queryResult numberOfRows]) ) {
    SBUInteger              i = 0;
    
    [theCGI appendStringToResponseText:@"<collaborations>"];
    while ( i < iMax ) {
      SBNumber*         collabId = [queryResult objectForRow:i fieldNum:0];
      SBString*         shortName = [queryResult objectForRow:i fieldNum:1];
      SBString*         description = [queryResult objectForRow:i fieldNum:2];
      SBNumber*         isAdmin = [queryResult objectForRow:i fieldNum:3];
      
      if ( shortName && [shortName length] ) {
        [theCGI appendFormatToResponseText:
                    "<collaboration id=\"%lld\"%s>"
                    "<shortName>%S</shortName>"
                    "<description>%S</description>"
                    "</collaboration>",
                    (long long int)[collabId int64Value],
                    ( [isAdmin boolValue] ? " administrator=\"yes\"" : "" ),
                    [shortName utf16Characters],
                    ( description ? [[description xmlSafeString] utf16Characters] : (const UChar*)"" )
                  ];
      }
      i++;
    }
    [theCGI appendStringToResponseText:@"</collaborations>"];
  }
#else
  SBArray*      collaborations = [SHUEBoxCollaboration collaborationsWithDatabase:theDatabase forUser:theUser];
  SBUInteger    iMax;
  
  if ( collaborations && (iMax = [collaborations count]) ) {
    SBUInteger  i = 0;
    
    [theCGI appendStringToResponseText:@"<collaborations>"];
    while ( i < iMax ) {
      SHUEBoxCollaboration*   collaboration = [collaborations objectAtIndex:i++];
      SBString*               baseURI = [theDatabase stringForFullDictionaryKey:SHUEBoxDictionarySystemBaseURIAuthorityKey];
      
      if ( collaboration ) {
        SBString*             shortName = [collaboration shortName];
        SBString*             description = [collaboration description];
        SBString*             uri = [collaboration uriString];
        
        if ( shortName && [shortName length] ) {
          [theCGI appendFormatToResponseText:
                      "<collaboration id=\"" SBIntegerFormat "\" administrator=\"%s\">"
                      "<shortName>%S</shortName>"
                      "<description>%S</description>"
                      "<baseURI>%S%S</baseURI>"
                      "</collaboration>",
                      [collaboration collabId],
											( [collaboration userIsAdministrator:theUser] ? "yes" : "no" ),
                      [shortName utf16Characters],
                      ( description ? [[description xmlSafeString] utf16Characters] : (const UChar*)"" ),
                      ( baseURI ? [[baseURI xmlSafeString] utf16Characters] : (const UChar*)"" ),
                      ( uri ? [[uri xmlSafeString] utf16Characters] : (const UChar*)"" )
                    ];
        }
      }
    }
    [theCGI appendStringToResponseText:@"</collaborations>"];
  }
#endif
  [theCGI appendStringToResponseText:@"</user>"];
  [theCGI sendResponse];
}

//

void
processUserUpdateRequest(
  id              theDatabase,
  SHUEBoxCGI*     theCGI,
  SHUEBoxUser*    theUser,
	SBXMLElement*		element
)
{
	SBXMLNode*			xmlNode = [element firstChildOfKind:kSBXMLNodeKindElement];
	BOOL            errorEncountered = NO;
  SBString*       oldPassword = nil;
  SBString*       newPassword = nil;
  
	//
	// Let's walk the child nodes:
	//
	while ( xmlNode && ! errorEncountered ) {
		// Element?
		if ( [xmlNode nodeKind] == kSBXMLNodeKindElement ) {
			SBString*		nodeName = [xmlNode nodeName];
			
			element = (SBXMLElement*)xmlNode;
			
			//
			// Full name update?
			//
			if ( [nodeName isEqual:@"fullName"] ) {
				SBString*	newFullName = [element stringForTextContainingNode];
				
				if ( newFullName ) {
					[theUser setFullName:newFullName];
					[SBDefaultLogFile writeFormatToLog:"+ setting full name `%S` for user %lld", [newFullName utf16Characters], [theUser shueboxUserId]];
				}
			}
      
			//
			// Setting a password?
			//
			else if ( [nodeName isEqual:@"newPassword"] && [theUser isGuestUser] ) {
				newPassword = [element stringForTextContainingNode];
      }
      else if ( [nodeName isEqual:@"oldPassword"] && [theUser isGuestUser] ) {
        oldPassword = [element stringForTextContainingNode];
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
          [SBDefaultLogFile writeFormatToLog:"+ setting user removal date to %S", [removalDateString utf16Characters]];
          [theUser setRemovalTimestamp:removeDate];
        } else if ( ok && [theUser removalTimestamp] ) {
          [SBDefaultLogFile writeFormatToLog:"+ clearing user removal date"];
          [theUser setRemovalTimestamp:nil];
        }
      }
		}
		xmlNode = [xmlNode nextSiblingNode];
	}
  
  // Password update indicated?
  if ( newPassword ) {
    if ( oldPassword ) {
      if ( ! [oldPassword isEqual:newPassword] ) {
        // Is the old password correct?
        if ( [theUser authenticateUsingPassword:oldPassword] ) {
          [theUser setPassword:newPassword];
          [SBDefaultLogFile writeFormatToLog:"+ changing password for user %lld", [theUser shueboxUserId]];
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"The existing password you provided was incorrect." forError:nil];
          errorEncountered = YES;
        }
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"You must provide your existing password in order to change your password." forError:nil];
      errorEncountered = YES;
    }
  }
	
  if ( ! errorEncountered ) {
    // Modified?
    if ( [theUser hasBeenModified] ) {
      SBString*       remoteUser = [theCGI remoteUser];
      SBInetAddress*  remoteHost = [theCGI remoteInetAddress];
      
      if ( [theUser commitModifications] ) {
        sendUserDescription(theDatabase, theCGI, theUser);
        [SBDefaultLogFile writeFormatToLog:"changes successful for user %lld [%S|%S]",
            [theUser shueboxUserId],
            ( remoteUser ? [remoteUser utf16Characters] : (UChar*)"" ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      } else {
        [theCGI sendErrorDocument:@"Database error" description:@"An error occurred while attempting to update the user information." forError:nil];
        [SBDefaultLogFile writeFormatToLog:"database update failed for user %lld [%S|%S]",
            [theUser shueboxUserId],
            ( remoteUser ? [remoteUser utf16Characters] : (UChar*)"" ),
            ( remoteHost ? [[remoteHost inetAddressAsString] utf16Characters] : SBUnknownRemoteAddr )
          ];
      }
    } else {
      [theCGI sendErrorDocument:@"Invalid request" description:@"No changes were made to the user information." forError:nil];
    }
  }
}

//

int
main()
{
  SBAutoreleasePool*    pool = [[SBAutoreleasePool alloc] init];
	
#ifdef LOG_DIR
	const char*						logDir = LOG_DIR;
	
	[SBLogger setBaseLoggingPath:[SBString stringWithUTF8String:logDir]];
#endif
	SBDefaultLogFile = [[SBLogger loggerWithFileAtPath:@"userdata.log"] retain];
	
  SBPostgresDatabase*   theDatabase = [[SBPostgresDatabase alloc] initWithConnectionString:SBDefaultDatabaseConnStr];
  
  if ( theDatabase ) {
    SHUEBoxCGI*         theCGI = [[SHUEBoxCGI alloc] initWithDatabase:theDatabase];
    
    if ( theCGI ) {
      switch ( [theCGI target] ) {
      
        case kSHUEBoxCGITargetUserData: {
          SHUEBoxUser*      theUser = [theCGI targetSHUEBoxUser];
          
          if ( theUser ) {
            //
            // What's the request:
            //
            switch ( [theCGI requestMethod] ) {
            
              case kSBHTTPMethodGET: {
                //
                // Send a description of the user:
                //
                sendUserDescription(theDatabase, theCGI, theUser);
                [SBDefaultLogFile writeFormatToLog:"User description sent for `%S` [%S]", [[theUser shortName] utf16Characters], [[[theCGI remoteInetAddress] inetAddressAsString] utf16Characters]];
                break;
              }
              
              case kSBHTTPMethodPOST: {
                SBXMLDocument*		userUpdateDoc = [theCGI xmlDocumentFromStdin];
                
                if ( userUpdateDoc ) {
                  //
                  // Valid document?
                  //
                  if ( [userUpdateDoc isNamedDocument:@"user"] ) {
                    SBXMLElement*	xmlElement = [userUpdateDoc rootElement];
                    SBNumber*     userId = [xmlElement numberAttributeForName:@"id"];
                    BOOL					valid = NO;
                    
                    if ( userId && ([userId int64Value] == [theUser shueboxUserId]) ) {
                      //
                      // Okay, we've validated the incoming XML document.  Now react to its directives:
                      //
                      valid = YES;
                      processUserUpdateRequest(theDatabase, theCGI, theUser, xmlElement);
                    }
                    if ( ! valid )
                      [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a valid `user` document." forError:nil];
                  } else {
                    [theCGI sendErrorDocument:@"Invalid request" description:@"The XML document sent with the request was not a `user` document." forError:nil];
                  }
                } else {
                  [theCGI sendErrorDocument:@"Invalid request" description:@"No XML document was sent with the request." forError:nil];
                }
                break;
              }
              
              default: {
                [theCGI sendErrorDocument:@"Invalid request" description:@"The HTTP request is invalid." forError:nil];
                break;
              }
            }
          } else {
            [theCGI sendErrorDocument:@"Unknown user" description:@"This interface is only accessible by authenticated SHUEBox users." forError:nil];
          }
          break;
        }
        
        case kSHUEBoxCGITargetGuestAccountConfirm: {
          SHUEBoxUser*      theUser = [theCGI targetSHUEBoxUser];
          
          if ( theUser ) {
            //
            // We really don't care what HTTP method was used.
            //
            SBString*       confirmationCode = [theCGI targetConfirmationCode];
            
            if ( confirmationCode && ([confirmationCode length] == 32) ) {
              SBError*      theError = [theUser confirmAccountWithCode:confirmationCode];
              
              if ( theError ) {
                [SBDefaultLogFile writeFormatToLog:"Guest account confirmation failed for user %lld", [theUser shueboxUserId]];
                [theCGI sendErrorDocument:@"Invalid confirmation code" description:@"The provided confirmation code is invalid." forError:theError];              
              } else if ( ! [theUser commitModifications] ) {
                [theCGI sendErrorDocument:@"Database error" description:@"Error while commiting guest confirmation to database." forError:nil];   
              } else {
                //
                // Success!
                //
                SBString*       baseURI = [theDatabase stringForFullDictionaryKey:SHUEBoxDictionarySystemBaseURIAuthorityKey];
                
                [SBDefaultLogFile writeFormatToLog:"Guest account confirmed for user %lld", [theUser shueboxUserId]];
                [theCGI setResponseHeaderValue:@"text/html; charset=utf-8" forName:@"Content-type"];
                [theCGI appendFormatToResponseText:"<html><head><title>Account confirmation successful</title><meta http-equiv=\"refresh\" content=\"0; url=%S\"/></head><body><h1>Account confirmation successful.</h1><h3>Go to the <a href=\"%S\">SHUEBox web console</a>.</h3></body></html>",
                          [baseURI utf16Characters],
                          [baseURI utf16Characters]
                        ];
                [theCGI sendResponse];
              }
            } else {
              [theCGI sendErrorDocument:@"Invalid confirmation code" description:@"The provided confirmation code is invalid." forError:[theCGI lastError]];
            }
          } else {
            [theCGI sendErrorDocument:@"Unknown user" description:@"This interface is only accessible by authenticated SHUEBox users." forError:[theCGI lastError]];
          }
          break;
        }
        
        default: {
          [theCGI sendErrorDocument:@"Invalid request" description:@"The implied request target is not handled by this CGI." forError:[theCGI lastError]];
          break;
        }
        
      }
      [theCGI release];
    }
    [theDatabase release];
  } else {
		[SBDefaultLogFile writeFormatToLog:"Unable to establish connection to database!"];
	}
  
  fflush(stdout);
  [pool release];
  return 0;
}
