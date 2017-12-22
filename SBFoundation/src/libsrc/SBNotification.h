//
// SBFoundation : ObjC Class Library for Solaris
// SBNotification.h
//
// Inter-object notifications.
//
// $Id$
//

#import "SBObject.h"

@class SBString, SBDictionary, SBMutableDictionary;


/*!
  @class SBNotification
  @discussion
  Instances of SBNotification are created when an event is posted to a notification
  center.  The resulting object is passed to each listener; the notification name and
  additional data posted to the notification center are made available to th
  listeners through the SBNotification object they receive.
  
  A listener should _not_ attempt to release the SBNotification object passed to
  it.
*/  
@interface SBNotification : SBObject
{
  SBString*     _identifier;
  id            _object;
  SBDictionary* _userInfo;
}

/*!
  @method notificationWithIdentifier:object:
  @discussion
    Returns an autoreleased instance initialized to contain the given identifier and
    object reference.  The resulting object can be posted to an SBNotificationCenter.
*/
+ (id) notificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject;
/*!
  @method notificationWithIdentifier:object:userInfo:
  @discussion
    Returns an autoreleased instance initialized to contain the given identifier and
    object reference, with the given userInfo dictionary.  The resulting object can be
    posted to an SBNotificationCenter.
*/
+ (id) notificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject userInfo:(SBDictionary*)theUserInfo;
/*!
  @method identifier
  @discussion
    Returns the receiver's notification identifier string.
*/
- (SBString*) identifier;
/*!
  @method object
  @discussion
    Returns the receiver's source object.
*/
- (id) object;
/*!
  @method userInfo
  @discussion
    Returns the receiver's additional information dictionary.
*/
- (SBDictionary*) userInfo;

@end


/*!
  @class SBNotificationCenter
  @discussion
    An SBNotificationCenter acts as a distribution point for inter-object communication.
    A notification is posted by providing its identifier (a unique string), a source object,
    and (optionally) any additional data encapsulated in an SBDictionary object.  Each
    object that has previously registered an interest in notifications having that identifier
    and/or that source object will be notified synchronously by performing the selector that
    was specified at registration time.
    
    There is a default, shared notification center created automatically by a running
    application; this center can be accessed using the defaultNotificationCenter class
    method.  Honestly, you'll probably never need to create your own notification center(s)
    anyway!
*/
@interface SBNotificationCenter : SBObject
{
  SBMutableDictionary* _registry;
}

/*!
  @method defaultNotificationCenter
  
  Returns the default, application-wide notification center.  Do not attempt to release
  or retain the returned object!
*/
+ (SBNotificationCenter*) defaultNotificationCenter;

/*!
  @method addObserver:selector:identifier:object:
  @discussion
    Register observer as being interested in notifications posted to the receiver with the given
    identifier string and/or source object.  When matching notifications are posted to the
    receiver, aSelector should be sent to observer; aSelector should be a void-typed method that
    takes a single id-type argument, e.g.
    
      - (void) reactToNotification:(id)aNotification
    
    The argument to the method is the SBNotification object that was posted to the receiver.
*/
- (void) addObserver:(id)observer selector:(SEL)aSelector identifier:(SBString*)anIdentifier object:(id)anObject;
/*!
  @method removeObserver:
  @discussion
    Remove all notification registrations made by observer from the receiver.
*/
- (void) removeObserver:(id)observer;
/*!
  @method removeObserver:identifier:object:
  @discussion
    Remove any registration for the given identifier string and/or source object made by observer
    from the receiver.
*/
- (void) removeObserver:(id)observer identifier:(SBString*)anIdentifier object:(id)anObject;

/*!
  @method postNotification:
  @discussion
    Post the given SBNotification to the receiver.  Any objects registered as observers of the
    identifier and/or object source of aNotification will be notified immediately.
*/
- (void) postNotification:(SBNotification*)aNotification;
/*!
  @method postNotificationWithIdentifier:object:
  @discussion
    Post an SBNotification for the given identifier string and object.  AnObject may be nil.  Any
    objects registered as observers of the identifier and/or object source of aNotification will
    be notified.
*/
- (void) postNotificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject;
/*!
  @method postNotificationWithIdentifier:object:userInfo:
  @discussion
    Post an SBNotification for the given identifier string and object, including the given userInfo
    dictionary.  AnObject and theUserInfo may be nil.  Any objects registered as observers of the
    identifier and/or object source of aNotification will be notified.
*/
- (void) postNotificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject userInfo:(SBDictionary*)theUserInfo;


@end
