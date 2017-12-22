//
// SBFoundation : ObjC Class Library for Solaris
// SBInetAddress.m
//
// Class cluster that represents IPv4 and IPv6 addresses.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBInetAddress.h"
#import "SBString.h"
#import "SBData.h"

#include <netinet/in.h>
#include <arpa/inet.h>

//

@interface SBInetAddress(SBInetAddressPrivate)

- (id) initWithBytes:(const void*)bytes;
- (id) initWithBytes:(const void*)bytes prefixLength:(unsigned int)prefixLength;

@end

//

@interface __SBIPv4Address : SBInetAddress
{
  unsigned char     _bytes[4];
  unsigned char     _prefix;
}

@end

//

@interface __SBIPv6Address : SBInetAddress
{
  unsigned char     _bytes[16];
  unsigned char     _prefix;
}

@end

//
#pragma mark -
//

@implementation SBInetAddress(SBInetAddressPrivate)

  - (id) initWithBytes:(const void*)bytes
  {
    return [self init];
  }
  - (id) initWithBytes:(const void*)bytes
    prefixLength:(unsigned int)prefixLength
  {
    return [self init];
  }
  
@end

@implementation SBInetAddress

  + (SBInetAddress*) inetAddressWithIPv4Bytes:(const void*)bytes
  {
    return [[[__SBIPv4Address alloc] initWithBytes:bytes] autorelease];
  }
  
//

  + (SBInetAddress*) inetAddressWithIPv4Bytes:(const void*)bytes
    prefixLength:(unsigned int)prefixLength
  {
    return [[[__SBIPv4Address alloc] initWithBytes:bytes prefixLength:prefixLength] autorelease];
  }
  
//

  + (SBInetAddress*) inetAddressWithIPv6Bytes:(const void*)bytes
  {
    return [[[__SBIPv6Address alloc] initWithBytes:bytes] autorelease];
  }
  
//

  + (SBInetAddress*) inetAddressWithIPv6Bytes:(const void*)bytes
    prefixLength:(unsigned int)prefixLength
  {
    return [[[__SBIPv6Address alloc] initWithBytes:bytes prefixLength:prefixLength] autorelease];
  }
  
//

  + (SBInetAddress*) inetAddressWithSockAddr:(struct sockaddr*)sockAddr
  {
    switch ( sockAddr->sa_family ) {
      
      case AF_INET:
        return [[[__SBIPv4Address alloc] initWithBytes:&sockAddr->sa_data[0]] autorelease];
      case AF_INET6:
        return [[[__SBIPv6Address alloc] initWithBytes:&sockAddr->sa_data[0]] autorelease];
        
    }
    return nil;
  }
  
//

  + (SBInetAddress*) inetAddressWithCString:(const char*)cString
  {
    unsigned char   bytes[16];
    size_t          cStringLen = 0;
    
    if ( cString == NULL )
      return nil;
      
    if ( (cStringLen = strlen(cString)) > 0 ) {
      char          cStringCopy[cStringLen + 1];
      char*         suffix;
      
      strncpy(cStringCopy, cString, cStringLen + 1);
      
      // Is there a prefix or netmask following the head of the string?
      if ( (suffix = strchr(cStringCopy, '/')) ) {
        *suffix = '\0';
        suffix++;
      }
      
      // Try for IPv4 first:
      if ( inet_pton(AF_INET, cStringCopy, bytes) ) {
        unsigned int  prefix = 0;
        
        // Examine the suffix string for prefix length, either as a CIDR-style
        // bit count or a netmask:
        if ( suffix ) {
          unsigned char maskBytes[4];
          int           count = 0, n;
          char*         p = suffix;
          
          do {
            if ( sscanf(p, "%hhu%n", maskBytes + count, &n) > 0 ) {
              count++;
            } else {
              break;
            }
            p += n;
            if ( *p == '.' )
              p++;
            else
              break;
          } while ( *p && (count < 4) );
          
          if ( (count == 1) && (maskBytes[0] <= 32) ) {
            prefix = maskBytes[0];
          } else {
            n = 0;
            while ( n < count ) {
              if ( maskBytes[n] == 255 ) {
                prefix += 8;
              } else {
                while ( maskBytes[n] != 0 ) {
                  prefix++;
                  maskBytes[n] <<= 1;
                }
                break;
              }
              n++;
            }
          }
        }
        if ( prefix != 0 )
          return [[[__SBIPv4Address alloc] initWithBytes:bytes prefixLength:prefix] autorelease];
        return [[[__SBIPv4Address alloc] initWithBytes:bytes] autorelease];
      }
      
      // How about IPv6?
      if ( inet_pton(AF_INET6, cStringCopy, bytes) ) {
        unsigned int  prefix = 0;
        
        // Examine the suffix string for prefix length:
        if ( suffix ) {
          unsigned char maskByte;
          
          if ( sscanf(suffix, "%hhu", &maskByte) > 0 )
            if ( maskByte <= 128 )
              prefix = maskByte;
        }
        if ( prefix != 0 )
          return [[[__SBIPv6Address alloc] initWithBytes:bytes prefixLength:prefix] autorelease];
        return [[[__SBIPv6Address alloc] initWithBytes:bytes] autorelease];
      }
    }
    return nil;
  }
  
