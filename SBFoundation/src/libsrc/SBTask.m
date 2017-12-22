//
// SBFoundation : ObjC Class Library for Solaris
// SBTask.m
//
// Class which launches child processes and interacts with them.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBTask.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBNotification.h"
#import "SBException.h"
#import "SBFileHandle.h"
#import "SBMemoryPool.h"

#include <signal.h>

extern char**       environ;

SBString* SBTaskDidTerminateNotification = @"SBTaskDidTerminateNotification";
SBString* SBInvalidArgumentException = @"SBInvalidArgumentException";

enum {
  kSBTaskStateConfiguring = 0,
  kSBTaskStateRunning,
  kSBTaskStateSuspended,
  kSBTaskStateCompleted
};

@implementation SBTask

  + (SBTask*) launchedTaskWithLaunchPath:(SBString*)path
    arguments:(SBArray*)arguments
  {
    SBTask*     newTask = [[SBTask alloc] init];
    
    if ( newTask ) {
      [newTask setLaunchPath:path];
      [newTask setArguments:arguments];
      [newTask launch];
      newTask = [newTask autorelease];
    }
    return newTask;
  }
  
//

  - (id) init
  {
    return [super init];
  }

//

  - (void) dealloc
  {
    if ( _launchPath ) [_launchPath release];
    if ( _arguments ) [_arguments release];
    if ( _environment ) [_environment release];
    if ( _currentDirectoryPath ) [_currentDirectoryPath release];
    
    if ( _ioStreams[0] ) [_ioStreams[0] release];
    if ( _ioStreams[1] ) [_ioStreams[1] release];
    if ( _ioStreams[2] ) [_ioStreams[2] release];
    
    [super dealloc];
  }

//

  - (SBString*) launchPath
  {
    return _launchPath;
  }
  - (void) setLaunchPath:(SBString*)launchPath
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( launchPath ) launchPath = [launchPath copy];
      if ( _launchPath ) [_launchPath release];
      _launchPath = launchPath;
    }
  }

//

  - (SBArray*) arguments
  {
    return _arguments;
  }
  - (void) setArguments:(SBArray*)arguments
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( arguments ) arguments = [arguments retain];
      if ( _arguments ) [_arguments release];
      _arguments = arguments;
    }
  }

//

  - (SBDictionary*) environment;
  {
    return _environment;
  }
  - (void) setEnvironment:(SBDictionary*)environment
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( environment ) environment = [environment retain];
      if ( _environment ) [_environment release];
      _environment = environment;
    }
  }
  
//

  - (SBString*) currentDirectoryPath
  {
    return _currentDirectoryPath;
  }
  - (void) setCurrentDirectoryPath:(SBString*)currentDirectoryPath
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( currentDirectoryPath ) currentDirectoryPath = [currentDirectoryPath copy];
      if ( _currentDirectoryPath ) [_currentDirectoryPath release];
      _currentDirectoryPath = currentDirectoryPath;
    }
  }

//

  - (id) standardError
  {
    return _ioStreams[2];
  }
  - (void) setStandardError:(id)standardError
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( standardError ) standardError = [standardError retain];
      if ( _ioStreams[2] ) [_ioStreams[2] release];
      _ioStreams[2] = standardError;
    }
  }
  - (id) standardOutput
  {
    return _ioStreams[1];
  }
  - (void) setStandardOutput:(id)standardOutput
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( standardOutput ) standardOutput = [standardOutput retain];
      if ( _ioStreams[1] ) [_ioStreams[1] release];
      _ioStreams[1] = standardOutput;
    }
  }
  - (id) standardInput
  {
    return _ioStreams[0];
  }
  - (void) setStandardInput:(id)standardInput
  {
    if ( _state == kSBTaskStateConfiguring ) {
      if ( standardInput ) standardInput = [standardInput retain];
      if ( _ioStreams[0] ) [_ioStreams[0] release];
      _ioStreams[0] = standardInput;
    }
  }

//

  - (BOOL) launchWithMinimalEnvironment
  {
    return _launchWithMinimalEnvironment;
  }
  - (void) setLaunchWithMinimalEnvironment:(BOOL)launchWithMinimalEnvironment
  {
    if ( _state == kSBTaskStateConfiguring ) {
      _launchWithMinimalEnvironment = launchWithMinimalEnvironment;
    }
  }

//

  - (BOOL) isRunning
  {
    return ( _state == kSBTaskStateRunning ? YES : NO );
  }
  
//

  - (int) terminationStatus
  {
    return _terminationStatus;
  }
  - (SBTaskTerminationReason) terminationReason
  {
    return _terminationReason;
  }
  
