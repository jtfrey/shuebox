//
// SBFoundation : ObjC Class Library for Solaris
// SBPostgres.h
//
// Access to a Postgres database.
//
// $Id$
//

#import "SBPostgres.h"
#import "SBNotification.h"

#import "SBData.h"
#import "SBValue.h"
#import "SBDate.h"
#import "SBInetAddress.h"
#import "SBMACAddress.h"

#include "SBPostgresOids.h"

/*
 * The following stuff is pilfered from Postgres headers...
 */
#include "pgtypes_interval.h"
 
/* Julian-date equivalents of Day 0 in Unix and Postgres reckoning */
#define UNIX_EPOCH_JDATE        2440588 /* == date2j(1970, 1, 1) */
#define POSTGRES_EPOCH_JDATE    2451545 /* == date2j(2000, 1, 1) */
#ifdef HAVE_INT64_TIMESTAMP
static in64_t PostgresEpochShift = ((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * 60 * 60 * 24);
#else
static double PostgresEpochShift = ((POSTGRES_EPOCH_JDATE - UNIX_EPOCH_JDATE) * 60 * 60 * 24);
#endif

#define PGSQL_AF_INET      (AF_INET + 0)
#define PGSQL_AF_INET6     (AF_INET + 1)

@interface SBPostgresQuery(SBPostgresQueryPrivate)

- (Oid*) paramOids;
- (const char**) paramValues;
- (int*) paramLengths;
- (int*) paramFormats;

- (void) setHasBeenPrepared:(BOOL)hasBeenPrepared;

@end

@implementation SBPostgresQuery(SBPostgresQueryPrivate)

  - (Oid*) paramOids { return _paramOids; }
  - (const char**) paramValues { return _paramValues; }
  - (int*) paramLengths { return _paramLengths; }
  - (int*) paramFormats { return _paramFormats; }
  - (void) setHasBeenPrepared:(BOOL)hasBeenPrepared { if ( hasBeenPrepared ) _hasBeenPrepared = YES; }

@end

//
#pragma mark -
//

@interface SBPostgresQueryResult(SBPostgresQueryResultPrivate)

- (id) initWithQueryResult:(PGresult*)pgResult;

@end

@implementation SBPostgresQueryResult(SBPostgresQueryResultPrivate)

  - (id) initWithQueryResult:(PGresult*)pgResult
  {
    if ( self = [super init] )
      _queryResult = pgResult;
    return self;
  }

@end

//
#pragma mark -
//

@interface SBPostgresDatabase(SBPostgresDatabasePrivate)

- (BOOL) setPostgresClientProperties;
- (BOOL) setPostgresSchemaSearchPath;
- (BOOL) prepareQuery:(SBPostgresQuery*)aQuery statementName:(const char*)statementName;
- (PGresult*) baseExecuteQuery:(id)aQuery;

@end

@implementation SBPostgresDatabase(SBPostgresDatabasePrivate)

  - (BOOL) setPostgresClientProperties
  {
    BOOL      rc = NO;
    
    if ( _databaseConnection ) {
      PGresult*         queryResult = PQexec(_databaseConnection, "SET CLIENT_ENCODING TO 'UTF8'");
      
      if ( queryResult ) {
        char*     errorMsg = PQresultErrorMessage(queryResult);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        } else {
          rc = [self setPostgresSchemaSearchPath];
        }
        PQclear(queryResult);
      }
    }
    return rc;
  }
  
//

  - (BOOL) setPostgresSchemaSearchPath
  {
    BOOL      rc = NO;
    
    if ( _databaseConnection ) {
      SBMutableString*  command = nil;
      PGresult*         queryResult = NULL;
      
      if ( _searchSchema ) {
        unsigned int      i = 0, iMax = [_searchSchema count];
        
        if ( iMax > 0 ) {
          command = [[SBMutableString alloc] initWithUTF8String:"SET search_path TO "];
          while ( i < iMax ) {
            [command appendFormat:"\"%S\"%c",
                [[_searchSchema objectAtIndex:i] utf16Characters],
                ( i == (iMax - 1) ? ';' : ',' )
              ];
            i++;
          }
        }
      }
      
      if ( command ) {
        SBSTRING_AS_UTF8_BEGIN(command)
        
          queryResult = PQexec(_databaseConnection, command_utf8);
        
        SBSTRING_AS_UTF8_END
        //
        // Done with that string we built:
        //
        [command release];
      } else {
        queryResult = PQexec(_databaseConnection, "SET search_path TO \"$user\",\"public\";");
      }
      if ( ! queryResult ) {
        rc = [self reconnect];
      } else {
        char*     errorMsg = PQresultErrorMessage(queryResult);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        } else {
          rc = YES;
        }
        PQclear(queryResult);
      }
    }
    return rc;
  }
  
//

  - (BOOL) prepareQuery:(SBPostgresQuery*)aQuery
    statementName:(const char*)statementName
  {
    BOOL          result = NO;
    PGresult*     prepResult = PQprepare(
                                  _databaseConnection,
                                  statementName,
                                  [aQuery queryString],
                                  [aQuery parameterCount],
                                  [aQuery paramOids]
                                );
    if ( prepResult ) {
      result = ( PQresultStatus(prepResult) == PGRES_COMMAND_OK );
      PQclear(prepResult);
    }
    return result;
  }

