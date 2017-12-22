//
// SBFoundation : ObjC Class Library for Solaris
// SBLogger.h
//
// Message logging helper class.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @enum Logging Priority
  @discussion
    Enumerates the verbosity levels for the logging interfaces.
*/
enum {
	kSBLoggerPriorityDebug,
	kSBLoggerPriorityNotice,
	kSBLoggerPriorityWarning,
	kSBLoggerPriorityError,
	kSBLoggerPriorityCritical,
	kSBLoggerPriorityAlert,
	kSBLoggerPriorityEmergency
};
typedef SBUInteger SBLoggerPriority;

//

@class SBOutputStream;

//

/*!
  @class SBLogger
  @discussion
    Instances of SBLogger provide a unified interface by which low-level programmatic
    messaging can be performed.  The standard example is a file containing a trace of
    operations performed by a program -- a log file.  Each SBLogger has a minimum
    priority assigned to it:  any messages with lower priority are discarded and not
    logged.  For example, setting the minimum priority to kSBLoggerPriorityError will
    avoid any debug, notice, and warning messages being added.
    
    Conceptually, this class performs the same duties as UNIX syslog.  Indeed, instances
    of this class can be created that send messages to the syslog facility.  The class
    is more generic, though, so the same API can be used to target syslog or a simple
    on-disk file.
*/
@interface SBLogger : SBObject
{
	SBLoggerPriority		_defaultPriority;
	SBLoggerPriority		_minimumPriority;
}

/*!
  @method baseLoggingPath
  @discussion
    Returns the filesystem path under which relative log file paths will reside.
*/
+ (SBString*) baseLoggingPath;
/*!
  @method setBaseLoggingPath:
  @discussion
    Set the filesystem path under which relative log file paths should reside.
*/
+ (void) setBaseLoggingPath:(SBString*)baseLoggingPath;
/*!
  @method loggerWithSyslog
  @discussion
    Returns an autoreleased instance that interfaces with the LOG_USER syslog
    facility.
*/
+ (id) loggerWithSyslog;
/*!
  @method loggerWithSyslogFacility:
  @discussion
    Returns an autoreleased instance that interfaces with the given syslog
    facility.
*/
+ (id) loggerWithSyslogFacility:(int)syslogFacility;
/*!
  @method loggerWithFileAtPath:
  @discussion
    Returns an autoreleased instance that logs to the given filePath.  If filePath
    exists then new messages are appended to the file.
*/
+ (id) loggerWithFileAtPath:(SBString*)filePath;
/*!
  @method loggerWithFileAtPath:openedForAppending:
  @discussion
    Returns an autoreleased instance that logs to the given filePath.  If filePath
    exists and openedForAppending is NO, the file is truncated.
*/
+ (id) loggerWithFileAtPath:(SBString*)filePath openedForAppending:(BOOL)openedForAppending;
/*!
  @method loggerWithOutputStream:
  @discussion
    Returns an autoreleased instance that logs messages by writing to the given
    SBOutputStream object.
*/
+ (id) loggerWithOutputStream:(SBOutputStream*)outputStream;

/*!
  @method defaultPriority
  @discussion
    Returns the receiver's priority at which unprioritized messages should be logged.
*/
- (SBLoggerPriority) defaultPriority;

/*!
  @method setDefaultPriority:
  @discussion
    Sets the priority at which the receiver should log unprioritized messages.
*/
- (void) setDefaultPriority:(SBLoggerPriority)defaultPriority;
/*!
  @method minimumPriority
  @discussion
    Returns the priority below which messages to the receiver should be discarded rather
    than logged.
*/
- (SBLoggerPriority) minimumPriority;
/*!
  @method setMinimumPriority:
  @discussion
    Sets the receiver such that messages with priority less than minimumPriority will
    be discarded rather than logged.
*/
- (void) setMinimumPriority:(SBLoggerPriority)minimumPriority;

/*!
  @method writeFormatToLog:...
  @discussion
    Logs a message created by passing the given format and arguments to the stringWithFormat:arguments:
    method of SBString.  The message is logged with the receiver's default priority.
*/
- (void) writeFormatToLog:(const char*)format,...;
/*!
  @method logPriority:writeFormatToLog:...
  @discussion
    Logs a message of the given priority created by passing the given format and arguments to the
    stringWithFormat:arguments: method of SBString.
*/
- (void) logPriority:(SBLoggerPriority)priority writeFormatToLog:(const char*)format,...;
/*!
  @method writeStringToLog:
  @discussion
    The text in aString is logged with the receiver's default priority.
*/
- (void) writeStringToLog:(SBString*)aString;
/*!
  @method logPriority:writeStringToLog:
  @discussion
    The text in aString is logged with the given priority.
*/
- (void) logPriority:(SBLoggerPriority)priority writeStringToLog:(SBString*)aString;

/*!
  @method shouldLogForPriority:
  @discussion
    Primitive method -- all subclasses should override this method to enable priority-based
    filtering of messages.
*/
- (BOOL) shouldLogForPriority:(SBLoggerPriority)priority;
/*!
  @method logPriority:writeUTF8StringToLog:
  @discussion
    Primitive method -- all subclasses should override this method to write the given UTF-8
    encoded C string to the logging medium with the given priority.
*/
- (void) logPriority:(SBLoggerPriority)priority writeUTF8StringToLog:(const char*)cString;

@end
