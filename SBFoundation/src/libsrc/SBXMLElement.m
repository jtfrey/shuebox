//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLElement.h
//
// Specific representation of XML elements.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLElement.h"
#import "SBXMLNodePrivate.h"

#import "SBString.h"
#import "SBValue.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBScanner.h"

@implementation SBXMLElement

  - (id) initWithElementName:(SBString*)elementName
  {
    return [self initWithElementName:elementName stringValue:nil namespaceURI:nil];
  }

//

  - (id) initWithElementName:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
  {
    return [self initWithElementName:elementName stringValue:nil namespaceURI:namespaceURI];
  }

//

  - (id) initWithElementName:(SBString*)elementName
    stringValue:(SBString*)stringValue
  {
    return [self initWithElementName:elementName stringValue:stringValue namespaceURI:nil];
  }
  
//

  - (id) initWithElementName:(SBString*)elementName
    stringValue:(SBString*)stringValue
    namespaceURI:(SBString*)namespaceURI
  {
    if ( (self = [super initWithNodeKind:kSBXMLNodeKindElement]) ) {
      _elementName = [elementName copy];
      _namespaceURI = ( namespaceURI ? [namespaceURI copy] : nil );
      [self setStringValueOfNode:stringValue];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    // Remove all children:
    if ( _childNodes ) {
      [self removeAllChildNodes];
      [_childNodes release];
    }
    
    if ( _elementName ) [_elementName release];
    if ( _namespaceURI ) [_namespaceURI release];
    if ( _attributes ) [_attributes release];
    if ( _namespaces ) [_namespaces release];
    
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
    SBUInteger      i, iMax;
    
    fprintf(stream, "SBXMLElement@%p[" SBUIntegerFormat "] ( name = ", self, [self referenceCount]);
    if ( _namespaceURI ) {
      [_namespaceURI writeToStream:stream];
      fputc(':', stream);
    }
    [_elementName writeToStream:stream];
    fprintf(stream, "; childCount = " SBUIntegerFormat " ; index = %d ) {\n", ( _childNodes ? [_childNodes count] : 0 ), [self nodeIndex]);
    if ( _attributes && (iMax = [_attributes count]) ) {
      
      fprintf(stream, "  attributes:\n");
      i = 0;
      while ( i < iMax ) {
        fprintf(stream, "    %d: ", i);
        [[_attributes objectAtIndex:i++] summarizeToStream:stream];
      }
    }
    if ( _namespaces && (iMax = [_namespaces count]) ) {
      
      fprintf(stream, "  namespaces:\n");
      i = 0;
      while ( i < iMax ) {
        fprintf(stream, "    %d: ", i);
        [[_namespaces objectAtIndex:i++] summarizeToStream:stream];
      }
    }
    if ( _childNodes && (iMax = [_childNodes count]) ) {
      i = 0;
      while ( i < iMax )
        [[_childNodes objectAtIndex:i++] summarizeToStream:stream];
    }
    printf("}\n");
  }

//

  - (SBString*) nodeName
  {
    return _elementName;
  }
  - (void) setNodeName:(SBString*)nodeName
  {
    if ( nodeName ) {
      nodeName = [nodeName retain];
      if ( _elementName ) [_elementName release];
      _elementName = nodeName;
    }
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
      case kSBXMLNodeKindComment:
      case kSBXMLNodeKindText:
      case kSBXMLNodeKindProcessingInstruction:
        return YES;
    
    }
    return NO;
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
    // Drop all child nodes:
    [self removeAllChildNodes];
    
    if ( stringValue ) {
      // Create a text node:
      SBXMLNode*    textNode = [SBXMLNode textNodeWithStringValue:stringValue];
      
      if ( textNode )
        [self addChildNode:textNode];
    }
  }

//

  - (SBArray*) attributes
  {
    return _attributes;
  }

