//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBPostgres.h
//
// Access to a Postgres database.
//
// $Id$
//

#import "SBPostgres.h"
#import "SBNotification.h"
#import "SBArray.h"
#import "SBDictionary.h"
#import "SBData.h"
#import "SBValue.h"
#import "SBCalendar.h"
#import "SBInetAddress.h"
#import "SBMACAddress.h"
#import "SBUUID.h"
#import "SBNotorization.h"
#import "SBAutoreleasePool.h"
#import "SBException.h"
#import "SBRunLoop.h"
#import "SBRunLoopPrivate.h"
#import "SBStream.h"
#import "SBStreamPrivate.h"

#import "SBPostgresAdditions.h"
#include "SBPostgresPrivate.h"

typedef struct {
#if defined(HAVE_INT64_TIMESTAMP)
  int64_t       time;
#else
  double        time;
#endif
  int           tz;
} SBPGTimeWithTimeZone;

typedef struct {
#if defined(HAVE_INT64_TIMESTAMP)
  int64_t       seconds;
#else
  double        seconds;
#endif
  int32_t       days;
  int32_t       months;
} SBPGBinaryInterval;

void
SBPostgresJulianDay2DateComponents(
  int               julianDay,
  SBDateComponents* components
)
{
	unsigned int julian;
	unsigned int quad;
	unsigned int extra;
  int          y;
  
	julian = julianDay + POSTGRES_EPOCH_JDATE;
	julian += 32044;
	quad = julian / 146097;
	extra = (julian - quad * 146097) * 4 + 3;
	julian += 60 + quad * 3 + extra / 146097;
	quad = julian / 1461;
	julian -= quad * 1461;
	y = julian * 4 / 1461;
	julian = ((y != 0) ? ((julian + 305) % 365) : ((julian + 306) % 366))
		+ 123;
	y += quad * 4;
  [components setYear:(y - 4800)];
	quad = julian * 2141 / 65536;
  [components setDay:(julian - 7834 * quad / 256)];
  [components setMonth:((quad + 10) % 12)];
}

int
SBPostgresDateComponents2JulianDay(
  SBDateComponents* components
)
{
	int			julian;
	int			century;
  int     y = [components year];
  int     m = [components month] + 1;
  int     d = [components day];
  
	if (m > 2)
	{
		m += 1;
		y += 4800;
	}
	else
	{
		m += 13;
		y += 4799;
	}

	century = y / 100;
	julian = y * 365 - 32167;
	julian += y / 4 - century + century / 4;
	julian += 7834 * m / 256 + d;

	return julian;
}

void
SBPostgresTime2DateComponents(
#ifdef HAVE_INT64_TIMESTAMP
  int64_t           aTime,
#else
  double            aTime,
#endif
  SBDateComponents* components
)
{
#ifdef HAVE_INT64_TIMESTAMP
  unsigned int      tmp;
	
  tmp = aTime / USECS_PER_HOUR;
  aTime -= tmp * USECS_PER_HOUR;
  [components setHour:tmp];
  
  tmp = aTime / USECS_PER_MINUTE;
  aTime -= tmp * USECS_PER_MINUTE;
  [components setMinute:tmp];
  
  tmp = aTime / USECS_PER_SEC;
  aTime -= tmp * USECS_PER_SEC;
  [components setSecond:tmp];
#else
	double		trem;
  int       hour, min, sec;

recalc:
	trem = aTime;
	TMODULO(trem, hour, (double) 3600);
	TMODULO(trem, min, (double) 60);
	TMODULO(trem, sec, 1.0);
	trem = TIMEROUND(trem);
	/* roundoff may need to propagate to higher-order fields */
	if (trem >= 1.0)
	{
		aTime = ceil(aTime);
		goto recalc;
	}
  [components setHour:hour];
  [components setMinute:min];
  [components setSecond:sec];
#endif
}

void
SBPostgresTimeTZ2DateComponents(
  SBPGTimeWithTimeZone*   timetz,
  SBDateComponents*       components
)
{
  SBPostgresTime2DateComponents(timetz->time, components);
  [components setTimeZoneOffset:(timetz->tz * -1000)];
}

#define PGSQL_AF_INET      (AF_INET + 0)
#define PGSQL_AF_INET6     (AF_INET + 1)

@interface SBPostgresQuery(SBPostgresQueryPrivate)

- (Class*) paramClasses;
- (Oid*) paramOids;
- (const char**) paramValues;
- (int*) paramLengths;
- (int*) paramFormats;

- (void) setHasBeenPrepared:(BOOL)hasBeenPrepared;

@end

@implementation SBPostgresQuery(SBPostgresQueryPrivate)

  - (Class*) paramClasses { return _paramClasses; }
  - (Oid*) paramOids { return _paramOids; }
  - (const char**) paramValues { return _paramValues; }
  - (int*) paramLengths { return _paramLengths; }
  - (int*) paramFormats { return _paramFormats; }
  - (void) setHasBeenPrepared:(BOOL)hasBeenPrepared { if ( hasBeenPrepared ) _hasBeenPrepared = YES; }

@end

//
#pragma mark -
//

static SBString* SBPostgresPreparedQueryUnprepare = @"SBPostgres::unprepare";
static SBString* SBPostgresPreparedQueryReference = @"SBPostgres::queryReference";

//
#pragma mark -
//

