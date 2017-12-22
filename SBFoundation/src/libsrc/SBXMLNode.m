//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLNode.m
//
// Generic representation of XML document nodes.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLNode.h"
#import "SBXMLNodePrivate.h"
#import "SBString.h"
#import "SBData.h"
#import "SBArray.h"
#import "SBXMLElement.h"
#import "SBXMLDocument.h"
#import "SBXMLParser.h"

//

@interface SBXMLProcessingInstructionNode : SBXMLNode
{
  SBString*         _piName;
}

- (id) initWithProcessingInstructionName:(SBString*)piName stringValue:(SBString*)stringValue;

@end

@implementation SBXMLProcessingInstructionNode

  - (id) initWithProcessingInstructionName:(SBString*)piName
    stringValue:(SBString*)stringValue
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindProcessingInstruction]) ) {
      _piName = [piName copy];
      [self setStringValueOfNode:stringValue];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _piName ) [_piName release];
    [super dealloc];
  }

//

  - (SBString*) nodeName
  {
    return _piName;
  }
  - (void) setNodeName:(SBString*)nodeName
  {
    if ( nodeName ) nodeName = [nodeName copy];
    if ( _piName ) [_piName release];
    _piName = nodeName;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBXMLNamespaceNode : SBXMLNode
{
  SBString*         _prefix;
}

- (id) initWithPrefix:(SBString*)prefix stringValue:(SBString*)stringValue;

@end

@implementation SBXMLNamespaceNode

  - (id) initWithPrefix:(SBString*)prefix
    stringValue:(SBString*)stringValue
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindNamespace]) ) {
      _prefix = [prefix copy];
      [self setStringValueOfNode:stringValue];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _prefix ) [_prefix release];
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    fprintf(stream, "SBXMLNamespaceNode@%p[" SBUIntegerFormat "] ( index = %d ) { ", self, [self referenceCount], [self nodeIndex]);
    [_prefix writeToStream:stream];
    fprintf(stream, " = ");
    [[self nodeValue] writeToStream:stream];
    fprintf(stream, " }\n");
  }

//

  - (SBString*) nodeName
  {
    return _prefix;
  }
  - (void) setNodeName:(SBString*)nodeName
  {
    if ( nodeName ) nodeName = [nodeName copy];
    if ( _prefix ) [_prefix release];
    _prefix = nodeName;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBXMLAttributeNode : SBXMLNode
{
  SBString*         _attributeName;
  SBString*         _namespaceURI;
}

- (id) initWithAttributeName:(SBString*)attribName stringValue:(SBString*)stringValue;
- (id) initWithAttributeName:(SBString*)attribName stringValue:(SBString*)stringValue namespaceURI:(SBString*)namespaceURI;

@end

@implementation SBXMLAttributeNode

  - (id) initWithAttributeName:(SBString*)attribName
    stringValue:(SBString*)stringValue
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindAttribute]) ) {
      //
      // We have to decompose the attribute name into namespace junk ourselves:
      //
      SBString*               nsURI = nil;
      SBString*               localName = attribName;
      SBRange                 nsDelim = [attribName rangeOfString:@":" options:SBStringBackwardsSearch];
  
      if ( ! SBRangeEmpty(nsDelim) ) {
        // Decompose the string:
        if ( nsDelim.start > 0 )
          nsURI = [attribName substringToIndex:nsDelim.start - 1];
        localName = [attribName substringFromIndex:SBRangeMax(nsDelim)];
      }
      _attributeName = [localName copy];
      _namespaceURI = ( nsURI ? [nsURI copy] : nil );
      [self setStringValueOfNode:stringValue];
    }
    return self;
  }
  
//

  - (id) initWithAttributeName:(SBString*)attribName
    stringValue:(SBString*)stringValue
    namespaceURI:(SBString*)namespaceURI
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindAttribute]) ) {
      _attributeName = [attribName copy];
      _namespaceURI = ( namespaceURI ? [namespaceURI copy] : nil );
      [self setStringValueOfNode:stringValue];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _attributeName ) [_attributeName release];
    if ( _namespaceURI ) [_namespaceURI release];
    [super dealloc];
  }

//

  - (SBString*) namespaceURI
  {
    return _namespaceURI;
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    fprintf(stream, "SBXMLAttributeNode@%p[" SBUIntegerFormat "] ( index = %d ) { ", self, [self referenceCount], [self nodeIndex]);
    if ( _namespaceURI ) {
      [_namespaceURI writeToStream:stream];
      fputc(':', stream);
    }
    [_attributeName writeToStream:stream];
    fprintf(stream, " = ");
    [[self nodeValue] writeToStream:stream];
    fprintf(stream, " }\n");
  }

