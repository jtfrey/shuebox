//
// SBDatabaseKit - Database access extentions to SBFoundation
// SBDatabaseAccess.h
//
// Generic protocols for database access.  Ideally, we'll have classes for each database
// system we need; each would provide <i>at least</i> a database class and a query result class
// which conform to the protocols below.
//
// $Id$
//

#import "SBObject.h"

@class SBArray, SBDictionary;

/*!
  @header SBDatabaseAccess.h
  @discussion
  In order to present a generalized API for database access, several protocols are declared in this
  header file.  Classes that provide database access and query processing should adopt these
  protocols in order to promote an engine-invariant API in applications.
  
  The protocols are split into access (query-related) and result processing groups.
  
  The SBDatabaseAccess protocol includes methods for working with transaction levels: create,
  discard, and commit a transaction.  It also includes two basic methods for performing a
  query:  one which returns a query result object and one that returns a BOOL indicative of
  the overall success or failure of the query.
  
  The SBDatabaseQueryResult protocol encompasses basic query status information:  was the
  query successful, how many rows/columns were produced?  Beyond simple status, there are methods
  which can be used to retrieve the data at a specific row and column of the result of a
  data-returning query (like a SELECT).  Since this is an object-oriented framework, there are
  also methods to wrap returned values in native objects:  for example, a VARCHAR(32) would be
  returned as an instance of SBString.
*/


/*!
  @protocol SBDatabaseAccess
  @discussion
  Groups methods which any database connection class should implement.  Together, these
  methods allow transaction-oriented database queries to be made without specific reference to
  the database engine in question.
*/
@protocol SBDatabaseAccess

/*!
  @method executeQuery
  
  Attempt to execute a query against the database.  The aQuery argument to the
  method can be either an SBString or a special query-represeting object specific
  to a particular database system.
  
  Returns an object which wraps the query result and (at least) responds to the
  SBDatabaseQueryResult protocol.
*/
- (id) executeQuery:(id)aQuery;
/*!
  @method executeQuery
  
  Attempt to execute a query against the database.  The aQuery argument to the
  method can be either an SBString or a special query-represeting object specific
  to a particular database system.
  
  Returns YES if the query executed successfully.
*/
- (BOOL) executeQueryWithBooleanResult:(id)aQuery;
/*!
  @method beginTransaction
  
  Attempt to create a new transactional context in the receiver's database connection.
  Returns YES if successful.
*/
- (BOOL) beginTransaction;
/*!
  @method discardLastTransaction
  
  Attempt to roll the database back to the state it was in prior to the last invocation
  of the beginTransaction method.  Returns YES if successful.
*/
- (BOOL) discardLastTransaction;
/*!
  @method discardAllTransactions
  
  Attempt to roll the database back to the state it was in prior to the first invocation
  of the beginTransaction method.  Returns YES if successful.
*/
- (BOOL) discardAllTransactions;
/*!
  @method commitLastTransaction
  
  Attempt to apply all changes made to the database since the last invocation of the
  beginTransaction method.  Returns YES if successful.
*/
- (BOOL) commitLastTransaction;
/*!
  @method commitAllTransactions
  
  Attempt to apply all changes made to the database since the first invocation of the
  beginTransaction method.  Returns YES if successful.
*/
- (BOOL) commitAllTransactions;
/*!
  @method stringEscapedForQuery:
  
  Return a copy of aString properly-escaped for inclusion in SQL statements.
*/
- (SBString*) stringEscapedForQuery:(SBString*)aString;

@end

/*!
  @protocol SBDatabaseQueryResult
  @discussion
  Groups methods which any database class' query result class(es) should implement.  The
  methods are general enough that they should be applicable to any database engine.
*/
@protocol SBDatabaseQueryResult

