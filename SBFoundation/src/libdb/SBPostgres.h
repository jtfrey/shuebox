//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBPostgres.h
//
// Access to a Postgres database.
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBDate.h"
#import "SBMemoryPool.h"
#import "SBDatabaseAccess.h"

#include <libpq-fe.h>

@class SBNotification, SBPostgresQuery, SBPostgresQueryResult, SBRunLoop;

/*!
  @const SBPostgresNotifierPayloadStringKey
  @discussion
    String which keys the Postgres async notification payload in an SBNotification
    userInfo dictionary. 
*/
extern SBString *SBPostgresNotifierPayloadStringKey;

/*!
  @class SBPostgresDatabase
  @discussion
  Instances of this class wrap a connection to a Postgres database.
  
  When the connection is opened the client encoding is set to UTF8; this forces Postgres to
  convert the database-native text encoding to UTF8 before handing textual data back to us;
  having done so, SBString objects can be instantiated without involving an encoding
  converter inside our app.  It also forces Postgres to convert any textual data being
  added to the database to the database-native text encoding from UTF8.  So this single
  feature keeps text consistently and properly encoded when moving between us and the
  database!  Sweet!
  
  Instances maintain an error message stack for queries headed through the wrapped database
  connection.
  
  A search schema stack is implemented, as well.  Additional schemas to search during
  queries can be pushed to the top or bottom of that stack.  With no explicit stack
  provided at initialization, the default stack is configured (containing the user's and
  "public" schemas).
  
  The executeQuery method can be used to submit:
  <ul>
    <li>Data w.r.t. a previously-prepared SBPostgresQuery</li>
    <li>A query wrapped by a SBPostgresQuery object</li>
    <li>A textual query in an SBString</li>
  </ul>
  Internally, the SBPostgresDatabase instance maintains an array of prepared SBPostgresQuery
  objects and looks into that array when executeQuery is handed an SBPostgresQuery object;
  if that object is present in the array, then it is treated as a prepared statement and handled
  using PQexecPrepared().  If it is not present, then it is executed using PQexecParams().  If
  handed an SBString, then a UTF8-encoded copy of that string is executed with PQexec().  See
  Postgres documentation for more info on the three functions mentioned.
  
  SBPostgresQuery instances can (as already mentioned) be used to create prepared functions within
  the context of the database connection.  After binding data to all parameters of an SBPostgresQuery,
  invoke the prepareQuery: method on an SBPostgresDatabase object.  Preparing a query pre-plans its
  execution profile, which includes any necessary type-casting of data to fit the actual column
  types of affected tables.  This implies that once you have prepared a SBPostgresQuery, subsequent
  bindings _cannot_ change the data type associated with a parameter.  If you do not prepare an
  SBPostgresQuery (instead opting for PQexecParams() calls) then data type can vary between submissions
  of the SBPostgresQuery object to a database.
  
  Nested transactions can be setup by an SBPostgresDatabase object, effectively providing for 
  arbitrary-depth "undo" functionality.  The beginTransaction message creates a new transactional
  context; sending the discardLastTransaction or commitLastTransaction message effectively cancels
  or saves whatever modifications were made within that context.  Methods also exist to discard or
  commit the _entire_ transactional stack.
*/
@interface SBPostgresDatabase : SBObject <SBDatabaseAccess>
{
  SBString*             _connectionString;
  id                    _runloopNotifier;
  PGconn*               _databaseConnection;
  SBMutableArray*       _searchSchema;
  SBMutableArray*       _preparedQueries;
  SBMutableDictionary*  _typeOids;
  SBMutableArray*       _errorMessageStack;
  SBUInteger            _checkpointIndex;
  struct {
    unsigned int    inNotifyRunLoop : 1;
    unsigned int    openingConnection : 1;
    unsigned int    connectionOpen : 1;
  } _flags;
}

