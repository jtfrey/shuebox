//
// SHUEBox CGIs : CGI programs for SHUEBox's web interfaces
// login.m
//
// Simple authentication helper, sets cookie if authentication succeeds.
//
// $Id$
//

#import "SBFoundation.h"
#import "SBPostgres.h"
#import "SBHTTPCookie.h"
#import "SHUEBox.h"
#import "SHUEBoxCGI.h"
#import "SHUEBoxAuthCookie.h"
#import "SHUEBoxUser.h"
#import "SHUEBoxCollaboration.h"
#import "SHUEBoxDictionary.h"

SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";

SBLogger* SBDefaultLogFile = nil;

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
                ( [theUser isGuestUser] ? "" : " native=\"yes\"" ),
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
      SBString*               baseURI = [theDatabase stringForFullDictionaryKey:@"system:base-uri-authority"];
      
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
	SBDefaultLogFile = [[SBLogger loggerWithFileAtPath:@"login.log"] retain];
	
  SBPostgresDatabase*   theDatabase = [[SBPostgresDatabase alloc] initWithConnectionString:SBDefaultDatabaseConnStr];
  
  if ( theDatabase ) {
    SHUEBoxCGI*         theCGI = [[SHUEBoxCGI alloc] initWithDatabase:theDatabase];
    
    if ( theCGI ) {
      SHUEBoxCGITarget  theTarget = [theCGI target];
      SBError*          theError = [theCGI lastError];
      
      if ( theError ) {
        [theCGI sendErrorDocument:@"Invalid request" description:@"The request could not be interpreted by this CGI." forError:theError];
      } else if ( theTarget != kSHUEBoxCGITargetLoginHelper ) {
        [theCGI sendErrorDocument:@"Invalid request" description:@"The implied request target is not handled by this CGI." forError:nil];
      } else {
        //
        // There need to be a "u" and "p" CGI parameter for this to work:
        //
        SBString*     uname = [theCGI queryArgumentForKey:@"u"];
        SBString*     password = [theCGI queryArgumentForKey:@"p"];
        char*         remoteAddr = getenv("REMOTE_ADDR");
        
        if ( uname && [uname length] && remoteAddr ) {
          SHUEBoxUser*  targetUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase shortName:uname];
          
          if ( targetUser ) {
            if ( [targetUser authenticateUsingPassword:password] ) {
              [SBDefaultLogFile writeFormatToLog:"Authentication succeeded:  %S [%s]", [uname utf16Characters], ( remoteAddr ? remoteAddr : "?.?.?.?" )];
              
              // Set our auth cookie:
              SHUEBoxAuthCookie*    cookie = [[SHUEBoxAuthCookie alloc] initWithUser:targetUser inetAddress:[SBInetAddress inetAddressWithCString:remoteAddr]];
              
              [theCGI setResponseHeaderValue:[cookie asString] forName:@"Set-Cookie"];
              sendUserDescription(theDatabase, theCGI, targetUser);
              [theCGI sendResponse];
            } else {
              [theCGI sendErrorDocument:@"Authentication failed" description:@"The provided password was incorrect." forError:nil];
              [SBDefaultLogFile writeFormatToLog:"Authentication failure:  %S [%s]", [uname utf16Characters], ( remoteAddr ? remoteAddr : "?.?.?.?" )];
            }
          } else {
            [theCGI sendErrorDocument:@"Invalid request" description:@"User not registered with SHUEBox." forError:nil];
            [SBDefaultLogFile writeFormatToLog:"Unrecognized user id:  %S [%s]", [uname utf16Characters], ( remoteAddr ? remoteAddr : "?.?.?.?" )];
          }
        } else {
          [theCGI sendErrorDocument:@"Invalid request" description:@"A username is required." forError:nil];
        }
      }
      [theCGI release];
    } else {
      printf(
          "Content-type: text/xml\r\n\r\n"
          "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
          "<error><title>Invalid request</title><description>There was no request.</description></error>\n"
        );
    }
    [theDatabase release];
  } else {
		[SBDefaultLogFile writeFormatToLog:"Unable to establish connection to database!"];
	}
  
  fflush(stdout);
  [pool release];
  return 0;
}
