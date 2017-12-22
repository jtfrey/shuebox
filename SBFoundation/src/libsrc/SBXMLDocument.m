//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLDocument.m
//
// Specific representation of an XML document.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLDocument.h"
#import "SBXMLElement.h"
#import "SBXMLNodePrivate.h"
#import "SBXMLInternalParser.h"
#import "SBString.h"
#import "SBArray.h"

@implementation SBXMLDocument

  - (id) init
  {
    return [super initWithNodeKind:kSBXMLNodeKindDocument];
  }

//

  - (id) initWithXMLString:(SBString*)xmlString
  {
    if ( (self = [self init]) ) {
      if ( ! [[SBXMLInternalParser sharedXMLInternalParser] document:self withXMLString:xmlString] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }
  
//

  - (id) initWithStream:(SBInputStream*)stream
  {
    if ( (self = [self init]) ) {
      if ( ! [[SBXMLInternalParser sharedXMLInternalParser] document:self withStream:stream] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithData:(SBData*)data
  {
    if ( (self = [self init]) ) {
      if ( ! [[SBXMLInternalParser sharedXMLInternalParser] document:self withData:data] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithRootElement:(SBXMLElement*)rootElement
  {
    if ( (self = [self init]) ) {
      [self setRootElement:rootElement];
    }
    return self;
  }

//

  - (void) dealloc
  {
    // _rootElement is not a reference copy...
    
    if ( _childNodes ) [_childNodes release];
    
    [super dealloc];
  }
    
//

  - (SBArray*) childNodes
  {
    return (SBArray*)_childNodes;
  }
  
//

  - (BOOL) shouldAddChildNode:(SBXMLNode*)childNode
  {
    //
    // An element can only have other elements, comments, text, and processing instructions added to it:
    //
    switch ( [childNode nodeKind] ) {
    
      case kSBXMLNodeKindElement:
        return ( _rootElement ? NO : YES );
        
      case kSBXMLNodeKindComment:
      case kSBXMLNodeKindProcessingInstruction:
        return YES;
    
    }
    return NO;
  }

//

  - (void) didAddChildNode:(SBXMLNode*)childNode
  {
    // If it was a root element, be sure to set _rootElement, too:
    if ( [childNode nodeKind] == kSBXMLNodeKindElement )
      _rootElement = (SBXMLElement*)childNode;
  }

//

  - (void) didRemoveChildNode:(SBXMLNode*)childNode
  {
    // Nil-out the _rootElement if the childNode removed was the root element:
    if ( childNode == _rootElement )
      _rootElement = nil;
  }

//

  - (SBMutableArray*) mutableChildNodesCreateIfNotPresent:(BOOL)createIfNotPresent
  {
    if ( ! _childNodes && createIfNotPresent )
      _childNodes = [[SBMutableArray alloc] init];
    return _childNodes;
  }

//

  - (SBString*) stringValueOfNode
  {
    // Unparse the node and all of its children:
    
  }
  - (void) setStringValueOfNode:(SBString*)stringValue
  {
    // NOOP
  }

//

  - (SBArray*) nodesForXPath:(SBString*)xPath
  {
    if ( _rootElement )
      return [_rootElement nodesForXPath:xPath];
    return nil;
  }

//

  - (SBXMLElement*) rootElement
  {
    return _rootElement;
  }
  - (void) setRootElement:(SBXMLElement*)rootElement
  {
    if ( ! _rootElement ) {
      [self addChildNode:rootElement];
    } else if ( ! rootElement && _childNodes ) {
      SBUInteger    i = 0, iMax = [_childNodes count];
      
      while ( i < iMax ) {
        rootElement = [_childNodes objectAtIndex:i];
        if ( [rootElement nodeKind] == kSBXMLNodeKindElement ) {
          [self removeChildNodeAtIndex:i];
          break;
        }
        i++;
      }
    }
  }
	
//

	- (BOOL) isNamedDocument:(SBString*)rootElementName
	{
		if ( _rootElement && [rootElementName isEqual:[_rootElement nodeName]] )
			return YES;
		return NO;
	}
	
//

	- (BOOL) isNamedDocument:(SBString*)rootElementName
		namespaceURI:(SBString*)namespaceURI
	{
		if ( _rootElement ) {
			if ( [rootElementName isEqual:[_rootElement nodeName]] && (! namespaceURI || [namespaceURI isEqual:[_rootElement namespaceURI]]) )
				return YES;
		}
		return NO;
	}

@end
