//
// SBFoundation : ObjC Class Library for Solaris
// SBPropertyList.m
//
// Serialization of core types
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBPropertyList.h"

#import "SBString.h"
#import "SBValue.h"
#import "SBData.h"
#import "SBDate.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBError.h"
#import "SBStream.h"
#import "SBScanner.h"
#import "SBDateFormatter.h"
#import "SBTimeZone.h"

#import "SBXMLParser.h"

typedef enum {
  kSBPropertyListObjectTypeDocument       = 0, // 1    0x001
  kSBPropertyListObjectTypePList          = 1, // 2    0x002
  kSBPropertyListObjectTypeDictionary     = 2, // 4    0x004
  kSBPropertyListObjectTypeArray          = 3, // 8    0x008
  kSBPropertyListObjectTypeString         = 4, // 16   0x010
  kSBPropertyListObjectTypeData           = 5, // 32   0x020
  kSBPropertyListObjectTypeDate           = 6, // 64   0x040
  kSBPropertyListObjectTypeInteger        = 7, // 128  0x080
  kSBPropertyListObjectTypeReal           = 8, // 256  0x100
  kSBPropertyListObjectTypeTrue           = 9, // 512  0x200
  kSBPropertyListObjectTypeFalse          = 10,// 1024 0x400
  //
  kSBPropertyListObjectTypeDictionaryKey  = 11 // 2048 0x800
  //
} SBPropertyListObjectType;

SBPropertyListObjectType      SBPropertyListSubTypes[12] = {
                                          0x00000002U,
                                          0x000007fcU,
                                          0x00000ffcU,
                                          0x000007fcU,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U,
                                          0x00000000U
                                };
//

@interface SBDateFormatter(SBPropertyListAdditions)

+ (SBDateFormatter*) propertyListDateFormatter;
  
@end

