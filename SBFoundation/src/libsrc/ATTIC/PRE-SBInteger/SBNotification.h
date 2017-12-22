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

+ (id) notificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject;
+ (id) notificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject userInfo:(SBDictionary*)theUserInfo;

- (SBString*) identifier;
- (id) object;
- (SBDictionary*) userInfo;

@end


/*!
  @class SBNotificationCenter
  @discussion
  An SBNotificationCenter acts as a distribution point for inter-object communication.
  A notification is posted by providing its name (a unique string) and, optionally, any
  additional data encapsulated in an SBDictionary object.  Each object that has
  previously registered an interest in notifications having said name will be notified
  by performing the selector that was specified at registration time with an instance of
  SBNotification holding the notification name and extra-info.
  
  There is a default, shared notification center created by default in a running
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

- (void) addObserver:(id)observer selector:(SEL)aSelector identifier:(SBString*)anIdentifier object:(id)anObject;

- (void) postNotification:(SBNotification*)aNotification;
- (void) postNotificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject;
- (void) postNotificationWithIdentifier:(SBString*)anIdentifier object:(id)anObject userInfo:(SBDictionary*)theUserInfo;

- (void) removeObserver:(id)observer;
- (void) removeObserver:(id)observer identifier:(SBString*)anIdentifier object:(id)anObject;

@end
