//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLParser.m
//
// An event-based XML parser.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLParser.h"
#import "SBData.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBStream.h"
#import "SBString.h"
#import "SBCharacterSet.h"

//

#define XML_UNICODE

#import "expat.h"
#define EXPAT_PARSER ((XML_Parser)_parser)
#define EXPAT_BUFFER_SIZE 4096


static inline SBUInteger
__EXPAT_strlen_UTF16(
  const XML_Char* s
)
{
  SBUInteger    l = 0;
  while ( *s++ )
    l++;
  return l;
}

//

enum {
  kSBXMLParserOptionSourceNone = 0,
  kSBXMLParserOptionSourceSBData = 1,
  kSBXMLParserOptionSourceSBString = 2,
  kSBXMLParserOptionSourceFileDescriptor = 3,
  kSBXMLParserOptionSourceSBStream = 4,
  kSBXMLParserOptionSourceMask = 0x0000000F,
  //
  kSBXMLParserOptionCloseWhenDone = 1 << 8,
  kSBXMLParserOptionProcessNamespaces = 1 << 9,
  kSBXMLParserOptionResolveExternalEntities = 1 << 10,
  kSBXMLParserOptionPreserveWhitespace = 1 << 11,
  //
  kSBXMLParserOptionStateInsideCDATA = 1 << 16,
  kSBXMLParserOptionStateMask = 0xFFFF0000
};

//

@interface SBXMLParser(SBXMLParserPrivate)

- (SBMutableDictionary*) state_getAttributeDict;
- (SBMutableString*) state_getText;
- (SBMutableData*) state_getCDATA;

- (void) stateCleanup;

- (BOOL) fileDescriptorParseLoop;
- (BOOL) streamParseLoop;

- (SBUInteger) options;
- (void) setOption:(SBUInteger)options;

@end

//

@implementation SBXMLParser(SBXMLParserPrivate)

  - (SBMutableDictionary*) state_getAttributeDict
  {
    if ( ! _state.attrs )
      _state.attrs = [[SBMutableDictionary alloc] init];
    return _state.attrs;
  }
  
//

  - (SBMutableString*) state_getText
  {
    if ( ! _state.text )
      _state.text = [[SBMutableString alloc] init];
    return _state.text;
  }
  
//
  - (SBMutableData*) state_getCDATA
  {
    if ( ! _state.cdata )
      _state.cdata = [[SBMutableData alloc] init];
    return _state.cdata;
  }

//

  - (void) stateCleanup
  {
    // Drop all state bits from the option bit vector:
    _options &= ~kSBXMLParserOptionStateMask;
    
    if ( _state.attrs ) [_state.attrs release];
    if ( _state.text ) [_state.text release];
    if ( _state.cdata ) [_state.cdata release];
    if ( _state.ns ) [_state.ns release];
    if ( _state.elements ) [_state.elements release];
    _state.attrs = nil;
    _state.text = nil;
    _state.cdata = nil;
    _state.ns = nil;
    _state.elements = nil;
  }

//

  - (BOOL) fileDescriptorParseLoop
  {
    while ( 1 ) {
      void*     buffer = XML_GetBuffer(EXPAT_PARSER, EXPAT_BUFFER_SIZE);
      
      if ( ! buffer )
        return NO;
      
      int       bytesRead = read(_source.fd, buffer, EXPAT_BUFFER_SIZE);
      
      if ( bytesRead < 0 )
        return NO;
      
      if ( ! XML_ParseBuffer(EXPAT_PARSER, bytesRead, (bytesRead == 0)) )
        return NO;
      
      if ( bytesRead == 0 )
        break;
    }
    return YES;
  }
  
//

  - (BOOL) streamParseLoop
  {
    while ( 1 ) {
      void*       buffer = XML_GetBuffer(EXPAT_PARSER, EXPAT_BUFFER_SIZE);
      
      if ( ! buffer )
        return NO;
      
      SBUInteger        bytesRead = [_source.stream read:buffer maxLength:EXPAT_BUFFER_SIZE];
      SBStreamStatus    status = [_source.stream streamStatus];
      
      if ( (bytesRead == 0) && (status != SBStreamStatusAtEnd) )
        return NO;
      
      if ( ! XML_ParseBuffer(EXPAT_PARSER, bytesRead, (status == SBStreamStatusAtEnd)) )
        return NO;
      
      if ( status == SBStreamStatusAtEnd )
        break;
    }
    return YES;
  }
  