//

  - (void) setAttributes:(SBArray*)attributes
  {
    if ( _attributes )
      [self removeAllAttributes];
    
    SBUInteger      i = 0, iMax = ( attributes ? [attributes count] : 0 );
    
    while ( i < iMax )
      [self addAttribute:[attributes objectAtIndex:i++]];
  }
  
//

  - (void) setAttributesFromDictionary:(SBDictionary*)attributes
  {
    if ( _attributes )
      [self removeAllAttributes];
    
    //
    // We'll iterate over keys, creating attribute SBXMLNode instances
    // as we go using the key and the value for the key:
    //
    SBEnumerator*     eKey = [attributes keyEnumerator];
    SBString*         key;
    
    while ( (key = [eKey nextObject]) ) {
      SBString*       value = [attributes objectForKey:key];
      SBXMLNode*      attrib = [SBXMLNode attributeNodeWithName:key stringValue:value];
      
      if ( attrib )
        [self addAttribute:attrib];
    }
  }
  
//

  - (SBXMLNode*) attributeForName:(SBString*)attribName
  {
    if ( _attributes ) {
      SBUInteger    i = 0, iMax = [_attributes count];
      
      while ( i < iMax ) {
        SBXMLNode*  attrib = [_attributes objectAtIndex:i];
        
        if ( [[attrib nodeName] isEqual:attribName] )
          return attrib;
        i++;
      }
    }
  }
  
//

  - (SBXMLNode*) attributeForName:(SBString*)attribName
    namespaceURI:(SBString*)namespaceURI
  {
    if ( _attributes ) {
      SBUInteger    i = 0, iMax = [_attributes count];
      
      while ( i < iMax ) {
        SBXMLNode*  attrib = [_attributes objectAtIndex:i];
        
        if ( [[attrib nodeName] isEqual:attribName] )
          return attrib;
        i++;
      }
    }
  }
  
//

  - (void) addAttribute:(SBXMLNode*)anAttribute
  {
    if ( [anAttribute parentNode] )
      return;
    
    if ( ! _attributes )
      _attributes = [[SBMutableArray alloc] init];
      
    [anAttribute setParentNode:self];
    [anAttribute setNodeIndex:[_attributes count]];
    
    [_attributes addObject:anAttribute];
  }

//

  - (void) removeAllAttributes
  {
    if ( _attributes ) {
      [_attributes makeObjectsPerformSelector:@selector(detachFromParent)];
      [_attributes removeAllObjects];
    }
  }
  
//

  - (void) removeAttributeForName:(SBString*)attribName
  {
    if ( _attributes ) {
      SBUInteger    i = 0, iMax = [_attributes count];
      
      while ( i < iMax ) {
        SBXMLNode*  attrib = [_attributes objectAtIndex:i];
        
        if ( [[attrib nodeName] isEqual:attribName] ) {
          [attrib detachFromParent];
          [_attributes removeObjectAtIndex:i];
          return;
        }
        i++;
      }
    }
  }

//

  - (SBArray*) namespaces
  {
    return _namespaces;
  }
  
//

  - (void) setNamespaces:(SBArray*)namespaces
  {
    if ( _namespaces )
      [self removeAllNamespaces];
    
    SBUInteger      i = 0, iMax = ( namespaces ? [namespaces count] : 0 );
    
    while ( i < iMax )
      [self addNamespace:[namespaces objectAtIndex:i++]];
  }
  
//

  - (SBXMLNode*) namespaceForPrefix:(SBString*)prefix
  {
    if ( _namespaces ) {
      SBUInteger    i = 0, iMax = [_namespaces count];
      
      while ( i < iMax ) {
        SBXMLNode*  ns = [_namespaces objectAtIndex:i];
        
        if ( [[ns nodeName] isEqual:prefix] )
          return ns;
        i++;
      }
    }
  }
  