@interface SBPostgresQueryResult(SBPostgresQueryResultPrivate)

- (id) initWithDatabase:(SBPostgresDatabase*)database queryResult:(PGresult*)pgResult;

- (BOOL) setupFieldNamesArray;

@end

@implementation SBPostgresQueryResult(SBPostgresQueryResultPrivate)

  - (id) initWithDatabase:(SBPostgresDatabase*)database
    queryResult:(PGresult*)pgResult
  {
    if ( self = [super init] ) {
      _parentDatabase = [database retain];
      _queryResult = pgResult;
    }
    return self;
  }

//

  - (BOOL) setupFieldNamesArray
  {
    if ( ! _fieldNames ) {
      int       cols = PQnfields(_queryResult);
      
      if ( cols > 0 ) {
        SBString*   names[cols];
        int         i = cols;
        
        while ( i-- )
          names[i] = [[SBString alloc] initWithUTF8String:PQfname(_queryResult, i)];
        
        _fieldNames = [[SBArray arrayWithObjects:names count:cols] retain];
        
        while ( cols-- )
          [names[cols] release];
      }
    }
    return ( _fieldNames != nil );
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

- (void) preparedQueryWasUnprepared:(SBNotification*)aNotify;

- (void) processPGNotifications;

@end

@implementation SBPostgresDatabase(SBPostgresDatabasePrivate)

  - (BOOL) setPostgresClientProperties
  {
    BOOL      rc = NO;
    
    if ( _flags.connectionOpen ) {
      PGresult*         queryResult = PQexec(_databaseConnection, "SET CLIENT_ENCODING TO 'UTF8'");
      
      if ( queryResult ) {
        char*     errorMsg = PQresultErrorMessage(queryResult);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
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
    
    if ( _flags.connectionOpen ) {
      SBMutableString*  command = nil;
      PGresult*         queryResult = NULL;
      
      if ( _searchSchema ) {
        unsigned int      i = 0, iMax = [_searchSchema count];
        
        if ( iMax > 0 ) {
          command = [[SBMutableString alloc] initWithUTF8String:"SET search_path TO "];
          [command appendString:[_searchSchema componentsJoinedByString:@":"]];
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
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
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
    PGresult*     prepResult;
    Oid*          paramOids = [aQuery paramOids];
    Class*        paramClasses = [aQuery paramClasses];
    unsigned int  i = 0, iMax = [aQuery parameterCount];
    
    // Check for any Oid subs:
    while ( i < iMax ) {
      if ( paramClasses[i] == [SBNotorization class] )
        paramOids[i] = [self typeOidForTypeName:@"notorization"];
      i++;
    }
    prepResult = PQprepare(
                      _databaseConnection,
                      statementName,
                      [aQuery queryString],
                      iMax,
                      paramOids
                    );
    if ( prepResult ) {
      result = ( PQresultStatus(prepResult) == PGRES_COMMAND_OK );
      PQclear(prepResult);
    }
    return result;
  }

//

  - (void) preparedQueryWasUnprepared:(SBNotification*)aNotify
  {
    id              preparedQuery = [[aNotify userInfo] objectForKey:SBPostgresPreparedQueryReference];
    unsigned int    index = [_preparedQueries indexOfObjectIdenticalTo:preparedQuery];
    
    if ( index != SBNotFound ) {
      [_preparedQueries replaceObject:[SBNull null] atIndex:index];
    }
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
        Oid*          paramOids = [aQuery paramOids];
        Class*        paramClasses = [aQuery paramClasses];
        unsigned int  i = 0, iMax = [aQuery parameterCount];
        
        // Check for any Oid subs:
        while ( i < iMax ) {
          if ( paramClasses[i] == [SBNotorization class] )
            paramOids[i] = [self typeOidForTypeName:@"notorization"];
          i++;
        }
        pgResult = PQexecParams(
                        _databaseConnection,
                        [aQuery queryString],
                        iMax,
                        paramOids,
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
        pgResult = PQexecParams(
                        _databaseConnection,
                        queryAsUTF8,
                        0,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        1
                      );
      }
    }
    if ( ! pgResult ) {
      // Push the last on-connection error onto the error stack:
      char*     errorMsg = PQerrorMessage(_databaseConnection);
      
      if ( errorMsg && *errorMsg ) {
        fprintf(stderr, ":: %s\n", errorMsg);
        [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
      }
    }
    return pgResult;
  }
  
//

  - (void) processPGNotifications
  {
    PGnotify*         notify;
    
    PQconsumeInput(_databaseConnection);
    while ( (notify = PQnotifies(_databaseConnection)) ) {
      SBString        *pgNotify = [[SBString alloc] initWithUTF8String:notify->relname];
      SBDictionary    *userInfo = nil;
      
      if ( notify->extra ) {
        SBString      *pgExtra = [[SBString alloc] initWithUTF8String:notify->extra];
        
        if ( pgExtra ) {
          userInfo = [SBDictionary dictionaryWithObject:pgExtra forKey:SBPostgresNotifierPayloadStringKey];
          [pgExtra release];
        } else {
          [pgNotify release];
          pgNotify = nil;
        }
      }
      if ( pgNotify ) {
        [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:pgNotify object:self userInfo:userInfo];
        [pgNotify release];
      }
      PQfreemem(notify);
    }
  }
  
@end

//

SBString *SBPostgresNotifierPayloadStringKey = @"postgresNotificationPayload";

//
#pragma mark -
//

@interface SBPostgresNotifier : SBObject<SBFileDescriptorStream>
{
  SBPostgresDatabase*     _parentDatabase;
}

- (id) initWithParentDatabase:(SBPostgresDatabase*)parentDatabase;

@end

@implementation SBPostgresNotifier

  - (id) initWithParentDatabase:(SBPostgresDatabase*)parentDatabase
  {
    if ( (self = [super init]) )
      _parentDatabase = parentDatabase;
    return self;
  }

//

  - (id) initWithFileDescriptor:(int)fd
    closeWhenDone:(BOOL)closeWhenDone
  {
    return [super init];
  }
  
//

  - (unsigned int) flagsForStream
  {
    return 0;
  }
  
//

  - (int) fileDescriptorForStream
  {
    PGconn*     connection = [_parentDatabase databaseConnection];
    
    if ( connection )
      return PQsocket(connection);
    return -1;
  }

//

  - (void) fileDescriptorReady
  {
    [_parentDatabase processPGNotifications];
  }
  
//

  - (void) fileDescriptorHasError:(int)errno
  {
  }

@end

//
#pragma mark -
//

@implementation SBPostgresDatabase

  + (BOOL) accessInstanceVariablesDirectly
  {
    return NO;
  }

//

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
      _errorMessageStack = [[SBMutableArray alloc] init];
      
      if ( [self reconnectWithRetryCount:0] ) {
        _searchSchema = ( searchSchema ? [[SBMutableArray alloc] initWithArray:searchSchema] : [[SBMutableArray alloc] init] );
        [self setPostgresSchemaSearchPath];
      }
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    [[SBNotificationCenter defaultNotificationCenter] removeObserver:self];
    
    if ( _connectionString ) [_connectionString release];
    if ( _databaseConnection ) PQfinish(_databaseConnection);
    if ( _searchSchema ) [_searchSchema release];
    if ( _preparedQueries ) [_preparedQueries release];
    if ( _typeOids ) [_typeOids release];
    if ( _errorMessageStack ) [_errorMessageStack release];
    
    [super dealloc];
  }
  
//

  - (BOOL) isConnectionOpen
  {
    return _flags.connectionOpen;
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
  - (BOOL) reconnectWithRetryCount:(SBUInteger)retryCount
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
        retryCount++;
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
              if ( ! retryCount )
                [_errorMessageStack addObject:[SBString stringWithUTF8String:PQerrorMessage(_databaseConnection)]];
              PQfinish(_databaseConnection);
              _databaseConnection = NULL;
            }
            if ( retryCount )
              sleep(5);
          } else {
            break;
          }
        }
      
      SBSTRING_AS_UTF8_END
    }
    return rc;
  }
  
//

#if PG_VERSION_NUM >= 90200
  - (BOOL) ping
  {
    BOOL      rc = NO;
    
    if ( _connectionString ) {
      SBSTRING_AS_UTF8_BEGIN(_connectionString)
      
      switch ( PQping((const char*)_connectionString_utf8) ) {
        case PQPING_OK:
          rc = YES;
          break;
          
        case PQPING_REJECT:
        case PQPING_NO_RESPONSE:
        case PQPING_NO_ATTEMPT:
          rc = NO;
          break;
      }
      
      SBSTRING_AS_UTF8_END
    }
    return rc;
  }
#endif

//

  - (SBArray*) searchSchema
  {
    if ( _searchSchema && [_searchSchema count] )
      return (SBArray*)_searchSchema;
    return nil;
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

  - (Oid) typeOidForTypeName:(SBString*)typeName
  {
    if ( _typeOids ) {
      SBNumber*     oidVal = [_typeOids objectForKey:typeName];
      
      if ( oidVal )
        return [oidVal intValue];
    }
    
    Oid             resultOid = -1;
    
    // Perform the lookup:
    SBString*       queryStr = [[SBString alloc] initWithFormat:
                                    "SELECT typelem FROM pg_type WHERE typname LIKE '%%%s%%' AND typelem > 0",
                                    [typeName utf8Characters]
                                  ];
    if ( queryStr ) {
      SBPostgresQueryResult*    queryResult = [self executeQuery:queryStr];
      
      if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
        SBNumber*   oidNum = [queryResult objectForRow:0 fieldNum:0];
        
        if ( oidNum && [oidNum isKindOf:[SBNumber class]] && (resultOid = [oidNum intValue]) ) {
          if ( _typeOids == nil ) {
            _typeOids = [[SBMutableDictionary alloc] initWithObjectsAndKeys:oidNum, typeName, nil];
          } else {
            [_typeOids setObject:oidNum forKey:typeName];
          }
        } else {
          resultOid = -1;
        }
      }
      [queryStr release];
    }
    return resultOid;
  }
//

  - (unsigned int) errorMessageCount
  {
    return [_errorMessageStack count];
  }
  
//

  - (SBString*) lastErrorMessage
  {
    SBString*     lastError = nil;
    
    if ( [_errorMessageStack count] ) {
      lastError = [[[_errorMessageStack lastObject] retain] autorelease];
      [_errorMessageStack removeLastObject];
    }
    return lastError;
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
    if ( _flags.connectionOpen ) {
      if ( ! _preparedQueries ) {
        _preparedQueries = [[SBMutableArray alloc] init];
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
          [[SBNotificationCenter defaultNotificationCenter] addObserver:self selector:@selector(preparedQueryWasUnprepared:) identifier:SBPostgresPreparedQueryUnprepare object:nil];
          return YES;
        }
      }
    }
    return NO;
  }
  
