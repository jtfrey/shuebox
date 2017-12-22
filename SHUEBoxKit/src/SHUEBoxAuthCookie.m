//
// SHUEBoxKit : application-wide support classes for SHUEBox
// SHUEBoxAuthCookie.h
//
// Support for the authentication cookie.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SHUEBoxAuthCookie.h"
#import "SHUEBoxUser.h"
#import "SBInetAddress.h"
#import "SBDate.h"
#import "SBTimeZone.h"
#import "SBDateFormatter.h"
#import "SBString.h"
#import "SBMD5Digest.h"
#import "SBScanner.h"
#import "SHUEBoxDictionary.h"

static SBString* SHUEBoxAuthCookieName = @"shuebox-identity";

//

@interface SHUEBoxAuthCookie(SHUEBoxAuthCookiePrivate)

+ (SBDateFormatter*) dateFormatterForCookieField;
- (id) initWithCookieValue:(SBString*)value database:(id)database;

@end

@implementation SHUEBoxAuthCookie(SHUEBoxAuthCookiePrivate)

  + (SBDateFormatter*) dateFormatterForCookieField
  {
    static SBDateFormatter*   __dateFormatterForCookieField = nil;
    
    if ( __dateFormatterForCookieField == nil ) {
      __dateFormatterForCookieField = [[SBDateFormatter alloc] init];
      
      [__dateFormatterForCookieField setPattern:@"yyyyMMdd'T'HHmmss"];
      [__dateFormatterForCookieField setTimeZone:[SBTimeZone utcTimeZone]];
    }
    return __dateFormatterForCookieField;
  }