//

  - (PGresult*) baseExecuteQuery:(id)aQuery
  {
    id          queryResult = nil;
    PGresult*   pgResult = NULL;
    
    if ( [aQuery isKindOf:[SBPostgresQuery class]] ) {
      unsigned int      queryIdx = SBNotFound;
      
      //
      // It's a query object; do we have it on record as having been
      // handed to PQprepare()?
      //
      if ( _preparedQueries && ((queryIdx = [_preparedQueries indexOfObjectIdenticalTo:aQuery]) != SBNotFound) ) {
        char            statementName[40];
        
        snprintf(
            statementName,
            40,
            "SBPostgresPreparedQuery0x08X",
            queryIdx
          );
        pgResult = PQexecPrepared(
                        _databaseConnection,
                        statementName,
                        [aQuery parameterCount],
                        [aQuery paramValues],
                        [aQuery paramLengths],
                        [aQuery paramFormats],
                        1
                      );
      } else {
        pgResult = PQexecParams(
                        _databaseConnection,
                        [aQuery queryString],
                        [aQuery parameterCount],
                        [aQuery paramOids],
                        [aQuery paramValues],
                        [aQuery paramLengths],
                        [aQuery paramFormats],
                        1
                      );
      }
    } else if ( [aQuery isKindOf:[SBString class]] ) {
      //
      // PQexec() on the UTF8 encoding of the string:
      //
      const unsigned char*  queryAsUTF8 = [(SBString*)aQuery utf8Characters];
      
      if ( queryAsUTF8 ) {
        pgResult = PQexec(
                        _databaseConnection,
                        queryAsUTF8
                      );
      }
    }
    if ( ! pgResult ) {
      // Push the last on-connection error onto the error stack:
      char*     errorMsg = PQerrorMessage(_databaseConnection);
      
      if ( errorMsg && *errorMsg ) {
        printf(":: %s\n", errorMsg);
        [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
      }
    }
    return pgResult;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresDatabase

  - (id) initWithConnectionString:(SBString*)connStr
  {
    return [self initWithConnectionString:connStr searchSchema:nil];
  }

//

  - (id) initWithConnectionString:(SBString*)connStr
    searchSchema:(SBArray*)searchSchema
  {
    if ( self = [super init] ) {
      _connectionString = [connStr copy];
      _searchSchema = ( searchSchema ? [[SBArray alloc] initWithArray:searchSchema] : [[SBArray alloc] init] );
      _errorMessageStack = [[SBArray alloc] init];
      
      [self reconnect];
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _connectionString ) [_connectionString release];
    if ( _databaseConnection ) PQfinish(_databaseConnection);
    if ( _searchSchema ) [_searchSchema release];
    if ( _preparedQueries ) [_preparedQueries release];
    if ( _errorMessageStack ) [_errorMessageStack release];
    
    [super dealloc];
  }
  
//

  - (PGconn*) databaseConnection
  {
    return _databaseConnection;
  }
  
//

  - (SBString*) connectionString
  {
    return _connectionString;
  }
  
//

  - (BOOL) reconnect
  {
    return [self reconnectWithRetryCount:3];
  }
  - (BOOL) reconnectWithRetryCount:(int)retryCount
  {
    BOOL      rc = NO;
    
    if ( _databaseConnection ) {
      PQfinish(_databaseConnection);
      _databaseConnection = NULL;
      
      _flags.openingConnection = NO;
      _flags.inNotifyRunLoop = NO;
      _flags.connectionOpen = NO;
    }
    if ( ! _flags.openingConnection && _connectionString ) {
      SBSTRING_AS_UTF8_BEGIN(_connectionString)
        //
        // Retry the connection several times, in case the server is
        // slightly busy, etc.  We sleep 5 seconds between each
        // attempt:
        //
        while ( retryCount-- ) {
          _databaseConnection = PQconnectdb((const char*)_connectionString_utf8);
          _flags.openingConnection = YES;
          if ( _databaseConnection ) {
            if ( PQstatus(_databaseConnection) == CONNECTION_OK ) {
              _flags.openingConnection = NO;
              _flags.connectionOpen = YES;
              rc = [self setPostgresClientProperties];
              break;
            } else {
              PQfinish(_databaseConnection);
            }
            sleep(5);
          }
        }
      
      SBSTRING_AS_UTF8_END
    }
    return rc;
  }
  
//

  - (void) prependSearchSchema:(SBString*)schemaName
  {
    unsigned int      index = [_searchSchema indexOfObject:schemaName];
    
    if ( index == SBNotFound ) {
      [_searchSchema addObject:schemaName];
      [self setPostgresSchemaSearchPath];
    }
  }

//

  - (void) appendSearchSchema:(SBString*)schemaName
  {
    unsigned int      index = [_searchSchema indexOfObject:schemaName];
    
    if ( index == SBNotFound ) {
      [_searchSchema addObject:schemaName];
      [self setPostgresSchemaSearchPath];
    }
  }

//

  - (void) removeSearchSchema:(SBString*)schemaName
  {
    unsigned int      index = [_searchSchema indexOfObject:schemaName];
    
    if ( index != SBNotFound ) {
      [_searchSchema removeObjectAtIndex:index];
      [self setPostgresSchemaSearchPath];
    }
  }
  
//

  - (BOOL) containsSearchSchema:(SBString*)schemaName
  {
    return ( [_searchSchema indexOfObject:schemaName] != SBNotFound );
  }

//

  - (unsigned int) errorMessageCount
  {
    return [_errorMessageStack count];
  }
  
//

  - (SBString*) lastErrorMessage
  {
    return [_errorMessageStack popObject];
  }
  
//

  - (SBEnumerator*) errorMessageEnumerator
  {
    return [_errorMessageStack reverseObjectEnumerator];
  }
  
//

  - (void) clearErrorMessageStack
  {
    [_errorMessageStack removeAllObjects];
  }

//

  - (BOOL) prepareQuery:(SBPostgresQuery*)aReadyQuery
  {
    if ( ! _preparedQueries ) {
      _preparedQueries = [[SBArray alloc] init];
    } else if ( [_preparedQueries containsObjectIdenticalTo:aReadyQuery] ) {
      //
      // Already prepared:
      //
      return YES;
    }
    if ( _preparedQueries ) {
      unsigned int      idx = [_preparedQueries count];
      char              statementName[40];
      
      snprintf(
          statementName,
          40,
          "SBPostgresPreparedQuery0x08X",
          idx
        );
      if ( [self prepareQuery:aReadyQuery statementName:statementName] ) {
        [_preparedQueries addObject:aReadyQuery];
        [aReadyQuery setHasBeenPrepared:YES];
        return YES;
      }
    }
    return NO;
  }
  
//

  - (SBPostgresQueryResult*) executeQuery:(id)aQuery
  {
    SBPostgresQueryResult*    queryResult = nil;
    PGresult*                 pgResult = [self baseExecuteQuery:aQuery];
    
    if ( pgResult )
      queryResult = [[[SBPostgresQueryResult alloc] initWithQueryResult:pgResult] autorelease];
    return queryResult;
  }

//

  - (BOOL) executeQueryWithBooleanResult:(id)aQuery
  {
    BOOL        rc = NO;
    PGresult*   pgResult = [self baseExecuteQuery:aQuery];
    
    if ( pgResult ) {
      switch ( PQresultStatus(pgResult) ) {
      
        case PGRES_TUPLES_OK:
        case PGRES_COMMAND_OK:
          rc = YES;
          break;
        
        default: {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            printf(":: %s\n", errorMsg);
            [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
          }
          break;
        }
        
      }
      PQclear(pgResult);
    }
    return rc;
  }

//

  - (BOOL) beginTransaction
  {
    PGresult*   pgResult = NULL;
    BOOL        rc = NO;
    
    if ( _checkpointIndex == 0 ) {
      pgResult = PQexec(_databaseConnection, "BEGIN");
    } else {
      char      query[24];
      
      snprintf(query, 24, "SAVEPOINT \"%08X\"", _checkpointIndex);
      pgResult = PQexec(_databaseConnection, query);
    }
    if ( pgResult ) {
      if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
        _checkpointIndex++;
        rc = YES;
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQresultErrorMessage(pgResult);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
      PQclear(pgResult);
    } else {
      // Push the last on-connection error onto the error stack:
      char*     errorMsg = PQerrorMessage(_databaseConnection);
      
      if ( errorMsg && *errorMsg ) {
        [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
      }
    }
    return rc;
  }
  
//

  - (BOOL) discardLastTransaction
  {
    BOOL        rc = NO;
    
    if ( _checkpointIndex > 0 ) {
      PGresult* pgResult = NULL;
      
      if ( _checkpointIndex == 1 ) {
        pgResult = PQexec(_databaseConnection, "ROLLBACK");
      } else {
        char      query[48];
        
        snprintf(query, 48, "ROLLBACK TO SAVEPOINT \"%08X\"", _checkpointIndex - 1);
        pgResult = PQexec(_databaseConnection, query);
      }
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex--;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) discardAllTransactions
  {
    BOOL        rc = NO;
    
    if ( _checkpointIndex > 0 ) {
      PGresult* pgResult = PQexec(_databaseConnection, "ROLLBACK");
      
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex = 0;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) commitLastTransaction
  {
    BOOL        rc = NO;
    
    if ( _checkpointIndex > 0 ) {
      PGresult* pgResult = NULL;
      
      if ( _checkpointIndex == 1 ) {
        pgResult = PQexec(_databaseConnection, "COMMIT");
      } else {
        char      query[48];
        
        snprintf(query, 48, "RELEASE SAVEPOINT \"%08X\"", _checkpointIndex - 1);
        pgResult = PQexec(_databaseConnection, query);
      }
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex--;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) commitAllTransactions
  {
    BOOL        rc = NO;
    
    if ( _checkpointIndex > 0 ) {
      PGresult* pgResult = PQexec(_databaseConnection, "COMMIT");
      
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex = 0;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack pushObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresDatabase(SBPostgresDatabaseNotification)

  - (int) notificationRunLoop
  {
    int     rc = 0;
    
    _flags.inNotifyRunLoop = YES;
    while ( _flags.inNotifyRunLoop ) {
      fd_set      socketMask;
      int         listenOnSocket = PQsocket(_databaseConnection);
      PGnotify    *notify;
      
      // Last chance to clear the pool!
      [SBObject emptyAutoreleasePool];
      
      //  Did we get a socket to listen on?
      if (listenOnSocket < 0) {
        rc = 1;
        break;
      }
      
      //  Listen for data:
      FD_ZERO(&socketMask);
      FD_SET(listenOnSocket, &socketMask);
      if ( select(listenOnSocket + 1, &socketMask, NULL, NULL, NULL) < 0 ) {
        rc = 2;
        break;
      }
       
      // Process all notifications that were waiting:
      PQconsumeInput(_databaseConnection);
      while ( (notify = PQnotifies(_databaseConnection)) ) {
        SBString*   pgNotify = [[SBString alloc] initWithUTF8String:notify->relname];
        
        [[SBNotificationCenter defaultNotificationCenter] postNotification:pgNotify];
        [pgNotify release];
        PQfreemem(notify);
      }
    }
  }
  
//

  - (void) exitFromNotificationRunLoop
  {
    _flags.inNotifyRunLoop = NO;
  }

//

  - (void) registerObject:(id)object
    forNotification:(SBString*)pgNotification
  {
    if ( _databaseConnection && pgNotification && [pgNotification length] ) {
      static const char*    registerQuery = "LISTEN \"";
      size_t                nLen = [pgNotification utf8Length];
      
      if ( nLen ) {
        char                query[ strlen(registerQuery) + nLen + 4 ];
        PGresult*           queryResult;
        
        //
        // Build the query string:
        //
        strcpy(query, registerQuery);
        [pgNotification copyUTF8CharactersToBuffer:query + strlen(registerQuery) length:nLen];
        strcat(query, "\";");
        
        //
        // Attempt the query:
        //
        queryResult = PQexec(_databaseConnection, query);
        if ( queryResult ) {
          if ( PQresultStatus(queryResult) == PGRES_COMMAND_OK ) {
            [[SBNotificationCenter defaultNotificationCenter] addListener:object
                selector:@selector(notificationFromDatabase:)
                forNotification:pgNotification
              ];
          }
          PQclear(queryResult);
        }
      }
    }
  }

//

  - (void) unregisterObject:(id)object
    forNotification:(SBString*)pgNotification
  {
    if ( pgNotification && [pgNotification length] ) {
      [[SBNotificationCenter defaultNotificationCenter] removeListener:object
          forNotification:pgNotification
        ];
    }
  }

@end

//
#pragma mark -
//

@implementation SBObject(SBPostgresDatabaseNotification)

  - (void) notificationFromDatabase:(SBNotification*)aNotify
  {
  }

@end

//
#pragma mark -
//

@implementation SBString(SBPostgresStringEscaping)

  - (SBString*) stringEscapedForPostgresDatabase:(SBPostgresDatabase*)aDatabase
  {
    SBString*     escString = nil;
    
    SBSTRING_AS_UTF8_BEGIN(self)
      size_t      bufferLen = [self utf8Length];
      char*       buffer = malloc(2 * bufferLen + 1);
      
      if ( buffer ) {
        int         error = 0;
        
        // self_utf8 is an array of UTF8 characters; 
        bufferLen = PQescapeStringConn(
                        [aDatabase databaseConnection],
                        buffer,
                        self_utf8,
                        bufferLen,
                        &error
                      );
        if ( ! error )
          escString = [SBString stringWithUTF8String:buffer];
        free(buffer);
      }
      
    SBSTRING_AS_UTF8_END
    
    return escString;
  }

//

  - (size_t) escapeForPostgresDatabase:(SBPostgresDatabase*)aDatabase
    inBuffer:(char*)buffer
    byteSize:(size_t)byteSize
  {
    size_t        actLen = 0;
    
    SBSTRING_AS_UTF8_BEGIN(self)
      int         error = 0;
      
      // self_utf8 is an array of UTF8 characters; 
      actLen = PQescapeStringConn(
                      [aDatabase databaseConnection],
                      buffer,
                      self_utf8,
                      byteSize,
                      &error
                    );    
    SBSTRING_AS_UTF8_END
    
    return actLen;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresQuery

  - (id) initWithQueryString:(SBString*)queryString
    parameterCount:(int)parameterCount
  {
    size_t              queryStringLen;
    
    if ( (queryString == nil) || ((queryStringLen = [queryString utf8Length]) == 0) || (parameterCount < 0) ) {
      [self release];
      return nil;
    }
    
    if ( self = [super init] ) {
      _parameterCount = parameterCount;
      
      //
      // It's quite possible a prepared query has NO parameters, so we setup a memory
      // pool and PQexecPrepared() arrays only when there _are_ parameters involved:
      //
      if ( parameterCount > 0 ) {
        if ( (_queryPool = SBMemoryPoolCreate(0)) ) {
          _queryString = (unsigned char*)malloc(++queryStringLen);
          if ( _queryString ) {
            [queryString copyUTF8CharactersToBuffer:_queryString length:queryStringLen];
            [self resetParameterBindings];
          } else {
            [self release];
            self = nil;
          }
        } else {
          [self release];
          self = nil;
        }
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _queryString ) free((void*)_queryString);
    if ( _queryPool ) SBMemoryPoolRelease(_queryPool);
    
    [super dealloc];
  }

//

  - (const char*) queryString { return _queryString; }
  - (int) parameterCount { return _parameterCount; }

//

  - (BOOL) resetParameterBindings
  {
    if ( _parameterCount > 0 ) {
      int     i;
      
      if ( _hasBeenPrepared ) {
        Oid     savedOid[_parameterCount];
        
        memcpy(savedOid, _paramOids, sizeof(Oid) * _parameterCount);
        SBMemoryPoolDrain(_queryPool);
        _paramOids    = (Oid*)SBMemoryPoolCalloc(_queryPool, sizeof(Oid) * _parameterCount);
        memcpy(_paramOids, savedOid, sizeof(Oid) * _parameterCount);
      } else {
        SBMemoryPoolDrain(_queryPool);
        _paramOids    = (Oid*)SBMemoryPoolCalloc(_queryPool, sizeof(Oid) * _parameterCount);
      }
      
      // Setup the PQexecPrepared() arrays:
      _paramValues  = (const char**)SBMemoryPoolCalloc(_queryPool, sizeof(char*) * _parameterCount);
      _paramLengths = (int*)SBMemoryPoolCalloc(_queryPool, sizeof(int) * _parameterCount);
      _paramFormats = (int*)SBMemoryPoolCalloc(_queryPool, sizeof(int) * _parameterCount);
      
      if ( ! (_paramOids && _paramValues && _paramLengths && _paramFormats) )
        return NO;
      
      // All parameters are binary:
      i = 0;
      while ( i < _parameterCount )
        _paramFormats[i++] = 1;
    }
    return YES;
  }
  
//

  - (BOOL) bindBoolValue:(BOOL)value toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != BOOLOID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, 1);
    if ( _paramValues[parameter] ) {
      _paramLengths[parameter]  = 1;
      _paramOids[parameter]     = BOOLOID;
      
      *((unsigned char*)_paramValues[parameter]) = ( value ? 1 : 0 );
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindInt2Value:(int16_t)value
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != INT2OID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(int16_t));
    if ( _paramValues[parameter] ) {
      _paramLengths[parameter]  = sizeof(int16_t);
      _paramOids[parameter]     = INT2OID;
      
      // It's on the stack, so no biggie if we byte-swap in situ:
      SBInSituByteSwapToNetwork(&value, sizeof(value));
      
      *((int16_t*)_paramValues[parameter]) = value;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindInt4Value:(int32_t)value
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != INT4OID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(int32_t));
    if ( _paramValues[parameter] ) {
      _paramLengths[parameter]  = sizeof(int32_t);
      _paramOids[parameter]     = INT4OID;
      
      // It's on the stack, so no biggie if we byte-swap in situ:
      SBInSituByteSwapToNetwork(&value, sizeof(value));
      
      *((int32_t*)_paramValues[parameter]) = value;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindInt8Value:(int64_t)value
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != INT8OID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(int64_t));
    if ( _paramValues[parameter] ) {
      uint32_t*           VALUE = (uint32_t*)_paramValues[parameter] ;
      
      _paramLengths[parameter]  = sizeof(int64_t);
      _paramOids[parameter]     = INT8OID;
      
      // It's on the stack, so no biggie if we byte-swap in situ:
      SBInSituByteSwapToNetwork(&value, sizeof(int64_t));
      
      *((int32_t*)_paramValues[parameter]) = value;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindFloatValue:(float)value
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != FLOAT4OID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(float));
    if ( _paramValues[parameter] ) {
      _paramLengths[parameter]  = sizeof(float);
      _paramOids[parameter]     = FLOAT4OID;
      
      // It's on the stack, so no biggie if we byte-swap in situ; note that
      // internally Postgres treats a 4-byte float like a 4-byte int for binary
      // transmission:
      SBInSituByteSwapToNetwork(&value, sizeof(value));
      
      *((float*)_paramValues[parameter]) = value;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindDoubleValue:(double)value
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != FLOAT8OID) )
      return NO;
    
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(double));
    if ( _paramValues[parameter] ) {
      uint32_t*           VALUE = (uint32_t*)_paramValues[parameter] ;
      
      _paramLengths[parameter]  = sizeof(double);
      _paramOids[parameter]     = FLOAT8OID;
      
      // It's on the stack, so no biggie if we byte-swap in situ; note that
      // internally Postgres treats an 8-byte float like a 8-byte int for binary
      // transmission:
      SBInSituByteSwapToNetwork(&value, sizeof(value));
      
      *((double*)_paramValues[parameter]) = value;
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindUTF8String:(const char*)string
    byteSize:(size_t)byteSize
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != TEXTOID) )
      return NO;
    
    if ( byteSize == 0 ) {
      byteSize = strlen(string);
    } else if ( string[byteSize - 1] == '\0' ) {
      // Postgres binary interface only wants the UTF8 characters SANS NUL!!
      byteSize--;
    }
      
    _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, byteSize);
    if ( _paramValues[parameter] ) {
      _paramLengths[parameter]  = byteSize;
      _paramOids[parameter]     = TEXTOID;
      
      memcpy((char*)_paramValues[parameter], string, byteSize);
      
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindUTF8StringNoCopy:(const char*)string
    byteSize:(size_t)byteSize
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    // Check if we've already been prepared:
    if ( _hasBeenPrepared && (_paramOids[parameter] != TEXTOID) )
      return NO;
    
    if ( byteSize == 0 ) {
      byteSize = strlen(string);
    } else if ( string[byteSize - 1] == '\0' ) {
      // Postgres binary interface only wants the UTF8 characters SANS NUL!!
      byteSize--;
    }
    
    _paramValues[parameter]     = string;
    _paramLengths[parameter]    = byteSize;
    _paramOids[parameter]       = TEXTOID;
      
    return YES;
  }
  
//

  - (BOOL) bindObject:(id)object
    toParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    if ( [object isKindOf:[SBNull class]] ) {
      return [self bindNULLToParameter:parameter + 1];
    }
    
    
    else if ( [object isKindOf:[SBMACAddress class]] ) {
      //
      // SBMACAddress
      //
    
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != MACADDROID) )
        return NO;
        
      _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, 6);
      if ( _paramValues[parameter] ) {
        _paramLengths[parameter]  = 6;
        _paramOids[parameter]     = MACADDROID;
        
        [(SBMACAddress*)object copyAddressBytes:(void*)_paramValues[parameter] length:6];
        return YES;
      }
    }
    
    
    else if ( [object isKindOf:[SBInetAddress class]] ) {
      //
      // SBInetAddress
      //
      char            family = -1;
      size_t          addrBytes = [(SBInetAddress*)object byteLength];
      size_t          bytes = 4 + addrBytes;
      
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != CIDROID) && (_paramOids[parameter] != INETOID) )
        return NO;
      
      switch ( [(SBInetAddress*)object addressFamily] ) {
        case kSBInetAddressIPv4Family:
          family = PGSQL_AF_INET;
          break;
        case kSBInetAddressIPv6Family:
          family = PGSQL_AF_INET6;
          break;
        default:
          return NO;
      }
      _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, bytes);
      if ( _paramValues[parameter] ) {
        uint8_t*      p = (uint8_t*)_paramValues[parameter];
        
        _paramLengths[parameter]  = bytes;
        _paramOids[parameter]     = ( [(SBInetAddress*)object prefixBitLength] != [(SBInetAddress*)object totalBitLength] ? CIDROID : INETOID );
        
        *p++ = family;
        *p++ = [(SBInetAddress*)object prefixBitLength];
        *p++ = ( _paramOids[parameter] == CIDROID );
        *p++ = addrBytes;
        
        [(SBInetAddress*)object copyMaskedAddressBytes:(void*)p length:addrBytes];
        return YES;
      }
    }
    
    
    else if ( [object isKindOf:[SBNumber class]] ) {
      //
      // SBNumber
      //
      const char*     nativeType = [(SBNumber*)object objCType];
      
      if ( strcmp(nativeType, @encode(unsigned int)) == 0 ) {
        return [self bindInt8Value:(int64_t)[(SBNumber*)object unsignedIntValue] toParameter:parameter + 1];
      }
      if ( strcmp(nativeType, @encode(int)) == 0 ) {
        return [self bindInt4Value:(int32_t)[(SBNumber*)object intValue] toParameter:parameter + 1];
      }
      if ( strcmp(nativeType, @encode(int64_t)) == 0 ) {
        return [self bindInt8Value:[(SBNumber*)object int64Value] toParameter:parameter + 1];
      }
      if ( strcmp(nativeType, @encode(double)) == 0 ) {
        return [self bindDoubleValue:[(SBNumber*)object doubleValue] toParameter:parameter + 1];
      }
      if ( strcmp(nativeType, @encode(BOOL)) == 0 ) {
        return [self bindBoolValue:[(SBNumber*)object boolValue] toParameter:parameter + 1];
      }
    }
    
    
    else if ( [object isKindOf:[SBData class]] ) {
      //
      // SBData
      //
      size_t          bytes = [(SBData*)object length];
    
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != BYTEAOID) )
        return NO;
      
      if ( bytes == 0 ) {
        _paramValues[parameter]   = NULL;
        _paramLengths[parameter]  = 0;
        _paramOids[parameter]     = BYTEAOID;
        
        return YES;
      } else {
        _paramValues[parameter]   = (char*)SBMemoryPoolCalloc(_queryPool, bytes);
        if ( _paramValues[parameter] ) {
          _paramLengths[parameter]= bytes;
          _paramOids[parameter]   = BYTEAOID;
          
          [(SBData*)object getBytes:(void*)_paramValues[parameter]];
          return YES;
        }
      }
    }
    
    
    else if ( [object isKindOf:[SBString class]] ) {
      //
      // SBString
      //
      size_t          lengthAsUTF8 = [(SBString*)object utf8Length];
    
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != TEXTOID) )
        return NO;
      
      if ( lengthAsUTF8 == 0 ) {
        _paramValues[parameter]   = NULL;
        _paramLengths[parameter]  = 0;
        _paramOids[parameter]     = TEXTOID;
        
        return YES;
      } else {
        _paramValues[parameter]   = (char*)SBMemoryPoolCalloc(_queryPool, lengthAsUTF8);
        if ( _paramValues[parameter] ) {
          _paramLengths[parameter]= lengthAsUTF8;
          _paramOids[parameter]   = TEXTOID;
          
          [(SBString*)object copyUTF8CharactersToBuffer:(unsigned char*)_paramValues[parameter] length:lengthAsUTF8];
          return YES;
        }
      }
    }
    
    
    else if ( [object isKindOf:[SBDate class]] ) {
      //
      // SBDate
      //
      // Sending a timestamp with time zone is acceptable for all these Postgres types:
      //
      //    - timestamp
      //    - timestamp with time zone
      //    - date
      //    - time
      //    - time with time zone
      //
      size_t          bytes;
    
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != TIMESTAMPTZOID) )
        return NO;
      