/*!
  @method queryWasSuccessful
  
  Returns YES if the receiver represents a successful SQL query.
*/
- (BOOL) queryWasSuccessful;
/*!
  @method numberOfRows
  
  For a data-returning query (e.g. SELECT), returns the number of rows returned
  by the database.
*/
- (SBUInteger) numberOfRows;
/*!
  @method numberOfFields
  
  For a data-returning query (e.g. SELECT), returns the number of columns of
  data returned by the database.
*/
- (SBUInteger) numberOfFields;
/*!
  @method fieldNameWithNumber:
  
  For a data-returning query (e.g. SELECT), returns the name associated with
  column number fieldNum; columns use a zero-based numbering scheme.
*/
- (SBString*) fieldNameWithNumber:(SBUInteger)fieldNum;
/*!
  @method fieldNumberWithName:
  
  For a data-returning query (e.g. SELECT), returns the column number which
  has the given fieldName associated with it.  Note that the treatment of case
  may vary between database systems.
*/
- (SBUInteger) fieldNumberWithName:(SBString*)fieldName;
/*!
  @method isNullValueAtRow:fieldNum:
  
  For a data-returning query (e.g. SELECT), returns YES if the value in the
  given row and column is NULL.
*/
- (BOOL) isNullValueAtRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum;
/*!
  @method sizeOfValue:atRow:fieldNum:
  
  For a data-returning query (e.g. SELECT), sets byteSize to the number of bytes
  used to represent the returned value in the given row and column.
  
  If the method was able to set byteSize, YES is returned.  Otherwise, NO is
  returned.
*/
- (BOOL) sizeOfValue:(SBUInteger*)byteSize atRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum;
/*!
  @method getValuePointer:atRow:fieldNum:
  
  For a data-returning query (e.g. SELECT), sets valuePtr to a pointer to the
  returned value in the given row and column.  Note that this is often a pointer
  to memory internal to the specific database's query result data structure, so
  the pointer should not be considered generally thread-safe or long-term viable.
  If you need the data to stick around, make a copy.
  
  If the method was able to set valuePtr, YES is returned.  Otherwise, NO is
  returned.
*/
- (BOOL) getValuePointer:(void**)valuePtr atRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum;
/*!
  @method getSizeOfValue:andPointer:atRow:fieldNum:
  
  Combination of the sizeOfValue:atRow:fieldNum: and getValuePointer:atRow:fieldNum:
  methods to get both size and pointer in one pass.
*/
- (BOOL) getSizeOfValue:(SBUInteger*)byteSize andPointer:(void**)valuePtr atRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum;
/*!
  @method copyValueAtRow:fieldNum:toBuffer:length:
  
  For a data-returning query (e.g. SELECT), copy the first "length" bytes of the value
  in the given row and column to "buffer".  If "length" is larger than the actual
  byte size of the value, the remainder of "buffer" is untouched.
  
  Returns the actual number of bytes copied to "buffer".
*/
- (SBUInteger) copyValueAtRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum toBuffer:(void*)buffer length:(SBUInteger)length;
/*!
  @method classForFieldNum:
  
  For a data-returning query (e.g. SELECT), inspect the data type associated with the
  given column and return the ObjC class which would be used to wrap the value.  For example,
  a column with a floating point type would return the SBNumber class while a BLOB would
  return the SBData class.
  
  Returns SBData as the default.
*/
- (Class) classForFieldNum:(SBUInteger)fieldNum;
/*!
  @method objectForRow:fieldNum:
  
  For a data-returning query (e.g. SELECT), inspect the data type associated with the
  given column and return an object of the appropriate ObjC class that wraps the value in
  the given row and column.  For example, a TEXT or VARCHAR field would return an
  SBString object.
*/
- (id) objectForRow:(SBUInteger)row fieldNum:(SBUInteger)fieldNum;
/*!
  @method arrayForRow:
  
  Convenience method which should invoke arrayForRow:createMutable: with the createMutable
  flag being NO.
*/
- (SBArray*) arrayForRow:(SBUInteger)row;
/*!
  @method arrayForRow:createMutable:
  
  For a data-returning query (e.g. SELECT), process all columns in the given row as they
  would be processed in the objectForRow:fieldNum: method and return the resulting objects
  in an array ordered according to field number.
  
  If createMutable is YES, then the returned array object will be an SBMutableArray.
*/
- (SBArray*) arrayForRow:(SBUInteger)row createMutable:(BOOL)createMutable;
/*!
  @method dictionaryForRow:
  
  Convenience method which should invoke dictionaryForRow:createMutable: with the
  createMutable flag being NO.
*/
- (SBDictionary*) dictionaryForRow:(SBUInteger)row;
/*!
  @method dictionaryForRow:createMutable:
  
  For a data-returning query (e.g. SELECT), process all columns in the given row as they
  would be processed in the objectForRow:fieldNum: method and return the resulting objects
  in a dictionary, keyed by field names.
  
  If createMutable is YES, then the returned array object will be an SBMutableDictionary.
*/
- (SBDictionary*) dictionaryForRow:(SBUInteger)row createMutable:(BOOL)createMutable;
/*!
	@method arrayForFieldNum:
  
  Convenience method which should invoke arrayForFieldNum:createMutable: with the createMutable
  flag being NO.
*/
- (SBArray*) arrayForFieldNum:(SBUInteger)fieldNum;
/*!
	@method arrayForFieldNum:createMutable:
	
	For a data-returning query (e.g. SELECT), extract the value of a given field (column)
	for all rows of the returned query result.  The values are added to the resulting array
	in the order in which they occur in the result set.
  
  If createMutable is YES, then the returned array object will be an SBMutableArray.
*/
- (SBArray*) arrayForFieldNum:(SBUInteger)fieldNum createMutable:(BOOL)createMutable;

@end
