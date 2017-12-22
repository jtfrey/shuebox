//
// SBFoundation : ObjC Class Library for Solaris
// SBStream.h
//
// Generalized i/o streams.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

@class SBData, SBError, SBHost;
@class SBRunLoop, SBFileHandle;

// Forward-declare this protocol:
@protocol SBStreamDelegate;

/*!
  @typedef SBStreamStatus
  @discussion
    An enumeration of the various states in which an SBStream can
    find itself.
*/
typedef SBUInteger SBStreamStatus;
enum {
  SBStreamStatusNotOpen   = 0,
  SBStreamStatusOpening,
  SBStreamStatusOpen,
  SBStreamStatusReading,
  SBStreamStatusWriting,
  SBStreamStatusAtEnd,
  SBStreamStatusClosed,
  SBStreamStatusError
};

/*!
  @typedef SBStreamEvent
  @discussion
    An enumeration of the events which will be passed to an SBStream's
    delegate.
*/
typedef SBUInteger SBStreamEvent;
enum {
  SBStreamEventNone             = 0,
  SBStreamEventOpenCompleted    = 1UL << 0,
  SBStreamEventBytesAvailable   = 1UL << 1,
  SBStreamEventSpaceAvailable   = 1UL << 2,
  SBStreamEventErrorOccurred    = 1UL << 3,
  SBStreamEventEndEncountered   = 1UL << 4
};


/*!
  @class SBStream
  @discussion
    An SBStream is an abstract base class for input and output streams.  Instances of
    this class should never be instantiated -- use the appropriate methods of
    SBInputStream or SBOutputStream.
*/
@interface SBStream : SBObject <SBStreamDelegate>

/*!
  @method open
  @discussion
    Attempt to prepare the i/o stream for reading or writing.  Check the streamStatus
    to verify that the stream is in the SBStreamStatusOpen state after invoking this
    method; the status will be SBStreamStatusError if an error was encountered.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.
*/
- (void) open;

/*!
  @method close
  @discussion
    Finalize a stream -- for a memory-based stream this may entail releasing its backing
    buffer; for a file-based stream, the file descriptor will be closed.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.
*/
- (void) close;

/*!
  @method delegate
  @discussion
    Returns the receiver's delegate object, which will receive stream:handleEvent: messages
    as the receiver transitions between states.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.
*/
- (id<SBStreamDelegate>) delegate;

/*!
  @method setDelegate:
  @dicussion
    Sets the receiver's delegate object, which will receive stream:handleEvent: messages
    as the receiver transitions between states.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.  Subclasses'
    implementations must observe the rule that setting the delegate to nil equates to
    making the receiver itself the delegate!
*/
- (void) setDelegate:(id<SBStreamDelegate>)delegate;

/*!
  @method propertyForKey:
  @discussion
    Returns a stream property as identified by aKey or nil if the property is undefined for
    the receiver.  Different kinds of streams respond to different keys.
    
    Subclasses of SBInputStream/SBOutputStream should override this method to respond to
    applicable keys.
*/
- (id) propertyForKey:(SBString*)aKey;

/*!
  @method setProperty:forKey:
  @discussion
    Attempts to assign a value to a stream property as identified by aKey.  Returns YES if
    the property was changed, NO if the property could not be changed or the receiver
    does not respond to aKey.
    
    Subclasses of SBInputStream/SBOutputStream should override this method to respond to
    applicable keys.
*/
- (BOOL) setProperty:(id)property forKey:(SBString*)aKey;

/*!
  @method streamStatus
  @discussion
    Returns the receiver's current status.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.
*/
- (SBStreamStatus) streamStatus;

/*!
  @method streamError
  @discussion
    Returns the last-registered SBError associated with the receiver.
    
    Subclasses of SBInputStream/SBOutputStream must override this method.
*/
- (SBError*) streamError;

/*!
  @method scheduleInRunLoop:forMode:
  @discussion
    Schedule the receiver to be afforded asynchronous i/o operation when
    theRunLoop is given time in aMode.
*/
- (void) scheduleInRunLoop:(SBRunLoop*)theRunLoop forMode:(SBString*)aMode;
/*!
  @method removeFromRunLoop:forMode:
  @discussion
    If the receiver is scheduled for processing when theRunLoop is given time
    in aMode, remove it.
*/
- (void) removeFromRunLoop:(SBRunLoop*)theRunLoop forMode:(SBString*)aMode;

