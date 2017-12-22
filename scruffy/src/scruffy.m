//
// scruffy : maintenance scheduler daemon for SHUEBox
// scruffy
//
// Main scheduling/responding daemon.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SBFoundation.h"
#import "SBPostgres.h"
#import "SBMailer.h"
#import "SBMaintenancePeriods.h"
#import "SBMaintenanceTaskManager.h"
#import "SBMaintenanceTask.h"
#import "SBPIDFile.h"
#import "SBLogger.h"

static const SBString* SBDefaultDatabaseConnStr = @"user=postgres dbname=shuebox";
static const SBString* SBDefaultDatabaseSchema = @"maintenance";
static const SBString* SBDefaultPrefix = @"/opt/local/SHUEBox/scruffy";

#ifndef RUN_DIR
#define RUN_DIR "/var/run"
#endif

static SBString* SBDefaultPIDFile = @RUN_DIR"/scruffy.pid";

static SBMaintenanceTaskManager*  SBTaskManager = nil;
static SBMaintenanceTask*         SBSingletonTask = nil;

//
#pragma mark -
//

static struct option SBScruffyCLIOptions[] = {
                                               { "help",          no_argument,            NULL,           'h' },
                                               { "db-conn-str",   required_argument,      NULL,           'c' },
                                               { "schema",        required_argument,      NULL,           's' },
                                               { "prefix",        required_argument,      NULL,           'p' },
                                               { "task",          required_argument,      NULL,           't' },
                                               { "uid",           required_argument,      NULL,           'u' },
                                               { "gid",           required_argument,      NULL,           'g' },
                                               { NULL,            0,                      NULL,            0  }
                                             };

//

void
__signalHandler(
  int sigmask
)
{
#ifdef SOLARIS
  signal(sigmask, __signalHandler);
#endif
  switch ( sigmask ) {
    
    case SIGINT:
      [[SBRunLoop currentRunLoop] setEarlyExit:YES];
      if ( SBTaskManager )
        [SBTaskManager setIsRunning:NO]; 
      break;
      
    case SIGHUP:
      if ( SBTaskManager ) {
        [[SBRunLoop currentRunLoop] setEarlyExit:YES];
        [SBTaskManager setIsRunning:NO];
      }
      break;
      
  }
}

//

void
usage(
  const char*   program
)
{
  fprintf(stderr,
      "usage:\n\n"
      "  %s <options>\n\n"
      " options:\n\n"
      "  -h/--help                  This information\n"
      "  -c/--db-conn-str           Postgres database connection string\n"
      "                               default: %s\n"
      "  -s/--schema                Postgres schema containing the task and period tables\n"
      "                               default: %s\n"
      "  -p/--prefix                Base path for the scruffy per-task directories\n"
      "                               default: %s\n"
      "  -u/--uid                   Specify a user name or number to run as\n"
      "  -g/--gid                   Specify a group name or number to run as\n\n"
      ,
      program,
      [SBDefaultDatabaseConnStr utf8Characters],
      [SBDefaultDatabaseSchema utf8Characters],
      [SBDefaultPrefix utf8Characters]
    );
}

//