#if defined(HAVE_INT64_TIMESTAMP)
      bytes = sizeof(int64_t);
#else
      bytes = sizeof(double);
#endif
      _paramValues[parameter]     = (char*)SBMemoryPoolCalloc(_queryPool, bytes);
      if ( _paramValues[parameter] ) {
        time_t    unixTS = [(SBDate*)object unixTimestamp];
        
        _paramLengths[parameter]  = bytes;
        _paramOids[parameter]     = TIMESTAMPTZOID;
#if defined(HAVE_INT64_TIMESTAMP)
        *((int64_t*)_paramValues[parameter]) = (int64_t)unixTS - PostgresEpochShift;
        SBInSituByteSwapToNetwork((void*)_paramValues[parameter], sizeof(int64_t));
#else
        *((double*)_paramValues[parameter]) = (double)unixTS - PostgresEpochShift;
        SBInSituByteSwapToNetwork((void*)_paramValues[parameter], sizeof(double));
#endif
        return YES;
      }
    }
    
    return NO;
  }

//

  - (BOOL) bindNULLToParameter:(int)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    _paramValues[parameter]     = NULL;
    _paramLengths[parameter]    = 0;
    
    if ( ! _hasBeenPrepared )
      _paramOids[parameter]     = TEXTOID;
      
    return YES;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresQueryResult

  - (void) dealloc
  {
    if ( _queryResult ) PQclear(_queryResult);
    [super dealloc];
  }
  
