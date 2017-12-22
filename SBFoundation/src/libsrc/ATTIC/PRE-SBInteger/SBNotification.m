//
// SBFoundation : ObjC Class Library for Solaris
// SBNotification.m
//
// Inter-object notifications.
//
// $Id$
//

#import "SBNotification.h"
#import "SBString.h"
#import "SBDictionary.h"
#import "SBArray.h"

@interface SBNotificationKey : SBObject
{
  SBString*     _identifier;
  id            _object;
}

- (id) initWithIdentifier:(SBString*)anIdentifier object:(id)anObject;
- (id) initTemporaryWithIdentifier:(SBString*)anIdentifier object:(id)anObject;

- (SBString*) identifier;
- (id) object;

- (BOOL) shouldNotifyForIdentifier:(SBString*)anIdentifier object:(id)anObject;

- (void) writeToStream:(FILE*)stream;

@end

@implementation SBNotificationKey

  - (id) initWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    if ( (self = [super init]) ) {
      _identifier = ( anIdentifier ? [anIdentifier copy] : nil );
      _object = ( anObject ? [anObject retain] : nil );
    }
    return self;
  }
  
//

  - (id) initTemporaryWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    if ( (self = [super init]) ) {
      _identifier = anIdentifier;
      _object = anObject;
    }
    return self;
  }
  
//

  - (void) dealloc
  {
    if ( _identifier ) [_identifier release];
    if ( _object ) [_object release];
    [super dealloc];
  }
  
//

  - (unsigned int) hash
  {
    unsigned int      hval = 0;
    
    if ( _identifier )
      hval = [_identifier hash];
    if ( _object )
      hval = (hval << 11) ^ (unsigned int)((size_t)_object);
    return hval;
  }

//

  - (BOOL) isEqual:(id)anObject
  {
    SBString*   otherIdentifier = [(SBNotificationKey*)anObject identifier];
    
    if ( _identifier ) {
      if ( ! otherIdentifier || ! [_identifier isEqualToString:otherIdentifier] )
        return NO;
    } else if ( otherIdentifier ) {
      return NO;
    }
    if ( _object != [(SBNotificationKey*)anObject object] )
      return NO;
    return YES;
  }

//

  - (SBString*) identifier { return _identifier; }
  - (id) object { return _object; }
  
//

  - (BOOL) shouldNotifyForIdentifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    if ( _identifier ) {
      if ( anIdentifier && [_identifier isEqualToString:anIdentifier] ) {
        if ( ! _object || (_object == anObject) )
          return YES;
      }
    } else if ( ! _object || (_object == anObject) ) {
      return YES;
    }
    return NO;
  }

//

  - (void) writeToStream:(FILE*)stream
  {
    if ( _identifier ) {
      fprintf(stream, "[identifier=\"");
      [_identifier writeToStream:stream];
      if ( _object )
        fprintf(stream, "\",object=%p]", _object);
      else
        fprintf(stream, "\"]");
    } else if ( _object ) {
      fprintf(stream, "[object=%p]", _object);
    } else {
      fprintf(stream, "[all notifications]");
    }
  }

@end

//
#pragma mark -
//

@interface SBNotificationRegistration : SBObject
{
  id      _object;
  SEL     _selector;
}

- (id) initWithObject:(id)object;
- (id) initWithObject:(id)object andSelector:(SEL)selector;
- (id) object;
- (SEL) selector;
- (void) notify:(SBNotification*)aNotification;

@end

@implementation SBNotificationRegistration

  - (id) initWithObject:(id)object
  {
    if ( self = [super init] ) {
      _object = object;
    }
    return self;
  }

//

  - (id) initWithObject:(id)object
    andSelector:(SEL)selector
  {
    if ( self = [super init] ) {
      _object = object;
      _selector = selector;
    }
    return self;
  }
  
//

  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream,
        "  object : %s@%p\n",
        [_object name], _object
      );
  }

//

  - (BOOL) isEqual:(id)otherObject
  {
    if ( [otherObject isKindOf:[self class]] ) {
      if ( [otherObject object] == _object )
        return YES;
    }
    return NO;
  }

//

  - (id) object { return _object; }
  - (SEL) selector { return _selector; }
  - (void) notify:(SBNotification*)aNotification
  {
    [_object perform:_selector with:aNotification];
  }

@end

//
#pragma mark -
//

@interface SBNotification(SBNotificationPrivate)

- (id) initWithIdentifier:(SBString*)anIdentifier object:(id)anObject userInfo:(SBDictionary*)theUserInfo;

@end

@implementation SBNotification(SBNotificationPrivate)

  - (id) initWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
    userInfo:(SBDictionary*)theUserInfo
  {
    if ( self = [super init] ) {
      if ( anIdentifier )
        _identifier = [anIdentifier retain];
      if ( anObject )
        _object = [anObject retain];
      if ( theUserInfo )
        _userInfo = [theUserInfo retain];
    }
    return self;
  }

@end

@implementation SBNotification

  + (id) notificationWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    return [self notificationWithIdentifier:anIdentifier object:anObject userInfo:nil];
  }
  
//

  + (id) notificationWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
    userInfo:(SBDictionary*)theUserInfo
  {
    return [[[self alloc] initWithIdentifier:anIdentifier object:anObject userInfo:theUserInfo] autorelease];
  }

//

  - (void) dealloc
  {
    if ( _identifier ) [_identifier release];
    if ( _object ) [_object release];
    if ( _userInfo ) [_userInfo release];
    [super dealloc];
  }

