//
// SHUEBox Web Console
// SBCollaboration.j
//
// Represents a SHUEBox collaboration.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import "SBBase.j"
@import "SBRepository.j"
@import "SBRole.j"

@implementation SBCollaboration : CPObject
{
  CPURL         _adminURI;
  CPImage       _logoImage;
  BOOL          _hasLoadedExtendedProperties;
  BOOL          _hasLoadedRepositoryList;
  BOOL          _hasLoadedRoleList;
  // Base properties:
  BOOL          _isLoaded @accessors(property=isLoaded);
  BOOL          _isModified @accessors(property=isModified);
  BOOL          _isAdmin @accessors(property=isAdmin);
  CPNumber      _collabId @accessors(property=collabId);
  CPString      _shortName @accessors(property=shortName);
  CPString      _description;
  CPURL         _baseURI @accessors(property=baseURI);
  // Extended properties:
  CPArray       _repositories @accessors(property=repositories);
  CPArray       _roles @accessors(property=roles);
  CPNumber      _totalQuota @accessors(property=totalQuota);
  CPNumber      _quotaUsed @accessors(property=quotaUsed);
  CPNumber      _reservation @accessors(property=reservation);
  CPDate        _createDate @accessors(property=createDate);
  CPDate        _modifiedDate @accessors(property=modifiedDate);
  CPDate        _provisionDate @accessors(property=provisionDate);
  CPDate        _removeAfterDate;
}

  + (SBCollaboration) collaborationWithBaseURI:(CPURL)baseURI
  {
    return [[SBCollaboration alloc] initWithBaseURI:baseURI];
  }

//

  + (CPSet) keyPathsForValuesAffectingNaturalTotalQuota
  {
    return [CPSet setWithObject:@"totalQuota"];
  }
  + (CPSet) keyPathsForValuesAffectingNaturalTotalQuotaUnit
  {
    return [CPSet setWithObject:@"totalQuota"];
  }

//

  + (CPSet) keyPathsForValuesAffectingWillBeRemoved
  {
    return [CPSet setWithObject:@"removeAfterDate"];
  }
  + (CPSet) keyPathsForValuesAffectingRemoveAfterDateToSelectedIndex
  {
    return [CPSet setWithObject:@"removeAfterDate"];
  }

//

  + (CPSet) keyPathsForValuesAffectingEveryoneRole
  {
    return [CPSet setWithObject:@"roles"];
  }
  + (CPSet) keyPathsForValuesAffectingAdminRole
  {
    return [CPSet setWithObject:@"roles"];
  }