//

  - (BOOL) queryWasSuccessful
  {
    if ( ! _flags.didCalcSuccess ) {
      _flags.wasSuccessful = NO;
      if ( _queryResult ) {
        switch ( PQresultStatus(_queryResult) ) {
        
          case PGRES_COMMAND_OK:
          case PGRES_TUPLES_OK:
            _flags.wasSuccessful = YES;
            break;
        
        }
      }
      _flags.didCalcSuccess = YES;
    }
    return ( _flags.wasSuccessful != 0 );
  }
  
//

  - (ExecStatusType) postgresResultStatus
  {
    if ( _queryResult )
      return PQresultStatus(_queryResult);
    return PGRES_FATAL_ERROR;
  }
  
//

  - (SBString*) queryErrorString
  {
    if ( _queryResult && ! [self queryWasSuccessful] ) {
      char*     errorStr = PQresultErrorMessage(_queryResult);
      
      if ( errorStr && *errorStr )
        return [SBString stringWithUTF8String:errorStr];
    }
    return nil;
  }
  
//

  - (int) numberOfRows
  {
    if ( [self queryWasSuccessful] ) {
      return PQntuples(_queryResult);
    }
    return -1;
  }
  
//

  - (int) numberOfFields
  {
    if ( [self queryWasSuccessful] ) {
      return PQnfields(_queryResult);
    }
    return -1;
  }
  
