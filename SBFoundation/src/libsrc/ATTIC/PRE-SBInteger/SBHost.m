//
// SBFoundation : ObjC Class Library for Solaris
// SBHost.m
//
// A basic interface to DNS name/address resolution.
//
// $Id$
//

#import "SBHost.h"
#import "SBString.h"
#import "SBInetAddress.h"
#import "SBArray.h"

#include <sys/socket.h>
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>

//

@interface SBHost(SBHostPrivate)

+ (SBHost*) hostWithUTF8Name:(const char*)hostname;
- (id) initWithHostnames:(SBArray*)hostnames ipAddresses:(SBArray*)ipAddresses;

@end

@implementation SBHost(SBHostPrivate)

  + (SBHost*) hostWithUTF8Name:(const char*)hostname
  {
    SBHost*           theHost = nil;
    SBMutableArray*   ipAddresses = [[SBMutableArray alloc] init];
    SBMutableArray*   hostnames = [[SBMutableArray alloc] init];
    int               dnserr;
    struct hostent*   he;
    SBString*         aString;
    SBInetAddress*    inetAddress;
    
    // Try for IPv4:
    he = getipnodebyname(hostname, AF_INET, AI_ALL | AI_ADDRCONFIG | AI_V4MAPPED, &dnserr);
    if ( he ) {
      char**          addr = he->h_addr_list;
      char**          alias = he->h_aliases;
      
      // Canonical hostname:
      aString = [[SBString alloc] initWithUTF8String:he->h_name];
      if ( ! [hostnames containsObject:aString] )
        [hostnames addObject:aString];
      [aString release];
      
      // Addresses:
      while ( *addr ) {
        inetAddress = [SBInetAddress inetAddressWithIPv4Bytes:*addr];
        if ( inetAddress && ! [ipAddresses containsObject:inetAddress] )
          [ipAddresses addObject:inetAddress];
        addr++;
      }
      
      // Aliases:
      while ( *alias ) {
        aString = [[SBString alloc] initWithUTF8String:*alias];
        if ( ! [hostnames containsObject:aString] )
          [hostnames addObject:aString];
        [aString release];
        alias++;
      }
      freehostent(he);
    }
    
    // Now try IPv6:
    he = getipnodebyname(hostname, AF_INET6, AI_ALL | AI_ADDRCONFIG | AI_V4MAPPED, &dnserr);
    if ( he ) {
      char**          addr = he->h_addr_list;
      char**          alias = he->h_aliases;
      
      // Canonical hostname:
      aString = [[SBString alloc] initWithUTF8String:he->h_name];
      if ( ! [hostnames containsObject:aString] )
        [hostnames addObject:aString];
      [aString release];
      
      // Addresses:
      while ( *addr ) {
        inetAddress = [SBInetAddress inetAddressWithIPv6Bytes:*addr];
        if ( inetAddress && ! [ipAddresses containsObject:inetAddress] )
          [ipAddresses addObject:inetAddress];
        addr++;
      }
      
      // Aliases:
      while ( *alias ) {
        aString = [[SBString alloc] initWithUTF8String:*alias];
        if ( ! [hostnames containsObject:aString] )
          [hostnames addObject:aString];
        [aString release];
        alias++;
      }
      freehostent(he);
    }
    
    // Ready to go create the host object if we found anything:
    if ( [ipAddresses count] || [hostnames count] ) {
      theHost = [[[SBHost alloc] initWithHostnames:hostnames ipAddresses:ipAddresses] autorelease];
    }
    [ipAddresses release];
    [hostnames release];
    
    return theHost;
  }

//

  - (id) initWithHostnames:(SBArray*)hostnames
    ipAddresses:(SBArray*)ipAddresses
  {
    if ( self = [super init] ) {
      _hostnames = [hostnames copy];
      _ipAddresses = [ipAddresses copy];
    }
    return self;
  }

@end

//
#pragma mark -
//

@implementation SBHost

  + (SBHost*) currentHost
  {
    char        hostname[MAXHOSTNAMELEN];
    
    if ( gethostname(hostname, MAXHOSTNAMELEN) == 0 )
      return [SBHost hostWithUTF8Name:hostname];
    return nil;
  }
  
//

  + (SBHost*) hostWithName:(SBString*)hostname
  {
    SBSTRING_AS_UTF8_BEGIN(hostname)
      
      return [SBHost hostWithUTF8Name:hostname_utf8];
    
    SBSTRING_AS_UTF8_END
    
    return nil;
  }

//

  + (SBHost*) hostWithIPAddress:(SBInetAddress*)ipAddress
  {
    SBHost*                   theHost = nil;
    struct hostent*           he = NULL;
    int                       dnserr;
    
    // We'll resolve the IP to a hostname and then init using that hostname; guess that's
    // kinda cheating, but cest la vie:
    if ( [ipAddress addressFamily] == kSBInetAddressIPv4Family ) {
      struct sockaddr_in      aSock;
      
      if ( [ipAddress setSockAddr:(void*)&aSock byteSize:sizeof(aSock)] )
        he = getipnodebyaddr(&aSock.sin_addr, sizeof(aSock.sin_addr), AF_INET, &dnserr);
    } else {
      struct sockaddr_in6     aSock;
      
      if ( [ipAddress setSockAddr:(void*)&aSock byteSize:sizeof(aSock)] )
        he = getipnodebyaddr(&aSock.sin6_addr, sizeof(aSock.sin6_addr), AF_INET6, &dnserr);
    }
    
    if ( he ) {
      theHost = [SBHost hostWithUTF8Name:he->h_name];
      freehostent(he);
    }
    return theHost;
  }

//

  - (void) dealloc
  {
    if ( _hostnames ) [_hostnames release];
    if ( _ipAddresses ) [_ipAddresses release];
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBArray*      A;
    unsigned int  i, iMax;
    
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " {\n"
        "  names:\n"
      );
    
    i=0; iMax = [_hostnames count];
    while ( i < iMax ) {
      fprintf(stream,"       ");
      [[_hostnames objectAtIndex:i++] writeToStream:stream];
      fprintf(stream,"\n");
    }
    
    fprintf(
        stream,
        "\n"
        "  addresses:\n"
      );
    
    i=0; iMax = [_ipAddresses count];
    while ( i < iMax ) {
      fprintf(stream,"       ");
      [[[_ipAddresses objectAtIndex:i++] inetAddressAsString] writeToStream:stream];
      fprintf(stream,"\n");
    }
    
    fprintf(
        stream,
        "}\n"
      );
  }

//

  - (BOOL) isEqualToHost:(SBHost*)aHost
  {
    if ( self == aHost )
      return YES;
    
    if ( [[aHost hostnames] containsObject:[self hostname]] && [[aHost ipAddresses] containsObject:[self ipAddress]] )
      return YES;
    
    return NO;
  }

//

  - (SBString*) hostname
  {
    if ( _hostnames )
      return [_hostnames objectAtIndex:0];
    return nil;
  }

//

  - (SBArray*) hostnames
  {
    return _hostnames;
  }
  
//

  - (SBInetAddress*) ipAddress
  {
    if ( _ipAddresses )
      return [_ipAddresses objectAtIndex:0];
    return nil;
  }
  
//

  - (SBArray*) ipAddresses
  {
    return _ipAddresses;
  }
  
@end