//

  - (SBString*) nodeName
  {
    return _attributeName;
  }
  - (void) setNodeName:(SBString*)nodeName
  {
    if ( nodeName ) nodeName = [nodeName copy];
    if ( _attributeName ) [_attributeName release];
    _attributeName = nodeName;
    
    if ( _namespaceURI ) {
      [_namespaceURI release];
      _namespaceURI = nil;
    }
    if ( _attributeName ) {
      SBString*               nsURI = nil;
      SBString*               localName = _attributeName;
      SBRange                 nsDelim = [_attributeName rangeOfString:@":" options:SBStringBackwardsSearch];
  
      if ( ! SBRangeEmpty(nsDelim) ) {
        // Decompose the string:
        if ( nsDelim.start > 0 )
          nsURI = [_attributeName substringToIndex:nsDelim.start - 1];
        localName = [_attributeName substringFromIndex:SBRangeMax(nsDelim)];
        
        [_attributeName release];
        _attributeName = [localName retain];
        _namespaceURI = ( nsURI ? [nsURI retain] : nil );
      }
    }
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBXMLCommentNode : SBXMLNode

- (id) initWithStringValue:(SBString*)stringValue;

@end

@implementation SBXMLCommentNode

  - (id) initWithStringValue:(SBString*)stringValue
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindComment]) )
      [self setStringValueOfNode:stringValue];
    return self;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@interface SBXMLTextNode : SBXMLNode

- (id) initWithStringValue:(SBString*)stringValue;

@end

@implementation SBXMLTextNode

  - (id) initWithStringValue:(SBString*)stringValue
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindText]) )
      [self setStringValueOfNode:stringValue];
    return self;
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLNode

  - (id) initWithNodeKind:(SBXMLNodeKind)nodeKind
  {
    if ( (self = [super init]) ) {
      _nodeKind = nodeKind;
    }
    return self;
  }

//

  - (void) dealloc
  {
    //
    // Since the parent node retains us, we shouldn't release our own reference to the parent!
    // Before we get deallocated the parent will have removed us from its child array and sent
    // a "detachFromParent" message to us.
    //
    if ( _nodeValue ) [_nodeValue release];
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    SBUInteger      i = 0, iMax;
    
    fprintf(stream, "SBXMLNode@%p[" SBUIntegerFormat "] ( kind = %d ; index = %d ) {", self, [self referenceCount], _nodeKind, _nodeIndex);
    if ( _nodeValue )
      [_nodeValue writeToStream:stream];
    if ( (iMax = [self childNodeCount]) ) {
      SBArray*      children = [self childNodes];
      
      while ( i < iMax )
        [[children objectAtIndex:i++] summarizeToStream:stream];
    }
    fprintf(stream, "}\n");
    
  }

//

  - (SBXMLNodeKind) nodeKind
  {
    return _nodeKind;
  }
  
//

  - (SBUInteger) nodeIndex
  {
    return _nodeIndex;
  }
  
//

  - (SBString*) nodeName
  {
    return nil;
  }
  - (void) setNodeName:(SBString*)nodeName
  {
    return;
  }

//

  - (id) nodeValue
  {
    return _nodeValue;
  }
  - (void) setNodeValue:(id)nodeValue
  {
    if ( nodeValue ) nodeValue = [nodeValue retain];
    if ( _nodeValue ) [_nodeValue release];
    _nodeValue = nodeValue;
  }
  
//

  - (SBString*) stringValueOfNode
  {
    // Basically, if we have a nodeValue and it's an SBString, return that:
    if ( _nodeValue && [_nodeValue isKindOf:[SBString class]] )
      return _nodeValue;
    return nil;
  }
  - (void) setStringValueOfNode:(SBString*)stringValue
  {
    SBString*     copyOfValue = ( stringValue ? [stringValue copy] : nil );
    
    [self setNodeValue:copyOfValue];
    if ( copyOfValue )
      [copyOfValue release];
  }
  
//

  - (SBXMLDocument*) rootDocument
  {
    // Walk back through all parent nodes until there is no parent:
    if ( _parentNode )
      return [_parentNode rootDocument];
    
    // If we're a document node, then we found the root document!
    if ( _nodeKind == kSBXMLNodeKindDocument )
      return (SBXMLDocument*)self;
    
    // We must be a standalone node, without a parent document:
    return nil;
  }
  
//

  - (SBXMLNode*) parentNode
  {
    return _parentNode;
  }
  
