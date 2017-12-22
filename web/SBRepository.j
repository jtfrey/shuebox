//
// SHUEBox Web Console
// SBRepository.j
//
// Represents a SHUEBox repository.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import "SBBase.j"

__SBRepositoryTypeMap = [CPArray arrayWithObjects:@"n/a", @"WebDAV", @"Subversion", @"Web Resources", @"GIT", nil];

@implementation SBRepository : CPObject
{
  SBCollaboration   _parentCollaboration @accessors(readonly,property=parentCollaboration);
  SBURL             _adminURI;
  BOOL              _hasLoadedExtendedProperties;
  BOOL              _hasLoadedRoleList;
  // Base properties:
  BOOL              _isLoaded @accessors(property=isLoaded);
  CPNumber          _reposId @accessors(property=reposId);
  CPNumber          _reposTypeId @accessors(property=reposTypeId);
  BOOL              _isImmutable @accessors(property=isImmutable);
  CPString          _shortName @accessors(property=shortName);
  CPString          _description @accessors(property=description);
  CPURL             _baseURI @accessors(property=baseURI);
  // Extended properties:
  CPArray           _roles @accessors(property=roles);
  CPDate            _createDate @accessors(property=createDate);
  CPDate            _modifiedDate @accessors(property=modifiedDate);
  CPDate            _provisionDate @accessors(property=provisionDate);
  CPDate            _removeAfterDate @accessors(property=removeAfterDate);
}

  + (CPPopUpButton) repositoryTypeMenu
  {
    var     menu = [[CPPopUpButton alloc] initWithFrame:CGRectMake(0, 0, 80, 24)];
    
    // Add menu items:
    [menu addItemWithTitle:@"WebDAV"];
    [menu addItemWithTitle:@"Subversion"];
    [menu addItemWithTitle:@"GIT"];
    
    // Set the item's tags to the numerical type id:
    [[menu itemAtIndex:0] setTag:1];
    [[menu itemAtIndex:1] setTag:2];
    [[menu itemAtIndex:2] setTag:4];
    
    return menu;
  }

//

  + (BOOL) validRepositoryType:(int)reposType
  {
    switch ( reposType ) {
      case 1:
      case 2:
      case 4:
        return YES;
    }
    return NO;
  }

//

  + (SBRepository) repositoryWithCollaboration:(SBCollaboration)collaboration
    reposId:(int)reposId
  {
    return [[SBRepository alloc] initWithCollaboration:collaboration reposId:reposId];
  }

//

  - (id) initWithCollaboration:(SBCollaboration)collaboration
    reposId:(int)reposId
  {
    if ( (self = [super init]) ) {
      _parentCollaboration = collaboration;
      [self setBaseURI:baseURI];
      _adminURI = [CPURL URLWithString:[[collaboration baseURI] absoluteString] + @"/__METADATA__/repository/" + reposId];
      
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
      [self setPropertiesWithXMLNode:xmlNode];
    }
    return self;
  }
  
//

  - (void) setPropertiesWithXMLNode:(id)xmlNode
  {
    [self setReposId:[CPNumber numberWithInt:xmlNode.getAttribute("id")]];
    [self setReposTypeId:[CPNumber numberWithInt:xmlNode.getAttribute("type")]];
    if ( xmlNode.getAttribute("immutable") && xmlNode.getAttribute("immutable") == "yes" )
      [self setIsImmutable:YES];
    
    // Fixup the admin URI for this repo:
    if ( _reposId ) {
      _adminURI = [CPURL URLWithString:[[_parentCollaboration baseURI] absoluteString] + @"/__METADATA__/repository/" + _reposId];
    }
    
    var       node = xmlNode.firstChild;
    var       hadRemoveAfter = NO;
    
    while ( node ) {
      switch ( node.nodeName ) {
        case "shortName": {
          [self setShortName:( node.firstChild ? node.firstChild.nodeValue : "" )];
          break;
        }
        case "description": {
          [self setDescription:( node.firstChild ? node.firstChild.nodeValue : "" )];
          break;
        }
        case "baseURI": {
          [self setBaseURI:( node.firstChild ? [CPURL URLWithString:node.firstChild.nodeValue] : nil )];
          break;
        }
        case "created": {
          [self setCreateDate:( node.firstChild ? [CPDate dateWithSHUEBoxString:node.firstChild.nodeValue] : nil )];
          break;
        }
        case "modified": {
          [self setModifiedDate:( node.firstChild ? [CPDate dateWithSHUEBoxString:node.firstChild.nodeValue] : nil )];
          break;
        }
        case "provisioned": {
          [self setProvisionDate:( node.firstChild ? [CPDate dateWithSHUEBoxString:node.firstChild.nodeValue] : nil )];
          break;
        }
        case "removeAfter": {
          [self setRemoveAfterDate:( node.firstChild ? [CPDate dateWithSHUEBoxString:node.firstChild.nodeValue] : nil )];
          hadRemoveAfter = YES;
          break;
        }
      }
      node = node.nextSibling;
    }
    if ( ! hadRemoveAfter )
      [self setRemoveAfterDate:nil];
    [self setIsLoaded:YES];
    
    if ( _createDate ) {
      _hasLoadedExtendedProperties = YES;
      // Load the rest of the stuff now, too:
      [self loadRoleList:self];
    }
  }

