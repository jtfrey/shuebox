//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBPostgresAdditions.m
//
// Postgres-oriented category additions to SBFoundation classes.
//
// $Id$
//

#import "SBPostgresAdditions.h"
#import "SBNotorization.h"
#import "SBString.h"
#import "SBInetAddress.h"
#import "SBPostgres.h"
#include "SBPostgresPrivate.h"

//

@implementation SBDate(SBPostgresAdditions)

  + (SBDate*) dateWithPostgresTimestamp:(int64_t)pgTimestamp
  {
    // Convert the Postgres timestamp to a UNIX timestamp:
    time_t    unixTimestamp = pgTimestamp + (int64_t)PostgresEpochShift;
    
    return [SBDate dateWithUnixTimestamp:unixTimestamp];
  }
  
//

  - (int64_t) postgresTimestamp
  {
    return ( ((int64_t)[self unixTimestamp]) - (int64_t)PostgresEpochShift );
  }

@end

//
#pragma mark -
//

static inline void*
__SBPostgresBinaryEndode_BeginRecord(
  void*       buffer,
  int         fieldCount
)
{
  SBByteSwapToNetwork(&fieldCount, sizeof(int), buffer); buffer += sizeof(int);
  
  return buffer;
}

//

static inline int
__SBPostgresBinaryDecode_BeginRecord(
  void**      buffer
)
{
  int         fieldCount;
  
  SBByteSwapFromNetwork(*buffer, sizeof(int), &fieldCount);
  *buffer += sizeof(int);
  
  return fieldCount;
}

//

static inline void*
__SBPostgresBinaryEncode_BeginRecordField(
  void*       buffer,
  Oid         typeOid,
  int         byteSize
)
{
  SBByteSwapToNetwork(&typeOid, sizeof(Oid), buffer); buffer += sizeof(Oid);
  SBByteSwapToNetwork(&byteSize, sizeof(int), buffer); buffer += sizeof(int);
  
  return buffer;
}

//

static inline void
__SBPostgresBinaryDecode_BeginRecordField(
  void**      buffer,
  Oid*        typeOid,
  int*        byteSize
)
{
  SBByteSwapToNetwork(*buffer, sizeof(Oid), typeOid); *buffer += sizeof(Oid);
  SBByteSwapToNetwork(*buffer, sizeof(int), byteSize); *buffer += sizeof(int);
}

//

@implementation SBNotorization(SBPostgresSerialization)

  - (id) initWithPostgresBinaryData:(const void*)binaryData
    length:(SBUInteger)length
  {
    unsigned char*    value = (unsigned char*)binaryData;
    unsigned char*    endValue = value + length;
    
    if ( __SBPostgresBinaryDecode_BeginRecord((void**)&value) == 3 ) {
      SBString*         userId = nil;
      SBInetAddress*    fromAddress = nil;
      SBDate*           timestamp = nil;
    
      while ( value < endValue ) {
        Oid             fieldType;
        int             fieldLength;
        
        __SBPostgresBinaryDecode_BeginRecordField((void**)&value, &fieldType, &fieldLength);
        switch ( fieldType ) {
        
          case VARCHAROID: {
            userId = [SBString stringWithUTF8String:value length:fieldLength];
            break;
          }
          
          case TIMESTAMPTZOID: {
#if defined(HAVE_INT64_TIMESTAMP)
            int64_t           pgTimestamp;
#else
            double            pgTimestamp;
#endif
            if ( fieldLength == sizeof(pgTimestamp) ) {
              SBInSituByteSwapFromNetwork(value, fieldLength);
#if defined(HAVE_INT64_TIMESTAMP)
              timestamp = [SBDate dateWithPostgresTimestamp:*((int64_t*)value)];
#else
              timestamp = [SBDate dateWithPostgresTimestamp:*((double*)value)];
#endif
            }
            break;
          }
        
          case INETOID: {
            switch ( *((unsigned char*)value) ) {
              
              case PGSQL_AF_INET:
                fromAddress = [SBInetAddress inetAddressWithIPv4Bytes:value + 4];
                break;
              
              case PGSQL_AF_INET6:
                fromAddress = [SBInetAddress inetAddressWithIPv6Bytes:value + 4];
                break;
              
            }
            break;
          }
          
        }
        value += fieldLength;
      }
      
      self = [self initWithUserId:userId fromAddress:fromAddress withTimestamp:timestamp];
    } else {
      [self release];
      self = nil;
    }
    return self;
  }