//

  - (void) addNamespace:(SBXMLNode*)aNamespace
  {
    if ( [aNamespace parentNode] )
      return;
    
    if ( ! _namespaces )
      _namespaces = [[SBMutableArray alloc] init];
      
    [aNamespace setParentNode:self];
    [aNamespace setNodeIndex:[_namespaces count]];
    
    [_namespaces addObject:aNamespace];
  }
  
//

  - (void) removeAllNamespaces
  {
    if ( _namespaces ) {
      [_namespaces makeObjectsPerformSelector:@selector(detachFromParent)];
      [_namespaces removeAllObjects];
    }
  }
  
//

  - (void) removeNamespaceForPrefix:(SBString*)prefix
  {
    if ( _namespaces ) {
      SBUInteger    i = 0, iMax = [_namespaces count];
      
      while ( i < iMax ) {
        SBXMLNode*  ns = [_namespaces objectAtIndex:i];
        
        if ( [[ns nodeName] isEqual:prefix] ) {
          [ns detachFromParent];
          [_namespaces removeObjectAtIndex:i];
          return;
        }
        i++;
      }
    }
  }
  
//

  - (void) coallesceTextNodes
  {
    if ( _childNodes ) {
      // Walk the children:
      SBUInteger    i = 0, iMax = [_childNodes count];
      SBUInteger    i0 = iMax, j;
      
      while ( i < iMax ) {
        SBXMLNode*    node = [_childNodes objectAtIndex:i];
        
        if ( [node nodeKind] == kSBXMLNodeKindText ) {
          if ( i0 == iMax )
            i0 = i;
        } else if ( i0 < iMax ) {
          if ( i0 == (i - 1) ) {
            // Just one node, don't do anything to that:
          } else {
            // Coallesce nodes i0 through (i - 1):
            j = i0;
            
            SBMutableString*    coallesce = [[[_childNodes objectAtIndex:j++] nodeValue] mutableCopy];
            
            while ( j < i )
              [coallesce appendString:[[_childNodes objectAtIndex:j++] nodeValue]];
            
            // Delete the nodes:
            while ( j-- > i0 ) {
              [self removeChildNodeAtIndex:j];
              iMax--;
            }
            
            // Now insert the replacement:
            SBXMLNode*          textNode = [SBXMLNode textNodeWithStringValue:coallesce];
            
            [coallesce release];
            [self insertChildNode:textNode atIndex:i0];
            iMax++;
          }
          // Reset:
          i = i0;
          i0 = iMax;
        }
        i++;
      }
      
      // In case the last node(s) were text:
      if ( i0 < iMax ) {
        if ( i0 == (i - 1) ) {
          // Just one node, don't do anything to that:
        } else {
          // Coallesce nodes i0 through (i - 1):
          j = i0;
          
          SBMutableString*    coallesce = [[[_childNodes objectAtIndex:j++] nodeValue] mutableCopy];
          
          while ( j < i )
            [coallesce appendString:[[_childNodes objectAtIndex:j++] nodeValue]];
          
          // Delete the nodes:
          while ( j-- > i0 ) {
            [self removeChildNodeAtIndex:j];
            iMax--;
          }
          
          // Now insert the replacement:
          SBXMLNode*          textNode = [SBXMLNode textNodeWithStringValue:coallesce];
          
          [coallesce release];
          [self insertChildNode:textNode atIndex:i0];
          iMax++;
        }
      }
    }
  }
  
//

  - (SBXMLElement*) firstChildElementForElementName:(SBString*)elementName
  {
    if ( _childNodes ) {
      SBUInteger      i = 0, iMax = [_childNodes count];
      SBXMLNode*      node;
      
      while ( i < iMax ) {
        node = [_childNodes objectAtIndex:i++];
        
        if ( [node nodeKind] == kSBXMLNodeKindElement ) {
          SBXMLElement*   element = (SBXMLElement*)node;
          
          if ( [[element nodeName] isEqual:elementName] )
            return element;
        }
      }
    }
    return nil;
  }
  