//

  + (SBInetAddress*) inetAddressWithString:(SBString*)aString
  {
    SBSTRING_AS_UTF8_BEGIN(aString)
    
      return [SBInetAddress inetAddressWithCString:aString_utf8];
    
    SBSTRING_AS_UTF8_END
  }

//

  - (BOOL) isEqual:(id)anObject
  {
    if ( [anObject isKindOf:[SBInetAddress class]] ) {
      return [self isEqualToInetAddress:(SBInetAddress*)anObject];
    }
    return NO;
  }

//

  - (SBInetAddressFamily) addressFamily
  {
    return kSBInetAddressUnknownFamily;
  }

//

  - (unsigned int) prefixBitLength
  {
    return 0;
  }

//

  - (unsigned int) totalBitLength
  {
    return 0;
  }

//

  - (unsigned int) byteLength
  {
    return 0;
  }

//

  - (BOOL) isEqualToInetAddress:(SBInetAddress*)anotherAddress
  {
    return ( [self compareToInetAddress:anotherAddress] == SBOrderSame );
  }
  
//

  - (SBComparisonResult) compareToInetAddress:(SBInetAddress*)anotherAddress
  {
    if ( ([self addressFamily] == [anotherAddress addressFamily]) ) {
      unsigned int      p1 = [self prefixBitLength];
      unsigned int      p2 = [anotherAddress prefixBitLength];
      
      if ( p1 == p2 ) {
        size_t            byteLength = [self byteLength];
        
        if ( byteLength ) {
          unsigned char   b1[byteLength];
          unsigned char   b2[byteLength];
          int             cmp;
          
          [self copyMaskedAddressBytes:b1 length:byteLength];
          [anotherAddress copyMaskedAddressBytes:b2 length:byteLength];
          
          cmp = memcmp(b1, b2, byteLength);
          
          if ( cmp < 0 )
            return SBOrderAscending;
          if ( cmp > 0 )
            return SBOrderDescending;
        }
      } else if ( p1 < p2 ) {
        return SBOrderAscending;
      } else if ( p1 > p2 ) {
        return SBOrderDescending;
      }
      return SBOrderSame;
    }
    return ([self addressFamily] - [anotherAddress addressFamily]);
  }

//

  - (size_t) copyAddressBytes:(void*)buffer
    length:(size_t)length
  {
    return 0;
  }
  
//

  - (size_t) copyMaskedAddressBytes:(void*)buffer
    length:(size_t)length
  {
    size_t    copied = [self copyAddressBytes:buffer length:length];
    
    if ( copied > 0 ) {
      unsigned char*  BUFFER = (unsigned char*)buffer;
      unsigned char   mask = 0xFF;
      int             prefixBits = [self prefixBitLength];
      int             idx = 0;
      
      do {
        if ( mask && (prefixBits < 8) ) {
          mask <<= (8 - prefixBits);
        }
        BUFFER[idx] &= mask;
        if ( (prefixBits -= 8) <= 0 ) {
          mask = 0x00;
          prefixBits = 0;
        }
      } while ( ++idx < copied );
    }
  }
  
//

  - (BOOL) setSockAddr:(struct sockaddr*)sockAddr
    byteSize:(size_t)byteSize
  {
    return NO;
  }
  
//

  - (SBString*) inetAddressAsString
  {
    return nil;
  }
  
//

  - (SBData*) inetAddressAsData
  {
    size_t            byteLength = [self byteLength];
    SBData*           result = nil;
    
    if ( byteLength ) {
      size_t                addressDataLen = sizeof(SBInetAddressData) + byteLength - 1;
      SBInetAddressData*    addressData = (SBInetAddressData*)objc_malloc(addressDataLen);
      
      if ( addressData ) {
        addressData->family = [self addressFamily];
        addressData->totalBitLength = [self totalBitLength];
        addressData->prefixBitLength = [self prefixBitLength];
        [self copyAddressBytes:&addressData->bytes[0] length:byteLength];
        
        result = [SBData dataWithBytesNoCopy:addressData length:addressDataLen freeWhenDone:YES];
      }
    }
    return result;
  }

@end

//
#pragma mark -
//

@implementation __SBIPv4Address

  - (id) init
  {
    if ( self = [super init] ) {
      _prefix = 32;
    }
    return self;
  }
  - (id) initWithBytes:(const void*)bytes
  {
    if ( self = [self init] ) {
      memcpy(_bytes, bytes, 4);
    }
    return self;
  }
  - (id) initWithBytes:(const void*)bytes
    prefixLength:(unsigned int)prefixLength
  {
    if ( self = [self init] ) {
      memcpy(_bytes, bytes, 4);
      _prefix = ( prefixLength <= 32 ? prefixLength : 32 );
    }
    return self;
  }
  
