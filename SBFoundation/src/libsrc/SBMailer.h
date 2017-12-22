//
// SBFoundation : ObjC Class Library for Solaris
// SBMailer.h
//
// Class which facilitates the sending of email.
//
// $Id$
//

#import "SBObject.h"
#import "SBString.h"
#import "SBData.h"

@class SBDictionary, SBArray, SBHost, SBError, SBMailer;

/*!
  @const SBMailerErrorDomain
  @discussion
  SBError domain used for errors originating in the SBMailer.
*/
extern SBString* SBMailerErrorDomain;

/*!
  @enum SBMailer Error Codes
  @discussion
  Error codes associated with the SBMailerErrorDomain.
*/
enum {
  kSBMailerOkay = 0,
  
  kSBMailerUnableToOpenSocket,
  kSBMailerSMTPCommandBuildFailure,
  kSBMailerSMTPCommandFailure,
  kSBMailerMessageNotReady,
  kSBMailerHeaderLengthExceeded,
  kSBMailerIncompleteMessage,
  kSBMailerErrorDuringSend,
  kSBMailerParameterError
};

/*!
  @typedef SBMailerMultipartComposerFunction
  @discussion
  Type of the callback functions used by the sendMessageWithComposerFunction:context:properties:
  method to build the content of a message.
*/
typedef SBError* (*SBMailerMultipartComposerFunction)(SBMailer* aMailer, void* context);

/*!
  @protocol SBMailerComposer
  @discussion
  A protocol which must be adopted by a class in order for it to act as a "composer" for
  an SBMailer.
*/
@protocol SBMailerComposer

/*!
  @method addMessagePartsToMailer:
  @discussion
  Add one or more MIME parts to a message which is being composed by aMailer.  Your method
  should make use of the send*Part methods of SBMailer to add the parts to the message.
*/
- (SBError*) addMessagePartsToMailer:(SBMailer*)aMailer;

@end

/*!
  @class SBMailer
  @discussion
  Instances of SBMailer represent a somewhat robust mail delivery engine.  Behind the scenes, the
  class does not simply call-through to sendmail:  it actually opens a connection to a mail relay
  host (on port 25 by default) and performs an SMTP dialogue.  Basic methods for starting an
  SMTP session with a server, sending SMTP control commands in that session, and cancelling or
  completing a message description are made available.
  
  A message is described within an open session by issuing an ordered sequence of commands:
  <ol>
    <li>sendFromAddress: (once only)</li>
    <li>sendRecipient: or sendRecipients: (at least once)</li>
    <li>sendMessageHeaders: (once only)</li>
    <li>sendTextPart: of sendTextPart:mimeType: (zero or more)</li>
  </ol>
  Barring any errors, the message is handed-off to the server by sending the finishSMTPSession
  message.  If at any point in the process the message should be discarded, the cancelSMTPSession
  message can be sent.
  
  If the instance is set to "stayAlive" then cancelling or finishing a session does not also
  immediately close the connection to the mail relay server.  Instead, the connection will be
  reused by the next session (or until the "stayAlive" option is disabled on the instance).
  
  The sendMessage:withSubject: and sendMessage:withProperties: methods are conveniences which
  implement the command sequence illustrated above for two relatively simply message classes.
  For both, the body of the message is an SBString containing character data treated as
  MIME type "text/plain".  The former method is the simplest of all, delivering the body and
  a subject to the default mail recipient for the receiver.  The latter allows a dictionary
  of message meta data (From address, To addresses, Subject, etc.) to accompany the mail body.
  
  The default recipient, sender, subject, and SMTP host/port can be set on a per-instance
  basis.
*/
@interface SBMailer : SBObject
{
  SBHost*         _smtpOpenHost;
  SBUInteger      _smtpOpenPort;
  int             _smtpSocket;
  FILE*           _smtpIn;
  FILE*           _smtpOut;
  SBUInteger      _flags;
  unsigned char   _reserved[1024];
  unsigned char   _boundary[64];
  //
  SBString*       _defaultSMTPSender;
  SBString*       _defaultSMTPRecipient;
  SBString*       _defaultSMTPSubject;
  //
  SBHost*         _defaultSMTPHost;
  SBUInteger      _defaultSMTPPort;
  //
  SBString*       _agentName;
}

