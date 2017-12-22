//
// SBFoundation : ObjC Class Library for Solaris
// SBXMLInternalParser.h
//
// Built-in XML parser which backends for SBXMLDocument and SBXMLElement.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

#import "SBXMLParser.h"
#import "SBXMLNode.h"
#import "SBXMLElement.h"
#import "SBXMLDocument.h"

@interface SBXMLInternalParser : SBObject
{
  SBXMLParser*      _parser;
  id                _parserDelegate;
}

+ (id) sharedXMLInternalParser;

- (BOOL) document:(SBXMLDocument*)document withXMLString:(SBString*)xmlString;
- (BOOL) document:(SBXMLDocument*)document withData:(SBData*)data;
- (BOOL) document:(SBXMLDocument*)document withStream:(SBInputStream*)stream;

@end
