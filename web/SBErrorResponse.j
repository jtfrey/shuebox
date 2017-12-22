//
// SHUEBox Web Console
// SBErrorResponse.j
//
// Wrapper to handle XML error responses coming from our CGI.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import <Foundation/CPObject.j>

@implementation SBErrorResponse : CPObject
{
  CPString      _description @accessors(property=description);
  CPString      _title @accessors(property=title);
  int           _errorCode @accessors(property=errorCode);
  CPString      _errorDomain @accessors(property=errorDomain);
  CPString      _errorExplanation @accessors(property=errorExplanation);
}

  - (id) initWithTitle:(CPString)title
    description:(CPString)description
  {
    if ( ! title || ! description ) {
      return nil;
    }
    if ( (self = [super init]) ) {
      if ( title )
        [self setTitle:title];
      if ( description )
        [self setDescription:description];
    }
    return self;
  }

//

  - (id) initWithXMLNode:(CPObject)xmlNode
  {
    if ( (self = [super init]) ) {
      var     node = xmlNode.firstChild;
      
      //
      // For now, we'll ignore an "error-object" descriptors that are attached
      //
      while ( node ) {
        switch ( node.nodeName ) {
          case "description": {
            [self setDescription:( node.firstChild ? node.firstChild.nodeValue : nil )];
            break;
          }
          case "title": {
            [self setTitle:( node.firstChild ? node.firstChild.nodeValue : nil )];
            break;
          }
          case "error-object": {
            [self setErrorCode:node.getAttribute("code")];
            [self setErrorDomain:node.getAttribute("domain")];
            var   subNode = node.firstChild;
            
            while ( subNode ) {
              if ( node.nodeName == "explanation" ) {
                [self setErrorExplanation:( subNode.firstChild ? subNode.firstChild.nodeValue : nil )];
              }
              subNode = subNode.nextSibling;
            }
            break;
          }
        }
        node = node.nextSibling;
      }
    }
    return self;
  }
  
//

  - (void) displayDialog
  {
    var    description = [self description];
    
    if ( [self errorDomain] ) {
      description += "(" + [self errorDomain] + "[" + [self errorCode] + "]: " + [self errorExplanation] + ")";
    }
    
    var    dialog = [CPAlert  alertWithMessageText:[self title]
                                  defaultButton:@"OK"
                                  alternateButton:nil
                                  otherButton:nil
                                  informativeTextWithFormat:description
                                ];
    [dialog setAlertStyle:CPCriticalAlertStyle];
    [dialog runModal];
  }

@end