@end

/*!
  @class SBInputStream
  @discussion
    Instances of SBInputStream provide a generalized interface to input sources.  The class
    handles in-memory buffers and filesystem paths as input sources.
    
    Subclasses of SBInputStream must implement the methods defined by the SBStream class.
    In addition, the
    
      - (SBUInteger) read:(void*)buffer maxLength:(SBUInteger)length;
      - (BOOL) getBuffer:(void**)buffer length:(SBUInteger*)length;
      - (BOOL) hasBytesAvailable;
      - (void) stream:(SBStream*)aStream handleEvent:(SBStreamEvent)eventCode;
      
    methods should also be overridden.
*/
@interface SBInputStream : SBStream

/*!
  @method inputStreamWithData:
  @discussion
    Returns a new, autoreleased SBInputStream instance which uses theData as its in-memory
    input source.  The incoming SBData object is copied by the receiver.
*/
+ (id) inputStreamWithData:(SBData*)theData;

/*!
  @method inputStreamWithFileAtPath:
  @discussion
    Returns a new, autoreleased SBInputStream instance which uses the given filesystem
    path, aPath, as its input source.
*/
+ (id) inputStreamWithFileAtPath:(SBString*)aPath;

/*!
  @method inputStreamWithFileHandle:
  @discussion
    Returns a new, autoreleased SBInputStream instance which uses the given SBFileHandle
    object, aFileHandle, as its input source.
*/
+ (id) inputStreamWithFileHandle:(SBFileHandle*)aFileHandle;

/*!
  @method initWithData:
  @discussion
    Initializes an SBInputStream instance to use theData as its in-memory input source.
    The incoming SBData object is copied by the receiver.
*/
- (id) initWithData:(SBData*)theData;

/*!
  @method initWithFileAtPath:
  @discussion
    Initializes an SBInputStream instance to use the given filesystem path, aPath, as its
    input source.
*/
- (id) initWithFileAtPath:(SBString*)aPath;

/*!
  @method initWithFileHandle:
  @discussion
    Initializes an SBInputStream instance to use the given SBFileHandle object, aFileHandle,
    as its input source.
*/
- (id) initWithFileHandle:(SBFileHandle*)aFileHandle;

/*!
  @method read:maxLength:
  @discussion
    Attempt to read a maximum of length octets from the receiver's input source into the
    provided buffer.  Returns the number of octets actually read, or zero if no data
    remains (or there was an error).
    
    If the return value is zero, then the nature of the problem can be determined using
    the streamStatus and streamError messages.
*/
- (SBUInteger) read:(void*)buffer maxLength:(SBUInteger)length;

/*!
  @method getBuffer:length:
  @discussion
    For a subclass which uses an internal i/o buffer of some kind, returns (by reference)
    a pointer to that buffer and (by reference) the number of bytes available in it. Returns
    YES if a buffer is available and was assigned, NO otherwise.
*/
- (BOOL) getBuffer:(void**)buffer length:(SBUInteger*)length;

/*!
  @method hasBytesAvailable
  @discussion
    Returns YES if the receiver is in a state whereby the read:maxLength: message may not
    block (there are bytes available to be read).  Subclasses which cannot establish such
    a condition should merely return YES, indicating that the only way to know if data is
    available is to actually perform a read:maxLength: operation. 
*/
- (BOOL) hasBytesAvailable;

@end

/*!
  @class SBOutputStream
  @discussion
    Instances of SBOutputStream provide a generalized interface to output destinations.  The
    class handles in-memory buffers and filesystem paths as output destinations.
    
    Subclasses of SBOutputStream must implement the methods defined by the SBStream class.
    In addition, the
    
      - (SBUInteger) write:(void*)buffer length:(SBUInteger)length;
      - (BOOL) hasSpaceAvailable;
      - (void) stream:(SBStream*)aStream handleEvent:(SBStreamEvent)eventCode;
      
    methods should also be overridden.
*/
@interface SBOutputStream : SBStream

/*!
  @method outputStreamToMemory
  @discussion
    Returns a new, autoreleased SBOutputStream instance which uses a growable memory buffer as
    its output destination.
*/
+ (id) outputStreamToMemory;

/*!
  @method outputStreamToBuffer:capacity:
  @discussion
    Returns a new, autoreleased SBOutputStream instance which uses a fixed-size external
    memory buffer as its output destination.
*/
+ (id) outputStreamToBuffer:(void*)buffer capacity:(SBUInteger)capacity;