//

  - (SBString*) fieldNameWithNumber:(int)fieldNum
  {
    SBString*   result = nil;
    
    if ( [self queryWasSuccessful] && PQnfields(_queryResult) ) {
      char*     fieldStr = PQfname(_queryResult, fieldNum);
      
      if ( fieldStr && *fieldStr )
        result = [SBString stringWithUTF8String:fieldStr];
    }
    return result;
  }
  
//

  - (int) fieldNumberWithName:(SBString*)fieldName
  {
    int     result = -1;
    
    if ( [self queryWasSuccessful] && PQnfields(_queryResult) ) {
      SBSTRING_AS_UTF8_BEGIN(fieldName)
      
        result = PQfnumber(_queryResult, fieldName_utf8);
      
      SBSTRING_AS_UTF8_END
    }
    return result;
  }

//

  - (BOOL) postgresType:(Oid*)typeOid
    forFieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] ) {
      Oid     tmpOid = PQftype(_queryResult, fieldNum);
      
      if ( tmpOid > 0 ) {
        *typeOid = tmpOid;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) postgresTypeModifier:(int*)typeMod
    forFieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] ) {
      int     tmpMod = PQfmod(_queryResult, fieldNum);
      
      if ( tmpMod >= 0 ) {
        *typeMod = tmpMod;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) postgresStorageSize:(size_t*)storageSize
    forFieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] ) {
      size_t    tmpSize = (size_t)PQfsize(_queryResult, fieldNum);
      
      if ( tmpSize >= 0 ) {
        *storageSize = tmpSize;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) isNullValueAtRow:(int)row
    fieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      if ( PQgetisnull(_queryResult, row, fieldNum) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) sizeOfValue:(size_t*)byteSize
    atRow:(int)row
    fieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      *byteSize = (size_t)PQgetlength(_queryResult, row, fieldNum);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) getValuePointer:(void**)valuePtr
    atRow:(int)row
    fieldNum:(int)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      *valuePtr = (void*)PQgetvalue(_queryResult, row, fieldNum);
      return YES;
    }
    return NO;
  }
  