//

  - (SBUInteger) childNodeCount
  {
    SBArray*      myChildren = [self childNodes];
    
    return ( myChildren ? [myChildren count] : 0 );
  }
  - (SBArray*) childNodes
  {
    return nil;
  }
  - (SBXMLNode*) childNodeAtIndex:(SBUInteger)index
  {
    SBArray*      myChildren = [self childNodes];
    
    return ( myChildren ? [myChildren objectAtIndex:index] : nil );
  }
	- (SBXMLNode*) firstChild
	{
		if ( [self childNodeCount] > 0 )
			return [self childNodeAtIndex:0];
		return nil;
	}
	- (SBXMLNode*) firstChildOfKind:(SBXMLNodeKind)nodeKind
	{
    SBArray*      myChildren = [self childNodes];
    SBUInteger		i = 0, iMax;
		
		if ( myChildren && (iMax = [myChildren count]) ) {
			while ( i < iMax ) {
				SBXMLNode*	childNode = [myChildren objectAtIndex:i++];
				
				if ( [childNode nodeKind] == nodeKind )
					return childNode;
			}
		}
		return nil;
	}

//

  - (SBXMLNode*) previousSiblingNode
  {
    if ( _parentNode && _nodeIndex )
      return [_parentNode childNodeAtIndex:(_nodeIndex - 1)];
    return nil;
  }
  - (SBXMLNode*) nextSiblingNode
  {
    if ( _parentNode )
      return [_parentNode childNodeAtIndex:(_nodeIndex + 1)];
    return nil;
  }

//

  - (SBXMLNode*) previousNode
  {
    SBXMLNode*    node = [self previousSiblingNode];
    
    if ( node ) {
      SBUInteger  i = [node childNodeCount];
      
      if ( i )
        return [node childNodeAtIndex:(i - 1)];
      return node;
    }
    return [self parentNode];
  }
  - (SBXMLNode*) nextNode
  {
    SBXMLNode*    node = nil;
    
    if ( [self childNodeCount] ) {
      if ( (node = [self childNodeAtIndex:0]) )
        return node;
    }
    if ( (node = [self nextSiblingNode]) ) {
      return node;
    }
    if ( (node = [self parentNode]) ) {
      return [node nextSiblingNode];
    }
    return nil;
  }

//

  - (void) detachFromParent
  {
    _nodeIndex = 0;
    _parentNode = nil;
  }

//

  - (SBArray*) nodesForXPath:(SBString*)xPath
  {
    SBMutableArray*   nodes = nil;
    
    // Is the xPath absolute?
    if ( [xPath characterAtIndex:0] == '/' ) {
      SBXMLDocument*    root = [self rootDocument];
      
      if ( root )
        return [root nodesForXPath:xPath];
      
      SBXMLNode*        element = [self parentNode];
      
      while ( element ) {
        if ( [element parentNode] )
          element = [element parentNode];
        else
          return [element nodesForXPath:xPath];
      }
    }
    
    SBArray*          pieces = [xPath componentsSeparatedByString:@"/"];
    
    [self walkXPathArray:pieces atIndex:0 matches:&nodes];
    
    return nodes;
  }

//

  + (id) documentNode
  {
    return [self documentNodeWithRootElement:nil];
  }
  + (id) documentNodeWithRootElement:(SBXMLElement*)docElement
  {
    return [[[SBXMLDocument alloc] initWithRootElement:docElement] autorelease];
  }
  
//

  + (id) elementNodeWithName:(SBString*)nodeName
  {
    return [self elementNodeWithName:nodeName stringValue:nil namespaceURI:nil];
  }
  + (id) elementNodeWithName:(SBString*)nodeName
    namespaceURI:(SBString*)namespaceURI
  {
    return [self elementNodeWithName:nodeName stringValue:nil namespaceURI:namespaceURI];
  }
  + (id) elementNodeWithName:(SBString*)nodeName
    stringValue:(SBString*)stringValue
  {
    SBXMLNode*      textNode = ( stringValue ? [self textNodeWithStringValue:stringValue] : nil );
    
    return [self elementNodeWithName:nodeName childNode:textNode attributes:nil namespaceURI:nil];
  }
  + (id) elementNodeWithName:(SBString*)nodeName
    stringValue:(SBString*)stringValue
    namespaceURI:(SBString*)namespaceURI
  {
    SBXMLNode*      textNode = ( stringValue ? [self textNodeWithStringValue:stringValue] : nil );
    
    return [self elementNodeWithName:nodeName childNode:textNode attributes:nil namespaceURI:namespaceURI];
  }
  + (id) elementNodeWithName:(SBString*)nodeName
    childNode:(SBXMLNode*)childNode
    attributes:(SBArray*)attributes
    namespaceURI:(SBString*) namespaceURI
  {
    SBXMLElement*   element = [[[SBXMLElement alloc] initWithElementName:nodeName namespaceURI:namespaceURI] autorelease];
    
    if ( element ) {
      if ( childNode )
        [element addChildNode:childNode];
      if ( attributes )
        [element setAttributes:attributes];
    }
    return element;
  }
  + (id) elementNodeWithName:(SBString *)nodeName
    childNodes:(SBArray*)childNodes
    attributes:(SBArray*)attributes
    namespaceURI:(SBString*) namespaceURI
  {
    SBXMLElement*   element = [[[SBXMLElement alloc] initWithElementName:nodeName namespaceURI:namespaceURI] autorelease];
    
    if ( element ) {
      if ( childNodes )
        [element setChildNodes:childNodes];
      if ( attributes )
        [element setAttributes:attributes];
    }
    return element;
  }

