//
// SHUEBox CGIs : CGI programs for SHUEBox's web interfaces
// useradd-native.m
//
// Add a UDelNetId to the system if not already present.
//
// $Id$
//

#import "SBFoundation.h"
#import "SBPostgres.h"
#import "SBLDAP.h"
#import "SBUDUser.h"
#import "SHUEBox.h"
#import "SHUEBoxUser.h"

#include <errno.h>
#include <getopt.h>

SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";

SBLogger* SBDefaultLogFile = nil;

static struct option cli_options[] = {
               { "udelnetid",     no_argument,        0,  'u' },
               { "emplid",        no_argument,        0,  'e' },
               { "nssid",         no_argument,        0,  'n' },
               { 0, 0, 0, 0}
             };

//

typedef enum {
  kUserIdentifierType_UDelNetId = 0,
  kUserIdentifierType_EmplId,
  kUserIdentifierType_NSSId
} UserIdentifierType;

static UserIdentifierType gUserIdType = kUserIdentifierType_UDelNetId;

//

void
usage(
  const char*   exe
)
{
  printf(
      "usage:\n\n"
      "  %s {options} [identifier]\n\n"
      " options:\n\n"
      "   --udelnetid/-u        [identifier] is a UDelNetId\n"
      "   --emplid/-e           [identifier] is a UDID (emplid)\n"
      "   --nssid/-n            [identifier] is an nssid\n"
      "\n",
      exe
    );
}

//

int
main(
  int         argc,
  char*       argv[]
)
{
  SBAutoreleasePool*    pool = [[SBAutoreleasePool alloc] init];
  const char*           exe = argv[0];
	int                   opt_c, rc = 0;
  
  do {
    int                 opt_idx;
    
    opt_c = getopt_long(argc, argv, "uen", cli_options, &opt_idx);
    
    switch ( opt_c ) {
      
      case 'u':
        gUserIdType = kUserIdentifierType_UDelNetId;
        break;
      
      case 'e':
        gUserIdType = kUserIdentifierType_EmplId;
        break;
      
      case 'n':
        gUserIdType = kUserIdentifierType_NSSId;
        break;
      
    }
  } while ( opt_c != -1 );
  argc -= optind;
  argv += optind;
  
  if ( argc < 1 ) {
    usage(exe);
    return EINVAL;
  }
  
#ifdef LOG_DIR
	const char*						logDir = LOG_DIR;
	
	[SBLogger setBaseLoggingPath:[SBString stringWithUTF8String:logDir]];
#endif
	SBDefaultLogFile = [[SBLogger loggerWithFileAtPath:@"useradd-native.log"] retain];
	
  SBPostgresDatabase*   theDatabase = [[SBPostgresDatabase alloc] initWithConnectionString:SBDefaultDatabaseConnStr];
  
  if ( theDatabase ) {
    SBString*           userIdStr = [SBString stringWithUTF8String:argv[0]];
    SHUEBoxUser*        theUser = nil;
    SBUDUser*           nativeUser = nil;
    SBString*           udelNetId = nil;
    BOOL                wasAdded = NO;
    
    if ( gUserIdType == kUserIdentifierType_UDelNetId ) {
      udelNetId = userIdStr;
      theUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase shortName:userIdStr];
      if ( ! theUser ) {
        nativeUser = [SBUDUser udUserWithUserIdentifier:userIdStr];
        if ( ! nativeUser ) {
          fprintf(stderr, "ERROR:  could not find user with provided credentials\n");
          rc = EINVAL;
        }
      }
    } else {
      switch ( gUserIdType ) {
      
        case kUserIdentifierType_EmplId:
          nativeUser = [SBUDUser udUserWithEmplid:userIdStr];
          break;
        
        case kUserIdentifierType_NSSId:
          nativeUser = [SBUDUser udUserWithNSSId:userIdStr];
          break;
      
      }
      if ( nativeUser ) {
        // Grab the UDelNetId and lookup the user in SHUEBox:
        if ( (udelNetId = [nativeUser userPropertyForKey:SBUserIdentifierKey]) ) {
          theUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase shortName:udelNetId];
        } else {
          fprintf(stderr, "ERROR:  no UDelNetId for user: id = %s\n", argv[0]);
          rc = EINVAL;
        }
      } else {
        fprintf(stderr, "ERROR:  could not find user with provided credentials\n");
        rc = EINVAL;
      }
    }
    if ( ! theUser && nativeUser ) {
      SBString*               emplId = [nativeUser userPropertyForKey:SBUDUserEmplidKey];
      
      if ( emplId ) {
        // Start a transaction block:
        if ( [theDatabase beginTransaction] ) {
          SBPostgresQuery*    insertQuery = [[SBPostgresQuery alloc] initWithQueryString:
                                                    @"INSERT INTO users.base (native, shortName, fullName) VALUES (true, $1, $2);"
                                                    parameterCount:2
                                                  ];
          
          if ( insertQuery ) {
            BOOL                ok;
            
            ok = [insertQuery bindObject:udelNetId toParameter:1];
            ok = ok && [insertQuery bindObject:[nativeUser userPropertyForKey:@"cn"] toParameter:2];
            ok = ok && [theDatabase executeQueryWithBooleanResult:insertQuery];
            [insertQuery release];
            if ( ok ) {
              insertQuery = [[SBPostgresQuery alloc] initWithQueryString:
                                    @"INSERT INTO users.native (userId, emplId) VALUES ((SELECT userId FROM users.base WHERE shortName = $1), $2)"
                                    parameterCount:2
                                  ];
              if ( insertQuery ) {
                ok = [insertQuery bindObject:udelNetId toParameter:1];
                ok = ok && [insertQuery bindObject:emplId toParameter:2];
                ok = ok && [theDatabase executeQueryWithBooleanResult:insertQuery];
                [insertQuery release];
                ok = ok && [theDatabase commitLastTransaction];
                if ( ok ) {
                  theUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase shortName:udelNetId];
                  wasAdded = YES;
                }
              } else {
                ok = NO;
              }
            }
            if ( ! ok ) {
              [theDatabase discardLastTransaction];
              fprintf(stderr, "ERROR:  Unable to add user to database\n");
              rc = EINVAL;
            }
          }
        }
      } else {
        fprintf(stderr, "ERROR:  No emplid for user\n");
        rc = EINVAL;
      }
    }
    if ( theUser ) {
      SHUEBoxUserId     userId = [theUser shueboxUserId];
      SBString*         shortName = [theUser shortName];
      SBString*         fullName = [theUser fullName];
      
      if ( wasAdded ) {
        [SBDefaultLogFile writeFormatToLog:"Added native user to SHUEBox: %s (userId = %lld) %s",
                                ( shortName ? (const char*)[shortName utf8Characters] : "<n/a>" ),
                                (long long int)userId,
                                ( fullName ? (const char*)[fullName utf8Characters] : "<n/a>" )
                              ];
      }
      printf(
          "%-16lld %-8s %s\n",
          (long long int)userId,
          ( shortName ? (const char*)[shortName utf8Characters] : "<n/a>" ),
          ( fullName ? (const char*)[fullName utf8Characters] : "<n/a>" )
        );
    }
    [theDatabase release];
  } else {
		fprintf(stderr, "Unable to establish connection to database!");
    rc = EACCES;
	}
  
  fflush(stdout);
  [pool release];
  return rc;
}
