//
// SBFoundation : ObjC Class Library for Solaris
// SBNotorization.m
//
// Class used to represent a special database value we'll call a "notorization" -- the combination
// of a user identifier, timestamp, and remote hostname/IP used to make the request.
//
// $Id$
//

#import "SBNotorization.h"
#import "SBString.h"
#import "SBDate.h"
#import "SBInetAddress.h"

UChar SBNotorizationDefaultUserId[] = { 's','y','s','t','e','m','\0' };
UChar SBNotorizationDefaultHost[] = { 'l','o','c','a','l','h','o','s','t','\0' };

//

@implementation SBNotorization

  + (SBNotorization*) notorization
  {
    return [SBNotorization notorizationWithUserId:nil fromAddress:nil];
  }

//

  + (SBNotorization*) notorizationViaApacheEnvironment
  {
    SBInetAddress*    fromAddress = nil;
    SBString*         userId = nil;
    
    char*             apacheRemoteIP = getenv("REMOTE_ADDR");
    char*             apacheRemoteUser = getenv("REMOTE_USER");
    
    if ( apacheRemoteIP && strlen(apacheRemoteIP) )
      fromAddress = [SBInetAddress inetAddressWithCString:apacheRemoteIP];
    
    if ( apacheRemoteUser && strlen(apacheRemoteUser) )
      userId = [SBString stringWithUTF8String:apacheRemoteUser];
    
    return [SBNotorization notorizationWithUserId:userId fromAddress:fromAddress];
  }

//

  + (SBNotorization*) notorizationWithUserId:(SBString*)userId
  {
    return [SBNotorization notorizationWithUserId:userId fromAddress:nil];
  }
  
//

  + (SBNotorization*) notorizationWithUserId:(SBString*)userId
    fromAddress:(SBInetAddress*)address
  {
    return [SBNotorization notorizationWithUserId:userId fromAddress:address withTimestamp:nil];
  }
  
//

  + (SBNotorization*) notorizationWithUserId:(SBString*)userId
    fromAddress:(SBInetAddress*)address
    withTimestamp:(SBDate*)timestamp
  {
    return [[[SBNotorization alloc] initWithUserId:userId fromAddress:address withTimestamp:timestamp] autorelease];
  }
  
//

  - (id) initWithUserId:(SBString*)userId
    fromAddress:(SBInetAddress*)address
    withTimestamp:(SBDate*)timestamp
  {
    if ( self = [super init] ) {
      _userId = ( userId ? [userId copy] : nil );
      _fromAddress = ( address ? [address retain] : nil );
      _timestamp = ( timestamp ? [timestamp retain] : [[SBDate alloc] init] );
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _userId ) [_userId release];
    if ( _fromAddress ) [_fromAddress release];
    if ( _timestamp ) [_timestamp release];
    [super dealloc];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  userId:       "
      );
    if ( _userId )
      [_userId writeToStream:stream];
    else
      fprintf(stream, "system");
      
    fprintf(
        stream,
        "\n  fromAddress:  "
      );
    if ( _fromAddress )
      [[_fromAddress inetAddressAsString] writeToStream:stream];
    else
      fprintf(stream, "localhost");
    
    fprintf(
        stream,
        "\n  timestamp:    "
      );
    [[_timestamp stringValue] writeToStream:stream];
    
    fprintf(
        stream,
        "\n}\n"
      );
  }

//

  - (SBString*) userId
  {
    return _userId;
  }
  - (SBDate*) timestamp
  {
    return _timestamp;
  }
  - (SBInetAddress*) fromAddress
  {
    return _fromAddress;
  }
  
//

  - (SBString*) stringValue
  {
    SBMutableString*      accum = [[SBMutableString alloc] initWithString:@"('"];
    UChar                 separator[3] = {'\'',',','\''}, terminator[2] = {'\'',')'};
    
    if ( _userId )
      [accum appendString:_userId];
    else
      [accum appendCharacters:SBNotorizationDefaultUserId length:( sizeof(SBNotorizationDefaultUserId) / sizeof(UChar) )];
    [accum appendCharacters:separator length:3];
    
    if ( _fromAddress )
      [accum appendString:[_fromAddress inetAddressAsString]];
    else
      [accum appendCharacters:SBNotorizationDefaultHost length:( sizeof(SBNotorizationDefaultHost) / sizeof(UChar) )];
    [accum appendCharacters:separator length:3];
    
    [accum appendString:[_timestamp stringValue]];
    [accum appendCharacters:terminator length:2];
      
    SBString*           rc = [accum copy];
    
    [accum release];
    
    return rc;
  }

@end
