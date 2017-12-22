//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLParser.h
//
// Generalized XML parsing.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"
#import "SBError.h"

@class SBString, SBDictionary;

/*!
  @const SBXMLParserErrorDomain
  @discussion
  String constant which identifies SBError instances originating from this API.
*/
extern SBString* SBXMLParserErrorDomain;

/*!
  @typedef SBXMLParserStatus
  @discussion
  Result codes which will be returned by this API, either wrapped by a SBError or
  as a direct integer value.  Note that the expat error codes are situated from zero
  through 41 (as of 2.0.1) and so we just re-use them and shift our own codes to
  the 1000 range.
*/
typedef enum {
  kSBXMLParserStatusOk                      = 0,
  //
  // ... expat errors fall in the range 1 to ~41, we map directly to them ...
  //
  kSBXMLParserStatusUnableToStartParsing    = 1000,
  kSBXMLParserStatusInvalidDocumentEncoding = 1001,
  kSBXMLParserStatusNoParsingSession        = 1002,
  kSBXMLParserStatusElementHasNoHandler     = 1003,
  kSBXMLParserStatusUndefinedNamespace      = 1004,
  kSBXMLParserStatusStackOverflow           = 1005
} SBXMLParserStatus;

/*!
  @class SBXMLNode
  @discussion
  An SBXMLNode object represents a parsing context created and used by the SBXMLParser
  class.  Do not allocate instances yourself.
  
  An SBXMLNode can have additional data associated with it via the userInfo field.  When
  parsing exits the context of a given SBXMLNode, the userInfo instance variable if set
  will be sent the release message. 
*/
@interface SBXMLNode : SBObject
{
  unsigned int          _options;
  SBXMLNode*            _parentXMLNode;
  SBDictionary*         _nodeAttributes;
  SBString*             _nodeName;
  SBString*             _nodeCharacterContent;
  SBObject*             _userInfo;
}

- (SBXMLNode*) parentXMLNode;
- (SBString*) nodeName;
- (SBDictionary*) nodeAttributes;
- (SBString*) nodeCharacterContent;

- (SBObject*) userInfo;
- (void) setUserInfo:(SBObject*)userInfo;

@end


@protocol SBXMLObserver

- (void) xmlNodeEnter:(SBXMLNode*)enteringNode;
- (void) xmlNodeLeave:(SBXMLNode*)leavingNode;
- (void) xmlNode:(SBXMLNode*)anXMLNode observeComment:(SBString*)commentText;

@end


@interface SBXMLParser : SBObject
{
  unsigned int        _options;
  SBString*           _baseURI;
  SBDictionary*       _namespaceHandlers;
  SBArray*            _nodePool;
}

- (id) init;
- (id) initWithOptions:(unsigned int)options;
- (id) initWithOptions:(unsigned int)options baseURI:(SBString*)baseURI;
- (id) initWithOptions:(unsigned int)options baseURI:(SBString*)baseURI maxStackDepth:(unsigned int)maxStackDepth;

- (id) nodeHandlerForName:(SBString*)nodeName;
- (void) setNodeHandler:(id)nodeHandler forName:(SBString*)nodeName;

- (id) nodeHandlerForName:(SBString*)nodeName inNamespace:(SBString*)xmlNamespace;
- (void) setNodeHandler:(id)nodeHandler forName:(SBString*)nodeName inNamespace:(SBString*)xmlNamespace;

- (BOOL) nodeHandlerExistsForName:(SBString*)nodeName;
- (BOOL) nodeHandlerExistsForName:(SBString*)nodeName inNamespace:(SBString*)xmlNamespace;
- (BOOL) namespaceExists:(SBString*)xmlNamespace;

@end
