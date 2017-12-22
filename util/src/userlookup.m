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
#import "SHUEBox.h"
#import "SHUEBoxUser.h"

#include <errno.h>
#include <getopt.h>

SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";

static struct option cli_options[] = {
               { "shortname",     no_argument,        0,  's' },
               { "userid",        no_argument,        0,  'i' },
               { "id-only",       no_argument,        0,  'I' },
               { 0, 0, 0, 0}
             };

//

typedef enum {
  kUserIdentifierType_ShortName = 0,
  kUserIdentifierType_UserId
} UserIdentifierType;

static UserIdentifierType gUserIdType = kUserIdentifierType_ShortName;

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
      "   --shortname/-s        [identifier] is a SHUEBox shortName\n"
      "   --userid/-i           [identifier] is a SHUEBox userId\n"
      "   --id-only/-I          only display the SHUEBox userId\n"
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
  BOOL                  idOnly = NO;
  
  do {
    int                 opt_idx;
    
    opt_c = getopt_long(argc, argv, "siI", cli_options, &opt_idx);
    
    switch ( opt_c ) {
      
      case 's':
        gUserIdType = kUserIdentifierType_ShortName;
        break;
      
      case 'i':
        gUserIdType = kUserIdentifierType_UserId;
        break;
      
      case 'I':
        idOnly = YES;
        break;
      
    }
  } while ( opt_c != -1 );
  argc -= optind;
  argv += optind;
  
  if ( argc < 1 ) {
    usage(exe);
    return EINVAL;
  }
	
  SBPostgresDatabase*   theDatabase = [[SBPostgresDatabase alloc] initWithConnectionString:SBDefaultDatabaseConnStr];
  
  if ( theDatabase ) {
    SHUEBoxUser*        theUser = nil;
    
    switch ( gUserIdType ) {
    
      case kUserIdentifierType_ShortName:
        theUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase shortName:[SBString stringWithUTF8String:argv[0]]];
        break;
      
      case kUserIdentifierType_UserId: {
        long long int   userId = strtoll(argv[0], NULL, 10);
        
        theUser = [SHUEBoxUser shueboxUserWithDatabase:theDatabase userId:(SHUEBoxUserId)userId];
        break;
      }
      
    }
    if ( theUser ) {
      SHUEBoxUserId     userId = [theUser shueboxUserId];
      
      if ( idOnly ) {
        printf("%lld\n", (long long int)userId);
      } else {
        SBString*       shortName = [theUser shortName];
        SBString*       fullName = [theUser fullName];
        
        printf(
            "%-16lld %-8s %s\n",
            (long long int)userId,
            ( shortName ? (const char*)[shortName utf8Characters] : "<n/a>" ),
            ( fullName ? (const char*)[fullName utf8Characters] : "<n/a>" )
          );
      }
    } else {
      printf("No such user.\n");
      rc = ENOENT;
    }
    [theDatabase release];
  } else {
		fprintf(stderr, "ERROR:  Unable to establish connection to database!");
    rc = EACCES;
	}
  
  fflush(stdout);
  [pool release];
  return rc;
}