//

  - (SBString*) identifier { return _identifier; }
  - (id) object { return _object; }
  - (SBDictionary*) userInfo { return _userInfo; }

@end

//
#pragma mark -
//

@implementation SBNotificationCenter

  + (SBNotificationCenter*) defaultNotificationCenter
  {
    static SBNotificationCenter*    defaultCenter = nil;
    
    if ( defaultCenter == nil ) {
      defaultCenter = [[SBNotificationCenter alloc] init];
    }
    return defaultCenter;
  }
  
//

  - (void) dealloc
  {
    if ( _registry ) [_registry release];
    [super dealloc];
  }
  
//

  - (void) addObserver:(id)observer
    selector:(SEL)aSelector
    identifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    SBNotificationRegistration*   newRegistration = [[SBNotificationRegistration alloc] initWithObject:observer andSelector:aSelector];
    SBNotificationKey*            newKey = [[SBNotificationKey alloc] initWithIdentifier:anIdentifier object:anObject];
    SBMutableArray*               registrations = nil;
    
    if ( _registry ) {
      if ( (registrations = [_registry objectForKey:newKey]) ) {
        unsigned int    index = [registrations indexOfObject:newRegistration];
        
        if ( index != SBNotFound ) {
          [registrations replaceObject:newRegistration atIndex:index];
          goto allDone;
        }
      }
    } else {
      _registry = [[SBMutableDictionary alloc] init];
    }
    if ( ! registrations ) {
      registrations = [[SBMutableArray alloc] init];
      [_registry setObject:registrations forKey:newKey];
      [registrations release];
    }
    [registrations addObject:newRegistration];

allDone:
    [newRegistration release];
    [newKey release];
  }

//

  - (void) postNotification:(SBNotification*)aNotification
  {
    if ( _registry && [_registry count] ) {
      SBString*             identifier = [aNotification identifier];
      id                    object = [aNotification object];
      SBEnumerator*         eKey = [_registry keyEnumerator];
      SBNotificationKey*    key;
      
      //
      // We quite simply just walk the registry, asking each key if it
      // responds to aNotification:
      //
      while ( (key = [eKey nextObject]) ) {
        if ( [key shouldNotifyForIdentifier:identifier object:object] ) {
          SBMutableArray*   observers = [_registry objectForKey:key];
          
          [observers makeObjectsPerformSelector:@selector(notify:) withObject:aNotification];
        }
      }
    }
  }
  
//

  - (void) postNotificationWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    SBNotification*     newNotification = [[SBNotification alloc] initWithIdentifier:anIdentifier object:anObject userInfo:nil];
    
    [self postNotification:newNotification];
    [newNotification release];
  }
  
//

  - (void) postNotificationWithIdentifier:(SBString*)anIdentifier
    object:(id)anObject
    userInfo:(SBDictionary*)theUserInfo
  {
    SBNotification*     newNotification = [[SBNotification alloc] initWithIdentifier:anIdentifier object:anObject userInfo:theUserInfo];
    
    [self postNotification:newNotification];
    [newNotification release];
  }

//

  - (void) removeObserver:(id)observer
  {
    if ( _registry && [_registry count] ) {
      SBNotificationRegistration*   removeObs = [[SBNotificationRegistration alloc] initWithObject:observer];
      SBEnumerator*                 eArray = [_registry objectEnumerator];
      SBMutableArray*               array;
      
      //
      // We quite simply just walk the registry, grabbing each array
      // and removing for all registrations for observer:
      //
      while ( (array = [eArray nextObject]) ) {
        unsigned int    i;
        while ( (i = [array indexOfObject:removeObs]) != SBNotFound )
          [array removeObjectAtIndex:i];
      }
      [removeObs release];
    }
  }
  
//

  - (void) removeObserver:(id)observer
    identifier:(SBString*)anIdentifier
    object:(id)anObject
  {
    if ( _registry && [_registry count] ) {
      SBNotificationKey*            newKey = [[SBNotificationKey alloc] initWithIdentifier:anIdentifier object:anObject];
      SBNotificationRegistration*   removeObs = [[SBNotificationRegistration alloc] initWithObject:observer];
      SBMutableArray*               array = [_registry objectForKey:newKey];
      
      [newKey release];
      if ( array ) {
        unsigned int    i;
        while ( (i = [array indexOfObject:removeObs]) != SBNotFound )
          [array removeObjectAtIndex:i];
      }
      [removeObs release];
    }
  }

//
  - (void) summarizeToStream:(FILE*)stream
  {
    [super summarizeToStream:stream];
    fprintf(stream, " {\n");
    if ( _registry && [_registry count] ) {
      SBEnumerator*       eKey = [_registry keyEnumerator];
      SBNotificationKey*  key;
      
      while ( (key = [eKey nextObject]) ) {
        SBArray*          regs = [_registry objectForKey:key];
        unsigned int      i = 0, iMax = [regs count];
        
        if ( iMax ) {
          fprintf(stream, "  ");
          [key writeToStream:stream];
          fprintf(stream, " => {\n");
          while ( i < iMax ) {
            SBNotificationRegistration* reg = [regs objectAtIndex:i++];
            
            fprintf(stream, "      %s@%p{SEL:%p}\n", [[reg object] name], [reg object], [reg selector]);
          }
          fprintf(stream, "    }\n");
        }
      }
    }
    fprintf(stream, "}\n");
  }

@end