//

  - (id) executeQuery:(id)aQuery
  {
    SBPostgresQueryResult*    queryResult = nil;
    if ( _flags.connectionOpen ) {
      PGresult*                 pgResult = [self baseExecuteQuery:aQuery];
      
      if ( pgResult )
        queryResult = [[[SBPostgresQueryResult alloc] initWithDatabase:self queryResult:pgResult] autorelease];
    }
    return queryResult;
  }

//

  - (BOOL) executeQueryWithBooleanResult:(id)aQuery
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen ) {
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
              [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
            }
            break;
          }
          
        }
        PQclear(pgResult);
      }
    }
    return rc;
  }

//

  - (BOOL) beginTransaction
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen ) {
      PGresult*   pgResult = NULL;
      
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
            [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) discardLastTransaction
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen && (_checkpointIndex > 0) ) {
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
            [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) discardAllTransactions
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen && (_checkpointIndex > 0) ) {
      PGresult* pgResult = PQexec(_databaseConnection, "ROLLBACK");
      
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex = 0;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) commitLastTransaction
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen && (_checkpointIndex > 0) ) {
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
            [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }
  
//

  - (BOOL) commitAllTransactions
  {
    BOOL        rc = NO;
    
    if ( _flags.connectionOpen && (_checkpointIndex > 0) ) {
      PGresult* pgResult = PQexec(_databaseConnection, "COMMIT");
      
      if ( pgResult ) {
        if ( PQresultStatus(pgResult) == PGRES_COMMAND_OK ) {
          _checkpointIndex = 0;
          rc = YES;
        } else {
          // Push the last on-connection error onto the error stack:
          char*     errorMsg = PQresultErrorMessage(pgResult);
          
          if ( errorMsg && *errorMsg ) {
            [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
          }
        }
        PQclear(pgResult);
      } else {
        // Push the last on-connection error onto the error stack:
        char*     errorMsg = PQerrorMessage(_databaseConnection);
        
        if ( errorMsg && *errorMsg ) {
          [_errorMessageStack addObject:[SBString stringWithUTF8String:errorMsg]];
        }
      }
    }
    return rc;
  }

//

  - (SBString*) stringEscapedForQuery:(SBString*)aString
  {
    SBString*     escString = nil;
    
    SBSTRING_AS_UTF8_BEGIN(aString)
      size_t      bufferLen = [aString utf8Length];
      char*       buffer = objc_malloc(2 * bufferLen + 1);
      
      if ( buffer ) {
        int         error = 0;
        
        // self_utf8 is an array of UTF8 characters; 
        bufferLen = PQescapeStringConn(
                        _databaseConnection,
                        buffer,
                        aString_utf8,
                        bufferLen,
                        &error
                      );
        if ( ! error )
          escString = [SBString stringWithUTF8String:buffer];
        objc_free(buffer);
      }
      
    SBSTRING_AS_UTF8_END
    
    return escString;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresDatabase(SBPostgresDatabaseNotification)

  - (int) notificationRunLoop
  {
    int     rc = 0;
    
    if ( _flags.connectionOpen ) {
      _flags.inNotifyRunLoop = YES;
      while ( _flags.inNotifyRunLoop ) {
        fd_set      socketMask;
        int         listenOnSocket = PQsocket(_databaseConnection);
        
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
         
        //
        // Process all notifications that were waiting.  We use our own autorelease
        // pool and drain before looping again:
        //
        SBAutoreleasePool*      dbPool = [[SBAutoreleasePool alloc] init];
        
        [self processPGNotifications];
        
        // Drain the pool:
        [dbPool release];
      }
    }
    return rc;
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
    if ( _flags.connectionOpen && pgNotification && [pgNotification length] ) {
      SBString*             registerQuery = [SBString stringWithFormat:"LISTEN \"%s\"", [pgNotification utf8Characters]];
      
      if ( registerQuery ) {
        PGresult*           queryResult;
        
        //
        // Attempt the query:
        //
        queryResult = PQexec(_databaseConnection, [registerQuery utf8Characters]);
        if ( queryResult ) {
          if ( PQresultStatus(queryResult) == PGRES_COMMAND_OK ) {
            [[SBNotificationCenter defaultNotificationCenter] addObserver:object
                selector:@selector(notificationFromDatabase:)
                identifier:pgNotification
                object:self
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
      [[SBNotificationCenter defaultNotificationCenter] removeObserver:object
          identifier:pgNotification
          object:self
        ];
    }
  }

//

  - (void) scheduleNotificationInRunLoop:(SBRunLoop*)aRunLoop
  {
    if ( ! _runloopNotifier ) {
      if ( (_runloopNotifier = [[SBPostgresNotifier alloc] initWithParentDatabase:self]) )
        [aRunLoop addInputSource:_runloopNotifier forMode:SBRunLoopDefaultMode];
    }
  }
  
//

  - (void) removeNotificationFromRunLoop:(SBRunLoop*)aRunLoop
  {
    if ( _runloopNotifier ) {
      [aRunLoop removeInputSource:_runloopNotifier forMode:SBRunLoopDefaultMode];
      [_runloopNotifier release];
      _runloopNotifier = nil;
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
      char*       buffer = objc_malloc(2 * bufferLen + 1);
      
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
        objc_free(buffer);
      }
      
    SBSTRING_AS_UTF8_END
    
    return escString;
  }

//

  - (SBUInteger) escapeForPostgresDatabase:(SBPostgresDatabase*)aDatabase
    inBuffer:(void*)buffer
    byteSize:(SBUInteger)byteSize
  {
    SBUInteger    actLen = 0;
    
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

  + (BOOL) accessInstanceVariablesDirectly
  {
    return NO;
  }

//

  - (id) initWithQueryString:(SBString*)queryString
    parameterCount:(SBUInteger)parameterCount
  {
    SBUInteger         queryStringLen;
    
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
      if ( parameterCount >= 0 ) {
        if ( (_queryPool = SBMemoryPoolCreate(0)) ) {
          _queryString = (unsigned char*)objc_calloc(1, ++queryStringLen);
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
    if ( _queryString ) objc_free((void*)_queryString);
    if ( _queryPool ) SBMemoryPoolRelease(_queryPool);
    
    [super dealloc];
  }

//

  - (const char*) queryString { return _queryString; }
  - (SBUInteger) parameterCount { return _parameterCount; }

//

  - (void) unprepareInAllDatabases
  {
    // Broadcast a destruction message:
    [[SBNotificationCenter defaultNotificationCenter] postNotificationWithIdentifier:SBPostgresPreparedQueryUnprepare
          object:self
          userInfo:[SBDictionary dictionaryWithObject:self forKey:SBPostgresPreparedQueryReference]
        ];
  }

//

  - (BOOL) resetParameterBindings
  {
    if ( _parameterCount > 0 ) {
      SBUInteger    i;
      
      if ( _hasBeenPrepared ) {
        Oid     savedOid[_parameterCount];
        Class   savedClasses[_parameterCount];
        
        memcpy(savedOid, _paramOids, sizeof(Oid) * _parameterCount);
        memcpy(savedClasses, _paramClasses, sizeof(Class) * _parameterCount);
        
        SBMemoryPoolDrain(_queryPool);
        
        _paramClasses = (Class*)SBMemoryPoolCalloc(_queryPool, sizeof(Class) * _parameterCount);
        _paramOids    = (Oid*)SBMemoryPoolCalloc(_queryPool, sizeof(Oid) * _parameterCount);
        
        memcpy(_paramClasses, savedClasses, sizeof(Class) * _parameterCount);
        memcpy(_paramOids, savedOid, sizeof(Oid) * _parameterCount);
      } else {
        SBMemoryPoolDrain(_queryPool);
        _paramClasses = (Class*)SBMemoryPoolCalloc(_queryPool, sizeof(Class) * _parameterCount);
        _paramOids    = (Oid*)SBMemoryPoolCalloc(_queryPool, sizeof(Oid) * _parameterCount);
      }
      
      // Setup the PQexecPrepared() arrays:
      _paramValues  = (const char**)SBMemoryPoolCalloc(_queryPool, sizeof(char*) * _parameterCount);
      _paramLengths = (int*)SBMemoryPoolCalloc(_queryPool, sizeof(int) * _parameterCount);
      _paramFormats = (int*)SBMemoryPoolCalloc(_queryPool, sizeof(int) * _parameterCount);
      
      if ( ! (_paramClasses && _paramOids && _paramValues && _paramLengths && _paramFormats) )
        return NO;
      
      // All parameters are binary:
      i = 0;
      while ( i < _parameterCount )
        _paramFormats[i++] = 1;
    }
    return YES;
  }
  
//

  - (BOOL) bindBoolValue:(BOOL)value toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
      
      memcpy((void*)_paramValues[parameter], &value, sizeof(value));
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) bindUTF8String:(const char*)string
    byteSize:(size_t)byteSize
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
    toParameter:(SBUInteger)parameter
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
          
          [(SBData*)object getBytes:(void*)_paramValues[parameter] length:bytes];
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
    
    
    else if ( [object isKindOf:[SBUUID class]] ) {
      //
      // SBUUID
      //
      
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != UUIDOID) )
        return NO;
      
      _paramValues[parameter]     = (char*)SBMemoryPoolAlloc(_queryPool, 16);
      if ( _paramValues[parameter] ) {
        [(SBUUID*)object getUUIDBytes:(void*)_paramValues[parameter]];
        _paramLengths[parameter]  = 16;
        _paramOids[parameter]     = UUIDOID;
      }
    }
    
    
    else if ( [object isKindOf:[SBTimeInterval class]] ) {
      SBPGBinaryInterval*     pgInterval;
    
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramOids[parameter] != INTERVALOID) )
        return NO;
        
      pgInterval = (SBPGBinaryInterval*)(_paramValues[parameter] = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(SBPGBinaryInterval)));
      if ( pgInterval ) {
#if defined(HAVE_INT64_TIMESTAMP)
        pgInterval->seconds = (int64_t)[(SBTimeInterval*)object secondsInTimeInterval];
#else
        pgInterval->seconds = [(SBTimeInterval*)object secondsInTimeInterval];
#endif
        SBInSituByteSwapToNetwork(&pgInterval->seconds, sizeof(pgInterval->seconds));
        pgInterval->days = [(SBTimeInterval*)object daysInTimeInterval];
        SBInSituByteSwapToNetwork(&pgInterval->days, sizeof(pgInterval->days));
        pgInterval->months = [(SBTimeInterval*)object monthsInTimeInterval];
        SBInSituByteSwapToNetwork(&pgInterval->months, sizeof(pgInterval->months));
        
        _paramLengths[parameter] = sizeof(SBPGBinaryInterval);
        _paramOids[parameter] = INTERVALOID;
        
        return YES;
      }
    }
    
    
    else if ( [object isKindOf:[SBNotorization class]] ) {
      // Check if we've already been prepared:
      if ( _hasBeenPrepared && (_paramClasses[parameter] != [SBNotorization class]) )
        return NO;
      
      // Stash the class:
      _paramClasses[parameter] = [SBNotorization class];
      
      if ( [(SBNotorization*)object encodePostgresBinaryData:(void**)&_paramValues[parameter]
                                              length:&_paramLengths[parameter]
                                              usingPool:_queryPool
                                            ]
      ) {
        // The OID will get set later when the query is executed:
        return YES;
      }
    }
    
    
    else if ( [object isKindOf:[SBDateComponents class]] ) {
      if ( [(SBDateComponents*)object isDateOnly] ) {
        int*                jdate;
        
        // Check if we've already been prepared:
        if ( _hasBeenPrepared && (_paramOids[parameter] != DATEOID) )
          return NO;
        
        jdate = (int*)(_paramValues[parameter] = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(int)));
        if ( jdate ) {
          *jdate = SBPostgresDateComponents2JulianDay((SBDateComponents*)object);
          SBInSituByteSwapToNetwork(jdate, sizeof(int));
          
          _paramLengths[parameter] = sizeof(int);
          _paramOids[parameter] = DATEOID;
          
          return YES;
        }
        return NO;
      }
      else if ( [(SBDateComponents*)object isTimeOnly] ) {
        SBPGTimeWithTimeZone*     timetz;
        
        // Check if we've already been prepared:
        if ( _hasBeenPrepared && (_paramOids[parameter] != TIMETZOID) )
          return NO;
        
        timetz = (SBPGTimeWithTimeZone*)(_paramValues[parameter] = (char*)SBMemoryPoolCalloc(_queryPool, sizeof(SBPGTimeWithTimeZone)));
        
        if ( timetz ) {
          timetz->time = [(SBDateComponents*)object hour];
          timetz->time = (timetz->time * 60) + [(SBDateComponents*)object minute];
          timetz->time = (timetz->time * 60) + [(SBDateComponents*)object second];
          SBInSituByteSwapToNetwork(&timetz->time, sizeof(timetz->time));
          
          if ( [(SBDateComponents*)object timeZoneOffset] != SBUndefinedDateComponent ) {
            // Time zone explicitly specified:
            timetz->tz = [(SBDateComponents*)object timeZoneOffset];
          } else {
            // Implicit value -- use default calendar's time zone offset:
            timetz->tz = [[SBCalendar defaultCalendar] defaultGMTOffset] / -1000;
          }
          return YES;
        }
        return NO;
      }
      
      // If it's mixed date and time, then we'll turn this into an SBDate according to the
      // default calendar and let it hit the [SBDate class] test that follows this else
      // block:
      object = [[SBCalendar defaultCalendar] dateFromComponents:object];
    }
    
    
    if ( [object isKindOf:[SBDate class]] ) {
      //
      // SBDate
      //
      // Sending a timestamp with time zone is acceptable for all these Postgres types:
      //
      //    - timestamp
      //    - timestamp with time zone
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
        double tdiff = (double)unixTS - PostgresEpochShift;
        
        memcpy((void*)_paramValues[parameter], &tdiff, bytes);
        SBInSituByteSwapToNetwork((void*)_paramValues[parameter], sizeof(double));
#endif
        return YES;
      }
    }
    
    return NO;
  }

//

  - (BOOL) bindNULLToParameter:(SBUInteger)parameter
  {
    // Parameters are one-based:
    parameter--;
    
    _paramValues[parameter]     = NULL;
    _paramLengths[parameter]    = 0;
    
    if ( ! _hasBeenPrepared )
      _paramOids[parameter]     = 0;
      
    return YES;
  }

@end

//
#pragma mark -
//

@implementation SBPostgresQueryResult

  + (BOOL) accessInstanceVariablesDirectly
  {
    return NO;
  }

//

  - (void) dealloc
  {
    if ( _parentDatabase ) [_parentDatabase release];
    if ( _queryResult ) PQclear(_queryResult);
    if ( _fieldNames ) [_fieldNames release];
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

  - (SBUInteger) numberOfRows
  {
    if ( [self queryWasSuccessful] ) {
      return PQntuples(_queryResult);
    }
    return 0;
  }
  
//

  - (SBUInteger) numberOfFields
  {
    if ( [self queryWasSuccessful] ) {
      return PQnfields(_queryResult);
    }
    return 0;
  }
  
//

  - (SBString*) fieldNameWithNumber:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] && [self setupFieldNamesArray] ) {
      return [_fieldNames objectAtIndex:fieldNum];
    }
    return nil;
  }
  
