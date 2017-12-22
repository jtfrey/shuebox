//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLDocument.h
//
// Specific representation of XML elements.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLNode.h"

@class SBXMLElement, SBMutableArray, SBInputStream, SBData;

/*!
  @class SBXMLDocument
  @discussion
    Instances of SBXMLDocument represent...well, an XML document.
*/
@interface SBXMLDocument : SBXMLNode
{
  SBXMLElement*           _rootElement;
  SBMutableArray*         _childNodes;
}

/*!
  @method initWithXMLString:
  @discussion
    Initialize a newly-allocated instance by parsing the text contained in xmlString.
*/
- (id) initWithXMLString:(SBString*)xmlString;
/*!
  @method initWithStream:
  @discussion
    Initialize a newly-allocated instance by reading from the given stream and parsing
    that data.
*/
- (id) initWithStream:(SBInputStream*)stream;
/*!
  @method initWithData:
  @discussion
    Initialize a newly-allocated instance by parsing the bytes contained in data.  The
    data is assumed to be UTF-8 character data OR have an <?xml?> lead-in with a specific
    encoding specified.
*/
- (id) initWithData:(SBData*)data;
/*!
  @method initWithRootElement:
  @discussion
    Initialize a newly-allocated instance to contain the given SBXMLElement as the document
    root.
*/
- (id) initWithRootElement:(SBXMLElement*)rootElement;
/*!
  @method rootElement
  @discussion
    Returns the root element of the receiver's XML document.
*/
- (SBXMLElement*) rootElement;
/*!
  @method setRootElement:
  @discussion
    Sets the root element of the receiver's XML document to rootElement.  If rootElement is
    nil, then the document is made "emtpy".
*/
- (void) setRootElement:(SBXMLElement*)rootElement;
/*!
  @method isNamedDocument:
  @discussion
    Returns YES if the receiver's root element's name is equal to rootElementName.
*/
- (BOOL) isNamedDocument:(SBString*)rootElementName;
/*!
  @method isNamedDocument:namespaceURI:
  @discussion
    Returns YES if the receiver's root element's name is equal to rootElementName.  The name must
    be qualified by the given namespace URI.
*/
- (BOOL) isNamedDocument:(SBString*)rootElementName namespaceURI:(SBString*)namespaceURI;

@end
