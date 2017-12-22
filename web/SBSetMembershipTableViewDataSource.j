//
// SHUEBox Web Console
// SBSetMembershipTableViewDataSource.j
//
// Acts as a data source and drag-and-drop director for dual table views.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import <Foundation/CPObject.j>
@import <Foundation/CPArray.j>
@import <Foundation/CPMutableArray.j>
@import <AppKit/CPTableView.j>

var   SBSetMembershipTableViewDataSourceDragType = @"SBSetMembershipTableViewDataSourceDragType";

SBSetMembershipItemsAdded = @"SBSetMembershipItemsAdded";
SBSetMembershipItemsRemoved = @"SBSetMembershipItemsRemoved";

@implementation SBSetMembershipTableViewDataSource : CPObject
{
  CPTableView         _nonMemberTableView;
  CPTableView         _memberTableView;
  //
  CPArray             _allItems;
  CPArray             _originalMembers;
  CPMutableArray      _nonMembers @accessors(property=nonMembers);
  CPMutableArray      _members @accessors(property=members);
  //
  CPSortDescriptor    _sortDescriptors @accessors(property=sortDescriptors);
}

  - (CPDictionary) changesToMembership
  {
    var     members = [_members copy];
    var     i = [members count];
    var     original = [_originalMembers copy];
    
    // Walk the new _members array:
    while ( i-- > 0 ) {
      var   item = [members objectAtIndex:i];
      
      // Was this item in the original?
      if ( [original containsObjectIdenticalTo:item] ) {
        // No net change, just remove from the original array:
        [original removeObjectIdenticalTo:item]; 
        [members removeObjectAtIndex:i];
      }
    }
    // The "members" array now contains any added items, while
    // the "original" array now contains any removed items.
    if ( [members count] ) {
      if ( [original count] ) {
        return [CPDictionary dictionaryWithObjectsAndKeys:
                    original, SBSetMembershipItemsRemoved,
                    members, SBSetMembershipItemsAdded
                  ];
      } else {
        return [CPDictionary dictionaryWithObject:members forKey:SBSetMembershipItemsAdded];
      }
    } else if ( [original count] ) {
      return [CPDictionary dictionaryWithObject:original forKey:SBSetMembershipItemsRemoved];
    }
    return nil;
  }

//

  - (CPArray) allItems
  {
    return _allItems;
  }
  - (void) setAllItems:(CPArray)allItems
  {
    _allItems = allItems;
    
    if ( _originalMembers ) {
      [self setMembers:[_originalMembers copy]];
      
      var nonMembers = [_allItems copy];
      [nonMembers removeObjectsInArray:_originalMembers];
      [self setNonMembers:nonMembers];
      
      if ( _memberTableView ) {
        [_memberTableView reloadData];
      }
      if ( _memberTableView ) {
        [_nonMemberTableView reloadData];
      }
    }
  }
  
//

  - (CPArray) originalMembers
  {
    return _originalMembers;
  }
  - (void) setOriginalMembers:(CPArray)originalMembers
  {
    _originalMembers = originalMembers;
    
    if ( _allItems ) {
      [self setMembers:[_originalMembers copy]];
      
      var nonMembers = [_allItems copy];
      [nonMembers removeObjectsInArray:_originalMembers];
      [self setNonMembers:nonMembers];
      
      if ( _memberTableView ) {
        [_memberTableView reloadData];
      }
      if ( _memberTableView ) {
        [_nonMemberTableView reloadData];
      }
    }
  }
  
//

  - (CPArray) nonMembers
  {
    return _nonMembers;
  }
  - (void) setNonMembers:(CPArray)nonMembers
  {
    if ( _sortDescriptors )
      _nonMembers = [nonMembers sortedArrayUsingDescriptors:_sortDescriptors];
    else
      _nonMembers = nonMembers;
  }
  
//

  - (CPArray) members
  {
    return _members;
  }
  - (void) setMembers:(CPArray)members
  {
    if ( _sortDescriptors )
      _members = [members sortedArrayUsingDescriptors:_sortDescriptors];
    else
      _members = members;
  }
  
//

  - (CPTableView) memberTableView
  {
    return _memberTableView;
  }
  - (void) setMemberTableView:(CPTableView)memberTableView
  {
    if ( memberTableView !== _memberTableView ) {
      if ( _memberTableView ) {
        [_memberTableView setDataSource:nil];
        [_memberTableView registerForDraggedTypes:nil];
      }
      _memberTableView = memberTableView;
      if ( _memberTableView ) {
        [_memberTableView setDataSource:self];
        [_memberTableView setDraggingSourceOperationMask:CPDragOperationEvery forLocal:YES];
        [_memberTableView registerForDraggedTypes:[CPArray arrayWithObject:SBSetMembershipTableViewDataSourceDragType]];
        [_memberTableView setAllowsMultipleSelection:YES];
      }
    }
  }
  
//

  - (CPTableView) nonMemberTableView
  {
    return _nonMemberTableView;
  }
  - (void) setNonMemberTableView:(CPTableView)nonMemberTableView
  {
    if ( nonMemberTableView !== _nonMemberTableView ) {
      if ( _nonMemberTableView ) {
        [_nonMemberTableView setDataSource:nil];
        [_nonMemberTableView registerForDraggedTypes:nil];
      }
      _nonMemberTableView = nonMemberTableView;
      if ( _nonMemberTableView ) {
        [_nonMemberTableView setDataSource:self];
        [_nonMemberTableView setDraggingSourceOperationMask:CPDragOperationEvery forLocal:YES];
        [_nonMemberTableView registerForDraggedTypes:[CPArray arrayWithObject:SBSetMembershipTableViewDataSourceDragType]];
        [_nonMemberTableView setAllowsMultipleSelection:YES];
      }
    }
  }
  