int
main(
  int             argc,
  char*           argv[]
)
{
  int                     rc = 0;
  const char*             program = (const char*)argv[0];
  SBPostgresDatabase*     database = nil;
  const char*             prefix = NULL;
  const char*             connStr = NULL;
  const char*             schema = NULL;
  const char*             taskKey = NULL;
  uid_t                   runAsUID = -1;
  gid_t                   runAsGID = -1;
  SBArray*                schemaList = nil;
  SBAutoreleasePool*      ourPool = [[SBAutoreleasePool alloc] init];
  int                     optCh;

  while ( (optCh = getopt_long(argc,argv,"hc:s:p:t:u:g:",SBScruffyCLIOptions,NULL)) != -1 ) {
    switch ( optCh ) {
    
      case 'h':
        usage(program);
        exit(0);
        break;
      
      case 'c':
        connStr = optarg;
        break;
      
      case 's':
        schema = optarg;
        break;
      
      case 'p':
        prefix = optarg;
        break;
      
      case 't':
        taskKey = optarg;
        break;
      
      case 'u': {
        runAsUID = strtol(optarg, NULL, 10);
        switch ( errno ) {
          case EINVAL:
          case ERANGE: {
            struct passwd*    userRec = getpwnam(optarg);
            
            runAsUID = ( userRec ? userRec->pw_uid : -1 );
            break;
          }
        }
        break;
      }
      
      case 'g': {
        runAsGID = strtol(optarg, NULL, 10);
        switch ( errno ) {
          case EINVAL:
          case ERANGE: {
            struct group*     groupRec = getgrnam(optarg);
            
            runAsGID = ( groupRec ? groupRec->gr_gid : -1 );
            break;
          }
        }
        break;
      }
      
    }
  }
  argc -= optind;
  argv += optind;
  
  // Run as someone else?
  if ( runAsGID != -1 ) {
    if ( setgid( runAsGID ) ) {
      fprintf(stderr, "[%d] ERROR:  Could not run as group id = %d\n", getpid(), runAsGID);
      exit(EPERM);
    }
  }
  if ( runAsUID != -1 ) {
    if ( setuid( runAsUID ) ) {
      fprintf(stderr, "[%d] ERROR:  Could not run as user id = %d\n", getpid(), runAsUID);
      exit(EPERM);
    }
  }
	
	//
	// Set default logging location if applicable:
	//
#ifdef LOG_DIR
	char*				logDir = LOG_DIR;
	
	[SBLogger setBaseLoggingPath:[SBString stringWithUTF8String:logDir]];
#endif
  
  //
  // Try to get a PID file:
  //
  if ( ! SBAcquirePIDFile(SBDefaultPIDFile) ) {
    fprintf(stderr, "ERROR:  Could not acquire PID file!\n");
    exit(EPERM);
  }
  
  //
  // Setup the schema search array:
  //
  if ( ! schema ) {
    schemaList = [SBArray arrayWithObjects:SBDefaultDatabaseSchema, nil];
  } else {
    schemaList = [[SBString stringWithUTF8String:schema] componentsSeparatedByString:@":"];
  }
  
  signal(SIGINT, __signalHandler);
  signal(SIGHUP, __signalHandler);
  
  //
  // Get the default SBMailer stuff setup:
  //
  SBMailer*     defaultMailer = [SBMailer sharedMailer];
  
  [defaultMailer setDefaultSMTPSender:@"\"Scruffy (SHUEBox Maintenance Daemon)\" <scruffy@shuebox.nss.udel.edu>"];
  [defaultMailer setDefaultSMTPRecipient:@"nss-ts-req@udel.edu"];

  //
  // Connect to database:
  //
  database = [[SBPostgresDatabase alloc] 
                  initWithConnectionString:( connStr ? (SBString*)[SBString stringWithUTF8String:connStr] : (SBString*)SBDefaultDatabaseConnStr )
                  searchSchema:schemaList
                ];
  if ( database ) {
    [database scheduleNotificationInRunLoop:[SBRunLoop currentRunLoop]];
    if ( taskKey ) {
      //
      // Attempt to start a specific maintenance task's handler:
      //
      SBSingletonTask = [SBMaintenanceTask maintenanceTaskWithDatabase:database taskKey:[SBString stringWithUTF8String:taskKey]];
      
      if ( SBSingletonTask ) {
        SBSingletonTask = [SBSingletonTask retain];
        
        // Clean-out the autorelease pool:
        [ourPool release];
        ourPool = [[SBAutoreleasePool alloc] init];
        
        // Give the runloop some time:
        [[SBRunLoop currentRunLoop] run];
        
        [SBSingletonTask invalidateTaskTimer];
        [SBSingletonTask release];
      } else {
        fprintf(stderr, "ERROR: unable to initialize task with key '%s'\n", taskKey);
        rc = EINVAL;
      }
    } else {
      SBTaskManager = [SBMaintenanceTaskManager maintenanceTaskManagerWithDatabase:database];
      if ( SBTaskManager ) {
        SBTaskManager = [SBTaskManager retain];
        
        // Clean-out the autorelease pool:
        [ourPool release];
        ourPool = [[SBAutoreleasePool alloc] init];
        
        // Enter the runloop:
        [SBTaskManager enterTaskManagerRunloop];
        
        // All done:
        [SBTaskManager release];
      }
    }
    
    //
    // Drop the database connection:
    //
    [database removeNotificationFromRunLoop:[SBRunLoop currentRunLoop]];
    [database release];
  } else {
    fprintf(stderr, "ERROR: unable to open database: %s\n", ( connStr ? connStr : (const char*)[SBDefaultDatabaseConnStr utf8Characters] ));
    rc = EPERM;
  }
  
  //
  // Done with the PID file:
  //
  SBDropPIDFile(SBDefaultPIDFile);
  
  //
  // One last chance to clear autoreleased junk:
  //
  [ourPool release];
  
  return 0;
}

