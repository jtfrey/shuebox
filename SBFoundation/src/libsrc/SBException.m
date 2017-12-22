//
// SBFoundation : ObjC Class Library for Solaris
// SBException.m
//
// Support for exception handling within non-Apple Objective-C runtimes.  Concepts
// borrowed from myStep.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBException.h"
#import "SBDictionary.h"
#import "SBAutoreleasePool.h"
#import "SBThread.h"

SBString*     SBGenericException = @"generic exception";
SBString*     SBAutoreleaseException = @"autorelease exception";

//

static void
_SBUncaughtExceptionHandlerImpl(
  SBException*    exception
)
{
  SBString*       str;
  
  fprintf(stderr, "Uncaught exception \"");
  if ( (str = [exception identifier]) )
    [str writeToStream:stderr];
  else
    fprintf(stderr, "[unidentified]");
  fputc('"', stderr);
  if ( (str = [exception reason]) ) {
    fprintf(stderr, ", reason: ");
    [str writeToStream:stderr];
  }
  fputc('\n', stderr);
  abort();
}

SBUncaughtExceptionHandler*     _SBUncaughtExceptionHandler = _SBUncaughtExceptionHandlerImpl;

//

@implementation SBException

  + (SBException*) exceptionWithIdentifier:(SBString*)identifier
    reason:(SBString*)reason
    userInfo:(SBDictionary*)userInfo
  {
    return [[[SBException alloc] initWithIdentifier:identifier reason:reason userInfo:userInfo] autorelease];
  }
  
//

  + (void) raise:(SBString*)identifier
    format:(const char*)format, ...
  {
    va_list       vargs;
    
    va_start(vargs, format);
    [self raise:identifier format:format arguments:vargs];
    va_end(vargs);
  }
  
//

  + (void) raise:(SBString*)identifier
    format:(const char*)format
    arguments:(va_list)argList
  {
    SBString*       reason = ( format ? [[SBString alloc] initWithFormat:format arguments:argList] : nil );
    SBException*    exception = [self exceptionWithIdentifier:identifier reason:reason userInfo:nil];
    
    if ( reason ) [reason release];
    [exception raise];
  }
  
//

  - (id) initWithIdentifier:(SBString*)identifier
    reason:(SBString*)reason
    userInfo:(SBDictionary*)userInfo
  {
    if ( (self = [super init]) ) {
      if ( identifier ) _identifier = [identifier copy];
      if ( reason ) _reason = [reason copy];
      if ( userInfo ) _userInfo = [userInfo retain];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _identifier ) [_identifier release];
    if ( _reason ) [_reason release];
    if ( _userInfo ) [_userInfo release];
    [super dealloc];
  }

//

  - (SBString*) identifier { return _identifier; }
  - (SBString*) reason { return _reason; }
  - (SBDictionary*) userInfo { return _userInfo; }

//

  - (void) raise
  {
  	SBThread*           currentThread = [SBThread currentThread];
    SBExceptionState*   exceptionState = currentThread->_exceptionState;
      
    if ( exceptionState == NULL) {
    	_SBUncaughtExceptionHandler(self);
    } else {
      // Pop the last exception state off the stack for the current thread:
      currentThread->_exceptionState = exceptionState->link;
      exceptionState->exception = self;
      
      // Return to the last "savepoint" created by a TRY_BEGIN macro:
      longjmp(exceptionState->origin, 1);
		}
  }

@end

//

void
_SBPushExceptionState(
  SBExceptionState*   newState
)
{
	SBThread*           currentThread = [SBThread currentThread];
  
  newState->link = currentThread->_exceptionState;
  currentThread->_exceptionState = newState;
}

//

void
_SBPopExceptionState()
{
	SBThread*           currentThread = [SBThread currentThread];
  
  if ( currentThread->_exceptionState )
    currentThread->_exceptionState = currentThread->_exceptionState->link;
}