//

  - (SBInetAddressFamily) addressFamily
  {
    return kSBInetAddressIPv4Family;
  }
  
//

  - (unsigned int) prefixBitLength
  {
    return _prefix;
  }

//

  - (unsigned int) totalBitLength
  {
    return 32;
  }

//

  - (unsigned int) byteLength
  {
    return 4;
  }

//

  - (size_t) copyAddressBytes:(void*)buffer
    length:(size_t)length
  {
    memcpy(buffer, _bytes, ( length = ( length < 4 ? length : 4 ) ) );
    return length;
  }
  
//

  - (BOOL) setSockAddr:(struct sockaddr*)sockAddr
    byteSize:(size_t)byteSize
  {
    if ( byteSize >= sizeof(struct sockaddr_in) ) {
      struct sockaddr_in*     SOCKADDR = (struct sockaddr_in*)sockAddr;
      
      SOCKADDR->sin_family = AF_INET;
      [self copyAddressBytes:&SOCKADDR->sin_addr length:sizeof(struct in_addr)];
      
      return YES;
    }
    return NO;
  }
  
//

  - (SBString*) inetAddressAsString
  {
    if ( _prefix < 32 )
      return [SBString stringWithFormat:"%u.%u.%u.%u/%u",
                          _bytes[0],
                          _bytes[1],
                          _bytes[2],
                          _bytes[3],
                          _prefix
                        ];
    return [SBString stringWithFormat:"%u.%u.%u.%u",
                        _bytes[0],
                        _bytes[1],
                        _bytes[2],
                        _bytes[3]
                      ];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
      stream,
      " {\n"
      "  prefix:   %u\n"
      "  bytes:    %02hhx%02hhx%02hhx%02hhx\n"
      "}\n",
      _prefix,
      _bytes[0], _bytes[1], _bytes[2], _bytes[3]
    );
  }
  
@end

//
#pragma mark -
//

@implementation __SBIPv6Address

  - (id) init
  {
    if ( self = [super init] ) {
      _prefix = 128;
    }
    return self;
  }
  - (id) initWithBytes:(const void*)bytes
  {
    if ( self = [self init] ) {
      memcpy(_bytes, bytes, 16);
    }
    return self;
  }
  - (id) initWithBytes:(const void*)bytes
    prefixLength:(unsigned int)prefixLength
  {
    if ( self = [self init] ) {
      memcpy(_bytes, bytes, 16);
      _prefix = ( prefixLength <= 128 ? prefixLength : 128 );
    }
    return self;
  }
  
//

  - (SBInetAddressFamily) addressFamily
  {
    return kSBInetAddressIPv6Family;
  }
  
//

  - (unsigned int) prefixBitLength
  {
    return _prefix;
  }

//

  - (unsigned int) totalBitLength
  {
    return 128;
  }

//

  - (unsigned int) byteLength
  {
    return 16;
  }

//

  - (size_t) copyAddressBytes:(void*)buffer
    length:(size_t)length
  {
    memcpy(buffer, _bytes, ( length = ( length < 16 ? length : 16 ) ) );
    return length;
  }

//

  - (BOOL) setSockAddr:(struct sockaddr*)sockAddr
    byteSize:(size_t)byteSize
  {
    if ( byteSize >= sizeof(struct sockaddr_in6) ) {
      struct sockaddr_in6*    SOCKADDR = (struct sockaddr_in6*)sockAddr;
      
      SOCKADDR->sin6_family = AF_INET6;
      [self copyAddressBytes:&SOCKADDR->sin6_addr length:sizeof(struct in6_addr)];
      
      return YES;
    }
    return NO;
  }

//

  - (SBString*) inetAddressAsString
  {
    struct sockaddr_in6     saddr;
    
    if ( [self setSockAddr:(struct sockaddr*)&saddr byteSize:sizeof(saddr)] ) {
      char                  pform[256];
      const char*           ok;
      
      ok = inet_ntop(
              AF_INET6,
              (struct sockaddr*)&saddr,
              pform,
              sizeof(pform)
            );
      if ( ok != NULL ) {
        if ( _prefix < 128 )
          return [SBString stringWithFormat:"%s/%u",
                              pform,
                              _prefix
                            ];
        return [SBString stringWithUTF8String:pform];
      }
    }
    return nil;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    int   i = 0;
    
    [super summarizeToStream:stream];
    fprintf(
      stream,
      " {\n"
      "  prefix:   %u\n"
      "  bytes:    ",
      _prefix
    );
    while ( i < 16 )
      fprintf(stream, "%02hhx", _bytes[i++]);
    fprintf(stream, "\n}\n");
  }

@end
