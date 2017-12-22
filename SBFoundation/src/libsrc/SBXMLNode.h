//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLNode.h
//
// Generic representation of XML document nodes.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @enum XML Node Kind
  @discussion
    Enumerates the sub-types of SBXMLNode objects.  There is
    a close correlation to the expat event-based processing model.
*/
enum {
  kSBXMLNodeKindUndefined = 0,
  kSBXMLNodeKindDocument,
  kSBXMLNodeKindElement,
  kSBXMLNodeKindAttribute,
  kSBXMLNodeKindProcessingInstruction,
  kSBXMLNodeKindNamespace,
  kSBXMLNodeKindComment,
  kSBXMLNodeKindText
};
/*!
  @typedef SBXMLNodeKind
  @discussion
    The type of an SBXMLNode sub-type identifier.
*/
typedef SBUInteger SBXMLNodeKind;

@class SBArray, SBXMLDocument, SBXMLElement;

/*!
  @class SBXMLNode
  @discussion
    The root of a class cluster that is used to represent XML document pieces.  An
    SBXMLNode has a distinct sub-type ("kind") that identifies what sub-class models
    it, etc.
    
    All SBXMLNode objects have a subordinate relationship with a parent SBXMLNode, with
    the exception of SBXMLDocumentNode objects.  An SBXMLNode also has an index that
    identifies its position among any sibling nodes.
    
    The value of an SBXMLNode is subject to its kind.  For example, a node of type
    kSBXMLNodeKindAttribute stores its attribute value in this property as an SBString.
    
    SBXMLNode instances should not be allocated directly.  Always use the class factory
    methods to ensure that the appropriate SBXMLNode subclass is used.
*/
@interface SBXMLNode : SBObject
{
  SBXMLNodeKind     _nodeKind;
  SBXMLNode*        _parentNode;
  SBUInteger        _nodeIndex;
  id                _nodeValue;
}

- (id) initWithNodeKind:(SBXMLNodeKind)nodeKind;

/*!
  @method nodeKind
  @discussion
    Returns the receiver's XML node kind. 
*/
- (SBXMLNodeKind) nodeKind;
/*!
  @method nodeIndex
  @discussion
    Returns the receiver's index within its parent's array of children (i.e. its
    index in its chain of siblings).
*/
- (SBUInteger) nodeIndex;
/*!
  @method nodeName
  @discussion
    Returns the name of the receiver node.
*/
- (SBString*) nodeName;
/*!
  @method setNodeName:
  @discussion
    Sets the name of the receiver node.
*/
- (void) setNodeName:(SBString*)nodeName;
/*!
  @method nodeValue
  @discussion
    Returns the value associated with the receiver node.
*/
- (id) nodeValue;
/*!
  @method setNodeValue:
  @discussion
    Sets the value associated with the receiver node.
*/
- (void) setNodeValue:(id)nodeValue;
/*!
  @method stringValueOfNode
  @discussion
    Return the value of the receiver node if it is an SBString.
*/
- (SBString*) stringValueOfNode;
/*!
  @method setStringValueOfNode:
  @discussion
    Set the value of the receiver node using the given stringValue.
*/
- (void) setStringValueOfNode:(SBString*)stringValue;
/*!
  @method rootDocument
  @discussion
    Traces back through the chain of parent nodes starting at the receiver until
    the SBXMLDocument that contains the receiver is found and returns it.
*/
- (SBXMLDocument*) rootDocument;
/*!
  @method parentNode
  @discussion
    Returns the parent node of the receiver.
*/
- (SBXMLNode*) parentNode;
/*!
  @method childNodeCount
  @discussion
    Returns the number of direct child nodes associated with the receiver.
*/
- (SBUInteger) childNodeCount;
/*!
  @method childNodes
  @discussion
    Returns an array of the direct child nodes associated with the receiver.
*/
- (SBArray*) childNodes;
/*!
  @method childNodeAtIndex:
  @discussion
    Returns the direct child node of the receiver with the given index in the
    sibling chain.
*/
- (SBXMLNode*) childNodeAtIndex:(SBUInteger)index;
/*!
  @method firstChild
  @discussion
    Returns the direct child node of the receiver at index 0.
*/
- (SBXMLNode*) firstChild;
/*!
  @method firstChildOfKind:
  @discussion
    Returns the lowest-index direct child node of the receiver that is of nodeKind.
*/
- (SBXMLNode*) firstChildOfKind:(SBXMLNodeKind)nodeKind;
/*!
  @method previousSiblingNode
  @discussion
    If the receiver has a parent node, return the parent's child node that occurs
    before the receiver in the list of siblings.
*/
- (SBXMLNode*) previousSiblingNode;
/*!
  @method nextSiblingNode
  @discussion
    If the receiver has a parent node, return the parent's child node that occurs
    after the receiver in the list of siblings.
*/
- (SBXMLNode*) nextSiblingNode;
/*!
  @method previousNode
  @discussion
    If the receiver is the first child of its parent, then the parent node is
    returned.  Otherwise, if the previous sibling has children, the last direct child
    of that sibling is returned.  Failing that, the previous sibling itself is
    returned.
*/
- (SBXMLNode*) previousNode;
/*!
  @method nextNode
  @discussion
    If the receiver is the last child of its parent, then the next sibling of the
    parent node is returned.  Otherwise, if the receiver has child nodes then the first
    child of the receiver is returned.  Failing that, the next sibling of the receiver
    is returned.
*/
- (SBXMLNode*) nextNode;
/*!
  @method detachFromParent
  @discussion
    Remove the receiver from its parent node.  The receiver becomes unassociated with
    any SBXMLDocument, etc.
*/
- (void) detachFromParent;