/*!
  @method outputStreamToFileAtPath:append:
  @discussion
    Returns a new, autoreleased SBOutputStream instance which uses the provided filesystem
    path as its output destination.  The shouldAppend flag specifies whether the write
    pointer should initially be placed at the end or the beginning of the file.
*/
+ (id) outputStreamToFileAtPath:(SBString*)path append:(BOOL)shouldAppend;

/*!
  @method initToMemory
  @discussion
    Initialize an SBOutputStream instance to use a growable memory buffer as its output
    destination.
*/
- (id) initToMemory;

/*!
  @method initToBuffer:capacity:
  @discussion
    Initialize an SBOutputStream instance to use a fixed-size external memory buffer as its
    output destination.  Through the lifetime of the receiver no other code should modify
    the contents of buffer.
*/
- (id) initToBuffer:(void*)buffer capacity:(SBUInteger)capacity;

/*!
  @method initToFileAtPath:append:
  @discussion
    Initialize an SBOutputStream instance which uses the provided filesystem path as its
    output destination.  The shouldAppend flag specifies whether the write pointer should
    initially be placed at the end or the beginning of the file.
*/
- (id) initToFileAtPath:(SBString*)aPath append:(BOOL)shouldAppend;

/*!
  @method write:length:
  @discussion
    Attempt to write length octets located at buffer to the stream's output destination.
    Returns the number of octets actually written.
*/
- (SBUInteger) write:(void*)buffer length:(SBUInteger)length;

/*!
  @method hasSpaceAvailable
  @discussion
    Returns YES if the output destination for the receiver is able to immediately receive
    additional data via the write:length: method.
*/
- (BOOL) hasSpaceAvailable;

@end

@interface SBStream(SBSocketStreamCreationExtensions)

/*!
  @method getStreamsToHost:port:inputStream:outputStream:
  @discussion
    Attempts to open a TCP stream to the given TCP/IP port on host.  If successful, inputStream and
    outputStream are set to SBStream instances that handle i/o for the TCP connection.
*/
+ (void) getStreamsToHost:(SBHost*)host port:(SBUInteger)port inputStream:(SBInputStream**)inputStream outputStream:(SBOutputStream**)outputStream;

@end

/*!
  @protocol SBStreamDelegate
  @discussion
    Protocol which should be adopted by any class that will act as a delegate of an
    SBStream object.
*/
@protocol SBStreamDelegate

/*!
  @method stream:handleEvent:
  @discussion
    Invoked on aStream's delegate when the given event occurs.
*/
- (void) stream:(SBStream*)aStream handleEvent:(SBStreamEvent)eventCode;

@end

/*!
  @constant SBStreamFileCurrentOffsetKey
  @discussion
    Key used with propertyForKey: and setProperty:forKey: to get/set the current offset
    (relative to the first octet of the stream).  The property is an instance of
    SBNumber.
*/
extern SBString* const SBStreamFileCurrentOffsetKey;

/*!
  @constant SBStreamDataWrittenToMemoryStreamKey
  @discussion
    Key used with propertyForKey: to retrieve an instance of SBData which contains:
    
    - For SBInputStream instances using in-memory data sources, the data source
    - For SBOutputStream instances using in-memory data destinations, the data thus
      far written to the stream
*/
extern SBString* const SBStreamDataWrittenToMemoryStreamKey;

/*!
  @constant SBStreamSocketSecurityLevelKey
  @discussion
    Key used with propertyForKey: and setProperty:forKey: to get/set the SSL encryption
    method in-use with the stream.  The value is a string from the following set of
    SBString constants:
    
    - SBStreamSocketSecurityLevelNone
    - SBStreamSocketSecurityLevelSSLv2
    - SBStreamSocketSecurityLevelSSLv3
    - SBStreamSocketSecurityLevelTLSv1
    - SBStreamSocketSecurityLevelNegotiatedSSL
*/
extern SBString* const SBStreamSocketSecurityLevelKey;
extern SBString* const SBStreamSocketSecurityLevelNone;
extern SBString* const SBStreamSocketSecurityLevelSSLv2;
extern SBString* const SBStreamSocketSecurityLevelSSLv3;
extern SBString* const SBStreamSocketSecurityLevelTLSv1;
extern SBString* const SBStreamSocketSecurityLevelNegotiatedSSL;