//

  - (SBUInteger) fieldNumberWithName:(SBString*)fieldName
  {
    if ( [self queryWasSuccessful] && [self setupFieldNamesArray] ) {
      return [_fieldNames indexOfObject:fieldName];
    }
    return SBNotFound;
  }

//

  - (BOOL) postgresType:(Oid*)typeOid
    forFieldNum:(SBUInteger)fieldNum
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

  - (BOOL) postgresTypeModifier:(SBUInteger*)typeMod
    forFieldNum:(SBUInteger)fieldNum
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

  - (BOOL) postgresStorageSize:(SBUInteger*)storageSize
    forFieldNum:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] ) {
      SBUInteger      tmpSize = (SBUInteger)PQfsize(_queryResult, fieldNum);
      
      if ( tmpSize >= 0 ) {
        *storageSize = tmpSize;
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) isNullValueAtRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      if ( PQgetisnull(_queryResult, row, fieldNum) )
        return YES;
    }
    return NO;
  }
  
//

  - (BOOL) sizeOfValue:(SBUInteger*)byteSize
    atRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      *byteSize = (SBUInteger)PQgetlength(_queryResult, row, fieldNum);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) getValuePointer:(void**)valuePtr
    atRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      *valuePtr = (void*)PQgetvalue(_queryResult, row, fieldNum);
      return YES;
    }
    return NO;
  }
  
