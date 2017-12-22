//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLInternalParser.m
//
// Built-in XML parser which backends for SBXMLDocument and SBXMLElement.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLInternalParser.h"
#import "SBData.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBString.h"

//

@interface SBXMLNodeParsingDelegate : SBObject <SBXMLParserDelegate>
{
  SBXMLDocument*      _document;
  SBXMLNode*          _target;
  SBMutableArray*     _namespaceAccumulator;
}

- (void) resetDelegate;

- (SBXMLDocument*) document;
- (void) setDocument:(SBXMLDocument*)document;

- (SBMutableArray*) namespaceAccumulator;

@end

@implementation SBXMLNodeParsingDelegate

  - (void) dealloc
  {
    if ( _document ) [_document release];
    if ( _namespaceAccumulator ) [_namespaceAccumulator release];
    
    [super dealloc];
  }

//

  - (void) resetDelegate
  {
    if ( _document ) {
      [_document release];
      _document = nil;
    }
    if ( _namespaceAccumulator ) {
      [_namespaceAccumulator removeAllObjects];
    }
    _target = nil;
  }

//

  - (SBXMLDocument*) document
  {
    return _document;
  }
  - (void) setDocument:(SBXMLDocument*)document
  {
    if ( document ) document = [document retain];
    if ( _document ) [_document release];
    _document = document;
  }
  
//

  - (SBMutableArray*) namespaceAccumulator
  {
    if ( ! _namespaceAccumulator )
      _namespaceAccumulator = [[SBMutableArray alloc] init];
    return _namespaceAccumulator;
  }

//

  - (void) xmlParserDidStartDocument:(SBXMLParser*)parser
  {
    if ( ! _document )
      _document = [[SBXMLDocument alloc] init];
    _target = (SBXMLNode*)_document;
  }

//

  - (void) xmlParserDidEndDocument:(SBXMLParser*)parser
  {
    if ( _namespaceAccumulator )
      [_namespaceAccumulator removeAllObjects];
    _target = nil;
  }
  
//

  - (void) xmlParser:(SBXMLParser*)parser
    didStartMappingPrefix:(SBString*)prefix
    toURI:(SBString*)namespaceURI
  {
    SBMutableArray*     namespaces = [self namespaceAccumulator];
    SBXMLNode*          namespaceNode = [SBXMLNode namespaceNodeWithPrefix:prefix stringValue:namespaceURI];
    
    [namespaces addObject:namespaceNode];
  }
  
//

  - (void) xmlParser:(SBXMLParser*)parser
    didEndMappingPrefix:(SBString*)prefix
  {
    // NOOP
  }

//

  - (void) xmlParser:(SBXMLParser*)parser
    didStartElement:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
    qualifiedName:(SBString*)qualifiedName
    attributes:(SBDictionary*)attributes
  {
    if ( _target ) {
      SBXMLElement*     elementNode = [SBXMLNode elementNodeWithName:elementName namespaceURI:namespaceURI];
      
      // Set attributes:
      if ( attributes )
        [elementNode setAttributesFromDictionary:attributes];
      
      // Set namespaces:
      if ( _namespaceAccumulator && [_namespaceAccumulator count] ) {
        [elementNode setNamespaces:_namespaceAccumulator];
        [_namespaceAccumulator removeAllObjects];
      }
      
      // Append to the current target...
      [_target addChildNode:elementNode];
      
      // ...and make this element the new target
      _target = elementNode;
    }
  }
  
//

  - (void) xmlParser:(SBXMLParser*)parser
    didEndElement:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
    qualifiedName:(SBString*)qualifiedName
  {
    if ( _target ) {
      // Coallesce text:
      [(SBXMLElement*)_target coallesceTextNodes];
      
      // Step back to the parent node for the target:
      _target = [_target parentNode];
    }
  }

//

  - (void) xmlParser:(SBXMLParser*)parser
    foundCharacters:(SBString*)string
  {
    if ( _target && [string length] ) {
      SBXMLNode*      textNode = [SBXMLNode textNodeWithStringValue:string];
      
      [_target addChildNode:textNode];
    }
  }
  
//
              
  - (void) xmlParser:(SBXMLParser*)parser
    foundCDATA:(SBData*)cdata
  {
    if ( _target ) {
      SBString*       string = [[SBString alloc] initWithCharacters:(UChar*)[cdata bytes] length:[cdata length] / sizeof(UChar)];
      SBXMLNode*      textNode = [SBXMLNode textNodeWithStringValue:string];
      
      [string release];
      [_target addChildNode:textNode];
    }
  }
  
//

  - (void) xmlParser:(SBXMLParser*)parser
    foundProcessingInstructionWithTarget:(SBString*)target
    data:(SBString*)data
  {
    if ( _target ) {
      SBXMLNode*      piNode = [SBXMLNode processingInstructionNodeWithName:target stringValue:data];
      
      [_target addChildNode:piNode];
    }
  }
  
//

  - (void) xmlParser:(SBXMLParser*)parser
    foundComment:(SBString*)comment
  {
    if ( _target ) {
      SBXMLNode*      commentNode = [SBXMLNode commentNodeWithStringValue:comment];
      
      [_target addChildNode:commentNode];
    }
  }
  
//

  - (SBData*) xmlParser:(SBXMLParser*)parser
    resolveExternalEntityName:(SBString*)name
    systemID:(SBString*)systemID
  {
    // NOOP
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLInternalParser

  + (id) sharedXMLInternalParser
  {
    static SBXMLInternalParser* __sharedParser = nil;
    
    if ( ! __sharedParser ) {
      __sharedParser = [[SBXMLInternalParser alloc] init];
    }
    return __sharedParser;
  }

//

  - (id) init
  {
    if ( (self = [super init]) ) {
      _parserDelegate = [[SBXMLNodeParsingDelegate alloc] init];
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _parser ) [_parser release];
    if ( _parserDelegate ) [_parserDelegate release];
    
    [super dealloc];
  }
  
//

  - (BOOL) document:(SBXMLDocument*)document withXMLString:(SBString*)xmlString
  {
    BOOL            rc = NO;
    
    [_parserDelegate setDocument:document];
    if ( (_parser = [[SBXMLParser alloc] initWithString:xmlString]) ) {
      [_parser setDelegate:_parserDelegate];
      rc = [_parser parse];
      [_parser release];
      _parser = nil;
    }
    [_parserDelegate resetDelegate];
    return rc;
  }
  
//

  - (BOOL) document:(SBXMLDocument*)document withData:(SBData*)data
  {
    BOOL            rc = NO;
    
    [_parserDelegate setDocument:document];
    if ( (_parser = [[SBXMLParser alloc] initWithData:data]) ) {
      [_parser setDelegate:_parserDelegate];
      rc = [_parser parse];
      [_parser release];
      _parser = nil;
    }
    [_parserDelegate resetDelegate];
    return rc;
  }

//

  - (BOOL) document:(SBXMLDocument*)document withStream:(SBInputStream*)stream
  {
    BOOL            rc = NO;
    
    [_parserDelegate setDocument:document];
    if ( (_parser = [[SBXMLParser alloc] initWithStream:stream]) ) {
      [_parser setDelegate:_parserDelegate];
      rc = [_parser parse];
      [_parser release];
      _parser = nil;
    }
    [_parserDelegate resetDelegate];
    return rc;
  }
  
@end