/*!
  @method nodesForXPath
  @discussion
    Evaluates the given XML xpath relative to the receiver node and returns an array
    containing the affected XML nodes.
*/
- (SBArray*) nodesForXPath:(SBString*)xPath;

/*!
  @method documentNode
  @discussion
    Returns an empty XML document node (see SBXMLDocument).
*/
+ (id) documentNode;
/*!
  @method documentNodeWithRootElement:
  @discussion
    Returns an XML document node (see SBXMLDocument) with docElement as its
    root element.
*/
+ (id) documentNodeWithRootElement:(SBXMLElement*)docElement;
/*!
  @method elementNodeWithName:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given unqualified name.
*/
+ (id) elementNodeWithName:(SBString*)nodeName;
/*!
  @method elementNodeWithName:namespaceURI:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given name qualified
    by the namespace URI.
*/
+ (id) elementNodeWithName:(SBString*)nodeName namespaceURI:(SBString*)namespaceURI;
/*!
  @method elementNodeWithName:stringValue:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given unqualified name.
    The value of the node is set to stringValue.
*/
+ (id) elementNodeWithName:(SBString*)nodeName stringValue:(SBString*)stringValue;
/*!
  @method elementNodeWithName:stringValue:namespaceURI:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given name qualified
    by the namespace URI.  The value of the node is set to stringValue.
*/
+ (id) elementNodeWithName:(SBString*)nodeName stringValue:(SBString*)stringValue namespaceURI:(SBString*)namespaceURI;
/*!
  @method elementNodeWithName:childNode:attributes:namespaceURI:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given name qualified
    by the namespace URI.  The node is configured to have the given set of attributes
    and a single childNode.
*/
+ (id) elementNodeWithName:(SBString*)nodeName childNode:(SBXMLNode*)childNode attributes:(SBArray*)attributes namespaceURI:(SBString*) namespaceURI;
/*!
  @method elementNodeWithName:childNodes:attributes:namespaceURI:
  @discussion
    Returns an XML element node (see SBXMLElement) with the given name qualified
    by the namespace URI.  The node is configured to have the given set of attributes
    and the children specified by the childNodes array.  The children will be ordered
    as they appear in the childNodes array.
*/
+ (id) elementNodeWithName:(SBString *)nodeName childNodes:(SBArray*)childNodes attributes:(SBArray*)attributes namespaceURI:(SBString*) namespaceURI;

/*!
  @method attributeNodeWithName:stringValue:
  @discussion
    Returns an XML attribute node with the given unqualified name.  The node is assigned the
    specified stringValue.
*/
+ (id) attributeNodeWithName:(SBString*)attribName stringValue:(SBString*)stringValue;
/*!
  @method attributeNodeWithName:stringValue:namespaceURI:
  @discussion
    Returns an XML attribute node with the given name qualified by the namespace URI.  The node
    is assigned the specified stringValue.
*/
+ (id) attributeNodeWithName:(SBString*)attribName stringValue:(SBString*)stringValue namespaceURI:(SBString*)namespaceURI;

/*!
  @method processingInstructionNodeWithName:stringValue:
  @discussion
    Returns an XML processing instruction node with the given unqualified name.  The node is assigned the
    specified stringValue.
*/
+ (id) processingInstructionNodeWithName:(SBString*)piName stringValue:(SBString*)stringValue;

/*!
  @method namespaceNodeWithPrefix:stringValue:
  @discussion
    Returns an XML namespace node for a namespace URI (as stringValue) with the given prefix.
*/
+ (id) namespaceNodeWithPrefix:(SBString*)prefix stringValue:(SBString*)stringValue;

/*!
  @method commentNodeWithStringValue:
  @discussion
    Returns an XML comment node with the content given by stringValue.
*/
+ (id) commentNodeWithStringValue:(SBString*)stringValue;

/*!
  @method textNodeWithStringValue:
  @discussion
    Returns an XML text node with the content given by stringValue.
*/
+ (id) textNodeWithStringValue:(SBString*)stringValue;

@end

//

/*!
  @category SBXMLNode(SBXMLNodeContainer)
  @discussion
    Informal protocol adopted by non-leaf XML node types to access child nodes.
*/
@interface SBXMLNode(SBXMLNodeContainer)

/*!
  @method setChildNodes:
  @discussion
    Set the receiver to have the XML nodes in childNodes as its children.
*/
- (void) setChildNodes:(SBArray*)childNodes;

/*!
  @method addChildNode:
  @discussion
    Append childNode to the receiver's array of children.
*/
- (void) addChildNode:(SBXMLNode*)childNode;

/*!
  @method insertChildNode:atIndex:
  @discussion
    Insert childNode in the receiver's array of children at the given
    index.
*/
- (void) insertChildNode:(SBXMLNode*)childNode atIndex:(SBUInteger)index;

/*!
  @method insertChildNodes:atIndex:
  @discussion
    Insert the XML nodes in the childNodes array in the receiver's array
    of children at the given index.
*/
- (void) insertChildNodes:(SBArray*)childNodes atIndex:(SBUInteger)index;

/*!
  @method removeAllChildNodes
  @discussion
    Purge all XML nodes from the receivers list of children.
*/
- (void) removeAllChildNodes;

/*!
  @method removeChildNodeAtIndex:
  @discussion
    Remove the XML node from the given index in the receivers list of children.
*/
- (void) removeChildNodeAtIndex:(SBUInteger)index;

/*!
  @method replaceChildNodeAtIndex:withNode:
  @discussion
    Remove the XML node from the given index in the receivers list of children
    and replace with aNode.
*/
- (void) replaceChildNodeAtIndex:(SBUInteger)index withNode:(SBXMLNode*)aNode;

@end
