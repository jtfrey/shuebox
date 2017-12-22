//
// SHUEBox Web Console
// AppController.j
//
// Controls the basic web environment, sets-up the GUI, etc.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import <Foundation/CPObject.j>

@import "LPMultiLineTextField.j"

@import "SBUser.j"
@import "SBCollaboration.j"
@import "SBRepository.j"
@import "SBRole.j"

@import "SBSetMembershipTableViewDataSource.j"

//
// This is to prevent bindings from treating a string like other classes...
//
@implementation CPString(SHUEBoxAdditions)

  - (id) filename
  {
    return nil;
  }
  - (CGSize) size
  {
    return CGSizeMake(0, 0);
  }
  - (CPString) shortName
  {
    return nil;
  }
  - (CPString) reposTypeString
  {
    return nil;
  }
  - (CPURL) baseURI
  {
    return nil;
  }
  - (int) count
  {
    return 0;
  }

@end

@implementation CPNull(SHUEBoxAdditions)

  - (BOOL) boolValue
  {
    return NO;
  }

@end

//

var __SBDialogModeNone = 0;
var __SBDialogModeRepositoryRemove = 1;
var __SBDialogModeRoleRemove = 2;

//

@implementation AppController : CPObject
{
  SBUser                _currentUser @accessors(property=currentUser);
  SBCollaboration       _currentCollaboration @accessors(property=currentCollaboration);
  SBRepository          _currentRepository @accessors(property=currentRepository);
  SBRole                _currentRole @accessors(property=currentRole);
  //
  CPWindow              _mainWindow;
  //
  CPButton              _userInfoButton;
  CPButton              _logoutButton;
  CPButton              _changePasswordButton;
  CPArrayController     _collaborationArray;
  CPTableView           _collaborationListView;
  CPArrayController     _repositoryArray;
  CPButton              _repositoryAddButton;
  CPButton              _repositoryRemoveButton;
  CPButton              _repositoryActionButton;
  CPArrayController     _roleArray;
  CPArrayController     _everyoneRoleArray;
  CPButton              _roleAddButton;
  CPButton              _roleRemoveButton;
  CPButton              _roleActionButton;
  //
  CPView                _detailView;
  //
  CPWindow              _userInfoSheet;
  CPTextField           _userInfoSheetUserName;
  CPTextField           _userInfoSheetShouldRemove;
  CPPopUpButton         _userInfoSheetRemovalPeriod;
  //
  CPWindow              _loginSheet;
  CPTextField           _loginSheetUsername;
  CPTextField           _loginSheetPassword;
  CPProgressIndicator   _loginSheetProgress;
  CPButton              _loginSheetLoginButton;
  CPButton              _loginSheetCancelButton;
  //
  CPWindow              _changePasswordSheet;
  CPSecureTextField     _changePasswordSheetOldPassword;
  CPSecureTextField     _changePasswordSheetNewPassword;
  CPSecureTextField     _changePasswordSheetVerifyPassword;
  //
  CPWindow              _repositoryInfoSheet;
  LPMultiLineTextField  _repositoryInfoSheetDescription;
  CPCheckBox            _repositoryInfoSheetShouldRemove;
  CPPopUpButton         _repositoryInfoSheetRemovalPeriod;
  //
  CPWindow              _addRepositorySheet;
  CPPopUpButton         _addRepositorySheetRepositoryType;
  CPTextField           _addRepositorySheetShortName;
  LPMultiLineTextField  _addRepositorySheetDescription;
  //
  CPTextField           _addRoleSheetShortName;
  LPMultiLineTextField  _addRoleSheetDescription;
  //
  CPWindow              _roleInfoSheet;
  CPTextField           _roleInfoSheetShortName;
  LPMultiLineTextField  _roleInfoSheetDescription;
  //
  CPCheckBox            _basicInfoShouldRemove;
  CPPopUpButton         _basicInfoRemovalPeriod;
  //
  int                   _dialogMode;
  //
  CPWindow              _repositoryACLSheet;
  CPArrayController     _repositoryACLSheetAllRolesArray;
  CPArrayController     _repositoryACLSheetMemberRolesArray;
  SBSetMembershipTableViewDataSource    _repositoryACLSheetDataSource;
  //
  CPWindow              _roleMembershipSheet;
  CPArrayController     _roleMembershipSheetAllUsersArray;
  CPArrayController     _roleMembershipSheetMemberUsersArray;
  SBSetMembershipTableViewDataSource    _roleMembershipSheetDataSource;
}

  - (void) applicationDidFinishLaunching:(CPNotification)aNotification
  {
    //CPLogRegister(CPLogPopup);
    //CPLog.warn(@"Application launch proceeding...");

    _dialogMode = __SBDialogModeNone;

    // Create the window-in-the-browser into which we'll display:
    _mainWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero()
                            styleMask:CPBorderlessBridgeWindowMask
                          ];
    var     contentView = [_mainWindow contentView];
    var     contentSize = [contentView frameSize];
    var     dummy, r, s;

    [self setCurrentUser:[SBUser user]];

    //
    // Create the "library" pane:
    //
    var     libraryView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, 200, contentSize.height)];

    [libraryView setBackgroundColor:[CPColor colorWithHexString:@"d0d0d8"]];
    [libraryView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    // Placard image:
    dummy = [[CPImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
    [dummy setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"shuebox-placard.png"]]];
    [dummy setAutoresizingMask:CPViewMaxXMargin | CPViewMaxYMargin];
    [libraryView addSubview:dummy];

    // User info:
    dummy = [CPTextField labelWithTitle:@"Logged in as:"];
    [dummy setFont:[CPFont boldSystemFontOfSize:12]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(4, 120)];
    [libraryView addSubview:dummy];
    //
    _userInfoButton = [CPButton buttonWithTitle:@""];
    dummy = [_userInfoButton frameSize];
    [_userInfoButton setFrame:CGRectMake(13, 140, 174, dummy.height)];
    [_userInfoButton setAutoresizingMask:CPViewWidthSizable];
    [_userInfoButton bind:@"title"
          toObject:_currentUser
          withKeyPath:@"fullName"
          options:[CPDictionary dictionaryWithObject:@"Log In" forKey:
CPNullPlaceholderBindingOption]
        ];
    [_userInfoButton setAutoresizingMask:CPViewWidthSizable];
    [_userInfoButton setTarget:self];
    [_userInfoButton setAction:@selector(userInfoButtonClicked:)];
    [libraryView addSubview:_userInfoButton];
    //
    _logoutButton = [CPButton buttonWithTitle:@"Logout"];
    dummy = [_logoutButton frameSize];
    [_logoutButton setFrame:CGRectMake(13, 170, 174, dummy.height)];
    [_logoutButton setAutoresizingMask:CPViewWidthSizable];
    [_logoutButton bind:@"enabled"
          toObject:_currentUser
          withKeyPath:@"isLoaded"
          options:nil
        ];
    [_logoutButton setAutoresizingMask:CPViewWidthSizable];
    [_logoutButton setTarget:self];
    [_logoutButton setAction:@selector(logoutButtonClicked:)];
    r = [_logoutButton frame];
    [libraryView addSubview:_logoutButton];
    //
    _changePasswordButton = [CPButton buttonWithTitle:@"Change Password"];
    dummy = [_changePasswordButton frameSize];
    [_changePasswordButton setFrame:CGRectMake(13, 200, 174, dummy.height)];
    [_changePasswordButton setAutoresizingMask:CPViewWidthSizable];
    [_changePasswordButton bind:@"enabled"
          toObject:_currentUser
          withKeyPath:@"isNative"
          options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
        ];
    [_changePasswordButton setAutoresizingMask:CPViewWidthSizable];
    [_changePasswordButton setTarget:self];
    [_changePasswordButton setAction:@selector(changePasswordButtonClicked:)];
    r = [_changePasswordButton frame];
    [libraryView addSubview:_changePasswordButton];

    //
    // Collaboration listing:
    //

    // Array controllers:
    _collaborationArray = [[CPArrayController alloc] init];
    [_collaborationArray setAvoidsEmptySelection:NO];
    [_collaborationArray bind:@"contentArray"
        toObject:_currentUser
        withKeyPath:@"collaborations"
        options:nil
      ];
    _repositoryArray = [[CPArrayController alloc] init];
    [_repositoryArray setAvoidsEmptySelection:NO];
    [_repositoryArray bind:@"contentArray"
        toObject:_collaborationArray
        withKeyPath:@"selection.repositories"
        options:nil
      ];
    _roleArray = [[CPArrayController alloc] init];
    [_roleArray setAvoidsEmptySelection:NO];
    [_roleArray bind:@"contentArray"
        toObject:_collaborationArray
        withKeyPath:@"selection.roles"
        options:nil
      ];
    _everyoneRoleArray = [[CPArrayController alloc] init];
    [_everyoneRoleArray setAvoidsEmptySelection:NO];
    [_everyoneRoleArray bind:@"contentArray"
        toObject:_collaborationArray
        withKeyPath:@"selection.everyoneRole.memberArray"
        options:nil
      ];

    // Scroll view; r = the frame of the last item we added:
    r.origin.y += r.size.height + 13;
    var collabBox = [[CPBox alloc] initWithFrame:CGRectMake(13, r.origin.y, 174, contentSize.height - r.origin.y - 13)];
    [collabBox setBorderType:CPLineBorder];
    [collabBox setBackgroundColor:[CPColor whiteColor]];
    [collabBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    r = [collabBox frame];
    [libraryView addSubview:collabBox];
    //
    dummy = [[CPScrollView alloc] initWithFrame:CGRectMake(1, 1, r.size.width - 2, r.size.height - 2)];
    [dummy setAutohidesScrollers:YES];
    [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    r = [dummy frame];
    [collabBox addSubview:dummy];

    // Collab list view:
    _collaborationListView = [[CPTableView alloc] initWithFrame:CGRectMake(0, 0, r.size.width, r.size.height)];
    [_collaborationListView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [_collaborationListView setRowHeight:24];
    [_collaborationListView setAllowsEmptySelection:YES];
    [_collaborationListView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [_collaborationListView bind:@"selectionIndexes"
        toObject:_collaborationArray
        withKeyPath:@"selectionIndexes"
        options:nil
      ];
    [_collaborationListView bind:@"sortDescriptors"
        toObject:_collaborationArray
        withKeyPath:@"sortDescriptors"
        options:nil
      ];
    //
    var   column = [[CPTableColumn alloc] initWithIdentifier:@"shortName"];

    [[column headerView] setStringValue:@"Collaborations"];
    [column setResizingMask:CPTableColumnAutoresizingMask];
    [column setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]];
    [_collaborationListView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"arrangedObjects.shortName"
        options:nil
      ];
    //
    [dummy setDocumentView:_collaborationListView];
    // So we can load additional data when the user selects a collaboration:
    [[CPNotificationCenter defaultCenter] addObserver:self
        selector:@selector(selectedCollaborationDidChange:)
        name:CPTableViewSelectionDidChangeNotification
        object:_collaborationListView
      ];

    //
    // Detail view:
    //
    _detailView = [[CPView alloc] initWithFrame:CGRectMake(0, 0, contentSize.width - 200, contentSize.height)];

    [_detailView setBackgroundColor:[CPColor colorWithHexString:@"f0f0f8"]];
    [_detailView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    r = [_detailView frame];

    // Basic information:
    var     basicView = [[CPView alloc] initWithFrame:CGRectMake(13, 13, r.size.width - 26, 300)];
    [basicView bind:@"hidden"
        toObject:_collaborationArray
        withKeyPath:@"selection.isLoaded"
        options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
      ];
    [basicView setAutoresizingMask:CPViewWidthSizable];
    r = [basicView frame];
    [_detailView addSubview:basicView];
    // Collaboration short name:
    dummy = [CPTextField labelWithTitle:@""];
    [dummy setTextColor:[CPColor colorWithHexString:@"a0a0a8"]];
    [dummy setFont:[CPFont boldSystemFontOfSize:64.0]];
    [dummy setFrame:CGRectMake(4, 4, r.size.width - 208, 112)];
    [dummy setAutoresizingMask:CPViewWidthSizable];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.shortName"
        options:nil
      ];
    [basicView addSubview:dummy];
    // Logo:
    dummy = [[CPImageView alloc] initWithFrame:CGRectMake(r.size.width - 204, 4, 200, 112)];
    [dummy setAutoresizingMask:CPViewMinXMargin | CPViewMaxYMargin];
    [dummy bind:@"image"
        toObject:_collaborationArray
        withKeyPath:@"selection.logoImage"
        options:nil
      ];
    [basicView addSubview:dummy];
    // CollabId:
    dummy = [CPTextField labelWithTitle:@"Collaboration Id:"];
    [dummy setFont:[CPFont boldSystemFontOfSize:12]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(4, 120)];
    r = [basicView frame];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@""];
    [dummy sizeToFit];
    s = [dummy frameSize];
    [dummy setFrame:CGRectMake(13, 140, r.size.width - 26, s.height)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.collabId"
        options:nil
      ];
    [basicView addSubview:dummy];
    r = [basicView frame];
    // Dates:
    dummy = [CPTextField labelWithTitle:@"Created / Provisioned / Modified Dates:"];
    [dummy setFont:[CPFont boldSystemFontOfSize:12]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(4, 160)];
    r = [basicView frame];
    [basicView addSubview:dummy];
    //
    var   w;
    dummy = [CPTextField labelWithTitle:@"n/a"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy sizeToFit];
    s = [dummy frameSize];
    w = (r.size.width - 26) / 3;
    [dummy setFrame:CGRectMake(13, 180, w, s.height)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.createDate"
        options:nil
      ];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"n/a"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy setFrame:CGRectMake(13 + w, 180, w, s.height)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.provisionDate"
        options:nil
      ];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"n/a"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy setFrame:CGRectMake(13 + 2 * w, 180, w, s.height)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.modifiedDate"
        options:nil
      ];
    [basicView addSubview:dummy];
    // Quota:
    dummy = [CPTextField labelWithTitle:@"Quota:"];
    [dummy setFont:[CPFont boldSystemFontOfSize:12]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(4, 200)];
    r = [basicView frame];
    [basicView addSubview:dummy];
    //
    dummy = [[CPProgressIndicator alloc] initWithFrame:CGRectMake(13, 220, 200, 24)];
    [dummy setMinValue:0.0];
    [dummy setMaxValue:100.0];
    [dummy bind:@"doubleValue"
        toObject:_collaborationArray
        withKeyPath:@"selection.quotaUsed"
        options:nil
      ];
    [dummy sizeToFit];
    r = [dummy frame];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"100.0"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy sizeToFit];
    [dummy setAlignment:CPRightTextAlignment];
    [dummy setFrameOrigin:CGPointMake(r.origin.x , 220)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.quotaUsed"
        options:nil
      ];
    s = [dummy frameSize];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"%"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(r.origin.x + s.width, 220)];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"9999999"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy sizeToFit];
    s = [dummy frameSize];
    [dummy setAlignment:CPRightTextAlignment];
    [dummy setFrameOrigin:CGPointMake(r.origin.x + r.size.width - s.width, r.origin.y + r.size.height)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.naturalTotalQuota"
        options:nil
      ];
    r = [dummy frame];
    [basicView addSubview:dummy];
    //
    dummy = [CPTextField labelWithTitle:@"MM"];
    [dummy setFont:[CPFont systemFontOfSize:10]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(r.origin.x + r.size.width, r.origin.y)];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.naturalTotalQuotaUnit"
        options:nil
      ];
    [basicView addSubview:dummy];


    // Tabbed controller:
    r = [_detailView frame];
    dummy = [[CPTabView alloc] initWithFrame:CGRectMake(13, 313, r.size.width - 26, r.size.height - 326)];
    [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [dummy bind:@"hidden"
        toObject:_collaborationArray
        withKeyPath:@"selection.isLoaded"
        options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
      ];
    [_detailView addSubview:dummy];
    s = [dummy frameSize];
    //
    var   tab = [[CPTabViewItem alloc] initWithIdentifier:@"info"];
    [tab setLabel:@"Basic Info"];
    [tab setView:[self buildCollaborationInfoView:s]];
    [dummy addTabViewItem:tab];
    //
    var   tab = [[CPTabViewItem alloc] initWithIdentifier:@"repositories"];
    [tab setLabel:@"Repositories"];
    [tab setView:[self buildRepositoryListView:s]];
    [dummy addTabViewItem:tab];
    //
    var   tab = [[CPTabViewItem alloc] initWithIdentifier:@"users"];
    [tab setLabel:@"Users"];
    [tab setView:[[CPView alloc] init]];
    [[tab view] bind:@"hidden"
        toObject:_collaborationArray
        withKeyPath:@"selection.isAdmin"
        options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
      ];
    [dummy addTabViewItem:tab];
    //
    var   tab = [[CPTabViewItem alloc] initWithIdentifier:@"roles"];
    [tab setLabel:@"Roles"];
    [tab setView:[self buildRoleListView:s]];
    [[tab view] bind:@"hidden"
        toObject:_collaborationArray
        withKeyPath:@"selection.isAdmin"
        options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
      ];
    [dummy addTabViewItem:tab];

    //
    // Drop both views into a split view:
    //
    var     splitView = [[CPSplitView alloc] initWithFrame:CGRectMake(0, 0, contentSize.width, contentSize.height)];

    [splitView setVertical:YES];
    [splitView addSubview:libraryView];
    [splitView addSubview:_detailView];
    [splitView setPosition:250 ofDividerAtIndex:0];
    [splitView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];

    [contentView addSubview:splitView];

    [_mainWindow orderFront:self];
  }