//

  - (CPString) reposTypeString
  {
    return [__SBRepositoryTypeMap objectAtIndex:[self reposTypeId]];
  }

//

  - (BOOL) hasLoadedExtendedProperties
  {
    return _hasLoadedExtendedProperties;
  }
  - (void) loadExtendedProperties:(id)sender
  {
    if ( ! _hasLoadedExtendedProperties ) {
      // Load the full description of the collaboration:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) loadRoleList:(id)sender
  {
    if ( ! _hasLoadedRoleList ) {
      var     url = [CPURL URLWithString:_adminURI + @"/role"]
      // Load the full description of the collaboration:
      var request = [CPURLRequest requestWithURL:url];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }
  - (void) setRolesWithXMLNode:(id)xmlNode
  { 
    var       node = xmlNode.firstChild;
    var       roleList = [[CPArray alloc] init];
    
    while ( node ) {
      if ( node.nodeName == "role" ) {
        var   role = [_parentCollaboration roleWithId:[CPNumber numberWithLongLong:Number(node.getAttribute("id"))]];
        
        if ( role ) {
          [roleList addObject:role];
        }
      }
      node = node.nextSibling;
    }
    [self setRoles:roleList];
    _hasLoadedRoleList = YES;
  }
  
//

  - (void) updateDescription:(CPString)description
    removalDayCount:(int)removalDayCount
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><repository id=\"" + [self reposId] + "\">";
    var delta = @"";
    
    if ( description && [description length] ) {
      if ( description != [self description] ) {
        delta += @"<description><![CDATA[" + description + "]]></description>";
      }
    }
    var removalDate = [self removeAfterDate];
    if ( (removalDayCount && ! removalDate) || (! removalDayCount && removalDate) ) {
      if ( removalDayCount ) {
        var   today = new Date();
        
        today = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0, 0);
        
        var futureDate = [CPDate dateWithTimeIntervalSince1970:(today.getTime() / 1000 + removalDayCount * 24 * 60 * 60)];
        delta += @"<removeAfter><![CDATA[" + [futureDate iso8601String] + "]]></removeAfter>";
      } else {
        delta += @"<removeAfter/>";
      }
    }
    if ( delta && [delta length] ) {
      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:body + delta + "</repository>"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) updateRoleMembershipByAddingRoles:(CPArray)addRoles
    andRemovingRoles:(CPArray)removeRoles
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><multiOp>";
    var delta = @"";
    var iMax;
    
    if ( addRoles && (iMax = [addRoles count]) ) {
      var   i = 0;
      
      delta += "<add>";
      while ( i < iMax ) {
        delta += "<role id=\"" + [[addRoles objectAtIndex:i++] roleId] + "\"/>";
      }
      delta += "</add>";
    }
    if ( removeRoles && (iMax = [removeRoles count]) ) {
      var   i = 0;
      
      delta += "<remove>";
      while ( i < iMax ) {
        delta += "<role id=\"" + [[removeRoles objectAtIndex:i++] roleId] + "\"/>";
      }
      delta += "</remove>";
    }
    if ( delta && [delta length] ) {
      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI + @"/role"];
      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:body + delta + @"</multiOp>"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
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
    } else if ( xmlDoc.nodeName == "repository" ) {
      [self setPropertiesWithXMLNode:xmlDoc];
    } else if ( xmlDoc.nodeName == "roles" ) {
      [self setRolesWithXMLNode:xmlDoc];
    }
  }
  - (void) connection:(CPURLConnection)aConnection
    didFailWithError:(CPString)error
  {
    // Show an error dialog, perhaps:
    var       error = [[SBErrorResponse alloc] initWithTitle:@"Error fetching repository data" description:error];
    
    if ( error )
      [error displayDialog];
  }
  
@end