/*!
  @method initWithConnectionString:
  
  Initialize a newly-allocated instance using the provided Postgres database connection
  string.  The connection string format is described in the Postgres libpq documentation:
  it contains key=value pairs separated by whitespace, e.g.
  
    "dbname=template1 user=postgres password=secret"
    
  Returns nil if a connection could not be established.
*/
- (id) initWithConnectionString:(SBString*)connStr;
/*!
  @method initWithConnectionString:searchSchema:
  
  Behaves exactly like initWithConnectionString: but in addition sets an initial search
  schema stack for the database.
*/
- (id) initWithConnectionString:(SBString*)connStr searchSchema:(SBArray*)searchSchema;
/*!
  @method isConnectionOpen
  
  Returns YES if the receiver _is_ connected to a database.
*/
- (BOOL) isConnectionOpen;
/*!
  @method databaseConnection
  
  Returns the Postgres database connection reference for the receiver.
*/
- (PGconn*) databaseConnection;
/*!
  @method connectionString
  
  Returns the connection string that was used to open the receiver's database connection.
*/
- (SBString*) connectionString;
/*!
  @method reconnect
  
  Convenience method that sends the reconnectWithRetryCount: message with a retry count
  of 3.
*/
- (BOOL) reconnect;
/*!
  @method reconnectWithRetryCount:
  
  Close the connection to the database and attempt to reestablish a new connection to the
  same database, using all the same parameters previously used. This might be useful for
  error recovery if a working connection is lost.
*/
- (BOOL) reconnectWithRetryCount:(SBUInteger)retryCount;

#if PG_VERSION_NUM >= 90200

/*!
  @method ping
  @discussion
    Returns boolean YES if the database connection is "okay."
*/
- (BOOL) ping;

#endif

/*!
  @method searchSchema
  
  Returns the array of search schemas for the receiver.
*/
- (SBArray*) searchSchema;
/*!
  @method prependSearchSchema:
  
  Add a schema name to the head of the schema-search stack.
*/
- (void) prependSearchSchema:(SBString*)schemaName;
/*!
  @method appendSearchSchema:
  
  Add a schema name to the tail of the schema-search stack.
*/
- (void) appendSearchSchema:(SBString*)schemaName;
/*!
  @method removeSearchSchema:
  
  Remove the provided schemaName from the schema-search stack.
*/
- (void) removeSearchSchema:(SBString*)schemaName;
/*!
  @method containsSearchSchema:
  
  Returns YES if the schema-search stack contains the provided schemaName.
*/
- (BOOL) containsSearchSchema:(SBString*)schemaName;
/*!
  @method typeOidForTypeName:
  
  Attempts to lookup in the database what Oid is associated with the
  given named type.
*/
- (Oid) typeOidForTypeName:(SBString*)typeName;
/*!
  @method errorMessageCount
  
  Returns the number of error messages currently available on the error stack.
*/
- (SBUInteger) errorMessageCount;
/*!
  @method lastErrorMessage
  
  Pop the last-added error message from error stack.
*/
- (SBString*) lastErrorMessage;
/*!
  @method errorMessageEnumerator
  
  Returns an SBEnumerator object that will iterate through the error messages
  on the error stack.
*/
- (SBEnumerator*) errorMessageEnumerator;
/*!
  @method clearErrorMessageStack
  
  Remove all messages from the error stack.
*/
- (void) clearErrorMessageStack;
/*!
  @method prepareQuery:
  
  Given an SBPostgresQuery object, attempt to create a prepared statement in the
  receiver's database context that will later be executed using data passed to
  the receiver in the same SBPostgresQuery object.  Once prepared, the
  statement can be executed multiple times by continuing to pass the SBPostgresQuery
  object to the executeQuery: method.
*/
- (BOOL) prepareQuery:(SBPostgresQuery*)aReadyQuery;

@end


/*!
  @category SBPostgresDatabase(SBPostgresDatabaseNotification)
  @discussion
  This category groups methods of the SBPostgresDatabase class which deal with handling asynchronous
  notifications coming from the database.  Essentially, one prepares for this behavior by 
  registering objects that will respond to commands like
  
    NOTIFY XXXXXXX{, 'Payload'}
    
  performed in the connected database, where XXXXXXX is some arbitrary string and the {, 'Payload'}
  is an optional string argument passed to any agents listening for the notification.  The objects
  are registered with one or more strings (XXXXXXX above) to which they respond.  The objects must
  implement the notificationFromDatabase: method.  A standard SBNotification object is sent to the
  registered method, with XXXXXXX as the notification name and the optional payload string in the
  userInfo dictionary (keyed by the string constant SBPostresNotifierPayloadStringKey).  If no
  payload was involved in the NOTIFY command, the userInfo dictionary will be nil.
  
  Once all interested objects are registered, a program begins polling for notifications by
  sending the notificationRunLoop message to a SBPostgresDatabase object.  The program blocks, waiting
  for notifications to be delivered by Postgres.
*/
@interface SBPostgresDatabase(SBPostgresDatabaseNotification)

