//
// SBFoundation : ObjC Class Library for Solaris
// SBLogger.m
//
// Message logging helper class.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBLogger.h"
#import "SBString.h"
#import "SBFileManager.h"
#import "SBStream.h"

#include "syslog.h"

//

int
__SBLoggerSyslogPriorityForOurPriority(
	SBLoggerPriority		priority
)
{
	switch ( priority ) {
		case kSBLoggerPriorityDebug:
			break;
		case kSBLoggerPriorityNotice:
			return LOG_NOTICE;
		case kSBLoggerPriorityWarning:
			return LOG_WARNING;
		case kSBLoggerPriorityError:
			return LOG_ERR;
		case kSBLoggerPriorityCritical:
			return LOG_CRIT;
		case kSBLoggerPriorityAlert:
			return LOG_ALERT;
		case kSBLoggerPriorityEmergency:
			return LOG_EMERG;
	}
	return LOG_DEBUG;
}

//
#if 0
#pragma mark -
#endif
//

@interface SBSyslogLogger : SBLogger
{
	int					_syslogFacility;
}

- (id) initWithSyslogFacility:(int)syslogFacility;

@end

@implementation SBSyslogLogger

	- (id) initWithSyslogFacility:(int)syslogFacility
	{
		if ( (self = [super init]) ) {
			_syslogFacility = syslogFacility;
		}
		return self;
	}

//

	- (void) logPriority:(SBLoggerPriority)priority
		writeUTF8StringToLog:(const char*)cString
	{
		if ( [self shouldLogForPriority:priority] ) {
			syslog(
					__SBLoggerSyslogPriorityForOurPriority(priority) | _syslogFacility,
					cString
				);
		}
	}

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBOutputStreamLogger : SBLogger
{
	SBOutputStream*				_outputStream;
}

- (id) initWithOutputStream:(SBOutputStream*)outputStream;

@end

@implementation SBOutputStreamLogger

	- (id) initWithOutputStream:(SBOutputStream*)outputStream
	{
		if ( (self = [super init]) ) {
			if ( ! outputStream ) {
				[self release];
				self = nil;
			} else {
				_outputStream = [outputStream retain];
			}
		}
		return self;
	}
	
//

	- (void) dealloc
	{
		if ( _outputStream ) {
			//
			// We don't close it -- someone else may be sharing the stream with us
			//
			[_outputStream release];
		}
		[super dealloc];
	}
	
//

	- (void) logPriority:(SBLoggerPriority)priority
		writeUTF8StringToLog:(const char*)cString
	{
		if ( [self shouldLogForPriority:priority] ) {
			char				dateStr[32];
			time_t			now = time(NULL);
			
			[_outputStream write:dateStr length:strftime(dateStr, sizeof(dateStr), "%Y-%m-%d %H:%M:%S", localtime(&now))];
			[_outputStream write:dateStr length:snprintf(dateStr, sizeof(dateStr), " [%5d] : ", getpid())];
			[_outputStream write:(void*)cString length:strlen(cString)];
			[_outputStream write:"\n" length:1];
		}
	}

@end


//
#if 0
#pragma mark -
#endif
//

static SBString*		__SBLoggerBaseLoggingPath = nil;

@implementation SBLogger

	+ (SBString*) baseLoggingPath
	{
		if ( __SBLoggerBaseLoggingPath )
			return __SBLoggerBaseLoggingPath;
		return @"/var/log";
	}
	
//

	+ (void) setBaseLoggingPath:(SBString*)baseLoggingPath
	{
		if ( baseLoggingPath ) baseLoggingPath = [baseLoggingPath copy];
		if ( __SBLoggerBaseLoggingPath ) [__SBLoggerBaseLoggingPath release];
		__SBLoggerBaseLoggingPath = baseLoggingPath;
	}

//

	+ (id) loggerWithSyslog
	{
		return [self loggerWithSyslogFacility:LOG_USER];
	}
	+ (id) loggerWithSyslogFacility:(int)syslogFacility
	{
		return [[[SBSyslogLogger alloc] initWithSyslogFacility:syslogFacility] autorelease];
	}

