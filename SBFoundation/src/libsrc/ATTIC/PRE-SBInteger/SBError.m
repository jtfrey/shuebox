//
// SBFoundation : ObjC Class Library for Solaris
// SBError.m
//
// Generic class for returning error information to a caller.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBError.h"
#import "SBString.h"
#import "SBDictionary.h"
#import "SBMailer.h"

SBString* SBPOSIXErrorDomain = @"POSIX";
SBString* SBFoundationErrorDomain = @"SBFoundation";

//

@implementation SBError
{
  SBString*       _domain;
  int             _code;
  SBDictionary*   _supportingData;
}

  + (id) posixErrorWithCode:(int)code
    supportingData:(SBDictionary*)data
  {
    return [[[SBError alloc] initWithDomain:SBPOSIXErrorDomain code:code supportingData:data] autorelease];
  }
  
//

  + (id) foundationErrorWithCode:(int)code
    supportingData:(SBDictionary*)data
  {
    return [[[SBError alloc] initWithDomain:SBFoundationErrorDomain code:code supportingData:data] autorelease];
  }
  
//

  + (id) errorWithDomain:(SBString*)domain
    code:(int)code
    supportingData:(SBDictionary*)data
  {
    return [[[SBError alloc] initWithDomain:domain code:code supportingData:data] autorelease];
  }
  
//

  - (id) initWithDomain:(SBString*)domain
    code:(int)code
    supportingData:(SBDictionary*)data
  {
    if ( ! domain ) {
      [self release];
      return nil;
    }
    if ( self = [super init] ) {
      _domain = [domain copy];
      _code = code;
      if ( data )
        _supportingData = [data copy];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _domain ) [_domain release];
    if ( _supportingData ) [_supportingData release];
    [super dealloc];
  }

//

  - (SBString*) domain
  {
    return _domain;
  }
  
//

  - (int) code
  {
    return _code;
  }
  
//

  - (SBDictionary*) supportingData
  {
    return _supportingData;
  }
  
//

  - (void) writeErrorSummaryToStream:(FILE*)stream
  {
    fprintf(stream, "ERROR(domain=");
    [_domain writeToStream:stream];
    fprintf(stream, ", code=%d)", _code);
    if ( _supportingData ) {
      SBString*   explanation = [_supportingData objectForKey:SBErrorExplanationKey];
      
      if ( explanation ) {
        fprintf(stream, " : ");
        [explanation writeToStream:stream];
      }
    }
    fputc('\n', stream);
  }

//

  - (void) emailErrorSummaryWithMailer:(SBMailer*)aMailer
  {
    SBString*           explanation = ( _supportingData ? [_supportingData objectForKey:SBErrorExplanationKey] : nil );
    SBMutableString*    message = [[SBMutableString alloc] initWithFormat:
                                      "\n"
                                      "SHUEBox has encountered an error that it felt you should know about:\n"
                                      "\n"
                                      "Error Domain : %s\n"
                                      "      Code:    %d\n"
                                      "\n"
                                      "Explanation:\n"
                                      "\n"
                                      "%S\n"
                                      "\n",
                                      [_domain utf8Characters],
                                      _code,
                                      ( explanation ? [explanation utf16Characters] : (const UChar*)"\0\0" )
                                    ];
    if ( message ) {
      [aMailer sendMessage:message withSubject:@"[SHUEBox] Error Notification"];
      [message release];
    }
  }

@end

//

SBString* SBErrorExplanationKey = @"explanation";
