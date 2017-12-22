//
// scruffy : maintenance scheduler daemon for SHUEBox
// SBMACAddress.m
//
// Class which handles MAC addresses.  Lots borrowed from my ieee-oui code
// for MAC-to-Manuf resolution.
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBMACAddress.h"
#import "SBString.h"


const char*     __SBMACAddressStringFormat[] = {
                      "%1$02hhx%7$c%2$02hhx%7$c%3$02hhx%7$c%4$02hhx%7$c%5$02hhx%7$c%6$02hhx",
                      "%1$02hhx%2$02hhx%7$c%3$02hhx%4$02hhx%7$c%5$02hhx%6$02hhx",
                      "%1$02hhx%2$02hhx%3$02hhx%7$c%4$02hhx%5$02hhx%6$02hhx",
                      "%02hhx%02hhx%02hhx%02hhx%02hhx%02hhx"
                    };
                    
//
#pragma mark -
//

@interface SBMACAddress(SBMACAddressPrivate)

- (unsigned char*) macBytes;

@end

@implementation SBMACAddress(SBMACAddressPrivate)

  - (unsigned char*) macBytes
  {
    return _bytes;
  }

@end

//
#pragma mark -
//

@implementation SBMACAddress

  + (SBMACAddress*) macAddressWithBytes:(const void*)bytes
  {
    if ( bytes == NULL )
      return nil;
    return [[[SBMACAddress alloc] initWithBytes:bytes] autorelease];
  }

//

  + (SBMACAddress*) macAddressWithCString:(const char*)cString
  {
    if ( cString == NULL )
      return nil;
    return [[[SBMACAddress alloc] initWithCString:cString] autorelease];
  }
  
//

  + (SBMACAddress*) macAddressWithString:(SBString*)aString
  {
    if ( aString == nil )
      return nil;
    return [[[SBMACAddress alloc] initWithString:aString] autorelease];
  }

//

  - (id) initWithBytes:(const void*)macBytes
  {
    if ( self = [super init] ) {
      memcpy(_bytes, macBytes, 6);
    }
    return self;
  }

