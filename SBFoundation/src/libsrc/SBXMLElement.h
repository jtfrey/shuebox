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

#import "SBXMLNode.h"

@class SBMutableArray, SBDictionary, SBNumber;

/*!
  @method SBXMLElement
  @discussion
    Instances of SBXMLElement represent an XML element, its attributes, and all nodes that are children
    of it.  Any localized namespace declarations are recorded.
*/
@interface SBXMLElement : SBXMLNode
{
  SBString*               _elementName;
  SBString*               _namespaceURI;
  //
  SBMutableArray*         _attributes;
  SBMutableArray*         _namespaces;
  SBMutableArray*         _childNodes;
}

/*!
  @method initWithElementName:
  @discussion
    Initializes a newly-allocated instance to have the given unqualified elementName.  The recevier
    contains no attributes, namespace definitions, or child nodes.
*/
- (id) initWithElementName:(SBString*)elementName;
/*!
  @method initWithElementName:namespaceURI:
  @discussion
    Initializes a newly-allocated instance to have the given elementName qualified by the provided
    namespace URI.  The recevier contains no attributes, namespace definitions, or child nodes.
*/
- (id) initWithElementName:(SBString*)elementName namespaceURI:(SBString*)namespaceURI;
/*!
  @method initWithElementName:stringValue:
  @discussion
    Initializes a newly-allocated instance to have the given unqualified elementName.  The recevier
    contains no attributes or namespace definitions, and a single child node.  The child node is a text
    node containing stringValue.
*/
- (id) initWithElementName:(SBString*)elementName stringValue:(SBString*)stringValue;
/*!
  @method initWithElementName:stringValue:namespaceURI:
  @discussion
    Initializes a newly-allocated instance to have the given elementName qualified by the provided
    namespace URI.  The recevier contains no attributes or namespace definitions, and a single child node.
    The child node is a text node containing stringValue.
*/
- (id) initWithElementName:(SBString*)elementName stringValue:(SBString*)stringValue namespaceURI:(SBString*)namespaceURI;

/*!
  @method namespaceURI
  @discussion
    Returns the receiver's XML namespace URI.
*/
- (SBString*) namespaceURI;

/*!
  @method attributes
  @discussion
    Returns an array containing all XML attribute nodes associated with the receiver.
*/
- (SBArray*) attributes;
/*!
  @method setAttributes:
  @discussion
    Given an array of XML attribute nodes (attributes), set the receiver to have those attributes.
*/
- (void) setAttributes:(SBArray*)attributes;
/*!
  @method setAttributesFromDictionary:
  @discussion
    Given a dictionary of SBString values keyed by SBString's, set the receiver to have XML attribute
    nodes that wrap those key-value pairs.
*/
- (void) setAttributesFromDictionary:(SBDictionary*)attributes;
/*!
  @method attributeForName:
  @discussion
    If the receiver has an attribute with the given unqualified name, return that attribute node.
*/
- (SBXMLNode*) attributeForName:(SBString*)attribName;
/*!
  @method attributeForName:namespaceURI:
  @discussion
    If the receiver has an attribute with the given name (qualified by namespace URI), return that
    attribute node.
*/
- (SBXMLNode*) attributeForName:(SBString*)attribName namespaceURI:(SBString*)namespaceURI;
/*!
  @method addAttribute:
  @discussion
    Append the given XML attribute node to the receiver's set of attributes.
*/
- (void) addAttribute:(SBXMLNode*)anAttribute;
/*!
  @method removeAllAttributes
  @discussion
    Remove all XML attributes associated with the receiver.
*/
- (void) removeAllAttributes;
/*!
  @method removeAttributeForName:
  @discussion
    Remove an XML attribute with the given name that is associated with the receiver.
*/
- (void) removeAttributeForName:(SBString*)attribName;

/*!
  @method namespaces
  @discussion
    Returns an array of the namespace URIs declared in the receiver XML element.  The array
    contains SBXMLNode objects of type kSBXMLNodeKindNamespace.
*/
- (SBArray*) namespaces;
/*!
  @method setNamespaces:
  @discussion
    Set the namespace URIs declared for the receiver XML element.  Contents of the namespaces
    array should be SBXMLNode objects of type kSBXMLNodeKindNamespace.
*/
- (void) setNamespaces:(SBArray*)namespaces;
/*!
  @method namespaceForPrefix:
  @discussion
    Returns an SBXMLNode object of type kSBXMLNodeKindNamespace which has the given namespace
    prefix.
*/
- (SBXMLNode*) namespaceForPrefix:(SBString*)prefix;
/*!
  @method addNamespace:
  @discussion
    Append the given XML namespace node to the receiver's namespace declarations.
*/
- (void) addNamespace:(SBXMLNode*)aNamespace;
/*!
  @method removeAllNamespaces
  @discussion
    Remove all namespace declarations for the receiver element.
*/
- (void) removeAllNamespaces;
/*!
  @method removeNamespaceForPrefix:
  @discussion
    Remove the namespace declaration for the receiver element which has the given prefix.
*/
- (void) removeNamespaceForPrefix:(SBString*)prefix;
/*!
  @method coallesceTextNodes
  @discussion
    In the list of direct child nodes for this element, locate any back-to-back occurrences of
    SBXMLNode's of type kSBXMLNodeKindText and coallesce them into a single node.
*/
- (void) coallesceTextNodes;
/*!
  @method firstChildElementForElementName:
  @discussion
    Attempts to locate a direct child SBXMLElement of the receiver that has the given unqualified
    name.
*/
- (SBXMLElement*) firstChildElementForElementName:(SBString*)elementName;
/*!
  @method firstChildElementForElementName:namespaceURI:
  @discussion
    Attempts to locate a direct child SBXMLElement of the receiver that has the given name qualified
    by a namespace URI.
*/
- (SBXMLElement*) firstChildElementForElementName:(SBString*)elementName namespaceURI:(SBString*)namespaceURI;
/*!
  @method childElementsForElementName:
  @discussion
    Attempts to locate all direct child SBXMLElement's of the receiver that have the given unqualified
    name and returns an array containing them.
*/
- (SBArray*) childElementsForElementName:(SBString*)elementName;
/*!
  @method childElementsForElementName:namespaceURI:
  @discussion
    Attempts to locate all direct child SBXMLElement's of the receiver that have the given name qualified
    by a namespace URI and returns an array of them.
*/
- (SBArray*) childElementsForElementName:(SBString*)elementName namespaceURI:(SBString*)namespaceURI;
/*!
  @method stringForTextContainingNode
  @discussion
    If the receiver contains a single child node and it is of type kSBXMLNodeKindText, return the
    string contained in that node.
*/
- (SBString*) stringForTextContainingNode;

@end

@interface SBXMLElement(SBExtendedXMLElement)

/*!
  @method booleanAttributeForName:
  @discussion
    If the receiver contains the named attribute, attempts to transmute the value of the attribute
    into a boolean value.  The text "yes" and "true" will return YES, as will any non-zero numerical
    value.  All other values will return NO.
*/
- (BOOL) booleanAttributeForName:(SBString*)attribName;
/*!
  @method numberAttributeForName:
  @discussion
    If the receiver contains the named attribute, attempts to transmute the value of the attribute
    into an SBNumber.
*/
- (SBNumber*) numberAttributeForName:(SBString*)attribName;
/*!
  @method stringAttributeForName:
  @discussion
    If the receiver contains the named attribute, returns the stirng value.
*/
- (SBString*) stringAttributeForName:(SBString*)attribName;

@end
