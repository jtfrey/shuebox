//
// SHUEBox Web Console
// SBRole.j
//
// Represents a SHUEBox role.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import "SBBase.j"
@import "SBErrorResponse.j"
@import "SBCollaboration.j"
@import "SBUser.j"

@implementation SBRole : CPObject
{
  SBCollaboration   _parentCollaboration @accessors(readonly,property=parentCollaboration);
  SBURL             _adminURI;
  BOOL              _hasLoadedExtendedProperties;
  // Base properties:
  BOOL              _isLoaded @accessors(property=isLoaded);
  CPNumber          _roleId @accessors(property=roleId);
  BOOL              _isImmutable @accessors(property=isImmutable);
  BOOL              _isRemovable @accessors(property=isRemovable);
  CPString          _shortName @accessors(property=shortName);
  CPString          _description @accessors(property=description);
  // Extended properties:
  CPArray           _memberArray @accessors(property=memberArray);
}

  + (BOOL) validateShortNameForRole:(CPString*)shortName
  {
    // Was a short name entered?
    if ( ! shortName || ! [shortName length] ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"Please enter a name for the role."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return NO;
    }

    var     shortNameRegex = new RegExp("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", "m");

    // Is the name valid?
    if ( ! shortNameRegex.test(shortName) ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"A role name must start with a letter and can contain only letters, numbers, and the dot (.), underscore (_), and dash (-) characters."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return NO;
    }

    return YES;
  }

//

  + (SBRole) roleWithCollaboration:(SBCollaboration)collaboration
    roleId:(int)roleId
  {
    return [[SBRole alloc] initWithCollaboration:collaboration roleId:roleId];
  }

//

  - (id) initWithCollaboration:(SBCollaboration)collaboration
    roleId:(int)roleId
  {
    if ( (self = [super init]) ) {
      _parentCollaboration = collaboration;
      _adminURI = [CPURL URLWithString:[[collaboration baseURI] absoluteString] + @"/__METADATA__/role/" + roleId];
      _isLoaded = NO;
      _isImmutable = NO;
      _isRemovable = NO;

      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
    return self;
  }

//

  - (id) initWithCollaboration:(SBCollaboration)collaboration
    basePropertiesFromXMLNode:(id)xmlNode
  {
    if ( (self = [super init]) ) {
      _parentCollaboration = collaboration;
      _isLoaded = NO;
      _isImmutable = NO;
      _isRemovable = NO;
      [self setPropertiesWithXMLNode:xmlNode];
    }
    return self;
  }

//

  - (void) setPropertiesWithXMLNode:(id)xmlNode
  {
    [self setRoleId:[CPNumber numberWithLongLong:Number(xmlNode.getAttribute("id"))]];
    if ( ! xmlNode.getAttribute("system") || xmlNode.getAttribute("system") != "yes" )
      [self setIsRemovable:YES];
    if ( xmlNode.getAttribute("locked") && xmlNode.getAttribute("locked") == "yes" )
      [self setIsImmutable:YES];

    // Fixup the admin URI for this repo:
    if ( _roleId ) {
      _adminURI = [CPURL URLWithString:[[_parentCollaboration baseURI] absoluteString] + @"/__METADATA__/role/" + _roleId];
    }

    var       node = xmlNode.firstChild;

    while ( node ) {
      switch ( node.nodeName ) {
        case "shortName": {
          [self setShortName:( node.firstChild ? node.firstChild.nodeValue : "" )];
          break;
        }
        case "description": {
          var   textNode = node.firstChild;
          var   text = "";

          while ( textNode ) {
            text = text + textNode.nodeValue;
            textNode = textNode.nextSibling;
          }
          [self setDescription:text];
          break;
        }
        case "members": {
          // Walk the list of members:
          var     subNode = node.firstChild;
          var     users = [CPArray array];

          while ( subNode ) {
            if ( subNode.nodeName == "user" ) {
              var user = [SBUser userWithXMLNode:subNode];

              if ( user ) {
                [users addObject:user];
              }
            }
            subNode = subNode.nextSibling;
          }
          [self setMemberArray:users];
          break;
        }
      }
      node = node.nextSibling;
    }
    [self setIsLoaded:YES];
    if ( _memberArray ) {
      _hasLoadedExtendedProperties = YES;
    }
  }

//

  - (BOOL) hasLoadedExtendedProperties
  {
    return _hasLoadedExtendedProperties;
  }
  - (void) loadExtendedProperties:(id)sender
  {
    if ( ! _hasLoadedExtendedProperties ) {
      // Load the membership list for the role:
      var request = [CPURLRequest requestWithURL:_adminURI + "/member"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) updateShortName:(CPString)shortName
    description:(CPString)description
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><role id=\"" + [self roleId] + "\">";
    var delta = @"";

    if ( description && [description length] ) {
      if ( description != [self description] ) {
        delta += @"<description><![CDATA[" + description + "]]></description>";
      }
    }
    if ( shortName && [shortName length] ) {
      if ( shortName != [self shortName] ) {
        delta += @"<shortName>" + shortName + "</shortName>";
      }
    }
    if ( delta && [delta length] ) {
      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:body + delta + "</role>"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) updateUserMembershipByAddingUsers:(CPArray)addUsers
    andRemovingUsers:(CPArray)removeUsers
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><multiOp>";
    var delta = @"";
    var iMax;

    if ( addUsers && (iMax = [addUsers count]) ) {
      var   i = 0;

      delta += "<add>";
      while ( i < iMax ) {
        delta += "<user id=\"" + [[addUsers objectAtIndex:i++] userId] + "\"/>";
      }
      delta += "</add>";
    }
    if ( removeUsers && (iMax = [removeUsers count]) ) {
      var   i = 0;

      delta += "<remove>";
      while ( i < iMax ) {
        delta += "<user id=\"" + [[removeUsers objectAtIndex:i++] userId] + "\"/>";
      }
      delta += "</remove>";
    }
    if ( delta && [delta length] ) {
      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI + @"/member"];
      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:body + delta + @"</multiOp>"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) removeFromCollaboration
  {
    if ( [self isRemovable] ) {
      [_parentCollaboration removeRoleWithAdminURI:_adminURI];
    } else {
      var    dialog = [CPAlert  alertWithMessageText:@"System role"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"That role is owned by the system and cannot be deleted."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }
  }

//

  - (void) connection:(CPURLConnection)aConnection
    didReceiveData:(CPString)data
  {
    var     parser, xmlDoc, nodes;

    //
    // Parse through the data and initialize this instance using it:
    //
    if (window.DOMParser) {
      parser = new DOMParser();
      xmlDoc = parser.parseFromString(data, "text/xml");
    } else {
      // Internet Explorer
      xmlDoc = new ActiveXObject("Microsoft.XMLDOM");
      xmlDoc.async = "false";
      xmlDoc.loadXML(data);
    }

    // Focus on the document element:
    xmlDoc = xmlDoc.documentElement;

    if ( xmlDoc.nodeName == "error" ) {
      var       error = [[SBErrorResponse alloc] initWithXMLNode:xmlDoc];

      if ( error )
        [error displayDialog];
      [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadFailed object:self];
    } else if ( xmlDoc.nodeName == "role" ) {
      [self setPropertiesWithXMLNode:xmlDoc];
    }
  }
  - (void) connection:(CPURLConnection)aConnection
    didFailWithError:(CPString)error
  {
    // Show an error dialog, perhaps:
    var       error = [[SBErrorResponse alloc] initWithTitle:@"Error fetching role data" description:error];

    if ( error )
      [error displayDialog];

    [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadFailed object:self];
  }

@end