//

  - (size_t) copyValueAtRow:(int)row
    fieldNum:(int)fieldNum
    toBuffer:(void*)buffer
    length:(size_t)length
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      void*       src = (void*)PQgetvalue(_queryResult, row, fieldNum);
      size_t      srcLen = (size_t)PQgetlength(_queryResult, row, fieldNum);
      
      if ( src && buffer && length ) {
        memcpy(buffer, src, length = ( srcLen > length ? length : srcLen ));
        return length;
      }
    }
    return 0;
  }
  
//

  - (BOOL) getOidOfInsertedRow:(Oid*)anOid
  {
    if ( _queryResult && (PQresultStatus(_queryResult) == PGRES_COMMAND_OK) ) {
      Oid         tmpOid = PQoidValue(_queryResult);
      
      if ( tmpOid != InvalidOid ) {
        *anOid = tmpOid;
        return YES;
      }
    }
    return NO;
  }

//

  - (Class) classForFieldNum:(int)fieldNum
  {
    Oid       pgType = InvalidOid;
    
    if ( [self postgresType:&pgType forFieldNum:fieldNum] ) {
      switch ( pgType ) {
        
        case BOOLOID:
        case INT2OID:
        case INT4OID:
        case INT8OID:
        case FLOAT4OID:
        case FLOAT8OID:
          return [SBNumber class];
        
        case CHAROID:
        case BPCHAROID:
        case VARCHAROID:
          return [SBString class];
        
        case DATEOID:
        case TIMEOID:
        case TIMETZOID:
        case TIMESTAMPOID:
        case TIMESTAMPTZOID:
        case INTERVALOID:
          return [SBDate class];
        
        case MACADDROID:
          return [SBMACAddress class];
        
        case INETOID:
        case CIDROID:
          return [SBInetAddress class];
        
        case BYTEAOID:
        default:
          return [SBData class];
        
      }
    }
    return Nil;
  }