//

  - (SBUInteger) options
  {
    return _options;
  }
  - (void) setOption:(SBUInteger)option
  {
    _options = (_options & ~kSBXMLParserOptionStateMask) | (option & kSBXMLParserOptionStateMask);
  }
  - (void) unsetOption:(SBUInteger)option
  {
    _options &= ~(option & kSBXMLParserOptionStateMask);
  }

@end

//
#if 0
#pragma mark -
#endif
//

#define THE_PARSER ((SBXMLParser*)parserObj)

//

static inline
__SBXMLParser_CheckText(
  SBXMLParser*    parser
)
{
  SBMutableString*  accumText = [parser state_getText];
  SBUInteger        l = [accumText length];
  
  if ( l ) {
    id              delegate = [parser delegate];
    
    if ( delegate ) {
      // Drop trailing whitespace if desired:
      if ( ! [parser shouldPreserveWhitespace] ) {
        SBRange     wsRange = [accumText rangeOfCharacterFromSet:[SBCharacterSet whitespaceAndNewlineCharacterSet] options:SBStringAnchoredSearch | SBStringBackwardsSearch];
        
        if ( ! SBRangeEmpty(wsRange) ) {
          [accumText deleteCharactersInRange:wsRange];
          l = [accumText length];
        }
      }
      if ( l ) {
        SBString*       chunk = [accumText copy];
        
        [delegate xmlParser:parser
                      foundCharacters:chunk];
        [chunk release];
      }
    }
    [accumText deleteAllCharacters];
  }
}

//

static inline
__SBXMLParser_CheckCDATA(
  SBXMLParser*    parser
)
{
  SBMutableData*  accumData = [parser state_getCDATA];
  
  if ( [accumData length] ) {
    id              delegate = [parser delegate];
    
    if ( delegate ) {
      SBData*       chunk = [accumData copy];
      
      [delegate xmlParser:parser
                    foundCDATA:chunk];
      [chunk release];
    }
    [accumData setLength:0];
  }
}

//

void XMLCALL
__SBXMLParser_Expat_StartElement(
  void*             parserObj,
  const XML_Char*   name,
  const XML_Char**  attributes
)
{
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(THE_PARSER);
    
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBMutableDictionary*    attributeDict = nil;
  
  if ( attributes ) {
    attributeDict = [THE_PARSER state_getAttributeDict];
    
    while ( *attributes ) {
      SBString*             key = [[SBString alloc] initWithCharacters:(UChar*)*attributes length:__EXPAT_strlen_UTF16(*attributes)];
      attributes++;
      
      SBString*             value = [[SBString alloc] initWithCharacters:(UChar*)*attributes length:__EXPAT_strlen_UTF16(*attributes)];
      attributes++;
      
      [attributeDict setValue:value forKey:key];
      [key release];
      [value release];
    }
    if ( [attributeDict count] )
      attributeDict = [attributeDict copy];
    else
      attributeDict = nil;
  }
  
  SBString*               qName = [[SBString alloc] initWithCharacters:(UChar*)name length:__EXPAT_strlen_UTF16(name)];
  
  [delegate xmlParser:THE_PARSER
                didStartElement:qName
                namespaceURI:nil
                qualifiedName:qName
                attributes:attributeDict
              ];
              
  [qName release];
}

//

void XMLCALL
__SBXMLParser_Expat_EndElement(
  void*             parserObj,
  const XML_Char*   name
)
{
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(THE_PARSER);
  
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBString*               qName = [[SBString alloc] initWithCharacters:(UChar*)name length:__EXPAT_strlen_UTF16(name)];
  
  [delegate xmlParser:THE_PARSER
                didEndElement:qName
                namespaceURI:nil
                qualifiedName:qName
              ];
  
  [qName release];
}

//