//
  - (id) initWithCookieValue:(SBString*)value
    database:(id)database
  {
    //
    // Decompose the cookie into the pieces we want:
    //
    SBScanner*  scanner = [[SBScanner alloc] initWithString:[value decodeURLEncodedString]];
    SBString*   uname = nil;
    SBString*   remoteAddress = nil;
    SBString*   expireTime = nil;
    SBString*   nonce = nil;
    SBString*   remoteDigest = nil;
    
    if ( ! [scanner scanUpToString:@"," intoString:&uname] || ! [scanner scanString:@"," intoString:NULL] )
      goto failure;
    if ( ! [scanner scanUpToString:@"," intoString:&remoteAddress] || ! [scanner scanString:@"," intoString:NULL] )
      goto failure;
    if ( ! [scanner scanUpToString:@"," intoString:&expireTime] || ! [scanner scanString:@"," intoString:NULL] )
      goto failure;
    if ( ! [scanner scanUpToString:@"," intoString:&nonce] || ! [scanner scanString:@"," intoString:NULL] )
      goto failure;
    if ( ! [scanner scanUpToString:@";" intoString:&remoteDigest] || ! [scanner scanString:@"," intoString:NULL] )
      goto failure;
    if ( ! (uname && remoteAddress && expireTime && nonce && remoteDigest) )
      goto failure;
    
    //
    // Validate the digest to confirm cookie validity:
    //
    SBString*   entropicSecret = [database stringForFullDictionaryKey:@"auth:entropic-secret"];
    
    if ( ! entropicSecret )
      goto failure;
    
    SBString*   digestSrc = [[SBString alloc] initWithFormat:"%S %S %S %S shuebox-identity %S",
                                  [uname utf16Characters],
                                  [remoteAddress utf16Characters],
                                  [expireTime utf16Characters],
                                  [nonce utf16Characters],
                                  [entropicSecret utf16Characters]
                                ];
    if ( ! [digestSrc md5DigestForUTF8MatchesString:remoteDigest] )
      goto failure;
    
    //
    // Can we get the user associated with the cookie?
    //
    SHUEBoxUser*    remoteUser = [SHUEBoxUser shueboxUserWithDatabase:database shortName:uname];
    
    if ( ! remoteUser )
      goto failure;
    
    //
    // Ready to init:
    //
    [scanner release];
    return [self initWithUser:remoteUser inetAddress:[SBInetAddress inetAddressWithString:remoteAddress]];

failure:
    [scanner release];
    [self release];
    return nil;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SHUEBoxAuthCookie

  - (id) initWithApacheEnvironmentAndDatabase:(id)database
  {
    // If the cookie exists already, use it:
    SBString*       extantCookie = [[SBDictionary dictionaryWithCookiesFromEnv] objectForKey:@"shuebox-identity"];
    
    if ( extantCookie ) {
      if ( (self = [self initWithCookieValue:extantCookie database:database]) )
        return self;
    }
    
    // Get auth user and remote IP from environment:
    const char*     remoteUser = getenv("REMOTE_USER");
    const char*     remoteAddr = getenv("REMOTE_ADDR");
    
    if ( ! remoteUser || ! remoteAddr )
      goto failure;
    
    SHUEBoxUser*    user = [SHUEBoxUser shueboxUserWithDatabase:database shortName:[SBString stringWithUTF8String:remoteUser]];
    
    if ( ! user )
      goto failure;
    
    return [self initWithUser:user inetAddress:[SBInetAddress inetAddressWithCString:remoteAddr]];

failure:
    [self release];
    return nil;
  }

//

  - (id) initWithUser:(SHUEBoxUser*)user
    inetAddress:(SBInetAddress*)inetAddress
  {
    if ( (self = [super initWithCookieName:SHUEBoxAuthCookieName andValue:@""]) ) {
      [self setTimeToLive:300];
      [self setBasePath:@"/"];
      [self setBaseDomain:@"shuebox.nss.udel.edu"];
      [self setSecureConnectionRequired:YES];
      
      _remoteUser = [user retain];
      _remoteAddress = [inetAddress retain];
      
      [self setCookieValue:nil];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    [_remoteUser release];
    [_remoteAddress release];
    [super dealloc];
  }

//

  - (SHUEBoxUser*) remoteUser
  {
    return _remoteUser;
  }
  
//

  - (SBInetAddress*) remoteAddress
  {
    return _remoteAddress;
  }
  
//

  - (void) setCookieValue:(SBString*)dummy
  {
    if ( ! _remoteUser )
      return;
      
    id          database = [_remoteUser parentDatabase];
    
    if ( ! database )
      return;
    
    SBString*   entropicSecret = [database stringForFullDictionaryKey:@"auth:entropic-secret"];
    
    if ( ! entropicSecret )
      return;
    
    srandom((unsigned int)time(NULL));
      
    SBString*   uname = [_remoteUser shortName];
    SBString*   remoteAddress = [_remoteAddress inetAddressAsString];
    SBString*   expireTime = [[SHUEBoxAuthCookie dateFormatterForCookieField] stringFromDate:[self expirationDate]];
    long int    nonce = random();
    
    SBString*   digestSrc = [[SBString alloc] initWithFormat:"%S %S %S %ld shuebox-identity %S",
                                  [uname utf16Characters],
                                  [remoteAddress utf16Characters],
                                  [expireTime utf16Characters],
                                  nonce,
                                  [entropicSecret utf16Characters]
                                ];
    unsigned char digestStr[16];
    char          digestCStr[33];
    int           i = 0;
    
    [digestSrc md5DigestForUTF8:digestStr];
    while ( i < 16 ) {
      static char* __hexdigits = "0123456789abcdef";
      digestCStr[2 * i] = __hexdigits[ (digestStr[i] & 0xF0) >> 4 ];
      digestCStr[2 * i + 1] = __hexdigits[ digestStr[i] & 0x0F ];
      i++;
    }
    digestCStr[32] = '\0';
    [super setCookieValue:[SBString stringWithFormat:"%S,%S,%S,%ld,%s",
                                  [uname utf16Characters],
                                  [remoteAddress utf16Characters],
                                  [expireTime utf16Characters],
                                  nonce,
                                  digestCStr
                                ]
                              ];
  }

@end