//

  - (id) objectForRow:(int)row
    fieldNum:(int)fieldNum
  {
    id        rowColObj = nil;
    Oid       pgType = InvalidOid;
    
    if ( [self isNullValueAtRow:row fieldNum:fieldNum] )
      return [SBNull null];
    
    if ( [self postgresType:&pgType forFieldNum:fieldNum] ) {
    
      switch ( pgType ) {
        
        case BOOLOID: {
          char*     value = PQgetvalue(_queryResult, row, fieldNum);
          
          rowColObj = [SBNumber numberWithBool:( *value != 0 )];
          break;
        }
        
        case INT2OID: {
          int16_t*  valuePtr = (int16_t*)PQgetvalue(_queryResult, row, fieldNum);
          int16_t   value;
          
          SBByteSwapFromNetwork(valuePtr, sizeof(int16_t), &value);
          return [SBNumber numberWithInt:(int)value];
        }
        
        case INT4OID: {
          int*      valuePtr = (int*)PQgetvalue(_queryResult, row, fieldNum);
          int       value;
          
          SBByteSwapFromNetwork(valuePtr, sizeof(int), &value);
          return [SBNumber numberWithInt:value];
        }
        
        case INT8OID: {
          int64_t*  valuePtr = (int64_t*)PQgetvalue(_queryResult, row, fieldNum);
          int64_t   value;
          
          SBByteSwapFromNetwork(valuePtr, sizeof(int64_t), &value);
          return [SBNumber numberWithInt64:value];
        }
        
        case FLOAT4OID: {
          float*    valuePtr = (float*)PQgetvalue(_queryResult, row, fieldNum);
          float     value;
          
          SBByteSwapFromNetwork(valuePtr, sizeof(float), &value);
          return [SBNumber numberWithDouble:(double)value];
        }
        
        case FLOAT8OID: {
          double*   valuePtr = (double*)PQgetvalue(_queryResult, row, fieldNum);
          double    value;
          
          SBByteSwapFromNetwork(valuePtr, sizeof(double), &value);
          return [SBNumber numberWithDouble:value];
        }
        
        case CHAROID:
        case BPCHAROID:
        case VARCHAROID: {
          char*     value = PQgetvalue(_queryResult, row, fieldNum);
          int       maxLen = PQfmod(_queryResult, fieldNum);
          int       actLen = PQgetlength(_queryResult, row, fieldNum);
          
          if ( pgType == CHAROID ) {
            char*     s = value + actLen;
            
            /* Trim any pad characters from the end: */
            while ( (s-- > value) && (*s == ' ') );
            actLen = s - value;
          }
          rowColObj = [SBString stringWithUTF8String:value length:actLen];
          break;
        }
        
        case DATEOID:
        case TIMEOID:
        case TIMETZOID:
        case TIMESTAMPOID:
        case TIMESTAMPTZOID:
        case INTERVALOID: {
          break;
        }
        
        case MACADDROID: {
          unsigned char*  valuePtr = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          
          rowColObj = [SBMACAddress macAddressWithBytes:valuePtr];
          break;
        }
        
        case INETOID: {
          unsigned char*  valuePtr = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          
          switch ( *valuePtr ) {
            
            case PGSQL_AF_INET:
              rowColObj = [SBInetAddress inetAddressWithIPv4Bytes:valuePtr + 4];
              break;
            
            case PGSQL_AF_INET6:
              rowColObj = [SBInetAddress inetAddressWithIPv6Bytes:valuePtr + 4];
              break;
            
          }
          break;
        }
        
        case CIDROID: {
          unsigned char*  valuePtr = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          
          switch ( *valuePtr ) {
            
            case PGSQL_AF_INET:
              rowColObj = [SBInetAddress inetAddressWithIPv4Bytes:valuePtr + 4 prefixLength:(unsigned int)valuePtr[1]];
              break;
            
            case PGSQL_AF_INET6:
              rowColObj = [SBInetAddress inetAddressWithIPv6Bytes:valuePtr + 4 prefixLength:(unsigned int)valuePtr[1]];
              break;
            
          }
          break;
        }
        
        case BYTEAOID:
        default: {
          char*     value = PQgetvalue(_queryResult, row, fieldNum);
          int       maxLen = PQfmod(_queryResult, fieldNum);
          int       actLen = PQgetlength(_queryResult, row, fieldNum);
          
          rowColObj = [SBData dataWithBytes:value length:actLen];
          break;
        }
        
      }
    }
    return rowColObj;
  }

@end

//
#pragma mark -
//

@implementation SBDate(SBPostgresDateAdditions)

  + (SBDate*) dateWithPostgresTimestamp:(int64_t)pgTimestamp
  {
    // Convert the Postgres timestamp to a UNIX timestamp:
    time_t    unixTimestamp = pgTimestamp + (int64_t)PostgresEpochShift;
    
    return [SBDate dateWithUnixTimestamp:unixTimestamp];
  }
  
//

  - (int64_t) postgresTimestamp
  {
    return ( ((int64_t)[self unixTimestamp]) - (int64_t)PostgresEpochShift );
  }

@end