void XMLCALL
__SBXMLParser_Expat_StartElementNS(
  void*             parserObj,
  const XML_Char*   name,
  const XML_Char**  attributes
)
{
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(THE_PARSER);
    
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBMutableDictionary*    attributeDict = nil;
  
  if ( attributes ) {
    attributeDict = [THE_PARSER state_getAttributeDict];
    
    [attributeDict removeAllObjects];
    
    while ( *attributes ) {
      SBString*             key = [[SBString alloc] initWithCharacters:(UChar*)*attributes length:__EXPAT_strlen_UTF16(*attributes)];
      attributes++;
      
      SBString*             value = [[SBString alloc] initWithCharacters:(UChar*)*attributes length:__EXPAT_strlen_UTF16(*attributes)];
      attributes++;
      
      [attributeDict setValue:value forKey:key];
      [key release];
      [value release];
    }
    if ( [attributeDict count] )
      attributeDict = [attributeDict copy];
    else
      attributeDict = nil;
  }
  
  SBString*               qName = [[SBString alloc] initWithCharacters:(UChar*)name length:__EXPAT_strlen_UTF16(name)];
  SBString*               nsURI = nil;
  SBString*               localName = qName;
  
  //
  // Do some namespace checking:
  //
  SBRange                 nsDelim = [qName rangeOfString:@":" options:SBStringBackwardsSearch];
  
  if ( ! SBRangeEmpty(nsDelim) ) {
    // Decompose the string:
    if ( nsDelim.start > 0 )
      nsURI = [qName substringToIndex:nsDelim.start - 1];
    localName = [qName substringFromIndex:SBRangeMax(nsDelim)];
  }
  
  [delegate xmlParser:THE_PARSER
                didStartElement:localName
                namespaceURI:nsURI
                qualifiedName:qName
                attributes:attributeDict
              ];
              
  [qName release];
  if ( attributeDict )
    [attributeDict release];
}

//

void XMLCALL
__SBXMLParser_Expat_EndElementNS(
  void*             parserObj,
  const XML_Char*   name
)
{
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(THE_PARSER);
  
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBString*               qName = [[SBString alloc] initWithCharacters:(UChar*)name length:__EXPAT_strlen_UTF16(name)];
  SBString*               nsURI = nil;
  SBString*               localName = qName;
  
  //
  // Do some namespace checking:
  //
  SBRange                 nsDelim = [qName rangeOfString:@":" options:SBStringBackwardsSearch];
  
  if ( nsDelim.length ) {
    // Decompose the string:
    if ( nsDelim.start > 0 )
      nsURI = [qName substringToIndex:nsDelim.start - 1];
    localName = [qName substringFromIndex:SBRangeMax(nsDelim)];
  }
  
  [delegate xmlParser:THE_PARSER
                didEndElement:localName
                namespaceURI:nsURI
                qualifiedName:qName
              ];
  
  [qName release];
}

//