@implementation SBDateFormatter(SBPropertyListAdditions)

  + (SBDateFormatter*) propertyListDateFormatter
  {
    static SBDateFormatter* __propertyListDateFormatter = nil;
    
    if ( ! __propertyListDateFormatter ) {
      if ( (__propertyListDateFormatter = [[SBDateFormatter alloc] init]) ) {
        [__propertyListDateFormatter setPattern:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [__propertyListDateFormatter setTimeZone:[SBTimeZone utcTimeZone]];
      }
    }
    return __propertyListDateFormatter;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBData(SBPropertyListAdditions)

+ (id) dataWithPropertyListRepresentation:(SBString*)base64Data;
- (SBString*) propertyListRepresentation;

@end

@implementation SBData(SBPropertyListAdditions)

  + (id) dataWithPropertyListRepresentation:(SBString*)base64Data
  {
    // Determine how large the data will be:
    id                dataObj = nil;
    SBUInteger        size = [base64Data length];
    SBUInteger        bytes = 3 * size;
    unsigned char*    buffer = NULL;
    
    bytes = (bytes / 4) + ((bytes % 4) ? 3 : 0);
    
    if ( [self isKindOf:[SBMutableData class]] ) {
      if ( (dataObj = [SBMutableData dataWithLength:bytes]) )
        buffer = [dataObj mutableBytes];
    } else {
      buffer = malloc(bytes);
    }
    if ( buffer ) {
      // Decode the base64 data:
      SBUInteger      i = 0;
      SBUInteger      I = 0;
      
      while ( i < size ) {
        UChar         chunk[4] = { 64, 64, 64, 64 };
        int           j = 0;
        
        // Fill the next 4-byte chunk:
        while ( i < size && j < 4 ) {
          chunk[j] = [base64Data characterAtIndex:i++];
          
          int         k = 0;
          
          while ( k <= 64 ) {
            if ( chunk[j] == SBBase64CharSet[k] ) {
              chunk[j] = k;
              break;
            }
            k++;
          }
          j++;
        }
        
        // Decode the chunk:
        j = 0;
        buffer[I++] = (chunk[0] << 2) | ((chunk[1] >> 4) & 0x3);
        if ( chunk[2] < 64 ) {
          buffer[I++] = ((chunk[1] & 0xF) << 4) | ((chunk[2] >> 2) & 0xF);
          if ( chunk[3] < 64 ) {
            buffer[I++] = ((chunk[2] & 0x3) << 6) | (chunk[3] & 0x3F);
          }
        }
      }
      
      if ( I > 0 ) {
        if ( [self isKindOf:[SBMutableData class]] ) {
          [dataObj setLength:I];
        } else {
          dataObj = [SBData dataWithBytesNoCopy:buffer length:I freeWhenDone:YES];
        }
      } else {
        if ( [self isKindOf:[SBMutableData class]] ) {
          [dataObj release];
          dataObj = NULL;
        } else {
          free(buffer);
        }
      }
    }
    return dataObj;
  }

//

  - (SBString*) propertyListRepresentation
  {
    unsigned char*      ptr = (unsigned char*)[self bytes];
    SBUInteger          byteLen = [self length];
    SBMutableString*    plistRep = nil;
      
    while ( byteLen > 0 ) {
      // Next 3 bytes:
      UChar     chunk[4];
      
      chunk[0] = (ptr[0] & 0xFC) >> 2;
      if ( byteLen > 1 ) {
        chunk[1] = ((ptr[0] & 0x03) << 4) | ((ptr[1] & 0xF0) >> 4);
        if ( byteLen > 2 ) {
          chunk[2] = ((ptr[1] & 0x0F) << 2) | ((ptr[2] & 0xC0) >> 6);
          chunk[3] = ptr[2] & 0x3F;
          ptr += 3;
          byteLen -= 3;
        } else {
          chunk[2] = (ptr[1] & 0x0F) << 2;
          chunk[3] = 64;
          ptr += 2;
          byteLen -= 2;
        }
      } else {
        chunk[1] = (ptr[0] & 0x03) << 4;
        chunk[2] = 64;
        chunk[3] = 64;
        ptr++;
        byteLen--;
      }
      if ( ! plistRep ) {
        plistRep = [[SBMutableString alloc] init];
      }
      chunk[0] = SBBase64CharSet[chunk[0]];
      chunk[1] = SBBase64CharSet[chunk[1]];
      chunk[2] = SBBase64CharSet[chunk[2]];
      chunk[3] = SBBase64CharSet[chunk[3]];
      [plistRep appendCharacters:chunk length:4];
    }
    
    SBString*     outRep = nil;
    
    if ( plistRep ) {
      outRep = [plistRep copy];
      [plistRep release];
    }
    return outRep;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBPropertyListParseContext : SBObject<SBXMLParserDelegate>
{
  SBXMLParser*                    _parser;
  SBPropertyListParseContext*     _parentContext;
  SBPropertyListObjectType        _objectType;
  SBPropertyListMutabilityOptions _mutability;
  id                              _parsedObject;
  SBMutableString*                _textBuffer;
  id                              _subObject;
}

- (id) initWithParser:(SBXMLParser*)parser objectType:(SBPropertyListObjectType)objectType mutability:(SBPropertyListMutabilityOptions)mutability;

- (SBPropertyListObjectType) objectType;
- (id) parsedObject;

- (void) subObjectParsingCompleted;

@end

//

@implementation SBPropertyListParseContext

  - (id) initWithParser:(SBXMLParser*)parser
    objectType:(SBPropertyListObjectType)objectType
    mutability:(SBPropertyListMutabilityOptions)mutability
  {
    if ( (self = [super init]) ) {
      _parser = parser;
      _parentContext = [parser delegate];
      [parser setDelegate:self];
      //
      _objectType = objectType;
      _mutability = mutability;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _parentContext )
      [_parser setDelegate:_parentContext];
    if ( _parsedObject )
      [_parsedObject release];
    if ( _textBuffer )
      [_textBuffer release];
    [super dealloc];
  }

//

  - (SBPropertyListObjectType) objectType
  {
    return _objectType;
  }
  - (id) parsedObject
  {
    return _parsedObject;
  }
  
//

  - (void) subObjectParsingCompleted
  {
    switch ( _objectType ) {
    
      case kSBPropertyListObjectTypeDocument: {
        // Our value is that of the underlying plist:
        if ( _subObject )
          _parsedObject = [[_subObject parsedObject] retain];
          
        // No more parsing necessary:
        [_parser setDelegate:nil];
        break;
      }
      
      case kSBPropertyListObjectTypePList: {
        // Our value is that of our sub-object:
        if ( _subObject )
          _parsedObject = [[_subObject parsedObject] retain];
        break;
      }
      
      case kSBPropertyListObjectTypeDictionary: {
        switch ( [_subObject objectType] ) {
        
          case kSBPropertyListObjectTypeDictionaryKey: {
            if ( _textBuffer ) {
              [_textBuffer release];
              _textBuffer = nil;
            }
            _textBuffer = (SBMutableString*)[[_subObject parsedObject] copy];
            break;
          }
          
          default: {
            id      subObj = [_subObject parsedObject];
            
            if ( _textBuffer && subObj ) {
              if ( ! _parsedObject )
                _parsedObject = [[SBMutableDictionary alloc] init];
              [_parsedObject setObject:subObj forKey:_textBuffer];
              [_textBuffer release];
              _textBuffer = nil;
            } else {
              // Parse error -- no <key> preceding object or no object:
              [_parser abortParsing];
            }
            break;
          }
          
        }
        break;
      }
      
      case kSBPropertyListObjectTypeArray: {
        id      subObj = [_subObject parsedObject];
            
        if ( subObj ) {
          if ( ! _parsedObject )
            _parsedObject = [[SBMutableArray alloc] init];
          [_parsedObject addObject:subObj];
        } else {
          // Parse error -- no object:
          [_parser abortParsing];
        }
        break;
      }
    }
    [_subObject release];
    _subObject = nil;
  }

//

  - (void) xmlParser:(SBXMLParser*)parser
    didStartElement:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
    qualifiedName:(SBString*)qualifiedName
    attributes:(SBDictionary*)attributes
  {
    SBPropertyListObjectType      validSubTypes = SBPropertyListSubTypes[_objectType];
    SBPropertyListObjectType      subType = 0;
    
    // What kind of element are we starting to parse?
    if ( [elementName isEqual:@"plist"] ) {
      subType = kSBPropertyListObjectTypePList;
    }
    else if ( [elementName isEqual:@"dict"] ) {
      subType = kSBPropertyListObjectTypeDictionary;
    }
    else if ( [elementName isEqual:@"array"] ) {
      subType = kSBPropertyListObjectTypeArray;
    }
    else if ( [elementName isEqual:@"string"] ) {
      subType = kSBPropertyListObjectTypeString;
    }
    else if ( [elementName isEqual:@"data"] ) {
      subType = kSBPropertyListObjectTypeData;
    }
    else if ( [elementName isEqual:@"date"] ) {
      subType = kSBPropertyListObjectTypeDate;
    }
    else if ( [elementName isEqual:@"integer"] ) {
      subType = kSBPropertyListObjectTypeInteger;
    }
    else if ( [elementName isEqual:@"real"] ) {
      subType = kSBPropertyListObjectTypeReal;
    }
    else if ( [elementName isEqual:@"true"] ) {
      subType = kSBPropertyListObjectTypeTrue;
    }
    else if ( [elementName isEqual:@"false"] ) {
      subType = kSBPropertyListObjectTypeFalse;
    }
    else if ( [elementName isEqual:@"key"] ) {
      subType = kSBPropertyListObjectTypeDictionaryKey;
    }
    
    // Can we handle this kind of object?
    if ( (validSubTypes & (1 << subType)) ) {
      _subObject = [[SBPropertyListParseContext alloc] initWithParser:_parser objectType:subType mutability:_mutability];
    } else {
      // Error condition?
      [parser abortParsing];
    }
  }

//

  - (void) xmlParser:(SBXMLParser*)parser
    didEndElement:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
    qualifiedName:(SBString*)qualifiedName
  {
    switch ( _objectType ) {
      
      case kSBPropertyListObjectTypeDictionary: {
        if ( _mutability & kSBPropertyListMutableContainers ) {
          // _parsedObject is already mutable
          if ( ! _parsedObject )
            _parsedObject = [[SBMutableDictionary alloc] init];
        } else if ( ! _parsedObject ) {
            _parsedObject = [[SBDictionary dictionary] retain];
        } else {
          id      immutableObj = [_parsedObject copy];
          
          [_parsedObject release];
          _parsedObject = immutableObj;
        }
        break;
      }
      
      case kSBPropertyListObjectTypeArray: {
        if ( _mutability & kSBPropertyListMutableContainers ) {
          // _parsedObject is already mutable
          if ( ! _parsedObject )
            _parsedObject = [[SBMutableArray alloc] init];
        } else if ( ! _parsedObject ) {
            _parsedObject = [[SBArray array] retain];
        } else {
          id      immutableObj = [_parsedObject copy];
          
          [_parsedObject release];
          _parsedObject = immutableObj;
        }
        break;
      }
    
      case kSBPropertyListObjectTypeString: {
        if ( _mutability & kSBPropertyListMutableContainersAndLeaves ) {
          _parsedObject = ( _textBuffer ? [_textBuffer retain] : [[SBMutableString alloc] initWithUTF8String:""] );
        } else {
          _parsedObject = ( _textBuffer ? [_textBuffer copy] : [[SBString alloc] init] );
        }
        break;
      }
    
      case kSBPropertyListObjectTypeData: {
        // Turn the base64 text in _textBuffer into an SBData object:
        if ( _mutability & kSBPropertyListMutableContainersAndLeaves ) {
          // SBMutableData
          if ( _textBuffer ) {
            _parsedObject = [[SBMutableData dataWithPropertyListRepresentation:_textBuffer] retain];
          } else {
            _parsedObject = [[SBMutableData alloc] init];
          }
        } else {
          // SBData
          if ( _textBuffer ) {
            _parsedObject = [[SBData dataWithPropertyListRepresentation:_textBuffer] retain];
          } else {
            _parsedObject = [[SBData data] retain];
          }
        }
        break;
      }
    
      case kSBPropertyListObjectTypeDate: {
        // Attempt to create a date from the text:
        if ( _textBuffer ) {
          if ( (_parsedObject = [[SBDateFormatter propertyListDateFormatter] dateFromString:_textBuffer]) )
            _parsedObject = [_parsedObject retain];
        }
        break;
      }
    
      case kSBPropertyListObjectTypeInteger: {
        // Attempt to create an integer from the text:
        if ( _textBuffer ) {
          SBScanner*    scanner = [[SBScanner alloc] initWithString:_textBuffer];
          SBInteger     value;
          
          if ( [scanner scanInteger:&value] ) {
            _parsedObject = [[SBNumber numberWithInteger:value] retain];
          } else {
            // Parse error:  not an integer:
            [_parser abortParsing];
          }
          [scanner release];
        }
        break;
      }
    
      case kSBPropertyListObjectTypeReal: {
        // Attempt to create a real from the text:
        if ( _textBuffer ) {
          SBScanner*    scanner = [[SBScanner alloc] initWithString:_textBuffer];
          double        value;
          
          if ( [scanner scanDouble:&value] ) {
            _parsedObject = [[SBNumber numberWithDouble:value] retain];
          } else {
            // Parse error:  not a real:
            [_parser abortParsing];
          }
          [scanner release];
        }
        break;
      }
      
      case kSBPropertyListObjectTypeTrue: {
        _parsedObject = [[SBNumber numberWithBool:YES] retain];
        break;
      }
      
      case kSBPropertyListObjectTypeFalse: {
        _parsedObject = [[SBNumber numberWithBool:NO] retain];
        break;
      }
      
      case kSBPropertyListObjectTypeDictionaryKey: {
        _parsedObject = [_textBuffer copy];
        break;
      }
    
    }
    [_parentContext subObjectParsingCompleted];
  }

//

  - (void) xmlParser:(SBXMLParser*)parser
    foundCharacters:(SBString*)string
  {
    switch ( _objectType ) {
      
      case kSBPropertyListObjectTypeString:
      case kSBPropertyListObjectTypeData:
      case kSBPropertyListObjectTypeDate:
      case kSBPropertyListObjectTypeInteger:
      case kSBPropertyListObjectTypeReal:
      case kSBPropertyListObjectTypeDictionaryKey: {
        if ( ! _textBuffer )
          _textBuffer = [[SBMutableString alloc] init];
        [_textBuffer appendString:string];
        break;
      }
      
    }
  }

//


  - (void) xmlParserDidStartDocument:(SBXMLParser*)parser
  {
  }
  - (void) xmlParserDidEndDocument:(SBXMLParser*)parser;
  {
  }
  - (void) xmlParser:(SBXMLParser*)parser
    didStartMappingPrefix:(SBString*)prefix
    toURI:(SBString*)namespaceURI
  {
  }
  - (void) xmlParser:(SBXMLParser*)parser
    didEndMappingPrefix:(SBString*)prefix;
  {
  }
  - (void) xmlParser:(SBXMLParser*)parser
    foundCDATA:(SBData*)cdata;
  {
  }
  - (void) xmlParser:(SBXMLParser*)parser
    foundProcessingInstructionWithTarget:(SBString*)target
    data:(SBString*)data;
  {
  }
  - (void) xmlParser:(SBXMLParser*)parser
    foundComment:(SBString*)comment;
  {
  }
  - (SBData*) xmlParser:(SBXMLParser*)parser
    resolveExternalEntityName:(SBString*)name
    systemID:(SBString*)systemID
  {
    return nil;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBPropertyListSerialization

  + (BOOL) propertyListIsValid:(id)plist
  {
    return YES;
  }

//

  + (SBData*) dataWithPropertyList:(id)plist
    error:(SBError**)error
  {
    return nil;
  }
  
//

  + (SBInteger) writePropertyList:(id)plist
    toStream:(SBOutputStream*)stream error:(SBError**)error
  {
    return 0;
  }

//

  + (id) propertyListWithData:(SBData*)data
    options:(SBPropertyListMutabilityOptions)options
    error:(SBError**)error
  {
    // Create an XML parser attached to the input data:
    id                            plist = nil;
    SBXMLParser*                  parser = [[SBXMLParser alloc] initWithData:data];
    
    if ( parser ) {
      SBPropertyListParseContext* baseContext = [[SBPropertyListParseContext alloc] initWithParser:parser
                                                      objectType:kSBPropertyListObjectTypeDocument
                                                      mutability:options
                                                    ];
      if ( [parser parse] ) {
        if ( (plist = [baseContext parsedObject]) ) {
          plist = [[plist retain] autorelease];
        }
      }
      [baseContext release];
      [parser release];
    }
    return plist;
  }
  
//

  + (id) propertyListWithStream:(SBInputStream*)stream
    options:(SBPropertyListMutabilityOptions)options
    error:(SBError**)error
  {
    // Create an XML parser attached to the input stream:
    id                            plist = nil;
    SBXMLParser*                  parser = [[SBXMLParser alloc] initWithStream:stream];
    
    if ( parser ) {
      SBPropertyListParseContext* baseContext = [[SBPropertyListParseContext alloc] initWithParser:parser
                                                      objectType:kSBPropertyListObjectTypeDocument
                                                      mutability:options
                                                    ];
      if ( [parser parse] ) {
        if ( (plist = [baseContext parsedObject]) ) {
          plist = [[plist retain] autorelease];
        }
      }
      [baseContext release];
      [parser release];
    }
    return plist;
  }

@end