//

  - (void) userInfoButtonClicked:(id)sender
  {
    if ( [_currentUser isLoaded] ) {
      _userInfoSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 375, 250) styleMask:CPDocModalWindowMask];

      var     contentView = [_userInfoSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Account: %s (id=%d)", [_currentUser shortName], [_currentUser userId]]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 355, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Date information:
      //
      dummy = [CPTextField labelWithTitle:@"Created:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 40;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentUser createDate] description]];
      r.size.width = 255;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      dummy = [CPTextField labelWithTitle:@"Last Modified:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 60;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentUser modifiedDate] description]];
      r.size.width = 255;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      dummy = [CPTextField labelWithTitle:@"Last Login:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 80;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentUser lastAuthDate] description]];
      r.size.width = 255;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 104, 355, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Full name:
      //
      dummy = [CPTextField labelWithTitle:@"Full name:"];
      [dummy setFrameOrigin:CGPointMake(13, 110)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];

      _userInfoSheetUserName = [CPTextField textFieldWithStringValue:[_currentUser fullName] placeholder:nil width:325];
      [_userInfoSheetUserName setFrameOrigin:CGPointMake(26, 130)];
      [contentView addSubview:_userInfoSheetUserName];

      //
      // Account removal:
      //
      r = [_currentUser removeAfterDate];
      if ( r ) {
        _userInfoSheetShouldRemove = [CPCheckBox checkBoxWithTitle:@"Remove my account after " + [r description]];
        [_userInfoSheetShouldRemove setState:YES];
      } else {
        _userInfoSheetShouldRemove = [CPCheckBox checkBoxWithTitle:@"Schedule my account for removal"];
        [_userInfoSheetShouldRemove setState:NO];
        _userInfoSheetRemovalPeriod = [[CPPopUpButton alloc] initWithFrame:CGRectMake(50, 184, 200, 24)];
        [_userInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 month"];
        [_userInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 week"];
        [_userInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 day"];
        [_userInfoSheetRemovalPeriod bind:@"enabled"
            toObject:_userInfoSheetShouldRemove
            withKeyPath:@"intValue"
            options:nil
          ];
        [contentView addSubview:_userInfoSheetRemovalPeriod];
      }
      [_userInfoSheetShouldRemove setFrameOrigin:CGPointMake(26, 160)];
      [contentView addSubview:_userInfoSheetShouldRemove];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveUserInfoSheet:)];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelUserInfoSheet:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_userInfoSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    } else {
      _loginSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 375, 250) styleMask:CPDocModalWindowMask];

      var     contentView = [_loginSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:@"Login to SHUEBox"];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 355, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Username:
      //
      dummy = [CPTextField labelWithTitle:@"Username:"];
      [dummy setFrameOrigin:CGPointMake(13, 60)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];

      _loginSheetUsername = [CPTextField textFieldWithStringValue:nil placeholder:@"Enter your SHUEBox username" width:325];
      [_loginSheetUsername setFrameOrigin:CGPointMake(26, 80)];
      [contentView addSubview:_loginSheetUsername];

      //
      // Password:
      //
      dummy = [CPTextField labelWithTitle:@"Password:"];
      [dummy setFrameOrigin:CGPointMake(13, 120)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];

      _loginSheetPassword = [CPSecureTextField textFieldWithStringValue:nil placeholder:nil width:325];
      [_loginSheetPassword setFrameOrigin:CGPointMake(26, 140)];
      [contentView addSubview:_loginSheetPassword];

      //
      // Login button:
      //
      _loginSheetLoginButton = [CPButton buttonWithTitle:@"Login"];
      r = [_loginSheetLoginButton frameSize];
      [_loginSheetLoginButton setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [_loginSheetLoginButton frameOrigin];
      [_loginSheetLoginButton setTarget:self]; [_loginSheetLoginButton setAction:@selector(proceedWithLogin:)];
      [_loginSheetLoginButton setKeyEquivalent:CPCarriageReturnCharacter];
      [contentView addSubview:_loginSheetLoginButton];

      //
      // Cancel button:
      //
      _loginSheetCancelButton = [CPButton buttonWithTitle:@"Cancel"];
      r = [_loginSheetCancelButton frameSize];
      [_loginSheetCancelButton setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [_loginSheetCancelButton setTarget:self]; [_loginSheetCancelButton setAction:@selector(cancelLogin:)];
      [_loginSheetCancelButton setKeyEquivalent:CPEscapeFunctionKey];
      [contentView addSubview:_loginSheetCancelButton];

      //
      // Progress indicator:
      //
      _loginSheetProgress = [[CPProgressIndicator alloc] initWithFrame:CGRectMake((contentSize.width - 64)/2, (contentSize.height - 64)/2, 64, 64)];
      [_loginSheetProgress setStyle:CPProgressIndicatorSpinningStyle];
      [_loginSheetProgress setDisplayedWhenStopped:NO];
      [contentView addSubview:_loginSheetProgress];

      [_loginSheetUsername becomeFirstResponder];

      [CPApp beginSheet:_loginSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

//

  - (void) cancelUserInfoSheet:(id)sender
  {
    [CPApp endSheet:_userInfoSheet];
  }
  - (void) saveUserInfoSheet:(id)sender
  {
    var removalDays = 0;

    if ( [_userInfoSheetShouldRemove intValue] ) {
      switch ( [_userInfoSheetRemovalPeriod selectedIndex] ) {
        case 0:
          removalDays = 30;
          break;
        case 1:
          removalDays = 7;
          break;
        case 2:
          removalDays = 1;
          break;
      }
    }
    [_currentUser updateFullName:[_userInfoSheetUserName stringValue]
        removalDayCount:removalDays];
    [CPApp endSheet:_userInfoSheet];
  }

//

  - (void) proceedWithLogin:(id)sender
  {
    if ( [_loginSheetUsername stringValue] == @"" ) {
      [_loginSheetUsername becomeFirstResponder];
      return;
    }
    if ( [_loginSheetPassword stringValue] == @"" ) {
      [_loginSheetPassword becomeFirstResponder];
      return;
    }

    // Disable the controls:
    [_loginSheetUsername setEnabled:NO];
    [_loginSheetPassword setEnabled:NO];
    [_loginSheetLoginButton setEnabled:NO];
    [_loginSheetCancelButton setEnabled:NO];

    // Show the progress spinner:
    [_loginSheetProgress startAnimation:self];

    // Make sure we can listen for the user object to complete a login:
    [[CPNotificationCenter defaultCenter] addObserver:self
        selector:@selector(loadUserDataComplete:)
        name:SBUserDataLoadIsComplete
        object:_currentUser
      ];
    [[CPNotificationCenter defaultCenter] addObserver:self
        selector:@selector(loadUserDataFailed:)
        name:SBUserDataLoadFailed
        object:_currentUser
      ];

    // Ask our current user object to try to login:
    [_currentUser authenticateWithShortName:[_loginSheetUsername stringValue] password:[_loginSheetPassword stringValue]];
  }
  - (void) loadUserDataComplete:(id)notification
  {
    [[CPNotificationCenter defaultCenter] removeObserver:self
        name:SBUserDataLoadIsComplete
        object:_currentUser
      ];
    [[CPNotificationCenter defaultCenter] removeObserver:self
        name:SBUserDataLoadFailed
        object:_currentUser
      ];
    [CPApp endSheet:_loginSheet];
  }
  - (void) loadUserDataFailed:(id)notification
  {
    // Re-enable the controls:
    [_loginSheetUsername setEnabled:YES];
    [_loginSheetPassword setEnabled:YES];
    [_loginSheetLoginButton setEnabled:YES];
    [_loginSheetCancelButton setEnabled:YES];

    // Hide the progress spinner:
    [_loginSheetProgress stopAnimation:self];
  }
  - (void) cancelLogin:(id)sender
  {
    [CPApp endSheet:_loginSheet];
  }

//

  - (void) didEndSheet:(CPWindow)sheet
    returnCode:(int)returnCode
    contextInfo:(id)contextInfo
  {
    [sheet orderOut:self];
  }

//

  - (void) logoutButtonClicked:(id)sender
  {
    var   cookie = [[CPCookie alloc] initWithName:"shuebox-identity"];

    [cookie setValue:@"" expires:nil domain:@"shuebox.nss.udel.edu"];
    [_currentUser invalidateUserData];
  }

//

  - (void) changePasswordButtonClicked:(id)sender
  {
    if ( _currentUser && ! [_currentUser isNative] ) {
      _changePasswordSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 425, 280) styleMask:CPDocModalWindowMask];

      var     contentView = [_changePasswordSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Change Password for `%s`", [_currentUser shortName]]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Old password:
      //
      dummy = [CPTextField labelWithTitle:@"Old Password:"];
      [dummy setFrameOrigin:CGPointMake(13, 40)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _changePasswordSheetOldPassword = [CPSecureTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_changePasswordSheetOldPassword frameSize];
      [_changePasswordSheetOldPassword setFrame:CGRectMake(26, 60, contentSize.width - 39, r.height)];
      [_changePasswordSheetOldPassword setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_changePasswordSheetOldPassword];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(26, 100, contentSize.width - 39, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // New password:
      //
      dummy = [CPTextField labelWithTitle:@"New Password:"];
      [dummy setFrameOrigin:CGPointMake(13, 120)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _changePasswordSheetNewPassword = [CPSecureTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_changePasswordSheetNewPassword frameSize];
      [_changePasswordSheetNewPassword setFrame:CGRectMake(26, 140, contentSize.width - 39, r.height)];
      [_changePasswordSheetNewPassword setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_changePasswordSheetNewPassword];

      //
      // Verify password:
      //
      dummy = [CPTextField labelWithTitle:@"Verify:"];
      [dummy setFrameOrigin:CGPointMake(13, 170)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _changePasswordSheetVerifyPassword = [CPSecureTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_changePasswordSheetVerifyPassword frameSize];
      [_changePasswordSheetVerifyPassword setFrame:CGRectMake(26, 190, contentSize.width - 39, r.height)];
      [_changePasswordSheetVerifyPassword setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_changePasswordSheetVerifyPassword];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveChangePassword:)];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelChangePassword:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_changePasswordSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];

      [_changePasswordSheetOldPassword becomeFirstResponder];
    }
  }

//

  - (void) saveChangePassword:(id)sender
  {
    var       oldPassword = [_changePasswordSheetOldPassword stringValue];
    var       newPassword = [_changePasswordSheetNewPassword stringValue];
    var       verifyPassword = [_changePasswordSheetVerifyPassword stringValue];

    if ( ! oldPassword || ! newPassword || ! verifyPassword ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Error"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"Please fill-in all password fields."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }
    if ( newPassword != verifyPassword ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Password mismatch"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"New passwords do not match."
                                  ];

      [_changePasswordSheetNewPassword setStringValue:@""];
      [_changePasswordSheetVerifyPassword setStringValue:@""];

      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    [_currentUser setNewPassword:newPassword usingOldPassword:oldPassword];

    [CPApp endSheet:_changePasswordSheet];
  }
  - (void) cancelChangePassword:(id)sender
  {
    [CPApp endSheet:_changePasswordSheet];
  }

//

  - (void) selectedCollaborationDidChange:(id)notification
  {
    var   selection = [_collaborationArray selectedObjects];
    var   collaboration = ( (selection && [selection count]) ? [selection objectAtIndex:0] : nil );

    [self setCurrentCollaboration:collaboration];

    if ( collaboration ) {
      [collaboration loadExtendedProperties:self];
    }
  }

//

  - (CPView) buildRepositoryListView:(CGRect)size
  {
    var     outerBox = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [outerBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    //
    var     scrollBox = [[CPBox alloc] initWithFrame:CGRectMake(13, 24, size.width - 26, size.height - 37)];
    [scrollBox setBackgroundColor:[CPColor whiteColor]];
    [scrollBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    size = [scrollBox frameSize];
    [outerBox addSubview:scrollBox];
    //
    var     buttonBar = [[CPButtonBar alloc] initWithFrame:CGRectMake(1, size.height - 24, size.width - 2, 23)];
    [buttonBar setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin];
    [scrollBox addSubview:buttonBar];
    //
    _repositoryActionButton = [CPButtonBar actionPopupButton];
    [_repositoryActionButton addItemWithTitle:@"Get info…"];
    [_repositoryActionButton addItemWithTitle:@"Access control…"];
    [_repositoryActionButton addItem:[CPMenuItem separatorItem]];
    [_repositoryActionButton addItemWithTitle:@"Go to repository in new window"];
    [_repositoryActionButton addItemWithTitle:@"Go to repository in this window"];
    var item = [_repositoryActionButton itemAtIndex:4];
    [item setTarget:self]; [item setAction:@selector(goToRepositoryInNewWindow:)];
    item = [_repositoryActionButton itemAtIndex:5];
    [item setTarget:self]; [item setAction:@selector(goToRepository:)];
    item = [_repositoryActionButton itemAtIndex:1];
    [item setTarget:self]; [item setAction:@selector(showRepositoryInfo:)];
    item = [_repositoryActionButton itemAtIndex:2];
    [item setTarget:self]; [item setAction:@selector(showRepositoryACL:)];
    //
    [_repositoryActionButton setEnabled:NO];
    _repositoryAddButton = [CPButtonBar plusButton];
    [_repositoryAddButton setTarget:self];
    [_repositoryAddButton setAction:@selector(addRepository:)];
    _repositoryRemoveButton = [CPButtonBar minusButton];
    [_repositoryRemoveButton setTarget:self];
    [_repositoryRemoveButton setAction:@selector(removeRepository:)];
    [_repositoryRemoveButton setEnabled:NO];
    [buttonBar setButtons:[CPArray arrayWithObjects:_repositoryActionButton, _repositoryAddButton, _repositoryRemoveButton, nil]];
    //
    var     scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(1, 1, size.width - 2, size.height - 26)];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    size = [scrollView frameSize];
    [scrollBox addSubview:scrollView];
    //
    var     listView = [[CPTableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [listView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [listView setRowHeight:24];
    [listView setAllowsEmptySelection:YES];
    [listView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [listView bind:@"selectionIndexes"
        toObject:_repositoryArray
        withKeyPath:@"selectionIndexes"
        options:nil
      ];
    [listView bind:@"sortDescriptors"
        toObject:_repositoryArray
        withKeyPath:@"sortDescriptors"
        options:nil
      ];
    //
    var   column = [[CPTableColumn alloc] initWithIdentifier:@"shortName"];
    [[column headerView] setStringValue:@"Name"];
    [column setResizingMask:CPTableColumnAutoresizingMask | CPTableColumnUserResizingMask];
    [column setWidth:150];
    [listView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_repositoryArray
        withKeyPath:@"arrangedObjects.shortName"
        options:nil
      ];
    [column setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]];
    //
    column = [[CPTableColumn alloc] initWithIdentifier:@"type"];
    [[column headerView] setStringValue:@"Type"];
    [column setResizingMask:CPTableColumnAutoresizingMask];
    [column setWidth:120];
    [listView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_repositoryArray
        withKeyPath:@"arrangedObjects.reposTypeString"
        options:nil
      ];
    [column setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"reposTypeString" ascending:YES]];
    //
    column = [[CPTableColumn alloc] initWithIdentifier:@"uri"];
    [[column headerView] setStringValue:@"URI"];
    [column setResizingMask:CPTableColumnAutoresizingMask];
    [listView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_repositoryArray
        withKeyPath:@"arrangedObjects.baseURI"
        options:nil
      ];
    //
    [scrollView setDocumentView:listView];

    // So we can fixup the UI when the repository selection changes:
    [[CPNotificationCenter defaultCenter] addObserver:self
        selector:@selector(selectedRepositoryDidChange:)
        name:CPTableViewSelectionDidChangeNotification
        object:listView
      ];

    return outerBox;
  }

//

  - (void) addRepository:(id)sender
  {
    if ( [self currentCollaboration] ) {
      // Present a sheet:
      _addRepositorySheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 400, 350) styleMask:CPDocModalWindowMask];

      var     contentView = [_addRepositorySheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:@"Add a Repository"];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 355, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Type:
      //
      dummy = [CPTextField labelWithTitle:@"Type:"];
      [dummy setFrameOrigin:CGPointMake(13, 40)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];

      _addRepositorySheetRepositoryType = [SBRepository repositoryTypeMenu];
      [_addRepositorySheetRepositoryType setFrame:CGRectMake(26, 60, contentSize.width - 39, 24)];
      [contentView addSubview:_addRepositorySheetRepositoryType];

      //
      // Short name:
      //
      dummy = [CPTextField labelWithTitle:@"Name:"];
      [dummy setFrameOrigin:CGPointMake(13, 90)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _addRepositorySheetShortName = [CPTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_addRepositorySheetShortName frameSize];
      [_addRepositorySheetShortName setFrame:CGRectMake(26, 110, contentSize.width - 39, r.height)];
      [_addRepositorySheetShortName setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_addRepositorySheetShortName];

      //
      // Description:
      //
      dummy = [CPTextField labelWithTitle:@"Description:"];
      [dummy setFrameOrigin:CGPointMake(13, 140)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _addRepositorySheetDescription = [[LPMultiLineTextField alloc] initWithFrame:CGRectMake(26, 160, contentSize.width - 39, contentSize.height - 160 - 50)];
      [_addRepositorySheetDescription setEditable:YES];
      [_addRepositorySheetDescription setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_addRepositorySheetDescription];

      //
      // Create button:
      //
      dummy = [CPButton buttonWithTitle:@"Create"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(createRepository:)];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelAddRepository:)];
      [dummy setKeyEquivalent:CPEscapeFunctionKey];
      [contentView addSubview:dummy];

      [_addRepositorySheetShortName becomeFirstResponder];
      [CPApp beginSheet:_addRepositorySheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

  - (void) createRepository:(id)sender
  {
    var     reposType = [_addRepositorySheetRepositoryType selectedTag];

    if ( ! [SBRepository validRepositoryType:reposType] ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid repository type"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"A repository type of `" + reposType + "` is not valid — please contact frey@udel.edu with this message."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    var     shortName = [_addRepositorySheetShortName stringValue];

    shortName = shortName.replace(/^\s+/, "");
    shortName = shortName.replace(/\s+$/, "");

    // Was a short name entered?
    if ( ! shortName || ! [shortName length] ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"Please enter a name for the repository."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    var     shortNameRegex = new RegExp("^[a-zA-Z0-9][a-zA-Z0-9_.-]*$", "m");

    // Is the name valid?
    if ( ! shortNameRegex.test(shortName) ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"A repository name must start with a letter and can contain only letters, numbers, and the dot (.), underscore (_), and dash (-) characters."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    // Is the name already taken?
    if ( [_currentCollaboration hasRepositoryWithShortName:shortName] ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"The collaboration already contains a repository with that name."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    var     description = [_addRepositorySheetDescription stringValue];

    description = description.replace(/^\s+/, "");
    description = description.replace(/\s+$/, "");



    [_currentCollaboration createRepositoryWithTypeId:reposType
            shortName:shortName
            description:description
          ];

    [CPApp endSheet:_addRepositorySheet];
  }

  - (void) cancelAddRepository:(id)sender
  {
    [CPApp endSheet:_addRepositorySheet];
  }

//

  - (void) removeRepository:(id)sender
  {
    // We mark the repository for removal in a month...
    if ( _currentRepository ) {
      if ( [_currentRepository isImmutable] ) {
        var    dialog = [CPAlert  alertWithMessageText:@"Repository cannot be removed"
                                      defaultButton:@"OK"
                                      alternateButton:nil
                                      otherButton:nil
                                      informativeTextWithFormat:@"The selected repository cannot be removed."
                                    ];
        [dialog setAlertStyle:CPInformationalAlertStyle];
        [dialog runModal];
      } else {
        var    dialog = [CPAlert  alertWithMessageText:@"Remove Repository"
                                      defaultButton:@"Cancel"
                                      alternateButton:@"OK"
                                      otherButton:nil
                                      informativeTextWithFormat:@"Clicking the OK button will mark this repository for removal in 30 days.  You can undo this action in the repository information sheet."
                                    ];
        [dialog setAlertStyle:CPCriticalAlertStyle];
        [dialog setDelegate:self];
        _dialogMode = __SBDialogModeRepositoryRemove;
        [dialog runModal];
      }
    }
  }

//

  - (void) selectedRepositoryDidChange:(id)notification
  {
    var   selection = [_repositoryArray selectedObjects];
    var   enabled = ( selection && [selection count] );
    var   repository = ( enabled ? [selection objectAtIndex:0] : nil );

    [self setCurrentRepository:repository];

    [_repositoryActionButton setEnabled:enabled];
    [_repositoryRemoveButton setEnabled:( repository && ! [repository isImmutable] )];

    if ( enabled ) {
      [repository loadExtendedProperties:self];
    }
  }

//

  - (void) goToRepositoryInNewWindow:(id)sender
  {
    if ( _currentRepository ) {
      window.open(
          [_currentRepository baseURI],
          "_blank"
        );
    }
  }
  - (void) goToRepository:(id)sender
  {
    if ( _currentRepository ) {
      window.location = [_currentRepository baseURI];
    }
  }
  - (void) showRepositoryInfo:(id)sender
  {
    if ( _currentRepository ) {
      if ( ! [_currentRepository hasLoadedExtendedProperties] ) {
        [_currentRepository loadExtendedProperties:self];
      }

      _repositoryInfoSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 425, 325) styleMask:CPDocModalWindowMask];

      var     contentView = [_repositoryInfoSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Repository: %s (id=%d)", [_currentRepository shortName], [_currentRepository reposId]]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Date information:
      //
      dummy = [CPTextField labelWithTitle:@"Created:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 40;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentRepository createDate] description]];
      r.size.width = 305;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      dummy = [CPTextField labelWithTitle:@"Last Modified:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 60;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentRepository modifiedDate] description]];
      r.size.width = 305;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      dummy = [CPTextField labelWithTitle:@"Provisioned:"];
      r = [dummy frame];
      r.origin.x = 13;
      r.origin.y = 80;
      r.size.width = 100;
      [dummy setFrame:r];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [contentView addSubview:dummy];
      dummy = [CPTextField labelWithTitle:[[_currentRepository provisionDate] description]];
      r.size.width = 305;
      r.origin.x = 107;
      [dummy setFrame:r];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 104, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Description:
      //
      dummy = [CPTextField labelWithTitle:@"Description:"];
      [dummy setFrameOrigin:CGPointMake(13, 110)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];

      _repositoryInfoSheetDescription = [[LPMultiLineTextField alloc] initWithFrame:CGRectMake(26, 130, 375, 100)];
      [_repositoryInfoSheetDescription setEditable:![_currentRepository isImmutable] && [[_currentRepository parentCollaboration] isAdmin]];
      [_repositoryInfoSheetDescription setStringValue:[_currentRepository description]];
      [contentView addSubview:_repositoryInfoSheetDescription];

      //
      // Account removal:
      //
      r = [_currentRepository removeAfterDate];
      if ( r ) {
        _repositoryInfoSheetShouldRemove = [CPCheckBox checkBoxWithTitle:@"Remove repository after " + [r description]];
        [_repositoryInfoSheetShouldRemove setState:YES];
        [_repositoryInfoSheetShouldRemove setEnabled:[[_currentRepository parentCollaboration] isAdmin]];
      } else {
        _repositoryInfoSheetShouldRemove = [CPCheckBox checkBoxWithTitle:@"Schedule repository for removal"];
        [_repositoryInfoSheetShouldRemove setState:NO];
        [_repositoryInfoSheetShouldRemove setEnabled:![_currentRepository isImmutable] && [[_currentRepository parentCollaboration] isAdmin]];
        //
        _repositoryInfoSheetRemovalPeriod = [[CPPopUpButton alloc] initWithFrame:CGRectMake(50, 270, 200, 24)];
        [_repositoryInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 month"];
        [_repositoryInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 week"];
        [_repositoryInfoSheetRemovalPeriod addItemWithTitle:@"remove after 1 day"];
        [_repositoryInfoSheetRemovalPeriod bind:@"enabled"
            toObject:_repositoryInfoSheetShouldRemove
            withKeyPath:@"intValue"
            options:nil
          ];
        [contentView addSubview:_repositoryInfoSheetRemovalPeriod];
      }
      [_repositoryInfoSheetShouldRemove setFrameOrigin:CGPointMake(26, 240)];
      [contentView addSubview:_repositoryInfoSheetShouldRemove];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setEnabled:![_currentRepository isImmutable]];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveRepositoryInfoSheet:)];
      [dummy setEnabled:![_currentRepository isImmutable] && [[_currentRepository parentCollaboration] isAdmin]];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelRepositoryInfoSheet:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_repositoryInfoSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

//

  - (void) cancelRepositoryInfoSheet:(id)sender
  {
    [CPApp endSheet:_repositoryInfoSheet];
  }
  - (void) saveRepositoryInfoSheet:(id)sender
  {
    if ( _currentRepository ) {
      var removalDays = 0;

      if ( [_repositoryInfoSheetShouldRemove intValue] ) {
        switch ( [_repositoryInfoSheetRemovalPeriod selectedIndex] ) {
          case 0:
            removalDays = 30;
            break;
          case 1:
            removalDays = 7;
            break;
          case 2:
            removalDays = 1;
            break;
        }
      }
      [_currentRepository updateDescription:[_repositoryInfoSheetDescription stringValue]
          removalDayCount:removalDays];
    }
    [CPApp endSheet:_repositoryInfoSheet];
  }

//

  - (void) showRepositoryACL:(id)sender
  {
    if ( _currentRepository ) {
      if ( ! [_currentRepository hasLoadedExtendedProperties] ) {
        [_currentRepository loadExtendedProperties:self];
      }

      _repositoryACLSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 425, 325) styleMask:CPDocModalWindowMask];

      var     contentView = [_repositoryACLSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p, scroller;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Repository ACL"]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Create our data source:
      //
      _repositoryACLSheetAllRolesArray = [[CPArrayController alloc] init];
      [_repositoryACLSheetAllRolesArray bind:@"contentArray"
          toObject:_currentCollaboration
          withKeyPath:@"roles"
          options:nil
        ];
      _repositoryACLSheetMemberRolesArray = [[CPArrayController alloc] init];
      [_repositoryACLSheetMemberRolesArray bind:@"contentArray"
          toObject:_currentRepository
          withKeyPath:@"roles"
          options:nil
        ];
      _repositoryACLSheetDataSource = [[SBSetMembershipTableViewDataSource alloc] init];
      [_repositoryACLSheetDataSource setSortDescriptors:[CPArray arrayWithObject:[CPSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]]];
      [_repositoryACLSheetDataSource bind:@"allItems"
          toObject:_repositoryACLSheetAllRolesArray
          withKeyPath:@"arrangedObjects"
          options:nil
        ];
      [_repositoryACLSheetDataSource bind:@"originalMembers"
          toObject:_repositoryACLSheetMemberRolesArray
          withKeyPath:@"arrangedObjects"
          options:nil
        ];

      scroller = [[CPScrollView alloc] initWithFrame:CGRectMake(13, 44, (contentSize.width - 26) / 2 - 6, 225)];
      [scroller setAutohidesScrollers:YES];
      [scroller setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [scroller setBorderType:CPLineBorder];
      r = [scroller frameSize];
      [contentView addSubview:scroller];
      //
      dummy = [[CPTableView alloc] initWithFrame:CGRectMake(1, 1, r.width - 2, r.height - 2)];
      [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [dummy setRowHeight:24];
      [dummy setAllowsEmptySelection:YES];
      [dummy setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
      var   column = [[CPTableColumn alloc] initWithIdentifier:@"role"];
      [[column headerView] setStringValue:@"Non-member roles"];
      [column setResizingMask:CPTableColumnAutoresizingMask];
      [dummy addTableColumn:column];
      [scroller setDocumentView:dummy];
      [_repositoryACLSheetDataSource setNonMemberTableView:dummy];

      ////

      scroller = [[CPScrollView alloc] initWithFrame:CGRectMake(13 + (contentSize.width - 26) / 2 + 6, 44, (contentSize.width - 26) / 2 - 6, 225)];
      [scroller setAutohidesScrollers:YES];
      [scroller setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [scroller setBorderType:CPLineBorder];
      r = [scroller frameSize];
      [contentView addSubview:scroller];
      //
      dummy = [[CPTableView alloc] initWithFrame:CGRectMake(1, 1, r.width - 2, r.height - 2)];
      [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [dummy setRowHeight:24];
      [dummy setAllowsEmptySelection:YES];
      [dummy setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
      var   column = [[CPTableColumn alloc] initWithIdentifier:@"role"];
      [[column headerView] setStringValue:@"Member roles"];
      [column setResizingMask:CPTableColumnAutoresizingMask];
      [dummy addTableColumn:column];
      [scroller setDocumentView:dummy];
      [_repositoryACLSheetDataSource setMemberTableView:dummy];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveRepositoryACLSheet:)];
      [dummy setEnabled:[[_currentRepository parentCollaboration] isAdmin]];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelRepositoryACLSheet:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_repositoryACLSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

//

  - (void) cancelRepositoryACLSheet:(id)sender
  {
    [CPApp endSheet:_repositoryACLSheet];
  }
  - (void) saveRepositoryACLSheet:(id)sender
  {
    // See what changes, if any, were made:
    var     delta = [_repositoryACLSheetDataSource changesToMembership];

    if ( delta ) {
      var   add = [delta objectForKey:SBSetMembershipItemsAdded];
      var   remove = [delta objectForKey:SBSetMembershipItemsRemoved];

      // Ask the repository to fixup its role membership:
      [_currentRepository updateRoleMembershipByAddingRoles:add andRemovingRoles:remove];
    }
    [CPApp endSheet:_repositoryACLSheet];
  }

//

  - (CPView) buildCollaborationInfoView:(CGRect)size
  {
    var     outerBox = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [outerBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    var     r, dummy, p, s;

    // Description:
    dummy = [CPTextField labelWithTitle:@"Description:"];
    [dummy setFont:[CPFont boldSystemFontOfSize:12]];
    [dummy sizeToFit];
    [dummy setFrameOrigin:CGPointMake(4, 24)];
    [dummy setAutoresizingMask:CPViewMaxXMargin | CPViewMaxYMargin];
    [outerBox addSubview:dummy];
    //
    dummy = [[LPMultiLineTextField alloc] initWithFrame:CGRectMake(13, 44, size.width - 26, size.height - 180)];
    //[dummy setEditable:YES];
    [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.description"
        options:nil
      ];
    [dummy bind:"editable"
        toObject:_collaborationArray
        withKeyPath:@"selection.isAdmin"
        options:nil
      ];
    [outerBox addSubview:dummy];

    r = [dummy frame];
    p = CGPointMake(13, r.origin.y + r.size.height + 13);

    // Removal is a checkbox and a popup menu
    _basicInfoShouldRemove = [CPCheckBox checkBoxWithTitle:@"Schedule this collaboration for removal"];
    [_basicInfoShouldRemove sizeToFit];
    [_basicInfoShouldRemove setFrameOrigin:CGPointMake(13, p.y)];
    [_basicInfoShouldRemove bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.willBeRemoved"
        options:nil
      ];
    [_basicInfoShouldRemove bind:"enabled"
        toObject:_collaborationArray
        withKeyPath:@"selection.isAdmin"
        options:nil
      ];
    p.y += 24;
    [_basicInfoShouldRemove setAutoresizingMask:CPViewMaxXMargin | CPViewMinYMargin];
    [outerBox addSubview:_basicInfoShouldRemove];
    //
    _basicInfoRemovalPeriod = [[CPPopUpButton alloc] initWithFrame:CGRectMake(34, p.y, 200, 24)];
    [_basicInfoRemovalPeriod addItemWithTitle:@"remove after 3 months"];
    [_basicInfoRemovalPeriod addItemWithTitle:@"remove after 1 month"];
    [_basicInfoRemovalPeriod addItemWithTitle:@"remove after 1 week"];
    [_basicInfoRemovalPeriod bind:@"enabled"
        toObject:_basicInfoShouldRemove
        withKeyPath:@"intValue"
        options:nil
      ];
    [_basicInfoRemovalPeriod setAutoresizingMask:CPViewMaxXMargin | CPViewMinYMargin];
    [_basicInfoRemovalPeriod sizeToFit];
    [_basicInfoRemovalPeriod bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.removeAfterDateToSelectedIndex"
        options:nil
      ];
    r = [_basicInfoRemovalPeriod frame];
    [outerBox addSubview:_basicInfoRemovalPeriod];
    //
    dummy = [CPTextField labelWithTitle:@""];
    [dummy sizeToFit];
    s = [dummy frameSize];
    p.x = 13 + r.origin.x + r.size.width;
    p.y = r.origin.y + (r.size.height - s.height) / 2;
    [dummy setFrame:CGRectMake(p.x, p.y, size.width - p.x - 13, s.height)];
    [dummy setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin];
    [dummy bind:CPValueBinding
        toObject:_collaborationArray
        withKeyPath:@"selection.removeAfterDate"
        options:nil
      ];
    [dummy bind:@"hidden"
        toObject:_basicInfoShouldRemove
        withKeyPath:@"intValue"
        options:[CPDictionary dictionaryWithObject:CPNegateBooleanTransformerName forKey:CPValueTransformerNameBindingOption]
      ];
    [outerBox addSubview:dummy];

    // Save button:
    dummy = [CPButton buttonWithTitle:@"Save Changes"];
    r = [dummy frameSize];
    [dummy setFrame:CGRectMake(
                        size.width - r.width - 13,
                        size.height - r.height - 13,
                        r.width,
                        r.height)
                      ];
    [dummy setAutoresizingMask:CPViewMinXMargin | CPViewMinYMargin];
    [dummy bind:@"enabled"
          toObject:_collaborationArray
          withKeyPath:@"selection.isModified"
          options:nil
        ];
    [dummy setTarget:self];
    [dummy setAction:@selector(saveCollaborationInfoChanges:)];
    [outerBox addSubview:dummy];

    return outerBox;
  }

//

  - (void) saveCollaborationInfoChanges:(id)sender
  {
    if ( _currentCollaboration ) {
      [_currentCollaboration updateUserEditableInfo];
    }
  }

//

  - (CPView) buildRoleListView:(CGRect)size
  {
    var     outerBox = [[CPView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [outerBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    //
    var     scrollBox = [[CPBox alloc] initWithFrame:CGRectMake(13, 24, size.width - 26, size.height - 37)];
    [scrollBox setBackgroundColor:[CPColor whiteColor]];
    [scrollBox setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    size = [scrollBox frameSize];
    [outerBox addSubview:scrollBox];
    //
    var     buttonBar = [[CPButtonBar alloc] initWithFrame:CGRectMake(1, size.height - 24, size.width - 2, 23)];
    [buttonBar setAutoresizingMask:CPViewWidthSizable | CPViewMinYMargin];
    [scrollBox addSubview:buttonBar];
    //
    _roleActionButton = [CPButtonBar actionPopupButton];
    [_roleActionButton addItemWithTitle:@"Get info…"];
    [_roleActionButton addItemWithTitle:@"Modify membership…"];
    [_roleActionButton setEnabled:NO];
    var item = [_roleActionButton itemAtIndex:1];
    [[item menu] setAutoenablesItems:NO];
    [item setTarget:self]; [item setAction:@selector(showRoleInfo:)];
    var item = [_roleActionButton itemAtIndex:2];
    [item setTarget:self]; [item setAction:@selector(modifyRoleMembership:)];
    //
    _roleAddButton = [CPButtonBar plusButton];
    [_roleAddButton setTarget:self];
    [_roleAddButton setAction:@selector(addRole:)];
    _roleRemoveButton = [CPButtonBar minusButton];
    [_roleRemoveButton setTarget:self];
    [_roleRemoveButton setAction:@selector(removeRole:)];
    [_roleRemoveButton setEnabled:NO];
    [buttonBar setButtons:[CPArray arrayWithObjects:_roleActionButton, _roleAddButton, _roleRemoveButton, nil]];
    //
    var     scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(1, 1, size.width - 2, size.height - 26)];
    [scrollView setAutohidesScrollers:YES];
    [scrollView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    size = [scrollView frameSize];
    [scrollBox addSubview:scrollView];
    //
    var     listView = [[CPTableView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    [listView setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
    [listView setRowHeight:24];
    [listView setAllowsEmptySelection:YES];
    [listView setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
    [listView bind:@"selectionIndexes"
        toObject:_roleArray
        withKeyPath:@"selectionIndexes"
        options:nil
      ];
    [listView bind:@"sortDescriptors"
        toObject:_roleArray
        withKeyPath:@"sortDescriptors"
        options:nil
      ];
    //
    var   column = [[CPTableColumn alloc] initWithIdentifier:@"shortName"];
    [[column headerView] setStringValue:@"Name"];
    [column setResizingMask:CPTableColumnAutoresizingMask | CPTableColumnUserResizingMask];
    [column setWidth:150];
    [listView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_roleArray
        withKeyPath:@"arrangedObjects.shortName"
        options:nil
      ];
    [column setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]];
    //
    column = [[CPTableColumn alloc] initWithIdentifier:@"description"];
    [[column headerView] setStringValue:@"Description"];
    [column setResizingMask:CPTableColumnAutoresizingMask];
    [listView addTableColumn:column];
    [column bind:CPValueBinding
        toObject:_roleArray
        withKeyPath:@"arrangedObjects.description"
        options:nil
      ];
    [column setSortDescriptorPrototype:[CPSortDescriptor sortDescriptorWithKey:@"description" ascending:YES]];
    //
    [scrollView setDocumentView:listView];

    // So we can fixup the UI when the role selection changes:
    [[CPNotificationCenter defaultCenter] addObserver:self
        selector:@selector(selectedRoleDidChange:)
        name:CPTableViewSelectionDidChangeNotification
        object:listView
      ];

    return outerBox;
  }

//

  - (void) addRole:(id)sender
  {
    if ( _currentCollaboration ) {
      // Present a sheet:
      _addRoleSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 400, 350) styleMask:CPDocModalWindowMask];

      var     contentView = [_addRoleSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:@"Add a Role"];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 355, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Short name:
      //
      dummy = [CPTextField labelWithTitle:@"Name:"];
      [dummy setFrameOrigin:CGPointMake(13, 40)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _addRoleSheetShortName = [CPTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_addRoleSheetShortName frameSize];
      [_addRoleSheetShortName setFrame:CGRectMake(26, 60, contentSize.width - 39, r.height)];
      [_addRoleSheetShortName setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_addRoleSheetShortName];

      //
      // Description:
      //
      dummy = [CPTextField labelWithTitle:@"Description:"];
      [dummy setFrameOrigin:CGPointMake(13, 90)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _addRoleSheetDescription = [[LPMultiLineTextField alloc] initWithFrame:CGRectMake(26, 110, contentSize.width - 39, contentSize.height - 160 - 50)];
      [_addRoleSheetDescription setEditable:YES];
      r = [_addRoleSheetDescription frameSize];
      [_addRoleSheetDescription setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [contentView addSubview:_addRoleSheetDescription];

      //
      // Create button:
      //
      dummy = [CPButton buttonWithTitle:@"Create"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(createRole:)];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelAddRole:)];
      [dummy setKeyEquivalent:CPEscapeFunctionKey];
      [contentView addSubview:dummy];

      [_addRoleSheetShortName becomeFirstResponder];
      [CPApp beginSheet:_addRoleSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

  - (void) createRole:(id)sender
  {
    var     shortName = [_addRoleSheetShortName stringValue];

    shortName = shortName.replace(/^\s+/, "");
    shortName = shortName.replace(/\s+$/, "");

    if ( ! [SBRole validateShortNameForRole:shortName] ) {
      return;
    }

    // Is the name already taken?
    if ( [_currentCollaboration hasRoleWithShortName:shortName] ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                    defaultButton:@"OK"
                                    alternateButton:nil
                                    otherButton:nil
                                    informativeTextWithFormat:@"The collaboration already contains a role with that name."
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog runModal];
      return;
    }

    var     description = [_addRoleSheetDescription stringValue];

    description = description.replace(/^\s+/, "");
    description = description.replace(/\s+$/, "");

    [_currentCollaboration createRoleWithShortName:shortName
            description:description
          ];

    [CPApp endSheet:_addRoleSheet];
  }

  - (void) cancelAddRole:(id)sender
  {
    [CPApp endSheet:_addRoleSheet];
  }

//

  - (void) removeRole:(id)sender
  {
     if ( _currentRole ) {
      var    dialog = [CPAlert  alertWithMessageText:@"Are you sure?"
                                    defaultButton:@"Cancel"
                                    alternateButton:@"OK"
                                    otherButton:nil
                                    informativeTextWithFormat:[CPString stringWithFormat:@"Are you sure you want to remove the role `%s`?", [_currentRole shortName]]
                                  ];
      [dialog setAlertStyle:CPInformationalAlertStyle];
      [dialog setDelegate:self];
      _dialogMode = __SBDialogModeRoleRemove;
      [dialog runModal];
    }
  }

//

  - (void) showRoleInfo:(id)sender
  {
    if ( _currentRole ) {
      if ( ! [_currentRole hasLoadedExtendedProperties] ) {
        [_currentRole loadExtendedProperties:self];
      }

      _roleInfoSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 425, 280) styleMask:CPDocModalWindowMask];

      var     contentView = [_roleInfoSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Role: %s (id=%d)", [_currentRole shortName], [_currentRole roleId]]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Short name:
      //
      dummy = [CPTextField labelWithTitle:@"Name:"];
      [dummy setFrameOrigin:CGPointMake(13, 40)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _roleInfoSheetShortName = [CPTextField textFieldWithStringValue:@"" placeholder:nil width:0];
      r = [_roleInfoSheetShortName frameSize];
      [_roleInfoSheetShortName setFrame:CGRectMake(26, 60, contentSize.width - 39, r.height)];
      [_roleInfoSheetShortName setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [_roleInfoSheetShortName setStringValue:[_currentRole shortName]];
      [contentView addSubview:_roleInfoSheetShortName];

      //
      // Description:
      //
      dummy = [CPTextField labelWithTitle:@"Description:"];
      [dummy setFrameOrigin:CGPointMake(13, 90)];
      [dummy setFont:[CPFont boldSystemFontOfSize:12.0]];
      [dummy sizeToFit];
      [contentView addSubview:dummy];
      _roleInfoSheetDescription = [[LPMultiLineTextField alloc] initWithFrame:CGRectMake(26, 110, 375, 120)];
      [_roleInfoSheetDescription setStringValue:[_currentRole description]];
      [_roleInfoSheetDescription setEditable:![_currentRole isImmutable]];
      [contentView addSubview:_roleInfoSheetDescription];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setEnabled:![_currentRole isImmutable]];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveRoleInfoSheet:)];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelRoleInfoSheet:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_roleInfoSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

//

  - (void) cancelRoleInfoSheet:(id)sender
  {
    [CPApp endSheet:_roleInfoSheet];
  }
  - (void) saveRoleInfoSheet:(id)sender
  {
    if ( _currentRole ) {
      var     shortName = [_roleInfoSheetShortName stringValue];

      shortName = shortName.replace(/^\s+/, "");
      shortName = shortName.replace(/\s+$/, "");

      if ( ! [SBRole validateShortNameForRole:shortName] ) {
        return;
      }

      // Is the name already taken?
      /*if ( [[_currentRole parentCollaboration] hasRoleWithShortName:shortName] ) {
        var    dialog = [CPAlert  alertWithMessageText:@"Invalid name"
                                      defaultButton:@"OK"
                                      alternateButton:nil
                                      otherButton:nil
                                      informativeTextWithFormat:@"The collaboration already contains a role with that name."
                                    ];
        [dialog setAlertStyle:CPInformationalAlertStyle];
        [dialog runModal];
        return;
      }*/

      var     description = [_roleInfoSheetDescription stringValue];

      description = description.replace(/^\s+/, "");
      description = description.replace(/\s+$/, "");

      [_currentRole updateShortName:shortName description:description];
    }
    [CPApp endSheet:_roleInfoSheet];
  }

//

  - (void) modifyRoleMembership:(id)sender
  {
    if ( _currentRole ) {
      if ( ! [_currentRole hasLoadedExtendedProperties] ) {
        [_currentRole loadExtendedProperties:self];
      }

      _roleMembershipSheet = [[CPWindow alloc] initWithContentRect:CGRectMake(0, 0, 425, 325) styleMask:CPDocModalWindowMask];

      var     contentView = [_roleMembershipSheet contentView];
      var     contentSize = [contentView frameSize];

      var     dummy, r, p, scroller;

      //
      // Header:
      //
      dummy = [CPTextField labelWithTitle:[CPString stringWithFormat:"Role membership"]];
      [dummy setFont:[CPFont boldSystemFontOfSize:14.0]];
      [dummy sizeToFit];
      [dummy setFrameOrigin:CGPointMake(13, 13)];
      [contentView addSubview:dummy];

      //
      // Separator:
      //
      dummy = [[CPBox alloc] initWithFrame:CGRectMake(10, 36, 405, 1)];
      [dummy setBoxType:CPBoxSeparator];
      [contentView addSubview:dummy];

      //
      // Create our data source:
      //
      _roleMembershipSheetAllUsersArray = [[CPArrayController alloc] init];
      [_roleMembershipSheetAllUsersArray bind:@"contentArray"
          toObject:_currentCollaboration
          withKeyPath:@"everyoneRole.memberArray"
          options:nil
        ];
      _roleMembershipSheetMemberUsersArray = [[CPArrayController alloc] init];
      [_roleMembershipSheetMemberUsersArray bind:@"contentArray"
          toObject:_currentRole
          withKeyPath:@"memberArray"
          options:nil
        ];
      _roleMembershipSheetDataSource = [[SBSetMembershipTableViewDataSource alloc] init];
      [_roleMembershipSheetDataSource setSortDescriptors:[CPArray arrayWithObject:[CPSortDescriptor sortDescriptorWithKey:@"shortName" ascending:YES]]];
      [_roleMembershipSheetDataSource bind:@"allItems"
          toObject:_roleMembershipSheetAllUsersArray
          withKeyPath:@"arrangedObjects"
          options:nil
        ];
      [_roleMembershipSheetDataSource bind:@"originalMembers"
          toObject:_roleMembershipSheetMemberUsersArray
          withKeyPath:@"arrangedObjects"
          options:nil
        ];

      scroller = [[CPScrollView alloc] initWithFrame:CGRectMake(13, 44, (contentSize.width - 26) / 2 - 6, 225)];
      [scroller setAutohidesScrollers:YES];
      [scroller setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [scroller setBorderType:CPLineBorder];
      r = [scroller frameSize];
      [contentView addSubview:scroller];
      //
      dummy = [[CPTableView alloc] initWithFrame:CGRectMake(1, 1, r.width - 2, r.height - 2)];
      [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [dummy setRowHeight:24];
      [dummy setAllowsEmptySelection:YES];
      [dummy setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
      var   column = [[CPTableColumn alloc] initWithIdentifier:@"user"];
      [[column headerView] setStringValue:@"Non-members"];
      [column setResizingMask:CPTableColumnAutoresizingMask];
      [dummy addTableColumn:column];
      [scroller setDocumentView:dummy];
      [_roleMembershipSheetDataSource setNonMemberTableView:dummy];

      ////

      scroller = [[CPScrollView alloc] initWithFrame:CGRectMake(13 + (contentSize.width - 26) / 2 + 6, 44, (contentSize.width - 26) / 2 - 6, 225)];
      [scroller setAutohidesScrollers:YES];
      [scroller setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [scroller setBorderType:CPLineBorder];
      r = [scroller frameSize];
      [contentView addSubview:scroller];
      //
      dummy = [[CPTableView alloc] initWithFrame:CGRectMake(1, 1, r.width - 2, r.height - 2)];
      [dummy setAutoresizingMask:CPViewWidthSizable | CPViewHeightSizable];
      [dummy setRowHeight:24];
      [dummy setAllowsEmptySelection:YES];
      [dummy setColumnAutoresizingStyle:CPTableViewLastColumnOnlyAutoresizingStyle];
      var   column = [[CPTableColumn alloc] initWithIdentifier:@"user"];
      [[column headerView] setStringValue:@"Members"];
      [column setResizingMask:CPTableColumnAutoresizingMask];
      [dummy addTableColumn:column];
      [scroller setDocumentView:dummy];
      [_roleMembershipSheetDataSource setMemberTableView:dummy];

      //
      // Save button:
      //
      dummy = [CPButton buttonWithTitle:@"Save"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(contentSize.width - r.width - 13,
                                 contentSize.height - r.height - 13,
                                 r.width,
                                 r.height)];
      p = [dummy frameOrigin];
      [dummy setTarget:self]; [dummy setAction:@selector(saveRoleMembershipSheet:)];
      [dummy setEnabled:[_currentCollaboration isAdmin]];
      [contentView addSubview:dummy];

      //
      // Cancel button:
      //
      dummy = [CPButton buttonWithTitle:@"Cancel"];
      r = [dummy frameSize];
      [dummy setFrame:CGRectMake(p.x - r.width - 13,
                                 p.y,
                                 r.width,
                                 r.height)];
      [dummy setTarget:self]; [dummy setAction:@selector(cancelRoleMembershipSheet:)];
      [contentView addSubview:dummy];

      [CPApp beginSheet:_roleMembershipSheet
             modalForWindow:_mainWindow
             modalDelegate:self
             didEndSelector:@selector(didEndSheet:returnCode:contextInfo:)
             contextInfo:nil
        ];
    }
  }

//

  - (void) cancelRoleMembershipSheet:(id)sender
  {
    [CPApp endSheet:_roleMembershipSheet];
  }
  - (void) saveRoleMembershipSheet:(id)sender
  {
    // See what changes, if any, were made:
    var     delta = [_roleMembershipSheetDataSource changesToMembership];

    if ( delta ) {
      var   add = [delta objectForKey:SBSetMembershipItemsAdded];
      var   remove = [delta objectForKey:SBSetMembershipItemsRemoved];

      // Ask the role to fixup its membership:
      [_currentRole updateUserMembershipByAddingUsers:add andRemovingUsers:remove];
    }
    [CPApp endSheet:_roleMembershipSheet];
  }

//

  - (void) selectedRoleDidChange:(id)notification
  {
    var   selection = [_roleArray selectedObjects];
    var   enabled = ( selection && [selection count] );
    var   role = ( enabled ? [selection objectAtIndex:0] : nil );

    [self setCurrentRole:role];

    [_roleRemoveButton setEnabled:( (role && [role isRemovable]) ? YES : NO )];
    if ( role && ! [role isImmutable] ) {
      [_roleActionButton setEnabled:YES];
      // Handle menu items, too:
      [[_roleActionButton itemAtIndex:1] setEnabled:( [role isRemovable] ? YES : NO )];
    } else {
      [_roleActionButton setEnabled:NO];
    }
  }

//

  - (void) alertDidEnd:(CPAlert)theAlert
    returnCode:(int)returnCode
  {
    switch ( _dialogMode ) {

      case __SBDialogModeRepositoryRemove: {
        if ( returnCode == 1 ) {
          [_currentRepository updateDescription:nil removalDayCount:30];
        }
        break;
      }

      case __SBDialogModeRoleRemove: {
        if ( returnCode == 1 ) {
          [_currentRole removeFromCollaboration];
        }
        break;
      }

    }
  }

@end