/*!
  @method sharedMailer
  @discussion
  Returns the default shared emailing agent.
*/
+ (SBMailer*) sharedMailer;
/*!
  @method startSMTPSession
  @discussion
  Convenience method that called startSMTPSessionWithHost:port: with the
  receiver's default SMTP host and port.
*/
- (SBError*) startSMTPSession;
/*!
  @method startSMTPSessionWithHost:
  @discussion
  Convenience method that called startSMTPSessionWithHost:port: with the
  given host and receiver's default SMTP port.
*/
- (SBError*) startSMTPSessionWithHost:(SBHost*)smtpHost;
/*!
  @method startSMTPSessionWithHost:port:
  @discussion
  Attempts to open a TCP connection to the given host and port and begin
  an SMTP dialogue by sending the EHLO command.
  
  If the stayAlive option is enabled on the receiver and the last-opened
  connection matches the incoming host and port, the connection is
  recycled.
*/
- (SBError*) startSMTPSessionWithHost:(SBHost*)smtpHost port:(SBUInteger)port;
/*!
  @method sendSMTPCommand:...
  @discussion
  If an SMTP session is active for the receiver, attempt to send the SMTP
  command produced by converting the given format using the variable argument
  list (a'la printf() and friends, see SBString's stringWithFormat:...
  method for more information on the formatting directives that are
  available).
*/
- (SBError*) sendSMTPCommand:(const char*)format, ...;
/*!
  @method cancelSMTPSession
  @discussion
  If an SMTP session is open for the receiver, send the RSET command to discard
  any in-progress message.  Unless the receiver has the stayAlive option set,
  the connection is terminated, as well. 
*/
- (SBError*) cancelSMTPSession;
/*!
  @method finishSMTPSession
  @discussion
  If an SMTP session is open for the receiver and headers have already been sent,
  close out the message and hand it off to the server.  Unless the receiver has
  the stayAlive option set, the connection is terminated, as well. 
*/
- (SBError*) finishSMTPSession;
/*!
  @method isVerbose
  @discussion
  Returns YES if the receiver is set to write debugging output to stderr.
*/
- (BOOL) isVerbose;
/*!
  @method setIsVerbose:
  @discussion
  If verbose is YES, then the receiver should write debugging output to stderr as
  the SMTP session proceeds.  If verbose is NO, then the receiver should be silent.
*/
- (void) setIsVerbose:(BOOL)verbose;
/*!
  @method stayAlive
  Returns NO if the receiver will terminate the connection to the SMTP server when
  the cancelSMTPSession or finishSMTPSession method are invoked.
*/
- (BOOL) stayAlive;
/*!
  @method setStayAlive:
  @discussion
  If stayAlive is YES, then the receiver will not terminate the connection to the
  SMTP server after the message is dispatched.  If stayAlive is NO, the connection
  will be terminated -- and if a connection is already active and no message is
  being composed the connection is immediately terminated, as well.
*/
- (void) setStayAlive:(BOOL)stayAlive;
/*!
  @method agentName
  @discussion
  Returns the X-Mailer identifier associated with the receiver.
*/
- (SBString*) agentName;
/*!
  @method setAgentName:
  @discussion
  Sets the X-Mailer identifier the receiver should send in message headers.
*/
- (void) setAgentName:(SBString*)agentName;
/*!
  @method defaultSMTPSender
  @discussion
  Returns the default SMTP sender email address associated with the receiver.
  Messages composed without any explicit sender will appear to be from this
  address.
*/
- (SBString*) defaultSMTPSender;
/*!
  @method setDefaultSMTPSender:
  @discussion
  Sets the default SMTP sender email address associated with the receiver.
*/
- (void) setDefaultSMTPSender:(SBString*)senderAddress;
/*!
  @method defaultSMTPRecipient
  @discussion
  Returns the default SMTP recipient email address associated with the receiver.
  Messages composed without any explicit recipients will be sent to this address.
*/
- (SBString*) defaultSMTPRecipient;
/*!
  @method setDefaultSMTPRecipient:
  @discussion
  Sets the default SMTP recipient email address associated with the receiver.
*/
- (void) setDefaultSMTPRecipient:(SBString*)recipientAddress;
/*!
  @method defaultSMTPSubject
  @discussion
  Returns the default SMTP subject line associated with the receiver.  Messages
  composed without any explicit subject will use this string.
*/
- (SBString*) defaultSMTPSubject;
/*!
  @method setDefaultSMTPSubject:
  @discussion
  Sets the default SMTP subject associated with the receiver.
*/
- (void) setDefaultSMTPSubject:(SBString*)subject;
/*!
  @method defaultSMTPHost
  @discussion
  Returns the default SMTP host associated with the receiver.  SMTP sessions
  started without any explicit SMTP host will be relayed using this host.
*/
- (SBHost*) defaultSMTPHost;
/*!
  @method setDefaultSMTPHost:
  @discussion
  Sets the default SMTP host associated with the receiver.
*/
- (void) setDefaultSMTPHost:(SBHost*)smtpHost;
/*!
  @method defaultSMTPPort
  @discussion
  Returns the default TCP port associated with the receiver.  SMTP sessions
  started without any explicit TCP port will use this port number.
*/
- (SBUInteger) defaultSMTPPort;
/*!
  @method setDefaultSMTPPort:
  @discussion
  Sets the default TCP port associated with the receiver.
*/
- (void) setDefaultSMTPPort:(SBUInteger)aPort;

