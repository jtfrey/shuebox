//
// SBFoundation : ObjC Class Library for Solaris
// SBUUID.m
//
// Wrap a universally-unique identifier (UUID).
//
// Copyright (c) 2008
// University of Delaware
//
// $Id$
//

#import "SBUUID.h"
#import "SBString.h"

@implementation SBUUID

  + (SBUUID*) uuid
  {
    return [[[SBUUID alloc] init] autorelease];
  }
  
//

  + (SBUUID*) uuidWithBytes:(void*)uuidBytes
  {
    return [[[SBUUID alloc] initWithBytes:uuidBytes] autorelease];
  }
  
//

  + (SBUUID*) uuidWithUUID:(SBUUID*)aUUID
  {
    return [[[SBUUID alloc] initWithUUID:aUUID] autorelease];
  }
  
//

  + (SBUUID*) uuidWithString:(SBString*)aString
  {
    SBSTRING_AS_UTF8_BEGIN(aString)
      return [self uuidWithUTF8String:aString_utf8];
    SBSTRING_AS_UTF8_END
    return nil;
  }
  
//

  + (SBUUID*) uuidWithUTF8String:(const char*)aCString
  {
    uuid_t      uuid;
    
    if ( uuid_parse((char*)aCString, uuid) == 0 ) {
      return [[[SBUUID alloc] initWithBytes:uuid] autorelease];
    }
    return nil;
  }

//

  - (id) init
  {
    if ( self = [super init] ) {
      uuid_generate(_uuid);
    }
    return self;
  }
  
//

  - (id) initWithBytes:(void*)uuidBytes
  {
    if ( self = [super init] ) {
      memcpy(_uuid, uuidBytes, sizeof(uuid_t));
    }
    return self;
  }
  
//

  - (id) initWithUUID:(SBUUID*)aUUID
  {
    if ( self = [super init] ) {
      [aUUID getUUIDBytes:_uuid];
    }
    return self;
  }
  
//

  - (id) initWithString:(SBString*)aString
  {
    SBSTRING_AS_UTF8_BEGIN(aString)
      self = [self initWithUTF8String:aString_utf8];
    SBSTRING_AS_UTF8_END
    
    return self;
  }
  
//

  - (id) initWithUTF8String:(const char*)aCString
  {
    if ( self = [super init] ) {
      if ( uuid_parse((char*)aCString, _uuid) != 0 ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[SBUUID class]] )
      return ( [self compareToUUID:otherObject] == SBOrderSame );
    return NO;
  }

//

  - (unsigned int) hash
  {
    unsigned int*   as32Bit = (unsigned int*)&_uuid;
    unsigned int    hashVal = as32Bit[0];
    
    hashVal <<= 17;
    hashVal ^= as32Bit[1];
    hashVal <<= 13;
    hashVal ^= as32Bit[2];
    hashVal <<= 11;
    hashVal ^= as32Bit[3];
    
    return hashVal;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    char        asString[UUID_PRINTABLE_STRING_LENGTH];
    
    [super summarizeToStream:stream];
    uuid_unparse(_uuid, asString);
    fprintf(stream, " { %s }\n", asString);
  }
  
//

  - (id) copy
  {
    return [[SBUUID alloc] initWithUUID:self];
  }

//

  - (void) getUUIDBytes:(void*)uuid
  {
    memcpy(uuid, _uuid, sizeof(uuid_t));
  }
  
//

  - (BOOL) isNull
  {
    return ( uuid_is_null(_uuid) != 0 );
  }
  
//

  - (SBComparisonResult) compareToUUID:(SBUUID*)anotherUUID
  {
    uuid_t      altUUID;
    int         cmp;
    
    if ( anotherUUID == self )
      return SBOrderSame;
      
    [anotherUUID getUUIDBytes:altUUID];
    cmp = uuid_compare(_uuid, altUUID);
    if ( cmp < 0 )
      return SBOrderAscending;
    if ( cmp > 0 )
      return SBOrderDescending;
    return SBOrderSame;
  }

//

  - (SBString*) asString
  {
    char        buffer[UUID_PRINTABLE_STRING_LENGTH];
    
    uuid_unparse(_uuid, buffer);
    return [SBString stringWithUTF8String:buffer];
  }

@end
