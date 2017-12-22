# shuebox

Software written to support ye olde "SHUEBox" collaboration system.  SHUEBox -- short for Shared Hierarchical Upload and Edit Box -- was designed to be a longer-term variant of the UD "Dropbox" service.  Folks at UD could request a _collaboration_ that would house their data, split between one or more _repositories_ within the collaboration.  In its lifetime it supported the following types of repositories/access:

- simple WebDAV share
- Subversion (svn) repository
- Git repository

It was envisioned to support an extensive amount of self-service so that users would not have to rely on IT to:

- add/remove users
- add/remove repositories
- maintain access lists for repositories

The service went online in late 2008 and was taken down in December of 2017.

## Software

The SHUEBox system used Apache 2.2 with its native DAV support, the SVN plug-in to the native DAV, and some custom CGI that called into git.  A multi-tier authentication and authorization module was present to support native UD users and guests (specific to the system).  Other modules handled cookie-based credential caching and extensions to the native DAV properties (implemented all standard DAV quota properties).  See the __apache_modules__ directory for source code.

RESTful CGIs were written in support of the self-service aspects of the system.  The source code is found in the __cgi__ directory.  The source is lightweight, being written atop the SHUEBoxKit and SBFoundation libraries.

### SBFoundation

Back in 2007 - 2008 Mac OS X had my favorite programming environment:  Objective-C with the Foundation and AppKit frameworks.  The message-oriented nature of Objective-C appealed to my object-oriented sensibilities, and the number and sophistication of the classes available in the Foundation framework was great.  I wanted to have something similar on Solaris, that I could use to write the underpinnings of the SHUEBox system.

And thus was produced SBFoundation, a collection of Objective-C classes built atop the GNU `Object` class and its runtime:

- exception handling
- Unicode strings, character sets, and regular expressions (using the icu library)
- XML documents (using expat)
- Arrays, dictionaries, ordered sets
- threads and subprocesses
- runloops, i/o streams, timers
- emailer
- LDAP lookups
- ZFS introspection and configuration
- generic database API (with concrete Postgres implementation)
- HTTP classes (cookies, HTTP protocol helper, CGI base class)

The code is in the __SBFoundation__ directory.  It's fairly massive.

### SHUEBoxKit

In the spirit of Mac OS X's having the application implemented in a framework that sits atop Foundation, the SHUEBox software existed as a "kit" atop the SBFoundation.  The SHUEBoxKit contained classes that represented the important entities in SHUEBox:  collaborations, repositories, roles, and users.  The classes implemented all the necessary verbs for those entities:  create, remove, alter properties.  And the `SHUEBoxCGI` class extended the base `SBCGI` class with functionality needed by every CGI written for the system.

### scruffy

Since I loved the show Futurama at the time, I envisioned the important components of the system to be related to characters on the show.  Thus, all maintenance tasks would fall under the purview of Scruffy, the Planet Express janitor.  This daemon hooked to the SHUEBox Postgres database and listened for notifications.  The CGIs, making alterations to rows in the tables, would trigger these notifications.  Thus, while scruffy ran as root (to allow creation of new ZFS datasets, etc.) the CGIs could run as an unprivileged user and never directly have such privileges.

Scruffy was at its most simple a runloop that listened on a socket for Postgres notifications.  A dispatch table, in which each maintenance task registered itself, mapped changes to the database to actions performed.  It worked beautifully.  See __scruffy__ for the source code.
