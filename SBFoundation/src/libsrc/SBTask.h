//
// SBFoundation : ObjC Class Library for Solaris
// SBTask.h
//
// Class which launches child processes and interacts with them.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBArray, SBDictionary;

/*!
  @enum SBTask Termination Reason
  @discussion
    Enumerated type that explains why a launched SBTask terminated.  Enum labels
    are self-explanatory.
*/
enum {
  kSBTaskTerminationReasonNone = 0,
  kSBTaskTerminationReasonExit = 1,
  kSBTaskTerminationReasonUncaughtSignal = 2
};
typedef SBInteger SBTaskTerminationReason;

/*!
  @class SBTask
  @abstract
    Creating/managing sub-processes.
  @discussion
    Using the SBTask class, a program can run another program as a subprocess and monitor that program’s execution.  An SBTask object creates a separate executable
    entity using the Unix fork() function and executes the specified program over the child process.

    A task operates within an environment defined by the current values for several items: the current directory, standard input, standard output, standard error,
    and the values of any environment variables.  By default, an SBTask object inherits its environment from the process that launches it.  If there are any values
    that should be different for the task, for example, if the current directory should change, you must change the value before you launch the task.  A task’s
    environment cannot be changed from the parent process while it is running.

    An SBTask object can only be run once.  Subsequent attempts to re-run the task raise an exception.
*/
@interface SBTask : SBObject
{
  SBString*                 _launchPath;
  SBArray*                  _arguments;
  SBDictionary*             _environment;
  SBString*                 _currentDirectoryPath;
  id                        _ioStreams[3];
  BOOL                      _launchWithMinimalEnvironment;
  //
  SBUInteger                _state;
  SBInteger                 _suspendCount;
  pid_t                     _processIdentifier;
  int                       _terminationStatus;
  SBTaskTerminationReason   _terminationReason;
}

/*!
  @method launchedTaskWithLaunchPath:arguments:
  @discussion
    Allocate and initialize an autoreleased instance of SBTask to execute the program at path with
    the provided array of arguments.  If the initialization is successful, the program is launched
    with the same environment as the parent program and the object is returned to the caller.
    Otherwise, nil is returned.
*/
+ (SBTask*) launchedTaskWithLaunchPath:(SBString*)path arguments:(SBArray*)arguments;

/*!
  @method init
  @discussion
    Designated initializer.
*/
- (id) init;

/*!
  @method launchPath
  @discussion
    Returns the path of the executable that is to be launched.
*/
- (SBString*) launchPath;

/*!
  @method setLaunchPath:
  @discussion
    Set the path of the executable that is to be launched to launchPath.
*/
- (void) setLaunchPath:(SBString*)launchPath;

/*!
  @method arguments
  @discussion
    Returns the array of string arguments passed to the executable.
*/
- (SBArray*) arguments;

/*!
  @method setArguments:
  @discussion
    Set the array of string arguments to be passed to the executable when launched.
*/
- (void) setArguments:(SBArray*)arguments;

/*!
  @method environment
  @discussion
    Returns a dictionary containing the environment variables that should be set
    when the executable is launched.  These values override and augment the
    current program's environment.
*/
- (SBDictionary*) environment;

/*!
  @method setEnvironment:
  @discussion
    Set the environment variables that should be added/augmented when the executable
    is launched.  These values override and augment the current program's environment.
*/
- (void) setEnvironment:(SBDictionary*)environment;

/*!
  @method currentDirectoryPath
  @discussion
    Returns the working directory that should be set when the executable is launched.
*/
- (SBString*) currentDirectoryPath;

/*!
  @method setCurrentDirectoryPath:
  @discussion
    Launch the executable with currentDirectoryPath as the working directory.
*/
- (void) setCurrentDirectoryPath:(SBString*)currentDirectoryPath;

/*!
  @method standardError
  @discussion
    Returns the SBPipe or SBFileHandle that should be used as the stderr for the task
    when launched.
*/
- (id) standardError;

/*!
  @method setStandardError:
  @discussion
    Set the SBPipe or SBFileHandle that should be used as the stderr for the task
    when launched.
*/
- (void) setStandardError:(id)standardError;

/*!
  @method standardOutput
  @discussion
    Returns the SBPipe or SBFileHandle that should be used as the stdout for the task
    when launched.
*/
- (id) standardOutput;

/*!
  @method setStandardOutput:
  @discussion
    Set the SBPipe or SBFileHandle that should be used as the stdout for the task
    when launched.
*/
- (void) setStandardOutput:(id)standardOutput;

/*!
  @method standardInput
  @discussion
    Returns the SBPipe or SBFileHandle that should be used as the stdin for the task
    when launched.
*/
- (id) standardInput;

/*!
  @method setStandardInput:
  @discussion
    Set the SBPipe or SBFileHandle that should be used as the stdin for the task
    when launched.
*/
- (void) setStandardInput:(id)standardInput;

/*!
  @method launchWithMinimalEnvironment
  @discussion
    Returns boolean YES if the task should be launched with an empty environment.
*/
- (BOOL) launchWithMinimalEnvironment;

/*!
  @method setLaunchWithMinimalEnvironment:
  @discussion
    If launchWithMinimalEnvironment is YES then the task should be launched with
    an empty environment.
*/
- (void) setLaunchWithMinimalEnvironment:(BOOL)launchWithMinimalEnvironment;

/*!
  @method isRunning
  @discussion
    Returns boolean YES if the receiver has been launched and is currently running as
    a child process of this program.
*/
- (BOOL) isRunning;

/*!
  @method terminationStatus
  @discussion
    Returns the status bitmask that the receiver's task returned when it exited.
*/
- (int) terminationStatus;

/*!
  @method terminationReason
  @discussion
    Once the receiver's task has been launched and has completed execution, returns the
    nature of its termination.
*/
- (SBTaskTerminationReason) terminationReason;

/*!
  @method launch
  @discussion
    Attempt to begin execution of the receiver's task.
*/
- (void) launch;

/*!
  @method interrupt
  @discussion
    If the receiver's task is running, send it the SIGINT signal.
*/
- (void) interrupt;

/*!
  @method resume
  @discussion
    If the receiver's task has been launched but is currently suspended, send it the SIGCONT signal.
*/
- (BOOL) resume;

/*!
  @method suspend
  @discussion
    If the receiver's task has been launched send it the SIGSTOP signal.
*/
- (BOOL) suspend;

/*!
  @method terminate
  @discussion
    If the receiver's task has been launched send it the SIGTERM signal.
*/
- (void) terminate;

/*!
  @method waitUntilExit
  @discussion
    If the receiver's task has been launched wait for it to exit.  This method blocks
    execution of this program until the child has completed.
*/
- (void) waitUntilExit;

@end

/*!
  @constant SBTaskDidTerminateNotification
  @discussion
    Notification sent when a child task has exited.
*/
extern SBString* SBTaskDidTerminateNotification;

/*!
  @constant SBInvalidArgumentException
  @discussion
    Name of the SBException objects that may be thrown when sending the launch message to an SBTask object.
*/
extern SBString* SBInvalidArgumentException;
