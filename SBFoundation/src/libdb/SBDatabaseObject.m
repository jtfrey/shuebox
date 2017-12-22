//
// SBDatabaseKit - Database-oriented extensions to SBFoundation
// SBDatabaseObject.m
//
// A simple object-from-database class -- basically descended from the PHP
// "NSSObject" classes that I've historically used on Dropbox, PO Box, etc.
//
// $Id$
//

#import "SBDatabaseObject.h"
#import "SBDatabaseAccess.h"
#import "SBPostgres.h"

#import "SBString.h"
#import "SBDictionary.h"
#import "SBValue.h"
#import "SBNotorization.h"

//

SBString* SBDatabaseObjectPropertyCreationTimestamp = @"created";
SBString* SBDatabaseObjectPropertyModificationTimestamp = @"modified";

SBString* SBDatabaseObjectPropertyCreationNotorization = @"createdby";
SBString* SBDatabaseObjectPropertyModificationNotorization = @"modifiedby";

//

@interface SBDatabaseObject(SBDatabaseObjectPrivate)

- (BOOL) loadPropertiesFromDatabaseWithKey:(SBString*)key value:(SBString*)value;
- (BOOL) loadPropertiesFromDatabase;
- (id) insertQueryForModifications;
- (id) updateQueryForModifications;

@end

@implementation SBDatabaseObject(SBDatabaseObjectPrivate)

  - (BOOL) loadPropertiesFromDatabaseWithKey:(SBString*)key
    value:(SBString*)value
  {
    if ( key && value ) {
      if ( [_database isKindOf:[SBPostgresDatabase class]] ) {
        SBString*     query = [SBString stringWithFormat:"SELECT * FROM %s WHERE %s = '%s'",
                                            [[self tableNameForClass] utf8Characters],
                                            [key utf8Characters],
                                            [[_database stringEscapedForQuery:value] utf8Characters]
                                          ];
        SBPostgresQueryResult*      queryResult = [_database executeQuery:query];
        
        if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
          SBDictionary*     properties = [queryResult dictionaryForRow:0];
          
          if ( properties ) {
            id                      objId;
            
            properties = [properties retain];
            if ( _properties ) [_properties release];
            _properties = properties;
            
            objId = [_properties objectForKey:[self objectIdKeyForClass]];
            
            // Attempt to pull the object id:
            if ( objId && [objId isKindOf:[SBNumber class]] ) {
              _objectId = [(SBNumber*)objId intValue];
              return YES;
            }
          }
        }
      }
    }
    return NO;
  }
  
//

  - (BOOL) loadPropertiesFromDatabase
  {
    if ( _objectId > 0 ) {
      if ( [_database isKindOf:[SBPostgresDatabase class]] ) {
        SBString*     query = [SBString stringWithFormat:"SELECT * FROM %s WHERE %s = " SBUIntegerFormat,
                                            [[self tableNameForClass] utf8Characters],
                                            [[self objectIdKeyForClass] utf8Characters],
                                            _objectId
                                          ];
        SBPostgresQueryResult*      queryResult = [_database executeQuery:query];
        
        if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
          SBDictionary*     properties = [queryResult dictionaryForRow:0];
          
          if ( properties ) {
            id                      objId;
            
            properties = [properties retain];
            if ( _properties ) [_properties release];
            _properties = properties;
            
            objId = [_properties objectForKey:[self objectIdKeyForClass]];
            
            // Attempt to pull the object id:
            if ( objId && [objId isKindOf:[SBNumber class]] ) {
              _objectId = [(SBNumber*)objId intValue];
              return YES;
            }
          }
        }
      }
    }
    return NO;
  }