//

  - (void) launch
  {
    if ( _state == kSBTaskStateConfiguring ) {
      // We're okay to run.  Prep the command path and argument array:
      int       rc = 0;
      
      if ( ! _launchPath )
        [SBException raise:SBInvalidArgumentException format:"Attempted to launch an SBTask with a nil launchPath."];
      
      const char*   launchPath = [_launchPath utf8Characters];
      
      if ( ! launchPath || ! *launchPath )
        [SBException raise:SBInvalidArgumentException format:"Attempted to launch an SBTask with a null launchPath."];
      
      SBUInteger    i, j, argc = ( _arguments ? [_arguments count] : 0 );
      const char**  argv = objc_malloc((2 + argc) * sizeof(const char*));
      
      if ( ! argv )
        [SBException raise:SBInvalidArgumentException format:"Unable to allocate argument list in SBTask."];
      
      argv[0] = launchPath;
      i = 0; j = 1;
      while ( i < argc ) {
        SBString*     arg = [_arguments objectAtIndex:i++];
        
        if ( arg && [arg isKindOf:[SBString class]] ) {
          if ( (argv[j] = [arg utf8Characters]) )
            j++;
        }
      }
      argv[j] = NULL;
      
      //
      // Setup environment variables; we'll use a memory pool to avoid repeated allocations via the
      // system mem mgmt routines and just dump it as soon as we've fork()'ed off the child
      // process.
      //
      SBMemoryPoolRef     mempool = NULL; 
      SBUInteger          envc = ( _environment ? [_environment count] : 0 );
      char**              curEnv = environ;
      char**              envp = NULL;
      
      if ( ! _launchWithMinimalEnvironment ) {
        while ( *curEnv ) {
          envc++;
          curEnv++;
        }
        if ( envc > 0 ) {
          if ( ! (mempool = SBMemoryPoolCreate(0)) )
            [SBException raise:SBInvalidArgumentException format:"Unable to create environment memory pool."];
          
          SBUInteger        envIdx = 0;
          
          if ( ! (envp = (char**)SBMemoryPoolAlloc(mempool, sizeof(char*) * envc)) )
            [SBException raise:SBInvalidArgumentException format:"Unable to create environment array."];
            
          //
          // Merge current environment into the task environment:
          //
          curEnv = environ;
          while ( *curEnv ) {
            envp[envIdx] = SBMemoryPoolAlloc(mempool, strlen(*curEnv) + 1);
            strcpy(envp[envIdx++], *curEnv++);
          }
          
          //
          // Now the variables from the receiver:
          //
          if ( _environment && [_environment count] ) {
            SBEnumerator*       eKey = [_environment keyEnumerator];
            SBString*           key;
            
            while ( (key = [eKey nextObject]) ) {
              if ( [key isKindOf:[SBString class]] ) {
                SBString*       value = [_environment objectForKey:key];
                
                if ( [value isKindOf:[SBString class]] ) {
                  SBUInteger    keyLen = [key utf8Length];
                  SBUInteger    valueLen = [value utf8Length];
                  
                  envp[envIdx] = SBMemoryPoolAlloc(mempool, keyLen + valueLen + 2);
                  [key copyUTF8CharactersToBuffer:envp[envIdx] length:keyLen];
                  (envp[envIdx])[keyLen] = '=';
                  [value copyUTF8CharactersToBuffer:envp[envIdx] + keyLen + 1 length:valueLen];
                  (envp[envIdx++])[keyLen + 1 + valueLen] = '\0';
                }
              }
            }
          }
        }
      }
      
      //
      // Fixup the stdio descriptors:
      //
      int             ifd = -1, ofd = -1, efd = -1;
      SBFileHandle*   fdsToClose[3];
      int             fdsToCloseCount = 0;
      
      if ( _ioStreams[0] ) {
        // stdin
        if ( [_ioStreams[0] isKindOf:[SBPipe class]] ) {
          fdsToClose[fdsToCloseCount] = [_ioStreams[0] fileHandleForReading];
          ifd = [fdsToClose[fdsToCloseCount++] fileDescriptor];
        } else if ( [_ioStreams[0] isKindOf:[SBFileHandle class]] && [_ioStreams[0] isReadable] ) {
          ifd = [_ioStreams[0] fileDescriptor];
        }
      }
      if ( _ioStreams[1] ) {
        // stdout
        if ( [_ioStreams[1] isKindOf:[SBPipe class]] ) {
          fdsToClose[fdsToCloseCount] = [_ioStreams[1] fileHandleForWriting];
          ofd = [fdsToClose[fdsToCloseCount++] fileDescriptor];
        } else if ( [_ioStreams[1] isKindOf:[SBFileHandle class]] && [_ioStreams[1] isWritable] ) {
          ofd = [_ioStreams[1] fileDescriptor];
        }
      }
      if ( _ioStreams[2] ) {
        // stderr
        if ( [_ioStreams[2] isKindOf:[SBPipe class]] ) {
          fdsToClose[fdsToCloseCount] = [_ioStreams[2] fileHandleForWriting];
          efd = [fdsToClose[fdsToCloseCount++] fileDescriptor];
        } else if ( [_ioStreams[2] isKindOf:[SBFileHandle class]] && [_ioStreams[2] isWritable] ) {
          efd = [_ioStreams[2] fileDescriptor];
        }
      }
      _processIdentifier = fork();
      if ( _processIdentifier == 0 ) {
        //
        // Child process:
        //
        if ( ifd != -1 && ifd != 0 )
          dup2(ifd, 0);
        if ( ofd != -1 && ofd != 1 )
          dup2(ofd, 1);
        if ( efd != -1 && efd != 2 )
          dup2(efd, 2);
        
        // Now run the program:
        rc = execve(launchPath, (char* const*)argv, (char* const*)envp);
        // Should only get here if execve() fails!
        _state = kSBTaskStateCompleted;
        _processIdentifier = 0;
        _terminationStatus = errno;
        _terminationReason = kSBTaskTerminationReasonExit;
      } else if ( _processIdentifier == -1 ) {
        _state = kSBTaskStateCompleted;
        _processIdentifier = 0;
        _terminationStatus = errno;
        _terminationReason = kSBTaskTerminationReasonExit;
      } else {
        _state = kSBTaskStateRunning;
      
        // Close any pipe-ends we shouldn't have open:
        while ( fdsToCloseCount-- )
          [fdsToClose[fdsToCloseCount] closeFile];
      }
      
      // Drop that memory pool:
      if ( mempool )
        SBMemoryPoolRelease(mempool);
    } else if ( _state == kSBTaskStateCompleted ) {
      [SBException raise:SBInvalidArgumentException format:"Attempted to launch an SBTask that has completed running."];
    } else {
      [SBException raise:SBInvalidArgumentException format:"Attempted to launch an SBTask that is already running."];
    }
  }
  