//

  + (id) attributeNodeWithName:(SBString*)attribName
    stringValue:(SBString*)stringValue
  {
    return [[[SBXMLAttributeNode alloc] initWithAttributeName:attribName stringValue:stringValue] autorelease];
  }
  + (id) attributeNodeWithName:(SBString*)attribName
    stringValue:(SBString*)stringValue
    namespaceURI:(SBString*)namespaceURI
  {
    return [[[SBXMLAttributeNode alloc] initWithAttributeName:attribName stringValue:stringValue namespaceURI:namespaceURI] autorelease];
  }

//

  + (id) processingInstructionNodeWithName:(SBString*)piName
    stringValue:(SBString*)stringValue
  {
    return [[[SBXMLProcessingInstructionNode alloc] initWithProcessingInstructionName:piName stringValue:stringValue] autorelease];
  }

//

  + (id) namespaceNodeWithPrefix:(SBString*)prefix
    stringValue:(SBString*)stringValue
  {
    return [[[SBXMLNamespaceNode alloc] initWithPrefix:prefix stringValue:stringValue] autorelease];
  }
  
//

  + (id) commentNodeWithStringValue:(SBString*)stringValue
  {
    return [[[SBXMLCommentNode alloc] initWithStringValue:stringValue] autorelease];
  }
  