//

  - (id) insertQueryForModifications
  {
    SBUInteger          iMax = [_modifications count];
    id                  query = nil;
    
    if ( iMax ) {
      if ( [_database isKindOf:[SBPostgresDatabase class]] ) {
        SBMutableString*  queryStr = [[SBMutableString alloc] init];
        SBEnumerator*     keysToUpdate = [_modifications keyEnumerator];
        SBString*         key;
        id                values[iMax];
        SBUInteger        i = 0;
        
        [queryStr appendFormat:"INSERT INTO %s (", [[self tableNameForClass] utf8Characters]];
        
        // Append the column names we need to set:
        while ( (i < iMax) && (key = [keysToUpdate nextObject]) ) {
          values[i] = [_modifications objectForKey:key];
          [queryStr appendFormat:"%c%S",
                          ( i == 0 ? ' ' : ',' ),
                          [key utf16Characters]
                        ];
          i++;
        }
        
        if ( iMax ) {
          // Append the value strings:
          iMax = i; i = 0;
          [queryStr appendString:@") VALUES ("];
          while ( i < iMax ) {
            [queryStr appendFormat:"%c$" SBUIntegerFormat, 
                            ( i == 0 ? ' ': ',' ),
                            i + 1];
            i++;
          }
          [queryStr appendString:@")"];
          
          // Create the query:
          query = [[SBPostgresQuery alloc] initWithQueryString:queryStr parameterCount:iMax];
          
          if ( query ) {
            // Bind the parameters:
            i = 0;
            while ( i < iMax ) {
              [query bindObject:values[i] toParameter:i + 1];
              i++;
            }
          }
        }
        [queryStr release];
      }
    }
    return query;
  }
  
//

  - (id) updateQueryForModifications
  {
    SBUInteger          iMax = [_modifications count];
    id                  query = nil;
    
    if ( iMax ) {
      if ( [_database isKindOf:[SBPostgresDatabase class]] ) {
        SBMutableString*  queryStr = [[SBMutableString alloc] init];
        SBEnumerator*     keysToUpdate = [_modifications keyEnumerator];
        SBString*         key;
        id                values[iMax];
        SBUInteger        i = 0;
        
        [queryStr appendFormat:"UPDATE %s SET ", [[self tableNameForClass] utf8Characters]];
        
        // Append the columns we need to set:
        while ( (i < iMax) && (key = [keysToUpdate nextObject]) ) {
          values[i] = [_modifications objectForKey:key];
          [queryStr appendFormat:"%c%S=$" SBUIntegerFormat,
                          ( i == 0 ? ' ' : ',' ),
                          [key utf16Characters],
                          i + 1
                        ];
          i++;
        }
        
        if ( (iMax = i) ) {
          // Append the object id predicate:
          [queryStr appendFormat:" WHERE %s = " SBUIntegerFormat, [[self objectIdKeyForClass] utf8Characters], _objectId];
          
          // Create the query:
          query = [[SBPostgresQuery alloc] initWithQueryString:queryStr parameterCount:iMax];
          
          if ( query ) {
            // Bind the parameters:
            i = 0;
            while ( i < iMax ) {
              [query bindObject:values[i] toParameter:i + 1];
              i++;
            }
          }
        }
        [queryStr release];
      }
    }
    return query;
  }

@end

//
#pragma mark -
//

@implementation SBDatabaseObject

  + (SBString*) tableNameForClass
  {
    return nil;
  }
  - (SBString*) tableNameForClass
  {
    return [[self class] tableNameForClass];
  }
  
//

  + (SBString*) archivalTableNameForClass
  {
    return nil;
  }
  - (SBString*) archivalTableNameForClass
  {
    return [[self class] archivalTableNameForClass];
  }
  
//

  + (SBString*) objectIdKeyForClass
  {
    return nil;
  }
  - (SBString*) objectIdKeyForClass
  {
    return [[self class] objectIdKeyForClass];
  }

//

  + (SBArray*) propertyKeysForClass
  {
    return nil;
  }
  - (SBArray*) propertyKeysForClass
  {
    return [[self class] propertyKeysForClass];
  }

//

  + (id) databaseObjectWithDatabase:(id)database
    objectId:(SBUInteger)objId
  {
    if ( [database conformsTo:@protocol(SBDatabaseAccess)] )
      return [[[self alloc] initWithDatabase:database objectId:objId] autorelease];
    return nil;
  }
  
//

  + (id) databaseObjectWithDatabase:(id)database
    key:(SBString*)key
    value:(SBString*)value
  {
    if ( [database conformsTo:@protocol(SBDatabaseAccess)] )
      return [[[self alloc] initWithDatabase:database key:key value:value] autorelease];
    return nil;
  }
  
