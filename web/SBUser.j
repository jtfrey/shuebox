//
// SHUEBox Web Console
// SBUser.j
//
// Represents a SHUEBox user.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import "SBBase.j"
@import "SBErrorResponse.j"
@import "SBCollaboration.j"

SBUserDataLoadIsComplete = @"SBUserDataLoadIsComplete";
SBUserDataLoadFailed = @"SBUserDataLoadFailed";

__SBUserCache = nil;

@implementation SBUser : CPObject
{
  CPURL         _actionURI;
  //
  BOOL          _isLoaded @accessors(property=isLoaded);
  CPNumber      _userId @accessors(property=userId);
  BOOL          _isAdministrator @accessors(property=isAdministrator);
  BOOL          _isNative @accessors(property=isNative);
  CPString      _shortName @accessors(property=shortName);
  CPString      _fullName @accessors(property=fullName);
  CPDate        _createDate @accessors(property=createDate);
  CPDate        _modifiedDate @accessors(property=modifiedDate);
  CPDate        _lastAuthDate @accessors(property=lastAuthDate);
  CPDate        _removeAfterDate @accessors(property=removeAfterDate);
  CPArray       _collaborations @accessors(property=collaborations);
}

  + (CPArray) userCache
  {
    if ( __SBUserCache == nil ) {
      __SBUserCache = [[CPDictionary alloc] init];
    }
    return __SBUserCache;
  }

//

  + (SBUser) user
  {
    //
    // Only if we have an authn cookie will we return an actual object:
    //
    var     ourCookie = [[CPCookie alloc] initWithName:@"shuebox-identity"];
    var     user = [[SBUser alloc] init];

    if ( ourCookie && [ourCookie value] ) {
      [user reloadUserData];
    }
    return user;
  }

//

  + (SBUser) userWithXMLNode:(id)xmlNode
  {
    var     theUser = nil;
    var     userId = xmlNode.getAttribute("id");

    if ( userId ) {
      var   userNum = [CPNumber numberWithLongLong:Number(userId)];

      if ( userNum && [userNum longLongValue] ) {
        // Cached?
        if ( ! (theUser = [[SBUser userCache] objectForKey:userNum]) ) {
          // Create a new object:
          theUser = [[SBUser alloc] initWithXMLNode:xmlNode];
        }
      }
    }
    return theUser;
  }

//

  - (id) init
  {
    if ( (self = [super init]) ) {
      _actionURI = [CPURL URLWithString:@"/__USERDATA__"];
      _isNative = YES;
    }
    return self;
  }

//

  - (id) initWithXMLNode:(id)xmlNode
  {
    if ( (self = [self init]) ) {
      [self setPropertiesWithXMLNode:xmlNode];
      if ( ! [self userId] || ! [[self userId] longLongValue] ) {
        self = nil;
      }
    }
    return self;
  }

//

  - (void) setPropertiesWithXMLNode:(id)xmlNode
  {
    var       attrib;
    var       userId = [CPNumber numberWithLongLong:Number(xmlNode.getAttribute("id"))];

    if ( ! userId || ! [userId longLongValue] )
      return;

    // If we had a user id, make sure to remove our old entry from the cache -- in case
    // the user id has changed somehow!
    [[SBUser userCache] removeObjectForKey:userId];
    // Now, set our user id and re-cache us:
    [self setUserId:userId];
    [[SBUser userCache] setObject:self forKey:userId];

    // Proceed...
    attrib = xmlNode.getAttribute("native");
    [self setIsNative:( attrib && (attrib == "yes" ) ? YES : NO )];
    attrib = xmlNode.getAttribute("administrator");
    [self setIsAdministrator:( attrib && (attrib == "yes" ) ? YES : NO )];

    var       hadCreateDate = NO;
    var       hadModifiedDate = NO;
    var       hadLastAuthDate = NO;
    var       hadRemoveAfterDate = NO;

    xmlNode = xmlNode.firstChild;

    while ( xmlNode ) {
      switch ( xmlNode.nodeName ) {
        case "shortName": {
          [self setShortName:( xmlNode.firstChild ? xmlNode.firstChild.nodeValue : "" )];
          break;
        }
        case "fullName": {
          [self setFullName:( xmlNode.firstChild ? xmlNode.firstChild.nodeValue : "" )];
          break;
        }
        case "created": {
          [self setCreateDate:[CPDate dateWithSHUEBoxString:xmlNode.firstChild.nodeValue]];
          hadCreateDate = YES;
          break;
        }
        case "modified": {
          [self setModifiedDate:[CPDate dateWithSHUEBoxString:xmlNode.firstChild.nodeValue]];
          hadModifiedDate = YES;
          break;
        }
        case "lastAuth": {
          [self setLastAuthDate:[CPDate dateWithSHUEBoxString:xmlNode.firstChild.nodeValue]];
          hadLastAuthDate = YES;
          break;
        }
        case "removeAfter": {
          [self setRemoveAfterDate:[CPDate dateWithSHUEBoxString:xmlNode.firstChild.nodeValue]];
          hadRemoveAfterDate = YES;
          break;
        }
        case "collaborations": {
          // Walk the list of collaborations:
          var   collabList = [[CPArray alloc] init];
          var   collab = xmlNode.firstChild;

          while ( collab ) {
            if ( collab.nodeName == "collaboration" ) {
              var   newCollab = [[SBCollaboration alloc] initWithBasePropertiesFromXMLNode:collab];

              if ( newCollab )
                [collabList addObject:newCollab];
            }
            collab = collab.nextSibling;
          }
          [self setCollaborations:collabList];
          break;
        }
      }
      xmlNode = xmlNode.nextSibling;
    }
    if ( ! hadCreateDate )
      [self setCreateDate:nil];
    if ( ! hadModifiedDate )
      [self setModifiedDate:nil];
    if ( ! hadLastAuthDate )
      [self setLastAuthDate:nil];
    if ( ! hadRemoveAfterDate )
      [self setRemoveAfterDate:nil];
    [self setIsLoaded:YES];
  }