/*!
  @method notificationRunLoop
  
  Enter the notification runloop for the receiver's database.  Blocks while waiting for NOTIFY
  commands to be seen coming from the database.
*/
- (int) notificationRunLoop;
/*!
  @method exitFromNotificationRunLoop
  
  Set the flag that will cause the receiver to exit its notification runloop.  I can only imagine
  this method being used from signal handlers, honestly.
*/
- (void) exitFromNotificationRunLoop;
/*!
  @method registerObject:forNotification:
  
  When a NOTIFY event with the provided name (pgNotification) is observed coming from the database,
  send the notificationFromDatabase: message to object.
*/
- (void) registerObject:(id)object forNotification:(SBString*)pgNotification;
/*!
  @method unregisterObject:forNotification:
  
  Remove object from being informed when a NOTIFY event is observed with the provided name
  (pgNotification).
*/
- (void) unregisterObject:(id)object forNotification:(SBString*)pgNotification;
/*!
  @method scheduleNotificationInRunLoop:
*/
- (void) scheduleNotificationInRunLoop:(SBRunLoop*)aRunLoop;
/*!
  @method removeNotificationFromRunLoop:
*/
- (void) removeNotificationFromRunLoop:(SBRunLoop*)aRunLoop;

@end


/*!
  @category SBObject(SBPostgresDatabaseNotification)
  @discussion
  This is the method that will be performed on an object that has registered for async Postgres
  notifications when a notification arrives.
*/
@interface SBObject(SBPostgresDatabaseNotification)

- (void) notificationFromDatabase:(SBNotification*)aNotify;

@end

/*!
  @category SBString(SBPostgresStringEscaping)
  @discussion
  Convenience methods that handle the escaping of text strings for use in Postgres database
  queries. Note that escaping is _not_ necessary when using SBPostgresQuery objects, only when
  creating SBString-based queries (for PQexec()).
*/
@interface SBString(SBPostgresStringEscaping)

/*!
  @method stringEscapedForPostgresDatabase:
  
  Returns an autoreleased copy of the receiver which has been properly escaped for inclusion
  in Postgres query strings.
  
  Returns nil on error.
*/
- (SBString*) stringEscapedForPostgresDatabase:(SBPostgresDatabase*)aDatabase;

/*!
  @method stringEscapedForPostgresDatabase:
  
  Place a copy of the receiver which has been properly escaped for inclusion in Postgres query
  strings into the provided buffer.
  
  Ideally the buffer should be one plus twice the size of the UTF8-encoded version of the
  receiver -- every character escaped plus the NUL terminator.  The actual number of bytes of
  buffer used in the escaping is returned by this method; if the returned byte count equals
  the byteSize then the string in buffer may _not_ be NUL terminated.
*/
- (SBUInteger) escapeForPostgresDatabase:(SBPostgresDatabase*)aDatabase inBuffer:(void*)buffer byteSize:(SBUInteger)byteSize;

@end


/*!
  @class SBPostgresQuery
  @discussion
  Class that wraps a database query.  Includes methods to bind several basic atomic types
  to query parameters.  Also includes the ability to bind some of the SBFoundation classes to
  query parameters:
  <ul>
    <li>SBString</li>
    <li>SBNumber</li>
    <li>SBData</li>
    <li>SBDate</li>
    <li>SBDateComponents</li>
    <li>SBInetAddress</li>
    <li>SBMACAddress</li>
    <li>SBUUID</li>
  </ul>
  Essentially, one allocates and initializes a query and then binds data to it.  Once all
  parameters have been bound, the SBPostgresQuery can be:
  <ul>
    <li>Used to create a prepared query in the context of the database connection</li>
    <li>Submitted to the database for execution</li>
  </ul>
  Once the query has been prepared, all subsequent bindings _must_ honor the data type
  that was present in the original preparation!
  
  An instance of SBPostgresQuery can be submitted multiple times to multiple
  SBPostgresDatabase objects.  Instances can also be re-used:  previous parameters can be
  scrubbed OR the existing parameters can be adjusted for the next query.  Beware:  reuse
  without resetting the bindings does not allow the object's memory pool to reclaim
  space -- it will continue to allocate more and more memory.  Using the resetParameterBindings
  method is a better choice since it will reset and reuse the memory already allocated by the
  pool for the previous query.
  
  All binding methods (except for bindUTF8StringNoCopy:byteSize:toParameter:) copy the
  intended data into the receiver's memory pool; this is due partly to the fact that we do
  binary (not textual) query execution and some of the data types require additional information
  above and beyond the actual data (e.g. the INET and CIDR types).  It's also important for
  strings since we hold text as UTF-16 internally, and Postgres will only take UTF8!  So it's
  sad that we have to duplicate data for query construction, but in the end we don't have much
  of a choice (could be worse, we could be doing purely textual queries and have to escape
  everything, etc!)
*/
@interface SBPostgresQuery : SBObject
{
  SBMemoryPoolRef       _queryPool;
  SBUInteger            _parameterCount;
  unsigned char*        _queryString;
  BOOL                  _hasBeenPrepared;
  //
  // The rest of the instance variables are allocated from the object's _queryPool:
  //
  Class*                _paramClasses;
  Oid*                  _paramOids;
  const char**          _paramValues;
  int*                  _paramLengths;
  int*                  _paramFormats;
}

