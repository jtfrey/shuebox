//
// SBFoundation : ObjC Class Library for Solaris
// SBException.h
//
// Support for exception handling within non-Apple Objective-C runtimes.  Concepts
// borrowed from myStep.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBString.h"
#include <setjmp.h>
#include <stdarg.h>

@class SBDictionary;

@interface SBException : SBObject
{    
	SBString*     _identifier;
	SBString*     _reason;
	SBDictionary* _userInfo;
}

+ (SBException*) exceptionWithIdentifier:(SBString*)identifier reason:(SBString*)reason userInfo:(SBDictionary*)userInfo;
+ (void) raise:(SBString*)identifier format:(const char*) format, ...;
+ (void) raise:(SBString*)identifier format:(const char*) format arguments:(va_list)argList;

- (id) initWithIdentifier:(SBString*)identifier reason:(SBString*)reason userInfo:(SBDictionary*)userInfo;

- (SBString*) identifier;
- (SBString*) reason;
- (SBDictionary*) userInfo;

- (void) raise;

@end

extern SBString* SBGenericException;
extern SBString* SBAutoreleaseException;

//
// Exception-handling state:
//
typedef struct _SBExceptionState {
  jmp_buf                     origin; /* place to which execution will return on longjmp() */
  struct _SBExceptionState*   link;
  SBException*                exception;
} SBExceptionState;

/*!
  @typedef SBUncaughtExceptionHandler
  @discussion
    Prototype for a function which handles exceptions raised outside the
    scope of any exception blocks.
*/
typedef void SBUncaughtExceptionHandler(SBException* exception);

/*!
  @const _SBUncaughtExceptionHandler
  @discussion
    Pointer to the function which currently handles uncaught exceptions
    in the runtime.
*/
extern SBUncaughtExceptionHandler* _SBUncaughtExceptionHandler;
#define SBGetUncaughtExceptionHandler() _SBUncaughtExceptionHandler
#define SBSetUncaughtExceptionHandler(proc) \
			(_SBUncaughtExceptionHandler = (proc))


extern void _SBPushExceptionState(SBExceptionState* newState);
extern void _SBPopExceptionState(void);

#define TRY_BEGIN \
{ \
  SBExceptionState  SBLocalExceptionState; \
  _SBPushExceptionState(&SBLocalExceptionState); \
  if( ! setjmp(SBLocalExceptionState.origin) ) {

#define TRY_CATCH(SBEXCEPTION_VAR) \
    _SBPopExceptionState(); \
  } else { \
    SBException*  SBEXCEPTION_VAR = SBLocalExceptionState.exception;

#define TRY_END \
  } \
}

#define TRY_RETURN_VALUE(SBEXCEPTION_VALUE, SBEXCEPTION_VALUETYPE) \
do { \
  SBEXCEPTION_VALUETYPE rc = (SBEXCEPTION_VALUE);	\
  _SBPopExceptionState();	\
  return (rc); \
} while (0)

#define TRY_RETURN \
do { \
  _SBPopExceptionState();	\
  return; \
} while (0)