void XMLCALL
__SBXMLParser_Expat_CharacterData(
  void*             parserObj,
  const XML_Char*   bytes,
  int               length  
)
{
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
    
  if ( [THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA ) {
    //
    // CDATA:
    //
    SBMutableData*  cdata = [THE_PARSER state_getCDATA];
    
    [cdata appendBytes:bytes length:length * sizeof(XML_Char)];
  } else {
    //
    // Regular text:
    //
    SBMutableString*  text = [THE_PARSER state_getText];
    BOOL              preserveWhitespace = [THE_PARSER shouldPreserveWhitespace];
    
    // Override if we're in the middle of some text processing:
    if ( ! preserveWhitespace && [text length] )
      preserveWhitespace = YES;
      
    [text appendCharacters:(UChar*)bytes length:length];
    
    // Drop leading whitespace if necessary:
    if ( ! preserveWhitespace ) {
      SBRange         wsRange = [text rangeOfCharacterFromSet:[SBCharacterSet whitespaceAndNewlineCharacterSet] options:SBStringAnchoredSearch];
      
      if ( ! SBRangeEmpty(wsRange) )
        [text deleteCharactersInRange:wsRange];
    }
  }
}

//

void XMLCALL
__SBXMLParser_Expat_ProcessingInstruction(
  void*             parserObj,
  const XML_Char*   target,
  const XML_Char*   data
)
{
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(THE_PARSER);
    
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBString*         targetStr = [[SBString alloc] initWithCharacters:(UChar*)target length:__EXPAT_strlen_UTF16(target)];
  SBString*         dataStr = [[SBString alloc] initWithCharacters:(UChar*)data length:__EXPAT_strlen_UTF16(data)];
  
  [delegate xmlParser:THE_PARSER
                foundProcessingInstructionWithTarget:targetStr
                data:dataStr];
  
  [targetStr release];
  [dataStr release];
}

//

void XMLCALL
__SBXMLParser_Expat_Comment(
  void*             parserObj,
  const XML_Char*   comment
)
{
  //
  // Is there accumulated text?
  //
  __SBXMLParser_CheckText(THE_PARSER);
  
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  UChar*            s = (UChar*)comment;
  SBUInteger        l = 0;
  SBCharacterSet*   ws = [SBCharacterSet whitespaceAndNewlineCharacterSet];
  
  // Drop leading whitespace:
  while ( *s ) {
    if ( [ws utf16CharacterIsMember:*s] )
      s++;
    else
      break;
  }
  // Drop trailing whitespace:
  l = __EXPAT_strlen_UTF16((XML_Char*)s);
  while ( l ) {
    if ( [ws utf16CharacterIsMember:s[l - 1]] )
      l--;
    else
      break;
  }
  if ( l ) {
    SBString*         commentStr = [[SBString alloc] initWithCharacters:s length:l];
    
    [delegate xmlParser:THE_PARSER
                foundComment:commentStr];
    [commentStr release];
  }
}

//

void XMLCALL
__SBXMLParser_Expat_StartCDATA(
  void*             parserObj
)
{
  //
  // Is there accumulated text?
  //
  __SBXMLParser_CheckText(THE_PARSER);
  
  [THE_PARSER setOption:kSBXMLParserOptionStateInsideCDATA];
}

//

void XMLCALL
__SBXMLParser_Expat_EndCDATA(
  void*             parserObj
)
{
  //
  // Did we accumulate any CDATA?
  //
  __SBXMLParser_CheckCDATA(THE_PARSER);
  
  [THE_PARSER unsetOption:kSBXMLParserOptionStateInsideCDATA];
}

//

int XMLCALL
__SBXMLParser_Expat_ExternalEntityRef(
  XML_Parser        parser,
  const XML_Char*   context,
  const XML_Char*   base,
  const XML_Char*   systemID,
  const XML_Char*   publicID
)
{
  SBXMLParser*      parserObj = XML_GetUserData(parser);
  
  //
  // Check for accumulated text:
  //
  if ( ! ([THE_PARSER options] & kSBXMLParserOptionStateInsideCDATA) )
    __SBXMLParser_CheckText(parserObj);
    
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
    
  SBString*         identifier = [[SBString alloc] initWithCharacters:(UChar*)context length:__EXPAT_strlen_UTF16(context)];
  SBString*         canonicalSystemId = [[SBString alloc] initWithCharacters:(UChar*)systemID length:__EXPAT_strlen_UTF16(systemID)];
  
  [delegate xmlParser:THE_PARSER
                resolveExternalEntityName:identifier
                systemID:canonicalSystemId];
  
  [identifier release];
  [canonicalSystemId release];
  
  return 1;
}

//

void XMLCALL
__SBXMLParser_Expat_StartNamespace(
  void*             parserObj,
  const XML_Char*   prefix,
  const XML_Char*   uri
)
{
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBString*         prefixStr = [[SBString alloc] initWithCharacters:(UChar*)prefix length:__EXPAT_strlen_UTF16(prefix)];
  SBString*         uriStr = [[SBString alloc] initWithCharacters:(UChar*)uri length:__EXPAT_strlen_UTF16(uri)];
  
  [delegate xmlParser:THE_PARSER
                didStartMappingPrefix:prefixStr
                toURI:uriStr];
  
  [prefixStr release];
  [uriStr release];
}

//

void XMLCALL
__SBXMLParser_Expat_EndNamespace(
  void*             parserObj,
  const XML_Char*   prefix
)
{
  id                delegate = [THE_PARSER delegate];
  
  if ( ! delegate )
    return;
  
  SBString*         prefixStr = [[SBString alloc] initWithCharacters:(UChar*)prefix length:__EXPAT_strlen_UTF16(prefix)];
  
  [delegate xmlParser:THE_PARSER
                didEndMappingPrefix:prefixStr];
  
  [prefixStr release];
}

//

#undef THE_PARSER

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLParser

  - (id) init
  {
    if ( (self = [super init]) ) {
      _options = kSBXMLParserOptionSourceNone | kSBXMLParserOptionProcessNamespaces;
    }
    return self;
  }

//

  - (id) initWithData:(SBData*)data
  {
    if ( (self = [self init]) ) {
      _options |= kSBXMLParserOptionSourceSBData;
      if ( data )
        _source.data = [data retain];
    }
    return self;
  }
  
//

  - (id) initWithString:(SBString*)string
  {
    if ( (self = [self init]) ) {
      _options |= kSBXMLParserOptionSourceSBString;
      if ( string )
        _source.string = [string retain];
    }
    return self;
  }
  
//

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    if ( (self = [self init]) ) {
      _options |= kSBXMLParserOptionSourceFileDescriptor | ( closeWhenDone ? kSBXMLParserOptionCloseWhenDone : 0 );
      _source.fd = fd;
    }
    return self;
  }
  