//

  - (int) numberOfRowsInTableView:(CPTableView)tableView
  {
    if ( tableView === _memberTableView ) {
      if ( _members && [_members isKindOfClass:[CPArray class]] )
        return [_members count];
    }
    else if ( tableView === _nonMemberTableView ) {
      if ( _nonMembers && [_nonMembers isKindOfClass:[CPArray class]] )
        return [_nonMembers count];
    }
    return 0;
  }
  
//

  - (id) tableView:(CPTableView)tableView
    objectValueForTableColumn:(CPTableColumn)tableColumn
    row:(int)row
  {
    if ( tableView === _memberTableView ) {
      if ( _members && [_members isKindOfClass:[CPArray class]] && (row < [_members count]) ) {
        var   role = [_members objectAtIndex:row];
        
        return [role shortName];
      }
    }
    else if ( tableView === _nonMemberTableView ) {
      if ( _nonMembers && [_nonMembers isKindOfClass:[CPArray class]] && (row < [_nonMembers count]) ) {
        var   role = [_nonMembers objectAtIndex:row];
        
        return [role shortName];
      }
    }
    return nil;
  }

//

  - (BOOL) tableView:(CPTableView)tableView
    writeRowsWithIndexes:(CPIndexSet)rowIndexes
    toPasteboard:(CPPasteboard)pboard
  {
    if ( tableView === _memberTableView ) {
      if ( _members && [_members isKindOfClass:[CPArray class]] ) {
        var     i = [rowIndexes firstIndex], iMax = [_members count], serializedIndices = @"";
        
        while ( (i != CPNotFound) && (i < iMax) ) {
          serializedIndices += i + ";";
          i = [rowIndexes indexGreaterThanIndex:i];
        }
        if ( [serializedIndices length] ) {
          [pboard addTypes:[CPArray arrayWithObject:SBSetMembershipTableViewDataSourceDragType] owner:self];
          [pboard setString:serializedIndices forType:SBSetMembershipTableViewDataSourceDragType];
          return YES;
        }
      }
    }
    else if ( tableView === _nonMemberTableView ) {
      if ( _nonMembers && [_nonMembers isKindOfClass:[CPArray class]] ) {
        var     i = [rowIndexes firstIndex], iMax = [_nonMembers count], serializedIndices = "";
        
        while ( (i != CPNotFound) && (i < iMax) ) {
          serializedIndices += i + ";";
          i = [rowIndexes indexGreaterThanIndex:i];
        }
        if ( [serializedIndices length] ) {
          [pboard addTypes:[CPArray arrayWithObject:SBSetMembershipTableViewDataSourceDragType] owner:self];
          [pboard setString:serializedIndices forType:SBSetMembershipTableViewDataSourceDragType];
          return YES;
        }
      }
    }
    return NO;
  }

//

  - (CPDragOperation) tableView:(CPTableView)tableView
    validateDrop:(CPDraggingInfo)info
    proposedRow:(int)row
    proposedDropOperation:(CPTableViewDropOperation)dropOperation
  {
    var     sourceView = [info draggingSource];
    
    if ( (tableView === _memberTableView) && (sourceView != _memberTableView) ) {
      return CPDragOperationMove;
    }
    else if ( (tableView === _nonMemberTableView) && (sourceView != _nonMemberTableView) ) {
      return CPDragOperationMove;
    }
    return CPDragOperationNone;
  }
  
//

  - (BOOL) tableView:(CPTableView)tableView
    acceptDrop:(CPDraggingInfo)info
    row:(int)row
    dropOperation:(CPTableViewDropOperation)dropOperation
  {
    var     sourceView = [info draggingSource];
    var     serializedIndices = [[info draggingPasteboard] stringForType:SBSetMembershipTableViewDataSourceDragType];
    
    // Unserialize the indices:
    var     indices = serializedIndices.split(";");
    
    // Final element of the array is empty, so ignore it:
    var     i = indices.length - 2;
    
    if ( i >= 0 ) {
      if ( (tableView === _memberTableView) && (sourceView === _nonMemberTableView) ) {
        // Moving role(s) from the non-member table to the member table.  Loop over
        // the indices from highest to lowest to facilitate proper removeal from the
        // non-member array:
        do {
          var   row = parseInt(indices[i--]);
          var   role = [_nonMembers objectAtIndex:row];
          
          [_members addObject:role];
          [_nonMembers removeObjectAtIndex:row];
        } while ( i >= 0 );
        if ( _sortDescriptors )
          [_members sortUsingDescriptors:_sortDescriptors];
      }
      else if ( (tableView === _nonMemberTableView) && (sourceView === _memberTableView) ) {
        // Moving role(s) from the member table to the non-member table.  Loop over
        // the indices from highest to lowest to facilitate proper removeal from the
        // non-member array:
        do {
          var   row = parseInt(indices[i--]);
          var   role = [_members objectAtIndex:row];
          
          [_nonMembers addObject:role];
          [_members removeObjectAtIndex:row];
        } while ( i >= 0 );
        if ( _sortDescriptors )
          [_nonMembers sortUsingDescriptors:_sortDescriptors];
      }
      [_nonMemberTableView reloadData];
      [_memberTableView reloadData];
      return YES;
    }
    return NO;
  }
  
@end