//

  - (SBXMLElement*) firstChildElementForElementName:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
  {
    if ( _childNodes ) {
      SBUInteger      i = 0, iMax = [_childNodes count];
      SBXMLNode*      node;
      
      while ( i < iMax ) {
        node = [_childNodes objectAtIndex:i++];
        
        if ( [node nodeKind] == kSBXMLNodeKindElement ) {
          SBXMLElement*   element = (SBXMLElement*)node;
          
          if ( [[element nodeName] isEqual:elementName] && (!namespaceURI || [[element namespaceURI] isEqual:namespaceURI]) )
            return element;
        }
      }
    }
    return nil;
  }
  
//

  - (SBArray*) childElementsForElementName:(SBString*)elementName
  {
    SBMutableArray*   matches = nil;
    
    if ( _childNodes ) {
      SBUInteger      i = 0, iMax = [_childNodes count];
      SBXMLNode*      node;
      
      while ( i < iMax ) {
        node = [_childNodes objectAtIndex:i++];
        
        if ( [node nodeKind] == kSBXMLNodeKindElement ) {
          SBXMLElement*   element = (SBXMLElement*)node;
          
          if ( [[element nodeName] isEqual:elementName] ) {
            if ( ! matches )
              matches = [[SBMutableArray alloc] init];
            [matches addObject:element];
          }
        }
      }
    }
    if ( matches ) [matches autorelease];
    return matches;
  }
  
//

  - (SBArray*) childElementsForElementName:(SBString*)elementName
    namespaceURI:(SBString*)namespaceURI
  {
    SBMutableArray*   matches = nil;
    
    if ( _childNodes ) {
      SBUInteger      i = 0, iMax = [_childNodes count];
      SBXMLNode*      node;
      
      while ( i < iMax ) {
        node = [_childNodes objectAtIndex:i++];
        
        if ( [node nodeKind] == kSBXMLNodeKindElement ) {
          SBXMLElement*   element = (SBXMLElement*)node;
          
          if ( [[element nodeName] isEqual:elementName] && (!namespaceURI || [[element namespaceURI] isEqual:namespaceURI]) ) {
            if ( ! matches )
              matches = [[SBMutableArray alloc] init];
            [matches addObject:element];
          }
        }
      }
    }
    if ( matches ) [matches autorelease];
    return matches;
  }

//

	- (SBString*) stringForTextContainingNode
	{
		[self coallesceTextNodes];
		if ( [self childNodeCount] == 1 ) {
			SBXMLNode*	singleNode = [self childNodeAtIndex:0];
			
			if ( [singleNode nodeKind] == kSBXMLNodeKindText )
				return [singleNode stringValueOfNode];
		}
		return nil;
	}

@end

//
#if 0
#pragma mark -
#endif
//

@implementation SBXMLElement(SBExtendedXMLElement)

  - (BOOL) booleanAttributeForName:(SBString*)attribName
  {
    SBString*       strValue = [self stringAttributeForName:attribName];
    
    if ( strValue ) {
      if ( [strValue caseInsensitiveCompare:@"yes"] || [strValue caseInsensitiveCompare:@"true"] || [strValue intValue] )
        return YES;
    }
    return NO;
  }

//

  - (SBNumber*) numberAttributeForName:(SBString*)attribName
  {
    SBString*       strValue = [self stringAttributeForName:attribName];
    SBNumber*       theNum = nil;
    
    if ( strValue ) {
      SBScanner*		strScanner = [[SBScanner alloc] initWithString:strValue];
      
      if ( strScanner ) {
        double      dblValue;
        
        if ( [strScanner scanDouble:&dblValue] ) {
          theNum = [SBNumber numberWithDouble:dblValue];
        }
        [strScanner release];
      }
    }
    return theNum;
  }

//

  - (SBString*) stringAttributeForName:(SBString*)attribName
  {
    SBXMLNode*      attribNode = [self attributeForName:attribName];
    
    return ( attribNode ? [attribNode stringValueOfNode] : (SBString*)nil );
  }

@end