//

  - (BOOL) encodePostgresBinaryData:(void**)buffer
    length:(SBUInteger*)length
    usingPool:(SBMemoryPoolRef)pool
  {
    SBString*       userId = [self userId];
    SBInetAddress*  fromAddress = [self fromAddress];
    SBDate*         timestamp = [self timestamp];
    unsigned char*  ptr = NULL;
    size_t          bytes = sizeof(int) + 3 * sizeof(Oid) + 3 * sizeof(int);
    int             userLen, timeLen, ipLen;
    
    // Add the byte length of the userId:
    if ( userId )
      bytes += (userLen = [userId utf8Length]);
    else
      bytes += (userLen = 6);
    
    // Add the size of the address:
    bytes += (ipLen = 4 + ( fromAddress ? [fromAddress byteLength] : 4 ));
    
    // Add the size of the timestamp:
#if defined(HAVE_INT64_TIMESTAMP)
    bytes += (timeLen = sizeof(int64_t));
#else
    bytes += (timeLen = sizeof(double));
#endif

    *buffer = ptr = (unsigned char*)SBMemoryPoolCalloc(pool, bytes);
    if ( ptr ) {
      *length = bytes;
      
      // Encode the sub-field count:
      ptr = __SBPostgresBinaryEndode_BeginRecord(ptr, 3);
      
      // Encode the (VARCHAROID, strlen(s), s) triplet:
      ptr = __SBPostgresBinaryEncode_BeginRecordField(ptr, VARCHAROID, userLen);
      if ( userId )
        [userId copyUTF8CharactersToBuffer:ptr length:userLen];
      else
        strncpy(ptr, "system", 6);
      ptr += userLen;
      
      // Encode the (INETOID, sizeof(INET), INET) triplet:
      ptr = __SBPostgresBinaryEncode_BeginRecordField(ptr, INETOID, ipLen);
      *ptr++ = ( fromAddress ? ( [fromAddress addressFamily] == kSBInetAddressIPv4Family ? PGSQL_AF_INET : PGSQL_AF_INET6 ) : PGSQL_AF_INET );
      *ptr++ = 32;  // prefix length
      *ptr++ = 0;   // is cidr?
      *ptr++ = ( fromAddress ? [fromAddress byteLength] : 4 );
      if ( fromAddress ) {
        [fromAddress copyMaskedAddressBytes:(void*)ptr length:[fromAddress byteLength]];
        ptr += [fromAddress byteLength];
      } else {
        *ptr++ = 127;
        *ptr++ = 0;
        *ptr++ = 0;
        *ptr++ = 1;
      }
      
      // Encode the (TIMESTAMPTZOID, sizeof(TIMESTAMP), TIMESTAMP) triplet:
      ptr = __SBPostgresBinaryEncode_BeginRecordField(ptr, TIMESTAMPTZOID, timeLen);
#if defined(HAVE_INT64_TIMESTAMP)
      *((int64_t*)ptr) = (int64_t)[timestamp unixTimestamp] - PostgresEpochShift;
      SBInSituByteSwapToNetwork((void*)ptr, sizeof(int64_t));
#else
      *((double*)ptr) = (double)[timestamp unixTimestamp] - PostgresEpochShift;
      SBInSituByteSwapToNetwork((void*)ptr, sizeof(double));
#endif
      return YES;
    }
    return NO;
  }

@end
