//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxApacheManager.m
//
// Manages interactions with the Apache web server software.
//
// Copyright (c) 2009
// University of Delaware
//
// $Id$
//

#import "SHUEBoxApacheManager.h"
#import "SHUEBoxPathManager.h"
#import "SHUEBoxCollaboration.h"
#import "SBString.h"
#import "SBError.h"
#import "SBDictionary.h"
#import "SBMailer.h"
#import "SBFileManager.h"

enum {
  kSHUEBoxApacheManagerCmdNOP = 0,
  kSHUEBoxApacheManagerCmdRestart,
  kSHUEBoxApacheManagerCmdGracefulRestart
};

@interface SHUEBoxApacheManager(SHUEBoxApacheManagerPrivate)

- (SBError*) doApachectlCommand:(int)command;

@end

@implementation SHUEBoxApacheManager(SHUEBoxApacheManagerPrivate)

  - (SBError*) doApachectlCommand:(int)command
  {
    SBError*      error = nil;
    SBString*     apachectl = [[SHUEBoxPathManager shueboxPathManager] pathForKey:SHUEBoxApachectlPath];
    
    if ( apachectl ) {
      SBSTRING_AS_UTF8_BEGIN(apachectl)
        
        //
        // Test the configuration files before we do anything:
        //
        pid_t     child;
        
        switch ( (child = fork()) ) {
          case 0: {
            int     devNull = open("/dev/null", O_WRONLY);
            
            //
            // Child process -- redirect stdout/stderr and run "apachectl -t"
            //
            dup2(devNull, 1);
            dup2(devNull, 2);
            close(devNull);
            execl(
                apachectl_utf8,
                apachectl_utf8,
                "-t",
                NULL
              );
          }
          default: {
            int     status;
            
            //
            // Wait on config test to finish:
            //
            waitpid(child, &status, 0);
            if ( status != 0 ) {
              error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                code:kSHUEBoxApacheManagerApachectlFailure
                                supportingData:[SBDictionary dictionaryWithObject:
                                    [SBString stringWithFormat:"Apachectl configuration test failed: %d", status] forKey:SBErrorExplanationKey]];
            } else {
              char        *arg1 = NULL, *arg2 = NULL;
              
              //
              // Choose our apachectl command:
              //
              switch ( command ) {
              
                case kSHUEBoxApacheManagerCmdRestart:
                  arg1 = "-k";
                  arg2 = "restart";
                  break;
              
                case kSHUEBoxApacheManagerCmdGracefulRestart:
                  arg1 = "-k";
                  arg2 = "graceful";
                  break;
              
              }
              switch ( (child = fork()) ) {
                case 0: {
                  int     devNull = open("/dev/null", O_WRONLY);
                  
                  //
                  // Child process -- redirect stdout/stderr and run "apachectl -k (restart|graceful)"
                  //
                  dup2(devNull, 1);
                  dup2(devNull, 2);
                  close(devNull);
                  execl(
                      apachectl_utf8,
                      apachectl_utf8,
                      arg1,
                      arg2,
                      NULL
                    );
                }
                default: {
                  int     status;
                  
                  //
                  // Wait on config test to finish:
                  //
                  waitpid(child, &status, 0);
                  if ( status != 0 ) {
                    error = [SBError errorWithDomain:SHUEBoxErrorDomain
                                      code:kSHUEBoxApacheManagerApachectlFailure
                                      supportingData:[SBDictionary dictionaryWithObject:
                                          [SBString stringWithFormat:"Apachectl graceful restart failed: %d", status] forKey:SBErrorExplanationKey]];
                  }
                }
              }
            }
          }
        }
        
      SBSTRING_AS_UTF8_END
    } else {
      error = [SBError errorWithDomain:SHUEBoxErrorDomain
                        code:kSHUEBoxApacheManagerInvalidPath
                        supportingData:[SBDictionary dictionaryWithObject:@"No path to apachectl is available." forKey:SBErrorExplanationKey]];
    }
    if ( error ) {
      //
      // Could be serious, let's send a message to the sysadmins:
      //
      [error emailErrorSummaryWithMailer:[SBMailer sharedMailer]];
    }
    return error;
  }

@end

//
#pragma mark -
//

@implementation SHUEBoxApacheManager

  + (id) shueboxApacheManager
  {
    static SHUEBoxApacheManager* sharedInstance = nil;
    
    if ( sharedInstance == nil ) {
      sharedInstance = [[[SHUEBoxApacheManager alloc] init] retain];
    }
    return sharedInstance;
  }

