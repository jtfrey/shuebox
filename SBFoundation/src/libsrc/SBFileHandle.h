//
// SBFoundation : ObjC Class Library for Solaris
// SBFileHandle.h
//
// Generalized interface to Unix file handles.
//
// Copyright (c) 2010
// University of Delaware
//
// $Id$
//

#import "SBObject.h"

/*!
  @typedef SBFileOffset
  @discussion
    Type used for byte offsets in file i/o.
*/
typedef off_t SBFileOffset;

@class SBData, SBArray;

/*!
  @class SBFileHandle
  @discussion
    SBFileHandle is an abstract base class that represents input and output channels, typically
    embodied by files.  A file handle can be readable, writable, or both.  The class uses a single
    read/write pointer that (in general) is positionable at arbitrary offsets.
    
    The majority of the SBFileHandle methods will raise an SBException on error conditions; all
    such exceptions are named according to the string constant SBFileHandleOperationException.
    
    Behind the scenes there is a hierarchy of private concrete subclasses that implement the different
    entities to which an SBFileHandle could be associated.
*/
@interface SBFileHandle : SBObject

/*!
  @method isReadable
  @discussion
    Returns boolean YES if data can be read from the receiver.
*/
- (BOOL) isReadable;

/*!
  @method isWritable
  @discussion
    Returns boolean YES if data can be written to the receiver.
*/
- (BOOL) isWritable;

/*!
  @method availableData
  @discussion
    If the receiver is readable and any data is avalable for reading,
    do so and return it wrapped in an SBData object.
*/
- (SBData*) availableData;

/*!
  @method readDataToEndOfFile
  @discussion
    If the receiver is readable, read until end-of-file is reached
    and return the data read as an SBData object.
*/
- (SBData*) readDataToEndOfFile;

/*!
  @method readDataOfLength:
  @discussion
    If the receiver is readable, read at most length bytes (or to end-of-file)
    and return the data read as an SBData object.
*/
- (SBData*) readDataOfLength:(SBUInteger)length;

/*!
  @method writeData:
  @discussion
    If the receiver is writable, write the contents of the data object at the current
    offset.
*/
- (void) writeData:(SBData*)data;

/*!
  @method offsetInFile
  @discussion
    Returns the receiver's current read/write file pointer.
*/
- (SBFileOffset) offsetInFile;

/*!
  @method seekToEndOfFile
  @discussion
    Attempt to reposition the receiver's file pointer at the end-of-file and, if
    successful, return the offset of that end-of-file.
*/
- (SBFileOffset) seekToEndOfFile;

/*!
  @method seekToFileOffset:
  @discussion
    Attempt to reposition the receiver's file pointer to the given offset relative to
    the start of the file.
*/
- (void) seekToFileOffset:(SBFileOffset)offset;

/*!
  @method truncateFileAtOffset:
  @discussion
    If the receiver is writable, set it to be offset bytes in length.
*/
- (void) truncateFileAtOffset:(SBFileOffset)offset;

/*!
  @method synchronizeFile
  @discussion
    If the receiver is writable, force all modified data and attributes to be flushed to
    the storage media behind the file (see fsync()). 
*/
- (void) synchronizeFile;

/*!
  @method closeFile
  @discussion
    Close the file associated with the receiver.  If the receiver is writable, all modified
    data and attributes will be flushed to the storage media.
*/
- (void) closeFile;

@end

/*!
  @category SBFileHandle(SBFileHandleCreation)
  @discussion
    Methods that allocate and initialize SBFileHandle instances.
*/
@interface SBFileHandle(SBFileHandleCreation)

/*!
  @method fileHandleWithStandardInput
  @discussion
    Returns a readable shared SBFileHandle object that wraps stdin.
*/
+ (id) fileHandleWithStandardInput;

/*!
  @method fileHandleWithStandardOutput
  @discussion
    Returns a writable shared SBFileHandle object that wraps stdout.
*/
+ (id) fileHandleWithStandardOutput;

/*!
  @method fileHandleWithStandardError
  @discussion
    Returns a writable shared SBFileHandle object that wraps stderr.
*/
+ (id) fileHandleWithStandardError;

/*!
  @method fileHandleWithNullDevice
  @discussion
    Returns a writable shared SBFileHandle object that discards all data written to it.
*/
+ (id) fileHandleWithNullDevice;

/*!
  @method fileHandleForReadingAtPath:
  @discussion
    Returns an autoreleased SBFileHandle object that allows for reading from the file at path.
*/
+ (id) fileHandleForReadingAtPath:(SBString*)path;

/*!
  @method fileHandleForWritingAtPath:
  @discussion
    Returns an autoreleased SBFileHandle object that allows for writing to the file at path.
*/
+ (id) fileHandleForWritingAtPath:(SBString*)path;

/*!
  @method fileHandleForUpdatingAtPath:
  @discussion
    Returns an autoreleased SBFileHandle object that allows for reading from and writing to
    the file at path.
*/
+ (id) fileHandleForUpdatingAtPath:(SBString*)path;

@end

/*!
  @category SBFileHandle(SBFileHandleUnixSpecific)
  @discussion
    Methods of SBFileHandle that are particular to Unix OSes.
*/
@interface SBFileHandle(SBFileHandleUnixSpecific)

/*!
  @method initWithFileDescriptor:
  @discussion
    Initialize the receiver to wrap the given file descriptor, fd, with implicit read and write
    capabilities.
    
    When the receiver is deallocated the file descriptor will NOT be closed.
*/
- (id) initWithFileDescriptor:(int)fd;

/*!
  @method initWithFileDescriptor:closeOnDealloc:
  @discussion
    Initialize the receiver to wrap the given file descriptor, fd, with implicit read and write
    capabilities.
    
    When the receiver is deallocated the file descriptor will only be closed if shouldClose is
    YES.
*/
- (id) initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)shouldClose;

/*!
  @method fileDescriptor
  @discussion
    Returns the Unix file descriptor associated with the receiver.
*/
- (int) fileDescriptor;

@end

/*!
  @class SBPipe
  @discussion
    SBPipe objects provide an object-oriented interface for accessing pipes.  An SBPipe object represents both ends
    of a pipe and enables communication through the pipe.  A pipe is a one-way communications channel between related
    processes; one process writes data, while the other process reads that data. The data that passes through the
    pipe is buffered; the size of the buffer is determined by the underlying operating system.
*/
@interface SBPipe : SBObject
{
  @private
  SBFileHandle*     _fileHandleForReading;
  SBFileHandle*     _fileHandleForWriting;
}

/*!
  @method pipe
  @discussion
    Allocate and initialize an autoreleased instance of the SBPipe class.
*/
+ (id) pipe;

/*!
  @method init
  @discussion
    Designated initializer; create the pipe and prepare the receiver's read and write file handles.
*/
- (id) init;

/*!
  @method fileHandleForReading
  @discussion
    Returns the SBFileHandle that represents the read end of the pipe.
*/
- (SBFileHandle*) fileHandleForReading;

/*!
  @method fileHandleForWriting
  @discussion
    Returns the SBFileHandle that represents the write end of the pipe.
*/
- (SBFileHandle*) fileHandleForWriting;

@end

/*!
  @constant SBFileHandleOperationException
  @discussion
    String constant that names all SBException's that can be thrown by the SBFileHandle and SBPipe classes.
*/
extern SBString* const SBFileHandleOperationException;