//

  + (id) textNodeWithStringValue:(SBString*)stringValue
  {
    return [[[SBXMLTextNode alloc] initWithStringValue:stringValue] autorelease];
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLNode(SBXMLNodeContainer)


  - (void) setChildNodes:(SBArray*)childNodes
  {
    // Drop all child nodes:
    [self removeAllChildNodes];
    
    // Add incoming children:
    if ( childNodes )
      [self insertChildNodes:childNodes atIndex:0];
  }
  
//

  - (void) addChildNode:(SBXMLNode*)childNode
  {
    if ( [self shouldAddChildNode:childNode] ) {
      SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
      
      // Don't do it if the node already has a parent:
      if ( ! [childNode parentNode] ) {
        // Make sure the child array exists now:
        if ( ! myChildren )
          myChildren = [self mutableChildNodesCreateIfNotPresent:YES];
        
        // Setup the child node:
        [childNode setParentNode:self];
        [childNode setNodeIndex:[myChildren count]];
        
        // Get the node in the chain:
        [myChildren addObject:childNode];
        [self didAddChildNode:childNode];
      }
    }
  }
  
//

  - (void) insertChildNode:(SBXMLNode*)childNode
    atIndex:(SBUInteger)index
  {
    if ( [self shouldAddChildNode:childNode] ) {
      SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
      SBUInteger          i, iMax = 0;
      
      // Check for cases where we're adding to the end of the child chain:
      if ( ! myChildren || (index >= (iMax = [myChildren count])) ) {
        [self addChildNode:childNode];
        return;
      }
      
      // Renumber children that will shift:
      i = index;
      while ( i < iMax ) {
        [[myChildren objectAtIndex:i] setNodeIndex:(i + 1)];
        i++;
      }
      
      // Setup the child node:
      [childNode setParentNode:self];
      [childNode setNodeIndex:index];
      
      // Insert the node into the chain:
      [myChildren insertObject:childNode atIndex:index];
      [self didAddChildNode:childNode];
    }
  }
  
//

  - (void) insertChildNodes:(SBArray*)childNodes
    atIndex:(SBUInteger)index
  {
    SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
    SBUInteger          i, iMax = 0;
    SBUInteger          j = 0, jMax = ( childNodes ? [childNodes count] : 0 );
    
    if ( ! jMax )
      return;
    
    // Check for cases where we're adding to the end of the child chain:
    if ( ! myChildren || (index >= (iMax = [myChildren count])) ) {
      // Iterate over the incoming children and add 'em one at a time:
      while ( j < jMax )
        [self addChildNode:[childNodes objectAtIndex:j++]];
    } else {
      // Iterate over the incoming children:
      i = index;
      while ( j < jMax ) {
        SBXMLNode*    childNode = [childNodes objectAtIndex:j];
        
        if ( ! [childNode parentNode] && [self shouldAddChildNode:childNode] ) {
          // Setup the child node:
          [childNode setParentNode:self];
          [childNode setNodeIndex:i];
          
          // Insert the node into the chain:
          [myChildren insertObject:childNode atIndex:i];
          [self didAddChildNode:childNode];
          i++;
          iMax++;
        }
        j++;
      }
      
      // Renumber children that shifted:
      while ( i < iMax ) {
        [[myChildren objectAtIndex:i] setNodeIndex:i];
        i++;
      }
      
    }
  }

//

  - (void) removeAllChildNodes
  {
    SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
    
    if ( myChildren ) {
      SBEnumerator*     eChild = [myChildren objectEnumerator];
      SBXMLNode*        child;
      
      while ( (child = [eChild nextObject]) ) {
        [child detachFromParent];
        [self didRemoveChildNode:child];
      }
      [myChildren removeAllObjects];
    }
  }
  
//

  - (void) removeChildNodeAtIndex:(SBUInteger)index
  {
    SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
    SBUInteger          i, iMax;
    
    if ( myChildren && (index < (iMax = [myChildren count])) ) {
      // Renumber children above this one:
      i = index + 1;
      while ( i < iMax ) {
        [[myChildren objectAtIndex:i] setNodeIndex:(i - 1)];
        i++;
      }
      // Now remove the node:
      SBXMLNode*      node = [myChildren objectAtIndex:index];
      
      [node detachFromParent];
      [self didRemoveChildNode:node];
      [myChildren removeObjectAtIndex:index];
    }
  }
  
//

  - (void) replaceChildNodeAtIndex:(SBUInteger)index
    withNode:(SBXMLNode*)aNode
  {
    if ( [self shouldAddChildNode:aNode] ) {
      SBMutableArray*     myChildren = [self mutableChildNodesCreateIfNotPresent:NO];
      
      if ( ! [aNode parentNode] && myChildren && (index < [myChildren count]) ) {
        // Snap the existing child out of the tree:
        SBXMLNode*      node = [myChildren objectAtIndex:index];
        
        // We're dismissing the extant node:
        [node detachFromParent];
        [self didRemoveChildNode:node];
        
        // Setup the child node:
        [aNode setParentNode:self];
        [aNode setNodeIndex:index];
        
        // Swap 'em:
        [myChildren replaceObject:aNode atIndex:index];
      }
    }
  }

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLNode(SBXMLNodePrivate)

  - (SBString*) namespaceURI
  {
    return nil;
  }

//

  - (BOOL) shouldAddChildNode:(SBXMLNode*)childNode
  {
    return NO;
  }
  - (void) didAddChildNode:(SBXMLNode*)childNode
  {
    // NOOP
  }

//

  - (void) didRemoveChildNode:(SBXMLNode*)childNode
  {
    // NOOP
  }

//

  - (SBMutableArray*) mutableChildNodesCreateIfNotPresent:(BOOL)createIfNotPresent
  {
    return nil;
  }

//

  - (void) setNodeIndex:(SBUInteger)nodeIndex
  {
    _nodeIndex = nodeIndex;
  }
  
//

  - (void) setParentNode:(SBXMLNode*)parentNode
  {
    if ( _parentNode )
      [self detachFromParent];
    _parentNode = parentNode;
  }
  
//

  - (void) walkXPathArray:(SBArray*)pieces
    atIndex:(SBUInteger)index
    matches:(SBMutableArray**)matches
  {
    SBUInteger      indexMax = [pieces count];
    
    // Skip to the first non-trivial component:
    while ( index < indexMax ) {
      SBString*     piece = [pieces objectAtIndex:index];
      
      if ( [piece isEqual:@"."] ) {
        index++;
      } else if ( [piece isEqual:@".."] ) {
        SBXMLNode*  parent = [self parentNode];
        
        if ( parent )
          [parent walkXPathArray:pieces atIndex:index + 1 matches:matches];
        return;
      } else {
        break;
      }
    }
    
    //  pieces[index] is an XPath component that targets this node:
    return;
  }
  
@end