//

  - (SBError*) writeConfiguration:(SBString*)config
    forCollaboration:(SHUEBoxCollaboration*)collaboration
    isHTTPS:(BOOL)isHTTPS
  {
    SBString*       confPath = [[SHUEBoxPathManager shueboxPathManager] pathForKey:SHUEBoxApacheConfsPath];
    SBError*        result = nil;
    
    if ( confPath ) {
      SBString*     finalConfPath = [SBString stringWithFormat:"%S/%s/%S.conf",
                                            [confPath utf16Characters],
                                            ( isHTTPS ? "https" : "http" ),
                                            [[collaboration shortName] utf16Characters]
                                          ];
      SBString*     tmpConfPath = nil;
      int           confFD = [[SHUEBoxPathManager shueboxPathManager] createTemporaryFile:&tmpConfPath error:&result];
      
      if ( confFD >= 0 ) {
        size_t            bytes = [config utf8Length];
        const char*       utf8 = [config utf8Characters];
        
        if ( write(confFD, utf8, bytes) == bytes ) {
          close(confFD);
          if ( ! [[SBFileManager sharedFileManager] movePath:tmpConfPath toPath:finalConfPath] ) {
            result = [SBError posixErrorWithCode:errno
                          supportingData:[SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Error while renaming temp config file: %S", [tmpConfPath utf16Characters]]
                                forKey:SBErrorExplanationKey
                            ]
                        ];
          }
          // Set owner and group on file:
          if ( ! [[SBFileManager sharedFileManager] setOwnerUId:[self apacheUserId]
                        andGId:[self apacheGroupId]
                        atPath:finalConfPath
                      ]
          ) {
            result = [SBError posixErrorWithCode:errno
                          supportingData:[SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Error while setting ownership of config file: %S", [finalConfPath utf16Characters]]
                                forKey:SBErrorExplanationKey
                            ]
                        ];
          }
        } else {
          result = [SBError posixErrorWithCode:errno
                        supportingData:[SBDictionary dictionaryWithObject:
                              [SBString stringWithFormat:"Error while writing to temp config file: %S", [tmpConfPath utf16Characters]]
                              forKey:SBErrorExplanationKey
                          ]
                      ];
        }
      }
      // createTemporaryFile:error: will have set result for us if it failed
    } else {
      result = [SBError errorWithDomain:SHUEBoxErrorDomain
                        code:kSHUEBoxApacheManagerInvalidPath
                        supportingData:[SBDictionary dictionaryWithObject:@"No path to the Apache per-collaboration configurations is available." forKey:SBErrorExplanationKey]];
    }
    return result;
  }

//

  - (SBError*) removeConfigurationForCollaboration:(SHUEBoxCollaboration*)collaboration
    isHTTPS:(BOOL)isHTTPS
  {
    SBString*       confPath = [[SHUEBoxPathManager shueboxPathManager] pathForKey:SHUEBoxApacheConfsPath];
    SBError*        result = nil;
    
    if ( confPath ) {
      SBString*     finalConfPath = [SBString stringWithFormat:"%S/%s/%S.conf",
                                            [confPath utf16Characters],
                                            ( isHTTPS ? "https" : "http" ),
                                            [[collaboration shortName] utf16Characters]
                                          ];
      
      if ( [[SBFileManager sharedFileManager] fileExistsAtPath:finalConfPath] ) {
        if ( ! [[SBFileManager sharedFileManager] removeItemAtPath:finalConfPath] ) {
          result = [SBError errorWithDomain:SHUEBoxErrorDomain
                            code:kSHUEBoxApacheManagerConfigFileFailure
                            supportingData:[SBDictionary dictionaryWithObject:
                                [SBString stringWithFormat:"Unable to delete Apache %s configuration for `%S`.", ( isHTTPS ? "https" : "http" ), [[collaboration shortName] utf16Characters]]
                                forKey:SBErrorExplanationKey]
                        ];
        }
      } else {
        result = [SBError errorWithDomain:SHUEBoxErrorDomain
                          code:kSHUEBoxApacheManagerConfigFileFailure
                          supportingData:[SBDictionary dictionaryWithObject:
                              [SBString stringWithFormat:"No Apache %s configuration available for `%S`.", ( isHTTPS ? "https" : "http" ), [[collaboration shortName] utf16Characters]]
                              forKey:SBErrorExplanationKey]
                      ];
      }
    } else {
      result = [SBError errorWithDomain:SHUEBoxErrorDomain
                        code:kSHUEBoxApacheManagerInvalidPath
                        supportingData:[SBDictionary dictionaryWithObject:@"No path to the Apache per-collaboration configurations is available." forKey:SBErrorExplanationKey]];
    }
    return result;
  }

//

  - (SBError*) hardRestart
  {
    if ( _delayRestarts ) {
      _restart = kSHUEBoxApacheManagerCmdRestart;
      return nil;
    }
    _restart = kSHUEBoxApacheManagerCmdNOP;
    return [self doApachectlCommand:kSHUEBoxApacheManagerCmdRestart];
  }

//

  - (SBError*) gracefulRestart
  {
    if ( _delayRestarts ) {
      _restart = kSHUEBoxApacheManagerCmdGracefulRestart;
      return nil;
    }
    _restart = kSHUEBoxApacheManagerCmdNOP;
    return [self doApachectlCommand:kSHUEBoxApacheManagerCmdGracefulRestart];
  }

//

  - (uid_t) apacheUserId
  {
    struct passwd*    uWebservd = getpwnam("webservd");
    
    if ( uWebservd )
      return uWebservd->pw_uid;
    return 0;
  }
  
//

  - (gid_t) apacheGroupId
  {
    struct group*     gWebservd = getgrnam("webservd");
    
    if ( gWebservd )
      return gWebservd->gr_gid;
    return 0;
  }

//

  - (BOOL) delayRestarts { return _delayRestarts; }
  - (void) setDelayRestarts:(BOOL)delayRestarts
  {
    if ( ! (_delayRestarts = delayRestarts) ) {
      switch ( _restart ) {
        
        case kSHUEBoxApacheManagerCmdRestart:
          [self hardRestart];
          break;
        
        case kSHUEBoxApacheManagerCmdGracefulRestart:
          [self gracefulRestart];
          break;
        
      }
    }
  }

@end