//

  - (id) initWithBaseURI:(CPURL)baseURI
  {
    if ( (self = [super init]) ) {
      [self setBaseURI:baseURI];
      _adminURI = [CPURL URLWithString:@"__METADATA__" relativeToURL:_baseURI];

      // Load the data:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
    return self;
  }

//

  - (id) initWithBasePropertiesFromXMLNode:(id)xmlNode
  {
    if ( (self = [super init]) ) {
      [self setPropertiesWithXMLNode:xmlNode];
    }
    return self;
  }

//

  - (void) setPropertiesWithXMLNode:(id)xmlNode
  {
    [self setCollabId:[CPNumber numberWithInt:xmlNode.getAttribute("id")]];
    if ( xmlNode.getAttribute("administrator") && xmlNode.getAttribute("administrator") == "yes" )
      [self setIsAdmin:YES];

    var       node = xmlNode.firstChild;

    while ( node ) {
      switch ( node.nodeName ) {
        case "shortName": {
          [self setShortName:( node.firstChild ? node.firstChild.nodeValue : "" )];
          break;
        }
        case "description": {
          [self setDescription:( node.firstChild ? node.firstChild.nodeValue : "" )];
          [self setIsModified:NO];
          break;
        }
        case "baseURI": {
          [self setBaseURI:( node.firstChild ? [CPURL URLWithString:node.firstChild.nodeValue] : nil )];
          if ( _baseURI ) {
            _adminURI = [CPURL URLWithString:[_baseURI absoluteString] + @"/__METADATA__"];
          }
          break;
        }
        case "quota": {
          [self setQuotaUsed:[CPNumber numberWithDouble:node.getAttribute("used")]];
          [self setTotalQuota:( node.firstChild ? [CPNumber numberWithUnsignedInt:parseInt(node.firstChild.nodeValue)] : nil )];
          break;
        }
        case "reservation": {
          [self setReservation:( node.firstChild ? [CPNumber numberWithUnsignedInt:parseInt(node.firstChild.nodeValue)] : nil )];
          break;
        }
        case "created": {
          [self setCreateDate:[CPDate dateWithSHUEBoxString:node.firstChild.nodeValue]];
          break;
        }
        case "modified": {
          [self setModifiedDate:[CPDate dateWithSHUEBoxString:node.firstChild.nodeValue]];
          break;
        }
        case "provisioned": {
          [self setProvisionDate:[CPDate dateWithSHUEBoxString:node.firstChild.nodeValue]];
          break;
        }
        case "removeAfter": {
          [self setRemoveAfterDate:[CPDate dateWithSHUEBoxString:node.firstChild.nodeValue]];
          [self setIsModified:NO];
          break;
        }
      }
      node = node.nextSibling;
    }
    [self setIsLoaded:YES];

    if ( _createDate ) {
      _hasLoadedExtendedProperties = YES;
      // Load the rest of the stuff now, too:
      [self loadRepositoryList:self];
      [self loadRoleList:self];
    }
  }

//

  - (void) setRepositoriesWithXMLNode:(id)xmlNode
  {
    var       node = xmlNode.firstChild;
    var       repoList = [[CPArray alloc] init];

    while ( node ) {
      if ( node.nodeName == "repository" ) {
        var   repo = [[SBRepository alloc] initWithCollaboration:self basePropertiesFromXMLNode:node];

        if ( repo )
          [repoList addObject:repo];
      }
      node = node.nextSibling;
    }
    [self setRepositories:repoList];
    _hasLoadedRepositoryList = YES;
  }

//

  - (void) setRolesWithXMLNode:(id)xmlNode
  {
    var       node = xmlNode.firstChild;
    var       roleList = [[CPArray alloc] init];

    while ( node ) {
      if ( node.nodeName == "role" ) {
        var   role = [[SBRole alloc] initWithCollaboration:self basePropertiesFromXMLNode:node];

        if ( role ) {
          if ( [role shortName] == "everyone" ) {
            [role loadExtendedProperties:self];
          }
          [roleList addObject:role];
        }
      }
      node = node.nextSibling;
    }
    [self setRoles:roleList];
    _hasLoadedRoleList = YES;
  }

//

  - (void) loadExtendedProperties:(id)sender
  {
    if ( ! _hasLoadedExtendedProperties ) {
      // Load the full description of the collaboration:
      var request = [CPURLRequest requestWithURL:_adminURI];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) loadRepositoryList:(id)sender
  {
    if ( ! _hasLoadedRepositoryList ) {
      var     url = [CPURL URLWithString:[_baseURI absoluteString] + @"/__METADATA__/repository"]
      // Load the full description of the collaboration:
      var request = [CPURLRequest requestWithURL:url];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (BOOL) hasRepositoryWithShortName:(CPString)shortName
  {
    if ( _repositories ) {
      var     i = 0, iMax = [_repositories count];

      while ( i < iMax ) {
        if ( [[_repositories objectAtIndex:i++] shortName] == shortName )
          return YES;
      }
    }
    return NO;
  }

//

  - (void) loadRoleList:(id)sender
  {
    if ( ! _hasLoadedRoleList ) {
      var     url = [CPURL URLWithString:[_baseURI absoluteString] + @"/__METADATA__/role"]
      // Load the full description of the collaboration:
      var request = [CPURLRequest requestWithURL:url];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (BOOL) hasRoleWithShortName:(CPString)shortName
  {
    if ( [self roleWithShortName:shortName] != nil )
      return YES;
    return NO;
  }
  - (SBRole) roleWithShortName:(CPString)shortName
  {
    if ( _roles ) {
      var     i = 0, iMax = [_roles count];

      while ( i < iMax ) {
        var   role = [_roles objectAtIndex:i++];

        if ( [role shortName] == shortName )
          return role;
      }
    }
    return nil;
  }
  - (BOOL) hasRoleWithId:(CPNumber)roleId
  {
    if ( [self roleWithId:roleId] != nil )
      return YES;
    return NO;
  }
  - (SBRole) roleWithId:(CPNumber)roleId
  {
    if ( _roles ) {
      var     i = 0, iMax = [_roles count];

      while ( i < iMax ) {
        var   role = [_roles objectAtIndex:i++];

        if ( [[role roleId] isEqual:roleId] )
          return role;
      }
    }
    return nil;
  }
  - (SBRole) everyoneRole
  {
    return [self roleWithShortName:@"everyone"];
  }
  - (void) setEveryoneRole:(id)dummy
  {
  }
  - (SBRole) adminRole
  {
    return [self roleWithShortName:@"administrator"];
  }
  - (void) setAdminRole:(id)dummy
  {
  }

//

  - (void) removeRoleWithAdminURI:(CPURL)adminURI
  {
    var request = [CPURLRequest requestWithURL:adminURI];
    [request setHTTPMethod:@"DELETE"];
    [[CPURLConnection alloc] initWithRequest:request delegate:self];
  }

//

  - (CPImage) logoImage
  {
    if ( ! _logoImage ) {
      var   url = [CPURL URLWithString:[_baseURI absoluteString] + @"/web-resources/images/collaboration-logo.png"];
      _logoImage = [[CPImage alloc] initWithContentsOfFile:[url absoluteString] size:CGSizeMake(200, 112)];
    }
    return _logoImage;
  }
  - (void) setLogoImage:(CPImage)anImage
  {
    _logiImage = anImage;
  }

//

  - (CPString) description
  {
    return _description;
  }
  - (void) setDescription:(CPString)description
  {
    if ( _description != description ) {
      _description = description;
      [self setIsModified:YES];
    }
  }

//

  - (CPDate) removeAfterDate
  {
    return _removeAfterDate;
  }
  - (void) setRemoveAfterDate:(CPDate)removeAfterDate
  {
    if ( _removeAfterDate != removeAfterDate ) {
      _removeAfterDate = removeAfterDate;
      [self setIsModified:YES];
    }
  }
  - (BOOL) willBeRemoved
  {
    return ( _removeAfterDate ? YES : NO );
  }
  - (void) setWillBeRemoved:(BOOL)dummy
  {
    if ( dummy ) {
      //[self setRemoveAfterDate:[CPDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 30)]];
      [self setRemoveAfterDateToSelectedIndex:0];
    } else {
      [self setRemoveAfterDate:nil];
      [self setRemoveAfterDateToSelectedIndex:-1];
    }
  }
  - (int) removeAfterDateToSelectedIndex
  {
    if ( _removeAfterDate ) {
      var     days = [_removeAfterDate timeIntervalSinceNow];

      days /= (60 * 60 * 24);
      if ( days <= 7.0 )
        return 2;
      if ( days <= 30.0 )
        return 1;
      if ( days <= 90.0 )
        return 0;
    }
    return -1;
  }
  - (void) setRemoveAfterDateToSelectedIndex:(int)index
  {
    var     days = 0;

    switch ( index ) {
      case 0:
        days = 90;
        break;
      case 1:
        days = 30;
        break;
      case 2:
        days = 7;
        break;
    }
    if ( days ) {
      var   today = new Date();
      today = new Date(today.getFullYear(), today.getMonth(), today.getDate(), 0, 0, 0, 0);

      var futureDate = [CPDate dateWithTimeIntervalSince1970:(today.getTime() / 1000 + days * 24 * 60 * 60)];

      [self setRemoveAfterDate:futureDate];
    }
  }

//

  - (CPNumber) naturalTotalQuota
  {
    if ( _totalQuota ) {
      var   q = [_totalQuota unsignedIntValue];

      if ( q > 1024 ) {
        if ( q > 1048576 ) {
          return [CPNumber numberWithUnsignedInt:q / 1048576];
        }
        return [CPNumber numberWithUnsignedInt:q / 1024];
      }
      return _totalQuota;
    }
    return nil;
  }
  - (CPString) naturalTotalQuotaUnit
  {
    if ( _totalQuota ) {
      var   q = [_totalQuota unsignedIntValue];

      if ( q > 1024 ) {
        if ( q > 1048576 ) {
          return @"TB";
        }
        return @"GB";
      }
      return @"MB";
    }
    return nil;
  }

//

  - (void) updateUserEditableInfo
  {
    if ( [self isModified] ) {
      var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><collaboration id=\"" + [self collabId] + "\">";

      if ( _description && [_description length] ) {
        body += @"<description><![CDATA[" + _description + "]]></description>";
      } else {
        body += @"<description/>";
      }

      if ( _removeAfterDate ) {
        body += @"<removeAfter>" + [_removeAfterDate iso8601String] + "</removeAfter>";
      } else {
        body += @"<removeAfter/>";
      }

      var request = [CPURLRequest requestWithURL:_adminURI];
      [request setHTTPMethod:@"POST"];
      [request setHTTPBody:body + "</collaboration>"];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) createRepositoryWithTypeId:(int)reposTypeId
    shortName:(CPString)shortName
    description:(CPString)description
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><repository type=\"" + reposTypeId + "\">";

    if ( shortName && [shortName length] ) {
      body += @"<shortName><![CDATA[" + shortName + "]]></shortName>";
    } else {
      body += @"<shortName/>";
    }

    if ( description && [description length] ) {
      body += @"<description><![CDATA[" + description + "]]></description>";
    } else {
      body += @"<description/>";
    }

    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:[_baseURI absoluteString] + @"/__METADATA__/repository"]];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:body + "</repository>"];
    [[CPURLConnection alloc] initWithRequest:request delegate:self];
  }

//

  - (void) createRoleWithShortName:(CPString)shortName
    description:(CPString)description
  {
    var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><role>";

    if ( shortName && [shortName length] ) {
      body += @"<shortName><![CDATA[" + shortName + "]]></shortName>";
    } else {
      body += @"<shortName/>";
    }

    if ( description && [description length] ) {
      body += @"<description><![CDATA[" + description + "]]></description>";
    } else {
      body += @"<description/>";
    }

    var request = [CPURLRequest requestWithURL:[CPURL URLWithString:[_baseURI absoluteString] + @"/__METADATA__/role"]];
    [request setHTTPMethod:@"PUT"];
    [request setHTTPBody:body + "</role>"];
    [[CPURLConnection alloc] initWithRequest:request delegate:self];
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
    } else if ( xmlDoc.nodeName == "collaboration" ) {
      [self setPropertiesWithXMLNode:xmlDoc];
    } else if ( xmlDoc.nodeName == "repositories" ) {
      [self setRepositoriesWithXMLNode:xmlDoc];
    } else if ( xmlDoc.nodeName == "roles" ) {
      [self setRolesWithXMLNode:xmlDoc];
    } else if ( xmlDoc.nodeName == "repository" ) {
      var   newRepo = [[SBRepository alloc] initWithCollaboration:self basePropertiesFromXMLNode:xmlDoc];

      if ( newRepo ) {
        var   repos = [self repositories];

        [repos addObject:newRepo];
        [self setRepositories:repos];
      }
    } else if ( xmlDoc.nodeName == "role" ) {
      var   newRole = [[SBRole alloc] initWithCollaboration:self basePropertiesFromXMLNode:xmlDoc];

      if ( newRole ) {
        var   roles = [self roles];

        [roles addObject:newRole];
        [self setRoles:roles];
      }
    }
  }
  - (void) connection:(CPURLConnection)aConnection
    didFailWithError:(CPString)error
  {
    // Show an error dialog, perhaps:
    var       error = [[SBErrorResponse alloc] initWithTitle:@"Error fetching collaboration data" description:error];

    if ( error )
      [error displayDialog];
  }

@end