//

  - (id) initWithCString:(const char*)cString
  {
    if ( self = [super init] ) {
      unsigned char   byte = 0, bytes[6];
      int             i = 0,n;
      char            digit, prevDigit = 0;
      char*           s = (char*)cString;
      
      digit = *s++;
      while ( i < 6 ) {
        char          value = 0;
        char          found = 0;
        char          force = 0;
        
        switch ( digit ) {
        
          case '0':
          case '1':
          case '2':
          case '3':
          case '4':
          case '5':
          case '6':
          case '7':
          case '8':
          case '9':
            value = digit - '0';
            found = 1;
            break;
        
          case 'A':
          case 'B':
          case 'C':
          case 'D':
          case 'E':
          case 'F':
            value = 10 + (digit - 'A');
            found = 1;
            break;
        
          case 'a':
          case 'b':
          case 'c':
          case 'd':
          case 'e':
          case 'f':
            value = 10 + (digit - 'a');
            found = 1;
            break;
          
          default:
            if ( prevDigit ) {
              found = 1;
              force = 1;
            } else {
              prevDigit = 0;
              byte = 0;
            }
            break;
        }
        if ( found ) {
          if ( prevDigit || force ) {
            bytes[i++] = ( force ? byte : (byte << 4) | value );
            prevDigit = 0;
            byte = 0;
          } else {
            byte = value;
            prevDigit = digit;
          }
        }
        
        if ( digit == '\0' )
          break;
          
        digit = *s++;
      }
      
      if ( i > 0 ) {
        /* We got _at least_ one byte out of the string, so let's make an
           object: */
        while ( i < 6 )
          bytes[i++] = 0;
        memcpy(_bytes, bytes, 6);
      } else {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithString:(SBString*)aString
  {
    SBSTRING_AS_UTF8_BEGIN(aString)
      return [self initWithCString:aString_utf8];
    SBSTRING_AS_UTF8_END
  }

//

  - (BOOL) isEqual:(id)anObject
  {
    if ( [anObject isKindOf:[SBMACAddress class]] ) {
      return [self isEqualToMACAddress:anObject];
    }
    return NO;
  }

//

  - (BOOL) isEqualToMACAddress:(SBMACAddress*)aMACAddr
  {
    return ( [self compareToMACAddress:aMACAddr] == SBOrderSame );
  }
  
//

  - (SBComparisonResult) compareToMACAddress:(SBMACAddress*)aMACAddr
  {
    int     cmp = memcmp(_bytes, [aMACAddr macBytes], 6);
    
    if ( cmp < 0 )
      return SBOrderDescending;
    if ( cmp > 0 )
      return SBOrderAscending;
    return SBOrderSame;
  }

//

  - (size_t) copyAddressBytes:(unsigned char*)buffer
    length:(size_t)length
  {
    memcpy(buffer, _bytes, ( length = ( length <= 6 ? length : 6 ) ));
    return length;
  }
  
//

  - (SBString*) macAddressAsStringWithFormat:(SBMACAddressFormat)format
  {
    char            cString[18];
    char            delimiter = ' ';
    
    switch ( format & 0xF ) {
      case SBMACAddressColonDelimFormat:
        delimiter = ':';
        break;
      case SBMACAddressHyphenDelimFormat:
        delimiter = '-';
        break;
      case SBMACAddressDotDelimFormat:
        delimiter = '.';
        break;
    }
    snprintf(
        (char*)cString,
        18,
        __SBMACAddressStringFormat[(format >> 4) & 0xF],
        _bytes[0],
        _bytes[1],
        _bytes[2],
        _bytes[3],
        _bytes[4],
        _bytes[5],
        delimiter
      );
    return [SBString stringWithUTF8String:cString];
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    int   i = 0;
    
    [super summarizeToStream:stream];
    fprintf(
      stream,
      " {\n"
      "    "
    );
    while ( i < 6 )
      fprintf(stream, "%02hhx", _bytes[i++]);
    fprintf(stream, "\n  }\n");
  }

@end

//
#pragma mark -
//

#ifdef WANT_EXTENDED_SBMACADDRESS

#include "sqlite3.h"

/*!
  @constant SBMACAddressOUIDatabase
  
  Our database of IEEE OUI registrations.
*/
const char*       SBMACAddressOUIDatabase = "/opt/local/SHUEBox/SBFoundation/data/ieee-oui.sqlite3db";

/**/

sqlite3*
__SBMACAddressOUIDBOpen()
{
  static sqlite3*   SBMACAddressOUIDBHandle = NULL;
  
  if ( SBMACAddressOUIDBHandle == NULL ) {
    int             rc = sqlite3_open_v2(
                              SBMACAddressOUIDatabase,
                              &SBMACAddressOUIDBHandle,
                              SQLITE_OPEN_READONLY,
                              NULL
                            );
    
    if ( rc ) {
      fprintf(
          stderr,
          "Unable to open the IEEE OUI database (%s): %s\n",
          sqlite3_errmsg(SBMACAddressOUIDBHandle),
          SBMACAddressOUIDatabase
        );
      sqlite3_close(SBMACAddressOUIDBHandle);
      SBMACAddressOUIDBHandle = NULL;
    }
  }
  return SBMACAddressOUIDBHandle;
}

/**/

int
__SBMACAddressOUIDBMACSearch(
  unsigned char*    macBytes,
  char*             manufStr,
  size_t            manufStrLen
)
{
  static sqlite3_stmt*    byMACQuery = NULL;
  
  sqlite3*    dbH = __SBMACAddressOUIDBOpen();
  
  if ( dbH ) {
    int       rc;
    char*     dummy;
    
    if ( byMACQuery == NULL ) {
      rc = sqlite3_prepare_v2(
              dbH,
              "SELECT manufacturer FROM macAddrOUI WHERE macPrefix = ?1",
              -1,
              &byMACQuery,
              (const char**)&dummy
            );
      if ( rc != SQLITE_OK ) {
        if ( byMACQuery ) {
          sqlite3_finalize(byMACQuery);
          byMACQuery = NULL;
        }
      }
    }
    if ( byMACQuery ) {
      rc = sqlite3_reset(byMACQuery);
      if ( rc == SQLITE_OK ) {
        char      prefix[9];
        
        snprintf(
            prefix,
            9,
            "%02hhx:%02hhx:%02hhx",
            macBytes[0],
            macBytes[1],
            macBytes[2]
          );
        rc = sqlite3_bind_text(byMACQuery, 1, prefix, -1, SQLITE_STATIC);
        if ( rc == SQLITE_OK ) {
          rc = sqlite3_step(byMACQuery);
          if ( rc == SQLITE_ROW ) {
            strncpy(manufStr, (char*)sqlite3_column_text(byMACQuery, 0), manufStrLen);
            return 1;
          }
        }
      }
    }
  }
  return 0;
}

@implementation SBMACAddress(SBMACAddressManufacturerLookup)

  - (SBString*) manufacturerName
  {
    char          manufStr[256];
    
    if ( __SBMACAddressOUIDBMACSearch(_bytes, manufStr, 256) )
      return [SBString stringWithUTF8String:manufStr];
    return nil;
  }

@end

#endif /* WANT_EXTENDED_SBMACADDRESS */
