//
// SHUEBox Web Console
// SBBase.j
//
// Application-wide additions to the API, etc.
//
// Copyright (c) 2011
// University of Delaware
//
// $Id$
//

@import <Foundation/Foundation.j>
@import <AppKit/AppKit.j>

@implementation CPDate(SHUEBox)

  + (CPDate) dateWithSHUEBoxString:(CPString)dateStr
  {
    /*dateStr = dateStr.replace("T", " ");
    var i = dateStr.lastIndexOf("-");
    if ( i > 0 ) {
      dateStr = dateStr.substr(0, i) + " " + dateStr.substr(i);
    } else if ( (i = dateStr.lastIndexOf("+")) > 0 ) {
      dateStr = dateStr.substr(0, i) + " " + dateStr.substr(i);
    }*/
    return [[CPDate alloc] initWithISO8601String:dateStr];
  }

//

  - (id)initWithISO8601String:(CPString)description
  {
    var format = /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([-+])(\d{2})(\d{2})/,
        d = description.match(new RegExp(format));

    if (!d || d.length != 10)
      [CPException raise:CPInvalidArgumentException
                    reason:"initWithString: the string must be of YYYY-MM-DDTHH:MM:SS±HHMM format"];

    var date = new Date(d[1], d[2] - 1, d[3]),
        timeZoneOffset =  (Number(d[8]) * 60 + Number(d[9])) * (d[7] === '-' ? -1 : 1);

    date.setHours(d[4]);
    date.setMinutes(d[5]);
    date.setSeconds(d[6]);

    self = new Date(date.getTime() +  (timeZoneOffset + date.getTimezoneOffset()) * 60 * 1000);
    return self;
  }

//

  - (CPString) iso8601String
  {
    return [CPString stringWithFormat:@"%04d-%02d-%02dT%02d:%02d:%02d%s",
                self.getFullYear(),
                self.getMonth() + 1,
                self.getDate(),
                self.getHours(),
                self.getMinutes(),
                self.getSeconds(),
                [CPDate timezoneOffsetString:self.getTimezoneOffset()]
              ];
  }

@end