//

  - (id) initWithStream:(SBInputStream*)stream
  {
    if ( (self = [self init]) ) {
      _options |= kSBXMLParserOptionSourceSBStream;
      if ( stream )
        _source.stream = [stream retain];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    // Drop the Expat parser:
    if ( _parser )
      XML_ParserFree(EXPAT_PARSER);
    
    // Drop the source if necessary:
    switch ( (_options & kSBXMLParserOptionSourceMask) ) {
    
      case kSBXMLParserOptionSourceSBData:
        if ( _source.data ) [_source.data release];
        break;
    
      case kSBXMLParserOptionSourceSBString:
        if ( _source.string ) [_source.string release];
        break;
        
      case kSBXMLParserOptionSourceFileDescriptor:
        if ( _options & kSBXMLParserOptionCloseWhenDone )
          close(_source.fd);
        break;
      
      case kSBXMLParserOptionSourceSBStream:
        if ( _source.stream ) [_source.stream release];
        break;
        
    }
    
    // Free any left-over state junk:
    [self stateCleanup];
    
    [super dealloc];
  }
  
//

  - (id<SBXMLParserDelegate>) delegate
  {
    return _delegate;
  }
  - (void) setDelegate:(id<SBXMLParserDelegate>)delegate
  {
    _delegate = delegate;
  }

//

  - (BOOL) parse
  {
    BOOL          rc = NO;
    BOOL          resuming = NO;
    
    //
    // Check to see if we're merely suspended:
    //
    if ( _parser ) {
      XML_ParsingStatus   status;
      
      XML_GetParsingStatus(EXPAT_PARSER, &status);
      if ( status.parsing == XML_SUSPENDED ) {
        XML_ResumeParser(EXPAT_PARSER);
        resuming = YES;
      }
    }
    if ( ! resuming ) {
      // Reset everything if there's pre-existing state:
      if ( _parser ) {
        XML_ParserFree(EXPAT_PARSER);
        _parser = NULL;
        [self stateCleanup];
      }
    
      // Create the Expat parser:
      static XML_Char     utf16CharSet[] = { 'U','T','F','-','1','6',0 };
      XML_Char*           charSet = NULL;
      
      if ( (_options & kSBXMLParserOptionSourceMask) == kSBXMLParserOptionSourceSBString )
        charSet = utf16CharSet;
      if ( _options & kSBXMLParserOptionProcessNamespaces )
        _parser = XML_ParserCreateNS(charSet, (XML_Char)':');
      else
        _parser = XML_ParserCreate(charSet);
    }
    
    if ( _parser ) {
      if ( ! resuming ) {
        rc = YES;
        
        // Set the receiver as the user data:
        XML_SetUserData(EXPAT_PARSER, (void*)self);
        
        // Allow for external entities if not standalone:
        XML_SetParamEntityParsing(EXPAT_PARSER, XML_PARAM_ENTITY_PARSING_UNLESS_STANDALONE);
        
        // Set all of the handlers:
        XML_SetCharacterDataHandler(EXPAT_PARSER, __SBXMLParser_Expat_CharacterData);
        XML_SetProcessingInstructionHandler(EXPAT_PARSER, __SBXMLParser_Expat_ProcessingInstruction);
        XML_SetCommentHandler(EXPAT_PARSER, __SBXMLParser_Expat_Comment);
        XML_SetCdataSectionHandler(EXPAT_PARSER, __SBXMLParser_Expat_StartCDATA, __SBXMLParser_Expat_EndCDATA);
        if ( _options & kSBXMLParserOptionResolveExternalEntities )
          XML_SetExternalEntityRefHandler(EXPAT_PARSER, __SBXMLParser_Expat_ExternalEntityRef);
        if ( _options & kSBXMLParserOptionProcessNamespaces ) {
          XML_SetElementHandler(EXPAT_PARSER, __SBXMLParser_Expat_StartElementNS, __SBXMLParser_Expat_EndElementNS);
          XML_SetNamespaceDeclHandler(EXPAT_PARSER, __SBXMLParser_Expat_StartNamespace, __SBXMLParser_Expat_EndNamespace);
        } else {
          XML_SetElementHandler(EXPAT_PARSER, __SBXMLParser_Expat_StartElement, __SBXMLParser_Expat_EndElement);
        }
        
        // We're ready to start:
        if ( _delegate ) [_delegate xmlParserDidStartDocument:self];
      }
      
      // Do the parsing loop:
      switch ( (_options & kSBXMLParserOptionSourceMask) ) {
      
        case kSBXMLParserOptionSourceSBData:
          //
          // This one's easy -- just parse the whole darn buffer with one call:
          //
          if ( _source.data && ! XML_Parse(EXPAT_PARSER, (const char*)[_source.data bytes], [_source.data length], 1) )
            rc = NO;
          break;
      
        case kSBXMLParserOptionSourceSBString:
          //
          // This one's easy -- just parse the whole darn UTF-16 character buffer with one call:
          //
          if ( _source.string && ! XML_Parse(EXPAT_PARSER, (const char*)[_source.string utf16Characters], sizeof(UChar) * [_source.string length], 1) )
            rc = NO;
          break;
          
        case kSBXMLParserOptionSourceFileDescriptor:
          if ( _source.fd >= 0 )
            rc = [self fileDescriptorParseLoop];
          break;
        
        case kSBXMLParserOptionSourceSBStream:
          if ( _source.stream )
            rc = [self streamParseLoop];
          break;
          
      }
      
      // Check to see if we were suspended -- if so, just return now:
      XML_ParsingStatus   status;
      
      XML_GetParsingStatus(EXPAT_PARSER, &status);
      if ( status.parsing == XML_SUSPENDED )
        return NO;
      
      // How'd we do?
      if ( ! rc ) {
        //
        // Error during parsing
        //
      } else if ( XML_GetErrorCode(EXPAT_PARSER) != XML_ERROR_NONE ) {
        //
        // Create an error object
        //
        rc = NO;
      } else {
        // We finished:
        if ( _delegate ) [_delegate xmlParserDidEndDocument:self];
      }
      
      XML_ParserFree(EXPAT_PARSER);
      _parser = NULL;
      [self stateCleanup];
    }
    return rc;
  }

//

  - (void) abortParsing
  {
    if ( _parser ) {
      XML_ParsingStatus   status;
      
      XML_GetParsingStatus(EXPAT_PARSER, &status);
      switch ( status.parsing ) {
      
        case XML_FINISHED:
        case XML_SUSPENDED:
          XML_StopParser(EXPAT_PARSER, XML_FALSE);
          XML_ParserFree(EXPAT_PARSER);
          _parser = NULL;
          [self stateCleanup];
          break;
        
        default:
          XML_StopParser(EXPAT_PARSER, XML_TRUE);
          break;
      }
    }
  }

//

  - (BOOL) shouldProcessNamespaces
  {
    return ( (_options & kSBXMLParserOptionProcessNamespaces) ? YES : NO );
  }
  - (BOOL) shouldResolveExternalEntities
  {
    return ( (_options & kSBXMLParserOptionResolveExternalEntities) ? YES : NO );
  }
  - (BOOL) shouldPreserveWhitespace
  {
    return ( (_options & kSBXMLParserOptionPreserveWhitespace) ? YES : NO );
  }
  
//

  - (void) setShouldProcessNamespaces:(BOOL)shouldProcessNamespaces
  {
    if ( ! _parser ) {
      if ( shouldProcessNamespaces )
        _options |= kSBXMLParserOptionProcessNamespaces;
      else
        _options &= ~kSBXMLParserOptionProcessNamespaces;
    }
  }
  - (void) setShouldResolveExternalEntities:(BOOL)shouldResolveExternalEntities
  {
    if ( ! _parser ) {
      if ( shouldResolveExternalEntities )
        _options |= kSBXMLParserOptionResolveExternalEntities;
      else
        _options &= ~kSBXMLParserOptionResolveExternalEntities;
    }
  }
  - (void) setShouldPreserveWhitespace:(BOOL)shouldPreserveWhitespace
  {
    if ( ! _parser ) {
      if ( shouldPreserveWhitespace )
        _options |= kSBXMLParserOptionPreserveWhitespace;
      else
        _options &= ~kSBXMLParserOptionPreserveWhitespace;
    }
  }

//

  - (SBUInteger) lineNumber
  {
    if ( _parser )
      return XML_GetCurrentLineNumber((XML_Parser)_parser);
    return 0;
  }

//

  - (SBUInteger) columnNumber
  {
    if ( _parser )
      return XML_GetCurrentColumnNumber((XML_Parser)_parser);
    return 0;
  }

@end

#undef EXPAT_PARSER