//

  - (void) interrupt
  {
    if ( _state == kSBTaskStateRunning ) {
      if ( kill(_processIdentifier, SIGINT) == 0 ) {
        _state = kSBTaskStateCompleted;
      } else {
        if ( errno == ESRCH ) {
          _state = kSBTaskStateCompleted;
          _processIdentifier = 0;
        }
      }
    }
  }
  - (BOOL) resume
  {
    if ( _state == kSBTaskStateSuspended ) {
      if ( --_suspendCount == 0 ) {
        if ( kill(_processIdentifier, SIGCONT) == 0 ) {
          _state = kSBTaskStateRunning;
          return YES;
        } else {
          if ( errno == ESRCH ) {
            _state = kSBTaskStateCompleted;
            _processIdentifier = 0;
          }
        }
      }
    }
    return NO;
  }
  - (BOOL) suspend
  {
    if ( _state == kSBTaskStateRunning ) {
      if ( _suspendCount > 0 ) {
        _suspendCount++;
        return YES;
      } else {
        if ( kill(_processIdentifier, SIGSTOP) == 0 ) {
          _state = kSBTaskStateSuspended;
          _suspendCount++;
          return YES;
        } else {
          if ( errno == ESRCH ) {
            _state = kSBTaskStateCompleted;
            _processIdentifier = 0;
          }
        }
      }
    }
    return NO;
  }
  - (void) terminate
  {
    switch ( _state ) {
    
      case kSBTaskStateRunning:
      case kSBTaskStateSuspended: {
        if ( kill(_processIdentifier, SIGTERM) == 0 ) {
          [self waitUntilExit];
        } else {
          if ( errno == ESRCH ) {
            _state = kSBTaskStateCompleted;
            _processIdentifier = 0;
          }
        }
        break;
      }
      
    }
  }

//

  - (void) waitUntilExit
  {
    if ( _state == kSBTaskStateRunning ) {
      int     procStat = 0;
      pid_t   rcPid = waitpid(_processIdentifier, &procStat, 0);
      
      if ( rcPid == _processIdentifier ) {
        if ( WIFEXITED(procStat) ) {
          _state = kSBTaskStateCompleted;
          _processIdentifier = 0;
          _terminationStatus = WEXITSTATUS(procStat);
          _terminationReason = kSBTaskTerminationReasonExit;
        }
        else if ( WIFSIGNALED(procStat) ) {
          _state = kSBTaskStateCompleted;
          _processIdentifier = 0;
          _terminationStatus = 0;
          _terminationReason = kSBTaskTerminationReasonUncaughtSignal;
        }
        else {
          /* Unknown??? */
          _state = kSBTaskStateCompleted;
          _processIdentifier = 0;
        }
        // Yep, that's right, this task is over:
        [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBTaskDidTerminateNotification object:self];
      }
    }
  }

@end