//

	+ (id) loggerWithFileAtPath:(SBString*)filePath
	{
		return [self loggerWithFileAtPath:filePath openedForAppending:YES];
	}
	+ (id) loggerWithFileAtPath:(SBString*)filePath
		openedForAppending:(BOOL)openedForAppending
	{
		if ( filePath && [filePath length] ) {
			//
			// Relative paths should be appended to the default base path:
			//
			if ( [filePath isRelativePath] )
				filePath = [[SBLogger baseLoggingPath] stringByAppendingPathComponent:filePath];
		
			SBOutputStream*			outputStream = [SBOutputStream outputStreamToFileAtPath:filePath append:openedForAppending];
			
			if ( outputStream ) {
				[outputStream open];
				if ( [outputStream streamStatus] == SBStreamStatusOpen )
					return [self loggerWithOutputStream:outputStream];
			}
		}
		return nil;
	}

//

	+ (id) loggerWithOutputStream:(SBOutputStream*)outputStream
	{
		return [[[SBOutputStreamLogger alloc] initWithOutputStream:outputStream] autorelease];
	}

//

	- (id) init
	{
		if ( (self = [super init]) ) {
			_defaultPriority = kSBLoggerPriorityError;
			_minimumPriority = kSBLoggerPriorityError;
		}
		return self;
	}
	
//

	- (SBLoggerPriority) defaultPriority
	{
		return _defaultPriority;
	}
	- (void) setDefaultPriority:(SBLoggerPriority)defaultPriority
	{
		if ( defaultPriority <= kSBLoggerPriorityEmergency )
			_defaultPriority = defaultPriority;
	}

//

	- (SBLoggerPriority) minimumPriority
	{
		return _minimumPriority;
	}
	- (void) setMinimumPriority:(SBLoggerPriority)minimumPriority
	{
		if ( minimumPriority <= kSBLoggerPriorityEmergency )
			_minimumPriority = minimumPriority;
	}

//

	- (void) writeFormatToLog:(const char*)format,...
	{
		if ( [self shouldLogForPriority:_defaultPriority] ) {
			va_list				vargs;
			
			va_start(vargs, format);
			
			SBString*			logString = [[SBString alloc] initWithFormat:format arguments:vargs];
			
			va_end(vargs);
			
			if ( logString ) {
				[self logPriority:_defaultPriority writeUTF8StringToLog:[logString utf8Characters]];
				[logString release];
			}
		}
	}
	
//

	- (void) logPriority:(SBLoggerPriority)priority
		writeFormatToLog:(const char*)format,...
	{
		if ( [self shouldLogForPriority:priority] ) {
			va_list				vargs;
			
			va_start(vargs, format);
			
			SBString*			logString = [[SBString alloc] initWithFormat:format arguments:vargs];
			
			va_end(vargs);
			
			if ( logString ) {
				[self logPriority:priority writeUTF8StringToLog:[logString utf8Characters]];
				[logString release];
			}
		}
	}
	
//

	- (void) writeStringToLog:(SBString*)aString
	{
		if ( [self shouldLogForPriority:_defaultPriority] )
			[self logPriority:_defaultPriority writeUTF8StringToLog:[aString utf8Characters]];
	}
	
//

	- (void) logPriority:(SBLoggerPriority)priority
		writeStringToLog:(SBString*)aString
	{
		if ( [self shouldLogForPriority:priority] )
			[self logPriority:_defaultPriority writeUTF8StringToLog:[aString utf8Characters]];
	}

//

	- (BOOL) shouldLogForPriority:(SBLoggerPriority)priority
	{
		return ( ((priority <= kSBLoggerPriorityEmergency) && (priority >= _minimumPriority)) ? YES : NO );
	}

//

	- (void) logPriority:(SBLoggerPriority)priority
		writeUTF8StringToLog:(const char*)cString
	{
		// NOOP
	}
	
@end