/*!
  @method initWithQueryString:parameterCount:
  
  Initialize a newly-allocated query object to use the given query string which contains
  parameterCount parameter substitutions.  The query string itself is documented in the
  Postgres documentation:  substitutable parameters are indicated in the SQL by the use
  of "$1", "$2", etc.
  
  Note that the query string and parameter count _can not_ be adjusted once the instance
  has been initialized.
*/
- (id) initWithQueryString:(SBString*)queryString parameterCount:(SBUInteger)parameterCount;
/*!
  @method queryString
  
  Returns the UTF8-encoded query string wrapped by the receiver.
*/
- (const char*) queryString;
/*!
  @method parameterCount
  
  Returns the number of substitutable parameters in the SQL query wrapped by the
  receiver.
*/
- (SBUInteger) parameterCount;
/*!
  @method unprepareInAllDatabases
  
  Broadcasts a notification to all databases against which the receiver was prepared so
  that the databases can drop their reference to the receiver.
  
  Send this message whenever you have finished using a prepared query and are about to
  release it.
*/
- (void) unprepareInAllDatabases;
/*!
  @method resetParameterBindings
  
  Invoke this method after executing the receiver in order to discard all of the data
  which was bound to it.  Behind the scenes this merely drains the receiver's memory
  pool and resets the parameter arrays in preparation for another round of binding
  parameter data to the receiver.
*/
- (BOOL) resetParameterBindings;
/*!
  @method bindBoolValue:toParameter:
  
  Attempt to bind a boolean value to the given parameter.  Parameters are numbered
  in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindBoolValue:(BOOL)value toParameter:(SBUInteger)parameter;
/*!
  @method bindInt2Value:toParameter:
  
  Attempt to bind a two-byte integer value to the given parameter.  Parameters are
  numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindInt2Value:(int16_t)value toParameter:(SBUInteger)parameter;
/*!
  @method bindInt4Value:toParameter:
  
  Attempt to bind a four-byte integer value to the given parameter.  Parameters are
  numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindInt4Value:(int32_t)value toParameter:(SBUInteger)parameter;
/*!
  @method bindInt8Value:toParameter:
  
  Attempt to bind an eight-byte integer value to the given parameter.  Parameters are
  numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindInt8Value:(int64_t)value toParameter:(SBUInteger)parameter;
/*!
  @method bindFloatValue:toParameter:
  
  Attempt to bind a single-precision floating point value to the given parameter.
  Parameters are numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindFloatValue:(float)value toParameter:(SBUInteger)parameter;
/*!
  @method bindDoubleValue:toParameter:
  
  Attempt to bind a double-precision floating point value to the given parameter.
  Parameters are numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindDoubleValue:(double)value toParameter:(SBUInteger)parameter;
/*!
  @method bindUTF8String:byteSize:toParameter:
  
  Attempt to bind a string of UTF8 characters to the given parameter.  The byteSize
  should not count any terminating NUL characters in string; passing zero for the
  byteSize indicates that string is NUL terminated and strlen() should be used to
  determine the length.
  
  Parameters are numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindUTF8String:(const char*)string byteSize:(SBUInteger)byteSize toParameter:(SBUInteger)parameter;
/*!
  @method bindUTF8StringNoCopy:byteSize:toParameter:
  
  Attempt to bind a string of UTF8 characters to the given parameter.  The byteSize
  should not count any terminating NUL characters in string; passing zero for the
  byteSize indicates that string is NUL terminated and strlen() should be used to
  determine the length.  The string is _not_ copied into a memory buffer supplied by
  the receiver's pool -- the parameter is bound directly to the string pointer.
  
  Parameters are numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindUTF8StringNoCopy:(const char*)string byteSize:(SBUInteger)byteSize toParameter:(SBUInteger)parameter;
/*!
  @method bindObject:toParameter:
  
  Attempt to bind the data represented by an SBFoundation object to the given parameter.
  This method recognizes the following SBFoundation classes:
  <ul>
    <li>SBString</li>
    <li>SBNumber</li>
    <li>SBData</li>
    <li>SBDate</li>
    <li>SBDateComponents</li>
    <li>SBInetAddress</li>
    <li>SBMACAddress</li>
    <li>SBUUID</li>
  </ul>
  Parameters are numbered in the range [1,parameterCount].
  
  Returns NO if the value could not be bound to the specified parameter.
*/
- (BOOL) bindObject:(id)object toParameter:(SBUInteger)parameter;
/*!
  @method bindNULLToParameter:
  
  Attempt to reset the given parameter to a NULL value. Parameters are numbered in the
  range [1,parameterCount].
*/
- (BOOL) bindNULLToParameter:(SBUInteger)parameter;