//

  - (id) initWithDatabase:(id)database
  {
    if ( [database conformsTo:@protocol(SBDatabaseAccess)] ) {
      if ( self = [self init] ) {
        _database = [database retain];
        _objectId = 0;
        _modifications = [[SBMutableDictionary alloc] init];
      }
    } else {
      [self release];
      self = nil;
    }
    return self;

  }

//

  - (id) initWithDatabase:(id)database
    objectId:(SBUInteger)objId
  {
    if ( self = [self initWithDatabase:database] ) {
      _objectId = objId;
      if ( ! [self loadPropertiesFromDatabase] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (id) initWithDatabase:(id)database
    key:(SBString*)key
    value:(SBString*)value
  {
    if ( self = [self initWithDatabase:database] ) {
      if ( ! [self loadPropertiesFromDatabaseWithKey:key value:value] ) {
        [self release];
        self = nil;
      }
    }
    return self;
  }

//

  - (void) dealloc
  {
    if ( _database ) [_database release];
    if ( _properties ) [_properties release];
    if ( _modifications ) [_modifications release];
    [super dealloc];
  }

//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(
        stream,
        " ( objectId = " SBUIntegerFormat " ) {\n",
        _objectId
      );
    
    SBArray*      keys = [self propertyKeysForClass];
    unsigned int  i = 0, iMax = [keys count];
    
    while ( i < iMax ) {
      SBString*   key = [keys objectAtIndex:i++];
      
      fprintf(stream, "  ");
      [key writeToStream:stream];
      fprintf(stream, " : ");
      [[self propertyForKey:key] summarizeToStream:stream];
      fputc('\n', stream);
    }
    fprintf(
        stream,
        "}\n"
      );
  }

//

  - (id) parentDatabase
  {
    return _database;
  }

//

  - (BOOL) validPropertyKey:(SBString*)aKey
  {
    return [[self propertyKeysForClass] containsObject:aKey];
  }
  
//

  - (SBEnumerator*) propertyKeyEnumerator
  {
    return [[self propertyKeysForClass] objectEnumerator];
  }
  
//

  - (id) propertyForKey:(SBString*)aKey
  {
    if ( _modifications ) {
      id      property = [_modifications objectForKey:aKey];
      
      if ( ! property && _properties )
        property = [_properties objectForKey:aKey];
      return property;
    }
    return nil;
  }
  
//

  - (BOOL) setProperty:(id)property
    forKey:(SBString*)aKey
  {
    if ( _modifications ) {
      if ( [self validPropertyKey:aKey] ) {
        [_modifications setObject:property forKey:aKey];
        return YES;
      }
    }
    return NO;
  }
  
//

  - (BOOL) hasBeenModified
  {
    return ( (_modifications && ([_modifications count] != 0)) ? YES : NO );
  }
  
//

  - (void) refreshCommittedProperties
  {
    if ( _modifications )
      [self loadPropertiesFromDatabase];
  }

//

  - (void) revertModifications
  {
    if ( _modifications )
      [_modifications removeAllObjects];
  }
  
//

  - (BOOL) commitModifications
  {
    id        theQuery = nil;
    BOOL      querySuccess = NO;
    
    // Valid object?
    if ( ! _modifications )
      return NO;
    
    // Encapsulate everything in a transaction:
    if ( ! [_database beginTransaction] )
      return NO;
    
    // Shall we proceed?
    if ( ([self respondsTo:@selector(shouldCommitModifications)] && ! [self shouldCommitModifications]) ) {
      [_database discardLastTransaction];
      return NO;
    }
      
    // Did anything actually change?
    if ( ! [self hasBeenModified] ) {
      [_database discardLastTransaction];
      return YES;
    }
    
    // Automatically modify the modification field(s) if present:
    if ( [self validPropertyKey:SBDatabaseObjectPropertyModificationTimestamp] ) {
      [_modifications setObject:[SBDate date] forKey:SBDatabaseObjectPropertyModificationTimestamp];
    }
    if ( [self validPropertyKey:SBDatabaseObjectPropertyModificationNotorization] ) {
      [_modifications setObject:[SBNotorization notorizationViaApacheEnvironment] forKey:SBDatabaseObjectPropertyModificationNotorization];
    }
    
    // Do we have an object id already?
    if ( _objectId ) {
      // Going for an update:
      if ( (theQuery = [self updateQueryForModifications]) ) {
        id<SBDatabaseQueryResult>   queryResult = [_database executeQuery:theQuery];
        
        querySuccess = ( queryResult && [queryResult queryWasSuccessful] );
        [theQuery release];
      }
    } else {
      // Going for a new tuple; if the creation field(s) are present, provide values:
      if ( [self validPropertyKey:SBDatabaseObjectPropertyCreationTimestamp] ) {
        [_modifications setObject:[SBDate date] forKey:SBDatabaseObjectPropertyCreationTimestamp];
      }
      if ( [self validPropertyKey:SBDatabaseObjectPropertyCreationNotorization] ) {
        [_modifications setObject:[SBNotorization notorizationViaApacheEnvironment] forKey:SBDatabaseObjectPropertyCreationNotorization];
      }
      // Do the insert:
      if ( (theQuery = [self insertQueryForModifications]) ) {
        id<SBDatabaseQueryResult>   queryResult = [_database executeQuery:theQuery];
        
        querySuccess = ( queryResult && [queryResult queryWasSuccessful] );
        [theQuery release];
        
        // Find the object id we just added; we can look for the highest object id:
        queryResult = [_database executeQuery:[SBString stringWithFormat:"SELECT %s FROM %s ORDER BY %1$s DESC LIMIT 1",
                                                          [[self objectIdKeyForClass] utf8Characters],
                                                          [[self tableNameForClass] utf8Characters]
                                                    ]
                          ];
        if ( queryResult && [queryResult queryWasSuccessful] && [queryResult numberOfRows] ) {
          if ( [[queryResult classForFieldNum:0] isKindOf:[SBNumber class]] ) {
            SBNumber*     newObjId = [queryResult objectForRow:0 fieldNum:0];
            
            [_modifications setObject:newObjId forKey:[self tableNameForClass]];
            _objectId = [newObjId unsignedIntegerValue];
          }
        }
      }
    }
    
    if ( querySuccess ) {
      // Yup, we added those modifications successfully; let's merge the changes into
      // the _properties dictionary:
      SBArray*      myKeys = [self propertyKeysForClass];
      SBUInteger    i = 0, iMax = [myKeys count];
      
      while ( i < iMax ) {
        SBString*   key = [myKeys objectAtIndex:i++];
        id          propVal = [_properties objectForKey:key];
        
        if ( propVal && ! [_modifications containsKey:key] )
          [_modifications setObject:propVal forKey:key];
      }
      [_properties release];
      _properties = [_modifications copy];
      [_modifications removeAllObjects];
      
      // If defined, do a didCommitModifications:
      if ( [self respondsTo:@selector(didCommitModifications)] )
        [self didCommitModifications];
      
      // Commit it all:
      return [_database commitLastTransaction];
    } else {
      [_database discardLastTransaction];
      return NO;
    }
  }
  
//

  - (BOOL) deleteFromDatabase
  {
    id        theQuery = nil;
    BOOL      success = NO;
    
    if ( _objectId > 0 ) {
      // Encapsulate everything in a transaction:
      if ( ! [_database beginTransaction] )
        return NO;
        
      // Delete the object id we just added; we can look for the highest object id:
      success = [_database executeQueryWithBooleanResult:[SBString stringWithFormat:"DELETE FROM %s WHERE %s = " SBUIntegerFormat,
                                                        [[self tableNameForClass] utf8Characters],
                                                        [[self objectIdKeyForClass] utf8Characters],
                                                        _objectId
                                                  ]
                        ];
      if ( success ) {
        success = [_database commitLastTransaction];
      } else {
        [_database discardLastTransaction];
      }
    } else {
      success = YES;
    }
    if ( success )
      [_modifications removeAllObjects];
    return success;
  }

//
#pragma mark SBKeyValueCoding overrides:
//

  - (id) valueForKey:(SBString*)aKey
  {
    if ( [[self propertyKeysForClass] containsObject:aKey] )
      return [self propertyForKey:aKey];
    return [super valueForKey:aKey];
  }

  - (id) setValue:(id)value
    forKey:(SBString*)aKey
  {
    if ( [[self propertyKeysForClass] containsObject:aKey] )
      [self setProperty:value forKey:aKey];
    [super setValue:value forKey:aKey];
  }

@end
