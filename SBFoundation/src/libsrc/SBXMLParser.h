//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLParser.h
//
// An event-based XML parser.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBData, SBDictionary, SBInputStream, SBMutableDictionary, SBMutableString, SBMutableData, SBMutableArray;
@protocol SBXMLParserDelegate;

//

@interface SBXMLParser : SBObject
{
  void*       _parser;
  id          _delegate;
  //
  SBUInteger  _options;
  union {
    SBData*         data;
    SBString*       string;
    int             fd;
    SBInputStream*  stream;
  } _source;
  //
  struct {
    SBMutableDictionary*    attrs;
    SBMutableString*        text;
    SBMutableData*          cdata;
    SBMutableArray*         ns;
    SBMutableArray*         elements;
  } _state;
}

- (id) initWithData:(SBData*)data;
- (id) initWithString:(SBString*)string;
- (id) initWithFileDescriptor:(int)fd closeWhenDone:(BOOL)closeWhenDone;
- (id) initWithStream:(SBInputStream*)stream;

- (id<SBXMLParserDelegate>) delegate;
- (void) setDelegate:(id<SBXMLParserDelegate>)delegate;

- (BOOL) parse;
- (void) abortParsing;

- (BOOL) shouldProcessNamespaces;
- (BOOL) shouldResolveExternalEntities;
- (BOOL) shouldPreserveWhitespace;

- (void) setShouldProcessNamespaces:(BOOL)shouldProcessNamespaces;
- (void) setShouldResolveExternalEntities:(BOOL)shouldResolveExternalEntities;
- (void) setShouldPreserveWhitespace:(BOOL)shouldPreserveWhitespace;

- (SBUInteger) lineNumber;
- (SBUInteger) columnNumber;

@end

//

@protocol SBXMLParserDelegate

- (void) xmlParserDidStartDocument:(SBXMLParser*)parser;
- (void) xmlParserDidEndDocument:(SBXMLParser*)parser;

- (void) xmlParser:(SBXMLParser*)parser
            didStartMappingPrefix:(SBString*)prefix
            toURI:(SBString*)namespaceURI;
- (void) xmlParser:(SBXMLParser*)parser
            didEndMappingPrefix:(SBString*)prefix;

- (void) xmlParser:(SBXMLParser*)parser
            didStartElement:(SBString*)elementName
            namespaceURI:(SBString*)namespaceURI
            qualifiedName:(SBString*)qualifiedName
            attributes:(SBDictionary*)attributes;
- (void) xmlParser:(SBXMLParser*)parser
            didEndElement:(SBString*)elementName
            namespaceURI:(SBString*)namespaceURI
            qualifiedName:(SBString*)qualifiedName;
            
- (void) xmlParser:(SBXMLParser*)parser
            foundCharacters:(SBString*)string;
            
- (void) xmlParser:(SBXMLParser*)parser
            foundCDATA:(SBData*)cdata;

- (void) xmlParser:(SBXMLParser*)parser
            foundProcessingInstructionWithTarget:(SBString*)target
            data:(SBString*)data;

- (void) xmlParser:(SBXMLParser*)parser
            foundComment:(SBString*)comment;

- (SBData*) xmlParser:(SBXMLParser*)parser
            resolveExternalEntityName:(SBString*)name
            systemID:(SBString*)systemID;

@end