@end

/*!
  @class SBPostgresQueryResult
  @discussion
  Instances of SBPostgresQueryResult are returned by an SBPostgresDatabase when a query is
  successfully performed.  Each instance wraps a Postgres query result and provides an
  interface for retrieving result status and (for SELECT queries) row/field data.
  
  The value of fields can be retrieved atomically using the getValuePointer:atRow:fieldNum:
  and copyValueAtRow:fieldNum:toBuffer:length: methods; these two methods retrieve the
  literal binary data returned by the query.  On the other hand, the objectForRow:fieldNum:
  method will inspect the field's data type and return an object appropriate for that
  field's type initialized to contain the value of the field.  For example, a field of
  SQL type INET or CIDR will produce an instance of SBInetAddress, while a TIMESTAMP field
  will produce an instance of SBDate.  The DATE and TIME types will produce an instance of
  SBDateComponents.
  
  For any "exotic" SQL type for which no corresponding class is known, the objectForRow:fieldNum:
  method will return an SBData object containing the binary data returned by the database.
*/
@interface SBPostgresQueryResult : SBObject <SBDatabaseQueryResult>
{
  id              _parentDatabase;
  PGresult*       _queryResult;
  SBArray*        _fieldNames;
  struct {
    unsigned int  wasSuccessful : 1;
    unsigned int  didCalcSuccess : 1;
  } _flags;
}

/*!
  @method postgresResultStatus
  
  Returns the Postgres status code returned for the query.
*/
- (ExecStatusType) postgresResultStatus;
/*!
  @method queryErrorString
  
  If an error occurred for the query, returns a string with the error description.
  Otherwise, returns nil.
*/
- (SBString*) queryErrorString;
/*!
  @method postgresType:forFieldNum:
  
  For a data-returning query (e.g. SELECT), attempts to retrieve the Postgres data type
  (as an Oid) for the given column.  If successful, the method sets typeOid and returns
  YES.  Otherwise, returns NO.
*/
- (BOOL) postgresType:(Oid*)typeOid forFieldNum:(SBUInteger)fieldNum;
/*!
  @method postgresTypeModifier:forFieldNum:
  
  For a data-returning query (e.g. SELECT), attempts to retrieve a type modifier for the
  given column (e.g. the dimension of a VARCHAR).  If successful, the method sets
  typeMod and returns YES.  Otherwise, returns NO.
*/
- (BOOL) postgresTypeModifier:(SBUInteger*)typeMod forFieldNum:(SBUInteger)fieldNum;
/*!
  @method postgresTypeModifier:forFieldNum:
  
  For a data-returning query (e.g. SELECT), attempts to retrieve the server's internal
  storage size for the given column's data type.  If successful, the method sets
  typeMod and returns YES.  Otherwise, returns NO.
  
  As the Postgres docs state, this isn't really of any use to client programs...but it's in
  their API, so why not include it.
*/
- (BOOL) postgresStorageSize:(SBUInteger*)storageSize forFieldNum:(SBUInteger)fieldNum;
/*!
  @method getOidOfInsertedRow:
  
  For a query that adds a row to a table, attempt to retrieve the Oid that was generated for
  the new row.  If successful, sets anOid and returns YES; otherwise, returns NO.
  
  Postgres does not always have OIDs enabled on tables, so this may return an InvalidOid
  even if the query was successful!
*/
- (BOOL) getOidOfInsertedRow:(Oid*)anOid;

@end
