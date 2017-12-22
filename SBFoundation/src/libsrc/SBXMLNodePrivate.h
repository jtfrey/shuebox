//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLNodePrivate.h
//
// Private interfaces to the SBXMLNode class.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@class SBMutableArray;

@interface SBXMLNode(SBXMLNodePrivate)

- (SBString*) namespaceURI;

- (BOOL) shouldAddChildNode:(SBXMLNode*)childNode;
- (void) didAddChildNode:(SBXMLNode*)childNode;

- (void) didRemoveChildNode:(SBXMLNode*)childNode;

- (SBMutableArray*) mutableChildNodesCreateIfNotPresent:(BOOL)createIfNotPresent;

- (void) setNodeIndex:(SBUInteger)nodeIndex;
- (void) setParentNode:(SBXMLNode*)parentNode;

//

- (void) walkXPathArray:(SBArray*)pieces atIndex:(SBUInteger)index matches:(SBMutableArray**)matches;

@end