@end

/*!
  @category SBMailer(SBMailerMessageComposition)
  @discussion
  Category that groups functions that actually compose a message for delivery.
*/
@interface SBMailer(SBMailerMessageComposition)

/*!
  @method sendFromAddress:
  @discussion
  Invoke this method one time only after a new SMTP session has been setup to
  send the "MAIL FROM" command with the given email address.
*/
- (SBError*) sendFromAddress:(SBString*)fromAddress;
/*!
  @method sendRecipient:
  @discussion
  Invoke this method after the sendFromAddress: method has been invoked to send a
  "RCPT TO" command with the provided email address.  Can be invoked multiple times.
*/
- (SBError*) sendRecipient:(SBString*)toAddress;
/*!
  @method sendRecipients:
  @discussion
  Invoke this method after the sendFromAddress: method has been invoked to send a
  "RCPT TO" command for each of the provided email addresses in the toAddresses
  array.  Can be invoked multiple times.
*/
- (SBError*) sendRecipients:(SBArray*)toAddresses;
/*!
  @method sendMessageHeaders:
  @discussion
  Given an SBDictionary containing message meta data keyed by the string constants
  defined at the end of this header file, send the DATA command followed by all
  applicable SMTP headers.
  
  This method should be invoked one time only after at least one of the recipient
  sending methods have been invoked.
*/
- (SBError*) sendMessageHeaders:(SBDictionary*)messageProps;
/*!
  @method sendTextPart:
  @discussion
  Invoke this method after message headers have been sent in order to add a MIME
  part containing the given text.  The MIME part has a content type of "text/plain"
  associated with it.
*/
- (SBError*) sendTextPart:(SBString*)text;
/*!
  @method sendTextPart:mimeType:
  @discussion
  Invoke this method after message headers have been sent in order to add a MIME
  part containing the given text.  An explicit mimeType can be provided (e.g.
  "text/html"); if mimeType is nil, the content type will be set to "text/plain".
*/
- (SBError*) sendTextPart:(SBString*)text mimeType:(SBString*)mimeType;
/*!
  @method sendDataPart:
  @discussion
  Invoke this method after message headers have been sent in order to add a MIME
  part containing the given binary data.  The MIME part has a content type of
  "application/octet-stream" associated with it.
  
  The content-disposition will be set to "inline".
*/
- (SBError*) sendDataPart:(SBData*)data;
/*!
  @method sendDataPart:mimeType:
  @discussion
  Invoke this method after message headers have been sent in order to add a MIME
  part containing the given binary data.  An explicit mimeType can be provided (e.g.
  "application/zip"); if mimeType is nil, the content type will be set to
  "application/octet-stream".
  
  The content-disposition will be set to "inline".
*/
- (SBError*) sendDataPart:(SBData*)data mimeType:(SBString*)mimeType;
/*!
  @method sendDataPart:mimeType:filename:
  @discussion
  Invoke this method after message headers have been sent in order to add a MIME
  part containing the given binary data.  An explicit mimeType can be provided (e.g.
  "application/zip"); if mimeType is nil, the content type will be set to
  "application/octet-stream".
  
  The content-disposition will be set to "attachment" as long as filename is a valid
  string.  Otherwise (or if filename is nil) the "inline" disposition is used.
*/
- (SBError*) sendDataPart:(SBData*)data mimeType:(SBString*)mimeType filename:(SBString*)filename;
/*!
  @method sendMessage:withSubject:
  @discussion
  Convenience method which sends the given message body and subject to the
  receiver's default recipient using the default SMTP host/port and the default
  sender address.
*/
- (SBError*) sendMessage:(SBString*)message withSubject:(SBString*)subject;
/*!
  @method sendMessage:withProperties:
  @discussion
  Convenience method which sends the given message body using the receiver's
  default SMTP host/port.  Message meta data are drawn from the messageProps
  dictionary, including recipients, sender adddress, subject, etc.
*/
- (SBError*) sendMessage:(SBString*)message withProperties:(SBDictionary*)messageProps;
/*!
  @method sendMessageWithComposer:properties:
  @discussion
  Akin to sendMessage:withProperties:, this method acts as a message-building driver.
  It opens a session, sends all sender and recipient information and meta data as
  drawn from the messageProps dictionary.  If successful to that point, it invokes the
  addMessagePartsToMailer: method on the composer object.
  
  The composer object must conform to the SBMailerComposer protocol and is responsible
  for adding content parts to the message.  It should keep track of errors as it proceeds
  and return an SBError object if it needs to signal that the message could not be
  composed properly.
*/
- (SBError*) sendMessageWithComposer:(id)composer properties:(SBDictionary*)messageProps;
/*!
  @method sendMessageWithComposerFunction:context:properties:
  @discussion
  Akin to sendMessage:withProperties:, this method acts as a message-building driver.
  It opens a session, sends all sender and recipient information and meta data as
  drawn from the messageProps dictionary.  If successful to that point, it calls the
  composer function.
  
  The composer function is responsible for adding content parts to the message.  It
  should keep track of errors as it proceeds and return an SBError object if it needs
  to signal that the message could not be composed properly.
*/
- (SBError*) sendMessageWithComposerFunction:(SBMailerMultipartComposerFunction)composer context:(void*)composerContext properties:(SBDictionary*)messageProps;