//

  - (void) invalidateUserData
  {
    [self setIsLoaded:NO];
    [self setIsNative:YES];
    [self setUserId:nil];
    [self setIsAdministrator:NO];
    [self setShortName:nil];
    [self setFullName:nil];
    [self setCreateDate:nil];
    [self setModifiedDate:nil];
    [self setLastAuthDate:nil];
    [self setRemoveAfterDate:nil];
    [self setCollaborations:nil];
  }

//

  - (void) reloadUserData
  {
    if ( _actionURI ) {
      // Load the data:
      var request = [CPURLRequest requestWithURL:_actionURI];
      [[CPURLConnection alloc] initWithRequest:request delegate:self];
    }
  }

//

  - (void) setNewPassword:(CPString)newPassword
    usingOldPassword:(CPString)oldPassword
  {
    if ( _actionURI ) {
      var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><user id=\"" + [self userId] + "\">";
      var delta = @"";

      if ( newPassword && [newPassword length] ) {
        delta += @"<newPassword><![CDATA[" + newPassword + "]]></newPassword>";
      }
      if ( oldPassword && [oldPassword length] ) {
        delta += @"<oldPassword><![CDATA[" + oldPassword + "]]></oldPassword>";
      }
      if ( delta && [delta length] ) {
        // Load the data:
        var request = [CPURLRequest requestWithURL:_actionURI];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:body + delta + "</user>"];
        [[CPURLConnection alloc] initWithRequest:request delegate:self];
      }
    }
  }

//

  - (void) updateFullName:(CPString)fullName
    removalDayCount:(int)removalDayCount
  {
    if ( _actionURI ) {
      var body = @"<?xml version=\"1.0\" standalone=\"yes\"?><user id=\"" + [self userId] + "\">";
      var delta = @"";

      if ( fullName && [fullName length] ) {
        if ( fullName != [self fullName] ) {
          delta += @"<fullName><![CDATA[" + fullName + "]]></fullName>";
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
          delta += @"<removeAfter></removeAfter>";
        }
      }
      if ( delta && [delta length] ) {
        // Load the data:
        var request = [CPURLRequest requestWithURL:_actionURI];
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:body + delta + "</user>"];
        [[CPURLConnection alloc] initWithRequest:request delegate:self];
      }
    }
  }

//

  - (void) authenticateWithShortName:(CPString)shortName
    password:(CPString)password
  {
    // Setup the login request:
    var request = [CPURLRequest requestWithURL:"/__LOGIN__/"];

    [request setHTTPMethod:@"POST"];
    [request setValue:"application/x-www-form-urlencoded" forHTTPHeaderField:"Content-Type"];
    [request setHTTPBody:"u=" + encodeURIComponent(shortName) + "&p=" + encodeURIComponent(password)];
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
      [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadFailed object:self];
    } else if ( xmlDoc.nodeName == "user" ) {
      [self setPropertiesWithXMLNode:xmlDoc];
      [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadIsComplete object:self];
    } else {
      [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadFailed object:self];
    }
  }
  - (void) connection:(CPURLConnection)aConnection
    didFailWithError:(CPString)error
  {
    // Show an error dialog, perhaps:
    var       error = [[SBErrorResponse alloc] initWithTitle:@"Error fetching user data" description:error];

    if ( error )
      [error displayDialog];

    [[CPNotificationCenter defaultCenter] postNotificationName:SBUserDataLoadFailed object:self];
  }

@end



