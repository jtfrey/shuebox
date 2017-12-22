//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBDatabaseObject.h
//
// A simple object-from-database class -- basically descended from the PHP
// "NSSObject" classes that I've historically used on Dropbox, PO Box, etc.
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBDictionary, SBMutableDictionary, SBArray, SBEnumerator;

/*!
  @class SBDatabaseObject
  @discussion
  The SBDatabaseObject class lays the foundation for creating classes that
  are backed by an SQL database.  Each instance of this class has a parent
  database, an integral object identifier, and two sets of keyed properties
  associated with it.  Each property key should equate to an SQL column
  or field.
  
  When an instance is loaded from the backing database, an immutable
  dictionary containing the keyed properties is created.  Any changes made
  to the recevier are stored in a mutable dictionary.  Thus, the immutable
  copy is considered the reference state of the receiver (but may still be
  out-of-date with respect to the state in the database).
  
  Properties are reference by their (string) keys, with the current value
  being taken first from the (mutable) "changes" dictionary and then from
  the (immutable) reference dictionary.
  
  Removing all local modifications to the receiver equates to emptying the
  "changes" dictionary.  If the changes are successfully committed back to
  the database, the values from the "changes" dictionary are merged into
  the reference dictionary for the receiver.
*/
@interface SBDatabaseObject : SBObject
{
  id                    _database;
  SBUInteger            _objectId;
  SBDictionary*         _properties;
  SBMutableDictionary*  _modifications;
}

/*!
  @method tableNameForClass
  @discussion
    Returns the SQL name of the database entity that backs instances
    of this class.
*/
+ (SBString*) tableNameForClass;

/*!
  @method tableNameForClass
  @discussion
    Returns the SQL name of the database entity that backs the
    recevier's class.
*/
- (SBString*) tableNameForClass;

/*!
  @method archivalTableNameForClass
  @discussion
    Some classes may provide for revisionary archiving of instance data.
    This method returns the SQL name of the entity that backs archival
    data for this class.
*/
+ (SBString*) archivalTableNameForClass;

/*!
  @method archivalTableNameForClass
  @discussion
    Some classes may provide for revisionary archiving of instance data.
    This method returns the SQL name of the entity that backs archival
    data for this receiver's class.
*/
- (SBString*) archivalTableNameForClass;

/*!
  @method objectIdKeyForClass
  @discussion
    Returns the property key that maps to a unique integral identifier
    used by the class to identify instances.
*/
+ (SBString*) objectIdKeyForClass;

/*!
  @method objectIdKeyForClass
  @discussion
    Returns the property key that maps to a unique integral identifier
    used by the receiver's class to identify instances.
*/
- (SBString*) objectIdKeyForClass;

/*!
  @method propertyKeysForClass
  @discussion
    Returns the property keys (SQL column/field names) managed by this
    class.
*/
+ (SBArray*) propertyKeysForClass;

/*!
  @method propertyKeysForClass
  @discussion
    Returns the property keys (SQL column/field names) managed by the
    receiver's class.
*/
- (SBArray*) propertyKeysForClass;

/*!
  @method databaseObjectWithDatabase:objectId:
  @discussion
    Lookup in the backing database an object instance with the given integral
    identifier.  If found, an autoreleased instance of this class is
    initialized and returned.
    
    This method is essentially a convenience for:
    
      [class databaseObjectWithDatabase:database key:[class objectIdKeyForClass] value:objId]
    
    Returns nil if the object does not exist in the backing database or there
    was an error while attempting to load it.
*/
+ (id) databaseObjectWithDatabase:(id)database objectId:(SBUInteger)objId;

/*!
  @method databaseObjectWithDatabase:key:value:
  @discussion
    Lookup in the backing database an object instance for which the given column/field
    (key) has the specified value.  If found, an autoreleased instance of this class is
    initialized and returned.  Note that if the (key,value) is not unique across all
    backed objects only the first match is returned by this method. 
    
    Returns nil if the object does not exist in the backing database or there
    was an error while attempting to load it.
*/
+ (id) databaseObjectWithDatabase:(id)database key:(SBString*)key value:(SBString*)value;

/*!
  @method initWithDatabase:objectId:
  @discussion
    Initialize the receiver by loading its properties from the backing database; see
    the discussion for databaseObjectWithDatabase:objectId:.
*/
- (id) initWithDatabase:(id)database objectId:(SBUInteger)objId;

/*!
  @method initWithDatabase:key:value:
  @discussion
    Initialize the receiver by loading its properties from the backing database; see
    the discussion for databaseObjectWithDatabase:key:value:.
*/
- (id) initWithDatabase:(id)database key:(SBString*)key value:(SBString*)value;

/*!
  @method parentDatabase
  @discussion
    Returns the reference to the receiver's backing database.
*/
- (id) parentDatabase;

/*!
  @method validPropertyKey:
  @discussion
    Returns boolean YES if aKey is a valid property key for the receiver.
*/
- (BOOL) validPropertyKey:(SBString*)aKey;

/*!
  @method propertyKeyEnumerator
  @discussion
    Returns an enumerator that walks the list of valid property keys for the receiver.
*/
- (SBEnumerator*) propertyKeyEnumerator;

/*!
  @method propertyForKey:
  @discussion
    Locates the current value for the given property (by aKey).
*/
- (id) propertyForKey:(SBString*)aKey;

/*!
  @method setProperty:forKey:
  @discussion
    Provide a new value for the property with key aKey.
*/
- (BOOL) setProperty:(id)property forKey:(SBString*)aKey;

/*!
  @method hasBeenModified
  @discussion
    Returns boolean YES if the receiver has had its properties modified.
*/
- (BOOL) hasBeenModified;

/*!
  @method refreshCommittedProperties
  @discussion
    Purge any modifications that have been made to the receiver's properties and reload
    all property values from the backing database.
*/
- (void) refreshCommittedProperties;

/*!
  @method revertModifications
  @discussion
    Purge any modifications that have been made to the receiver's properties.
*/
- (void) revertModifications;

/*!
  @method commitModifications
  @discussion
    Attempt to commit all modified property values for the receiver to the backing
    database.  Returns boolean YES if there were no modifications to commit or the
    commit was successful.
*/
- (BOOL) commitModifications;

/*!
  @method deleteFromDatabase
  @discussion
    Attempt to remove the receiver from the backing database.  Returns boolean YES
    if sucessful.
*/
- (BOOL) deleteFromDatabase;

@end


/*!
  @category SBDatabaseObject(SBDatabaseObjectDelegate)
  @discussion
    Optional delegation methods that an SBDatabaseObject class can implement in order
    to control and react to instances' being committed to the database.  For example,
    the shouldCommitModifications method could be used to "check" the modified data
    for correctness and allow/deny the commit accordingly.
*/
@interface SBDatabaseObject(SBDatabaseObjectDelegate)

/*!
  @method shouldCommitModifications
  @discussion
    Returning boolean YES indicates to the commitModifications method that the
    receiver should be committed to the backing database.  Returning boolean NO
    aborts the commit and commitModifications returns immediately with boolean
    NO.
*/
- (BOOL) shouldCommitModifications;

/*!
  @method didCommitModifications
  @discussion
    This optional method is called after the commitModifications method has
    successfully pushed all modifications to the backing database and the receiver's
    property state has been updated to match.
*/
- (void) didCommitModifications;

@end