//

  - (BOOL) getSizeOfValue:(SBUInteger*)byteSize
    andPointer:(void**)valuePtr
    atRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      *byteSize = (SBUInteger)PQgetlength(_queryResult, row, fieldNum);
      *valuePtr = (void*)PQgetvalue(_queryResult, row, fieldNum);
      return YES;
    }
    return NO;
  }
  
//

  - (SBUInteger) copyValueAtRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
    toBuffer:(void*)buffer
    length:(SBUInteger)length
  {
    if ( [self queryWasSuccessful] && PQntuples(_queryResult) ) {
      void*       src = (void*)PQgetvalue(_queryResult, row, fieldNum);
      SBUInteger  srcLen = (SBUInteger)PQgetlength(_queryResult, row, fieldNum);
      
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

  - (Class) classForFieldNum:(SBUInteger)fieldNum
  {
    Oid       pgType = InvalidOid;
    
    if ( [self postgresType:&pgType forFieldNum:fieldNum] ) {
      switch ( pgType ) {
        
        case OIDOID:
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
        case TEXTOID:
          return [SBString class];
        
        case UUIDOID:
          return [SBUUID class];
        
        case DATEOID:
        case TIMEOID:
        case TIMETZOID:
          return [SBDateComponents class];
          
        case TIMESTAMPOID:
        case TIMESTAMPTZOID:
          return [SBDate class];
          
        case INTERVALOID:
          return [SBTimeInterval class];
        
        case MACADDROID:
          return [SBMACAddress class];
        
        case INETOID:
        case CIDROID:
          return [SBInetAddress class];
        
        case BYTEAOID:
        default: {
          if ( pgType == [_parentDatabase typeOidForTypeName:@"notorization"] ) {
            return [SBNotorization class];
          }
          return [SBData class];
        }
        
      }
    }
    return Nil;
  }

//

  - (id) objectForRow:(SBUInteger)row
    fieldNum:(SBUInteger)fieldNum
  {
    id        rowColObj = nil;
    Oid       pgType = InvalidOid;
    
    if ( [self postgresType:&pgType forFieldNum:fieldNum] ) {
      
      if ( [self isNullValueAtRow:row fieldNum:fieldNum] )
        return [SBNull null];
      
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
        
        case OIDOID:
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
        
        case TEXTOID:
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
        
        case UUIDOID: {
          unsigned char*    value = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          int               length = PQgetlength(_queryResult, row, fieldNum);
          
          if ( length == 16 )
            rowColObj = [[[SBUUID alloc] initWithBytes:value] autorelease];
          break;
        }
        
        case DATEOID: {
          unsigned char*    value = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          int               length = PQgetlength(_queryResult, row, fieldNum);

          if ( length == sizeof(int) ) {
            if ( (rowColObj = [[[SBDateComponents alloc] init] autorelease]) ) {
              SBInSituByteSwapFromNetwork(value, length);
              SBPostgresJulianDay2DateComponents(*((int*)value), rowColObj);
            }
          }
          break;
        }
        
        case TIMEOID: {
          unsigned char*    value = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          int               length = PQgetlength(_queryResult, row, fieldNum);

#if defined(HAVE_INT64_TIMESTAMP)
          if ( length == sizeof(int64_t) )
#else
          if ( length == sizeof(double) )
#endif
          {
            if ( (rowColObj = [[[SBDateComponents alloc] init] autorelease]) ) {
              SBInSituByteSwapFromNetwork(value, length);
#if defined(HAVE_INT64_TIMESTAMP)
              SBPostgresTime2DateComponents(*((int64_t*)value), rowColObj);
#else
              SBPostgresTime2DateComponents(*((double*)value), rowColObj);
#endif
            }
          }
          break;
        }
        
        case TIMETZOID: {
          unsigned char*    value = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          int               length = PQgetlength(_queryResult, row, fieldNum);
          
          if ( length == sizeof(SBPGTimeWithTimeZone) ) {
            if ( (rowColObj = [[[SBDateComponents alloc] init] autorelease]) ) {
              SBPGTimeWithTimeZone*   timetz = (SBPGTimeWithTimeZone*)value;
              
              SBInSituByteSwapFromNetwork(&timetz->time, sizeof(timetz->time));
              SBInSituByteSwapFromNetwork(&timetz->tz, sizeof(timetz->tz));
              
              SBPostgresTimeTZ2DateComponents(timetz, rowColObj);
            }
          }
          break;
        }
        
        case TIMESTAMPOID:
        case TIMESTAMPTZOID: {
          unsigned char*    value = (unsigned char*)PQgetvalue(_queryResult, row, fieldNum);
          int               length = PQgetlength(_queryResult, row, fieldNum);

#if defined(HAVE_INT64_TIMESTAMP)
          int64_t           pgTimestamp;
#else
          double            pgTimestamp;
#endif
          if ( length == sizeof(pgTimestamp) ) {
            SBInSituByteSwapFromNetwork(value, length);
#if defined(HAVE_INT64_TIMESTAMP)
            rowColObj = [SBDate dateWithPostgresTimestamp:*((int64_t*)value)];
#else
            rowColObj = [SBDate dateWithPostgresTimestamp:*((double*)value)];
#endif
          }
          break;
        }
        
        case INTERVALOID: {
          SBPGBinaryInterval* pgInterval = (SBPGBinaryInterval*)PQgetvalue(_queryResult, row, fieldNum);
          
          //
          // Byte swap everything in-place:
          //
          SBInSituByteSwapFromNetwork(&pgInterval->seconds, sizeof(pgInterval->seconds));
          SBInSituByteSwapFromNetwork(&pgInterval->days, sizeof(pgInterval->days));
          SBInSituByteSwapFromNetwork(&pgInterval->months, sizeof(pgInterval->months));
          
          if ( pgInterval->months ) {
            rowColObj = [SBTimeInterval timeIntervalWithMonths:pgInterval->months days:pgInterval->days seconds:pgInterval->seconds];
          }
          else if ( pgInterval->days ) {
            rowColObj = [SBTimeInterval timeIntervalWithDays:pgInterval->days seconds:pgInterval->seconds];
          }
          else {
            rowColObj = [SBTimeInterval timeIntervalWithSeconds:pgInterval->seconds];
          }
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
          
          //
          // Handle any special types we defined ourselves:
          //
          if ( pgType == [_parentDatabase typeOidForTypeName:@"notorization"] ) {
            rowColObj = [[SBNotorization alloc] initWithPostgresBinaryData:value length:actLen];
          }
          //
          // Catch-all:
          //
          else {
            rowColObj = [SBData dataWithBytes:value length:actLen];
          }
          break;
        }
        
      }
    }
    return rowColObj;
  }

//

  - (SBArray*) arrayForRow:(SBUInteger)row
  {
    return [self arrayForRow:row createMutable:NO];
  }
  - (SBArray*) arrayForRow:(SBUInteger)row
    createMutable:(BOOL)createMutable
  {
    SBArray*      theRow = nil;
    SBUInteger    cols;
    
    if ( [self queryWasSuccessful] && (cols = PQnfields(_queryResult)) && (row < PQntuples(_queryResult)) ) {
      id          objs[cols];
      SBUInteger  i = cols;
      
      while ( i-- )
        objs[i] = [self objectForRow:row fieldNum:i];
      
      if ( createMutable )
        theRow = [SBMutableArray arrayWithObjects:objs count:cols];
      else
        theRow = [SBArray arrayWithObjects:objs count:cols];
    }
    return theRow;
  }

//

  - (SBDictionary*) dictionaryForRow:(SBUInteger)row
  {
    return [self dictionaryForRow:row createMutable:NO];
  }
  - (SBDictionary*) dictionaryForRow:(SBUInteger)row
    createMutable:(BOOL)createMutable
  {
    SBDictionary*   theRow = nil;
    SBUInteger      cols;
    
    if ( [self queryWasSuccessful] && [self setupFieldNamesArray] && (cols = PQnfields(_queryResult)) && (row < PQntuples(_queryResult)) ) {
      id            objs[cols];
      SBString*     keys[cols];
      SBUInteger    i = cols;
      
      while ( i-- ) {
        objs[i] = [self objectForRow:row fieldNum:i];
        keys[i] = [_fieldNames objectAtIndex:i];
      }
      if ( createMutable )
        theRow = [SBMutableDictionary dictionaryWithObjects:objs forKeys:keys count:cols];
      else
        theRow = [SBDictionary dictionaryWithObjects:objs forKeys:keys count:cols];
    }
    return theRow;
  }
	
//

  - (SBArray*) arrayForFieldNum:(SBUInteger)fieldNum
  {
    return [self arrayForFieldNum:fieldNum createMutable:NO];
  }
  - (SBArray*) arrayForFieldNum:(SBUInteger)fieldNum
    createMutable:(BOOL)createMutable
  {
    SBArray*      theCol = nil;
    SBUInteger    rows;
    
    if ( [self queryWasSuccessful] && (fieldNum < PQnfields(_queryResult)) && (rows = PQntuples(_queryResult)) ) {
      id          objs[rows];
      SBUInteger  i = rows;
      
      while ( i-- )
        objs[i] = [self objectForRow:i fieldNum:fieldNum];
      
      if ( createMutable )
        theCol = [SBMutableArray arrayWithObjects:objs count:rows];
      else
        theCol = [SBArray arrayWithObjects:objs count:rows];
    }
    return theCol;
  }

@end