@end

/*!
  @const SBMailerToAddressesKey
  @discussion
  Keys either an SBString or an SBArray of SBStrings; each SBString is a recipient
  email address.
*/
extern SBString* SBMailerToAddressesKey;
/*!
  @const SBMailerBCCAddressesKey
  @discussion
  Keys either an SBString or an SBArray of SBStrings; each SBString is a blind
  carbon-copy recipient email address.
*/
extern SBString* SBMailerBCCAddressesKey;
/*!
  @const SBMailerCCAddressesKey
  @discussion
  Keys either an SBString or an SBArray of SBStrings; each SBString is a carbon-copy
  recipient email address.
*/
extern SBString* SBMailerCCAddressesKey;
/*!
  @const SBMailerSubjectKey
  @discussion
  Keys an SBString containing the subject line for a message.
*/
extern SBString* SBMailerSubjectKey;
/*!
  @const SBMailerFromKey
  @discussion
  Keys an SBString containing the email address which should be presented as the
  sender of the message.
*/
extern SBString* SBMailerFromKey;
/*!
  @const SBMailerMessageIdKey
  @discussion
  Keys an SBString containing an explicit message identifier that should be used
  when sending the message.
*/
extern SBString* SBMailerMessageIdKey;
/*!
  @const SBMailerReplyToKey
  @discussion
  Keys an SBString containing the email address which should be presented as the
  address to which message replies should be directed.
*/
extern SBString* SBMailerReplyToKey;
/*!
  @const SBMailerFakeRecipientKey
  @discussion
  Keys an SBString containing a "fake" recipient of the message, e.g.
  
    "SHUEBox Bulk Mail" undisclosed-recipients:;
    
  If this key is provided, then the real address lists will not be sent for the
  To and CC headers; only the To header will be sent, containing this string.
*/
extern SBString* SBMailerFakeRecipientKey;
/*!
  @const SBMailerMultipartSubtypeKey
  @discussion
  Keys an SBString containing the MIME multipart subtype that should be used for
  the message.  By default, messages are sent as "multipart/mixed"; if you are
  constructing an email with alternate representations (plaintext and HTML forms
  of the same message, for example) then the SBString should be "alternative".
  
  Other subtypes are, of course, permissible -- the class blindly sends whatever
  subtype you specify.  It is up to your code to build the body of each part
  properly!
*/
extern SBString* SBMailerMultipartSubtypeKey;

/*!
  @category SBString(SBMailerAdditions)
  @discussion
  Category containing additional SBString functionality implemented under the auspices
  of the SBMailer class.
*/
@interface SBString(SBMailerAdditions)

/*!
  @method writeQuotedPrintableToSMTPStream:
  @discussion
  Writes the receiver's UTF-8 content to the given stream, encoding in the "quoted-printable" format
  used for Internet mail.
*/
- (void) writeQuotedPrintableToSMTPStream:(FILE*)stream;
/*!
  @method writeEncodedWordToSMTPStream:
  @discussion
  Writes the receiver's UTF-8 content to the given stream, encoding in the "encoded-word" format
  used for preserving special characters in MIME headers.
*/
- (void) writeEncodedWordToSMTPStream:(FILE*)stream;
/*!
  @method stringByDiscardingDisplayNameFromEmailAddress
  @discussion
    Attempt to isolate an email address by discarding any leading display name bits.  Basically,
    search backwards from the end of the string for a ">" and if present, search from there for
    a "<" and make a substring of whatever's between 'em.
*/
- (SBString*) stringByDiscardingDisplayNameFromEmailAddress;

@end

/*!
  @category SBData(SBMailerAdditions)
  @discussion
  Category containing addition SBData functionality implemented under the auspices
  of the SBMailer class.
*/
@interface SBData(SBMailerAdditions)

/*!
  @method writeBase64EncodingToSMTPStream:
  @discussion
  Writes the receiver's binary data to the given stream, encoding in "base64" format in the
  appropriate 76-character-per-line form required by SMTP for base64 MIME parts.
*/
- (void) writeBase64EncodingToSMTPStream:(FILE*)stream;

@end
