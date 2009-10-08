#!/usr/bin/perl

#
# (c) Copyright 2004, 2005 Software Garden, Inc.
# All Rights Reserved.
# Subject to Software License at the end of this file
#

#
# ListGarden RSS Generator Program
#
# This is the main software for running the program.
# It is called by listgarden.pl, listgardencgi.pl,
# and listgardenwin.pl.
#
# Use the interface program appropriate to your needs.
#

   use strict;
   use CGI qw(:standard);
   use Time::Local;
   use Net::FTP;
   use utf8;
   use LWP::UserAgent;

#
# Export symbols
#

package ListGarden;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($programname %config_values process_request);
our $VERSION = '1.3.1';

# # # # # # # # # #
#
# HTML Constants & Templates
#
# # # # # # # # # #

our $programname = "ListGarden Program 1.3.1";

my @itemtags = qw(itemtitle itemlink itemdesc itempubdate itemguid itemguidispermalink itemdeschtml
                  itemenclosureurl itemenclosurelength itemenclosuretype itemaddlxml); # item field names
my @feedtags = qw(rsstitle rsslink rssdesc); # feed field names
my @publishfields = qw(ftpurl ftpfilename ftpdirectory ftpuser ftppassword publishfile 
                       maxpublishitems mintimepublishitems publishsequence
                       htmlversion rssfileurl htmlabove htmlitem htmlbelow htmlallitems
                       publishhtmlfile ftphtmlfilename ftphtmldirectory
                       backupftpfilename backupftpdirectory backuplocalfilename
                       backuptyperadio backuppasswords); # information for publishing
my %mintimemapping = ('000' => "None", '024' => "1 day", '048' => "2 days", '072' => "3 days", '168' => "1 week", '336' => "2 weeks"); # hours to string

my @optionfields = qw(optionsmaxsaved maxlistitems templatetitle templatelink templatedesc templateenclosuretype
                      templatedeschtml templatepubdate templatepubdateusecurrent templateguid templateguidispermalink templateguidradio templateaddlxml
                      displaytitle displaylink displaypubdate displaydesc displayguid displayenclosure
                      desclines channeladdlxml rsstagaddltext); # other feed options
my %templatefields = ('templatetitle' => 'itemtitle', 'templatelink' => 'itemlink', 'templatedesc' => 'itemdesc',
                      'templateenclosuretype' => 'itemenclosuretype',
                      'templatedeschtml' => 'itemdeschtml', 'templatepubdate' => 'itempubdate',
                      'templateguid' => 'itemguid', 'templateguidispermalink' => 'itemguidispermalink',
                      'templateaddlxml' => 'itemaddlxml'); # template to item mapping
my @browsefields = qw(browseftpurl browseftpdirectory browseftpuser browseftppassword browseurlprefix); # information for browsing

my @tablist = qw(Feed Items Publish Options Quit);

my %monthnames = ('Jan' => 0, 'Feb' => 1, 'Mar' => 2, 'Apr' => 3, 'May' => 4, 'Jun' => 5, 'Jul' => 6,
      'Aug' => 7, 'Sep' => 8, 'Oct' => 9, 'Nov' => 10, 'Dec' => 11);
my %daynames = ('Sun' => 1, 'Mon' => 2, 'Tue' => 3, 'Wed' => 4, 'Thu' => 5, 'Fri' => 6, 'Sat' => 7);

my $STYLE_STRING = <<"EOF";

body {
  background-color:#CCFFFF;
}

body, td, input, textarea, select {
  font-size:small;
  font-family:verdana,helvetica,sans-serif;
}
td {
  vertical-align: top;
}
form {
  margin:0px;
  padding:0px;
}
.sectiondark {
  border: 1px solid #99CC99;
  padding: 8px;
}
.sectionplain {
  padding: 10px;
}
.title {
  color: #006600;
  font-weight:bold;
  margin: 0em 0px 2pt 0px;
  padding: 0px 0px 0px 0px;
}
.title2 {
  border-top: 1px solid #006600;
  color: #006600;
  font-weight:bold;
  margin: .5em 0px 0px 0px;
  padding: 0px 0px 0px 0px;
}
.pagetitle {
  color: #006600;
  font-weight:bold;
  margin: 0em 0px 0px 0px;
  padding: 0px 0px 0px 0px;
}
.pagefeedinfo {
  color: black;
  font-size: smaller;
  margin: 1pt 0px 2pt 0px;
  padding: 0px 0px 0px 0px;
}
.desc {
  font-size:smaller;
  padding: 0px 0px .75em 0px;
}
.tabtable {font-size:small;}
.tab {
  border-bottom: 1px solid black;
  padding-bottom: 4px;
  }
.tab input {
  background-color:#CCCC99;
  color:black;
}
.tabselected {
  border-left: 1px solid black;
  border-right: 1px solid black;
  border-top: 1px solid black;
  background-color:#DDFFDD;
  color:black;
  padding: 1px 14px 0px 14px;
  text-align: center;
  font-weight: bold;
  }
.tab1 {
  border-bottom: 1px solid black;
  }
.tab2 {
  background-color:#DDFFDD;
  }
.tab2left {
  border-left: 1px solid black;
  background-color:#DDFFDD;
  padding-left:20px;
  }
.tab2right {
  border-right: 1px solid black;
  background-color:#DDFFDD;
  padding-left:20px;
  }
.ttbody {
  background-color:#DDFFDD;
  border-right: 1px solid black;
  border-left: 1px solid black;
  border-bottom: 1px solid black;
  padding: 0px 10px 4px 10px;
}
.head {
  border: 1px dashed #006600;
  padding: 6px;
  color: #006600;
  font-weight: bold;
  margin: 1em 0px .5em 0px;
}
.footer {
  border: 1px dashed #006600;
  padding: 6px;
  color: #006600;
  font-size: smaller;
  margin: 1em 0px .5em 0px;
}
input.small {
  font-size: smaller;
}
.itemheader {
  color: #006600;
  font-weight:bold;
  margin: .5em 0px 0px 0px;
  padding: 0px 0px 0px 0px;
}
.itemselected {
  color: #990000;
  font-weight:bold;
  margin: .5em 0px 0px 0px;
  padding: 0px 0px 0px 0px;
}
.selectedexample {
  color: #990000;
}
.itemtitle {
  border-left: 1px solid #99CC99;
  padding-left: 8px;
  margin: 4px 0px 0px 24px;
  font-weight: bold;
}
.itemlink {
  border-left: 1px solid #99CC99;
  padding: 0px 0px 0px 8px;
  margin-left: 24px;
  font-size: smaller;
}
.itemdesc {
  border-left: 1px dotted #99CC99;
  padding: 8px 0px 8px 8px;
  margin-left: 24px;
  font-size: smaller;
}
.itemmisc {
  border-left: 1px solid #99CC99;
  padding: 8px 0px 8px 8px;
  margin-left: 24px;
  font-size: smaller;
}
.itembuttons {
  float:right;
  clear:right;
  padding:5px 0px 0px 30px;
  border-top:1px solid #99CC99;
  margin:.5em 0px 0px 0px;
}
.warning {
  color: red;
}
.smallprompt {
  font-size: smaller;
}
.tdsmall {
  font-size: xx-small;
}
.itemmisc td {
  font-size: xx-small;
}
.browsefilename {
  font-size: smaller;
  font-weight: bold;
  background-color: white;
  padding-left: 4pt;
}
.browsefilesize {
  font-size: smaller;
  padding-left: 4pt;
}
.browsefiledate {
  font-size: smaller;
  padding-left: 4pt;
}
.browsecolumnhead {
  background-color: #99CC99;
  color: white;
  font-size: smaller;
  font-weight: bold;
  padding: 4pt 0 4pt 4pt;
}
EOF

my $defaulthtmlabove = <<"EOF";
<html>
<head>
<meta HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<title>Contents of RSS feed for: {{rsstitle}}</title>
<style type="text/css"><!--
body {font-family:verdana,helvetica,sans-serif;}
.above {font-size:smaller;background-color:#CCCCCC;padding:1em;margin-bottom:1em;}
.rsstitle {font-size:larger;font-weight:bold;}
.rssdesc {font-style:italic;margin-top:.5em;}
.rsspubdate {font-style:italic;}
.item {font-size:smaller;padding:0px 1em .5em 1em;}
.itemtitle {font-weight:bold;margin-bottom:1em;}
.itemdesc {margin:0px 0px 1em 2em;font-size:smaller;}
.itempubdate {font-style:italic;margin:0px 0px .5em 2em;font-size:smaller;}
.below {font-size:smaller;border-top:1px solid black;padding:.25em 1em 0px 1em;margin-top:.5em;}
.note {font-size:smaller;margin-top:1em;}
-->
</style>
</head>
<body>
<div class="above">
 <b>Contents of RSS feed for:</b><br><br>
 <div class="rsstitle"><a href="{{rsslink}}">{{rsstitle}}</a></div>
 <div class="rssdesc">{{rssdesc}}</div>
</div>
EOF

my $defaulthtmlitem = <<"EOF";
<div class="item">
 <div class="itemtitle"><a href="{{itemlink}}">{{itemtitle}}</a></div>
 <div class="itemdesc">{{itemdesc}}</div>
 <div class="itempubdate">Published: {{itempubdate}}</div>
</div>
EOF

my $defaulthtmlbelow = <<"EOF";
<div class="below">
 <div class="rsspubdate">Updated: {{rsspubdate}}</div>
 <div class="note">
  The URL to provide to an RSS aggregator when subscribing to this feed: <a href="{{rssfileurlraw}}">{{rssfileurl}}</a><br>
  (For more information about RSS see: <a href="http://rss.softwaregarden.com/aboutrss.html">What is RSS?</a>.)
 </div>
</div>
</body>
</html>
EOF

   my $datafiledefault = "listdata"; # default filename prefix to hold data and settings
   my $socketdefault = 6555; # default socket to listen to for browser

   my $securitycode = "not set!"; # Requests must have a parameter that matches this
   my $placeholderpw = "s a m e "; # Used by Save Publish Info and edit FTP password

   my $defaultmaxlistitems = 10; # default number of items listed per page

#
# Define configuration information from command line
#

   our %config_values;  # most configuration values

   $config_values{datafile} = $datafiledefault;
   $config_values{socket} = $socketdefault;

#
# Main Data
#

   my %datavalues;

# # # # # # # # # #
#   Subroutines
# # # # # # # # # #

# # # # # # # # # #
# process_request($querystring, $using_cgi)
#
# Responds to browser request and does all the work
# Returns $response, a string with the HTML response
# The $querystring is the raw query from the browser.
# Unless $using_cgi is present and true, a "security"
# parameter is used in each request to guard against
# URLs on web sites that guess we are running locally.
#

sub process_request {

   my ($querystring, $using_cgi) = @_;
   my $response;

   # Remember when we started

   my $start_clock_time = scalar localtime;
   my $start_program_time = times();

   # Get GMT time string

   my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime;
   my $dayname = qw(Sun Mon Tue Wed Thu Fri Sat)[$wday];
   my $monname = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
   my $dtstring = sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT", $dayname, $mday, $monname, $year+1900,
      $hour, $min, $sec);

   # Output start of HTML, including style information

   $response .= <<"EOF";
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN" "http://www.w3.org/TR/REC-html40/strict.dtd">
<html>
<head>
<meta HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<title>$programname</title>
<style type="text/css"><!--

$STYLE_STRING

-->
</style>
<script>
<!--
var setf = function() {1;}
// -->
</script>
</head>

<body onload="setf()">
EOF

   # Get CGI object to get parameters:

   $querystring ||= ""; # make sure has something

   my $q = new CGI($querystring);
   my %params = $q->Vars;

   if ($params{newtab} eq 'Quit') {
      return;
   }

   #
   # Check security code
   #
   # If not the same as ours, set it and wipe out parameters.
   # This is to prevent malicious web sites from linking
   # to a "known" local address and affect this app.
   #

   $securitycode = "" if $using_cgi; # Don't use if running through a web server

   if ($params{securitycode} ne $securitycode) {
      %params = ();
      $querystring = "";
      $securitycode = sprintf("%.14f", rand); # assign a random security code
      }

   # No parameters starts on "Feed" tab

   if ($querystring eq "") {
      $params{newtab} = "Feed";
      }

   #
   # Delete feed if requested
   #

   if ($params{deletefeed}) {
      my $fn = $params{deletefeednamelist};
      $fn =~ s/(\W|_)//g;
      unlink "$config_values{datafile}.feed.$fn.txt";
      $params{feedname} = "";
      }

   #
   # Default feed is first file
   #

   if (!$params{feedname}) {
      my $globstr = $config_values{datafile} . ".feed.*.txt";
      $globstr =~ s/ /?/g; # escape spaces (bsd_glob not available)
      my $fn = (glob ($globstr))[0];
      $fn =~ m/feed\.(.+?)\.txt$/;
      $params{feedname} = $1;
      }
   $config_values{feedname} = $params{feedname};

   #
   # Check to see if feedname selected -- then do operation
   #

   foreach my $p (keys %params) {  # go through all the parameters

      # Select feed

      if ($p =~ /^selectfeed(\w+)/) {
         $config_values{feedname} = $1;
         $params{feedname} = $config_values{feedname};
         }

      # Select and list feed

      if ($p =~ /^listfeed(\w+)/) {
         $config_values{feedname} = $1;
         $params{feedname} = $config_values{feedname};
         $params{newtab} = "Items";
         $params{itemmode} = "";
         }

      # Select and add item to feed

      if ($p =~ /^addfeed(\w+)/) {
         $config_values{feedname} = $1;
         $params{feedname} = $config_values{feedname};
         $params{newtab} = "Items";
         $params{itemmode} = "add";
         }
      }

   if ($params{choosefeed}) {
      $config_values{feedname} = $params{feednamelist};
      $params{feedname} = $config_values{feedname};
      }

   $config_values{feedname} =~ s/(\W|_)//g; # make sure only alphanumerics

   # If Add & Publish, then switch tabs and still do add

   if ($params{addonepublish}) {
      $params{addone} = "Add";
      $params{newtab} = "Publish";
      }

   #
   # Get current tab and switch if necessary
   #

   my $currenttab = $params{newtab} || $params{currenttab};

   #
   # Display tabs and other top stuff
   #

   $response .= <<"EOF";
<b>$programname</b>
<br><br>
<form name="f0" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<table cellpadding="0" cellspacing="0" width="600">
<tr>
EOF

   foreach my $tab (@tablist) {
      if ($currenttab eq $tab) {
         $response .= <<"EOF";
<td class="tab1">&nbsp;</td>
<td class="tabselected">$tab</td>
EOF
         }
      else {
         $response .= <<"EOF";
<td class="tab1">&nbsp;</td>
<td class="tab"><input type="submit" name="newtab" value="$tab"></td>
EOF
         }
      }

   $response .= <<"EOF";
<td class="tab1" width="100%">&nbsp;</td>
</tr>
<tr>
<td class="tab2left" width="1">&nbsp;</td>
EOF

   my $ncols = @tablist;
   $ncols = $ncols * 2 + 1;
   for (my $i=0; $i<$ncols-2; $i++) {
      $response .= <<"EOF";
<td class="tab2">&nbsp;</td>
EOF
      }

   $response .= <<"EOF";
<td class="tab2right">&nbsp;</td>
</tr>
</table>
EOF

   #
   # Read in datafile (if feedname defined)
   #

   my %datavalues;
   if ($params{feedname}) {
      open (DATAFILEIN, "$config_values{datafile}.feed.$config_values{feedname}.txt");
      while (<DATAFILEIN>) {
         chomp;
         s/\r//g; # remove CRs in case moved data from Windows
         s/^\x{EF}\x{BB}\x{BF}//; # remove UTF-8 Byte Order Mark if present
         my ($valname, $val) = split(/=/, $_, 2);
         $datavalues{$valname} = $val;

         # retrieve CR and LF's

         my %tc = ("\\" => "\\", "n" => "\n", "r" => "\r");
         $datavalues{$valname} =~ s/\\(\\|n|r)/$tc{$1}/eg;

         }
      close DATAFILEIN;
      }

   my $changed;   # if non-zero, then a change was posted

   #
   # *** Update an edited item
   #

   if ($params{saveitem}) {
      foreach my $vn (@itemtags) {
         $datavalues{"$vn$params{edititemnum}"} = $params{"edit$vn"};
         }

      $datavalues{"itempubdate$params{edititemnum}"} = $dtstring if $params{edititempubdateusecurrent};

      if (!$params{edititemguid}) {  # do the automatic guid stuff
         if ($params{edititemguidauto} eq 'auto') {
            $datavalues{"itemguid$params{edititemnum}"} = sprintf("%s-%04d-%02d-%02d-%02d-%02d-%02d",
               $config_values{feedname}, $year+1900, $mon+1, $mday, $hour, $min, $sec); # add one to zero-based month
            }
         elsif ($params{edititemguidauto} eq 'link') {
            $datavalues{"itemguid$params{edititemnum}"} = $datavalues{"itemlink$params{edititemnum}"};
            }
         }

      $changed++;
      }

   #
   # *** Cancel feed edit mode without saving
   #

   if ($params{cancelfeededit}) {
      # Nothing to do
      }

   #
   # *** Save edited feed info
   #

   if ($params{savefeededit}) {
      foreach my $vn (@feedtags) {
         $datavalues{$vn} = $params{"feededit$vn"};
         }
      $changed++; # assume all changed -- doesn't check for unchanged values
      }

   #
   # *** Save publish info
   #

   if ($params{savepublish}) {

      # The saved password is not used as an initial value for simple security reasons.
      # If blank, the initial value is blank; if not, the initial value is $placeholderpw.
      # Yes -- this means you can't set that as a password except from blank, but it's unlikely a problem.

      $params{editftppassword} = $datavalues{ftppassword} if ($datavalues{ftppassword} && $params{editftppassword} eq $placeholderpw);

      foreach my $vn (@publishfields) {
         $datavalues{$vn} = $params{"edit$vn"};
         }
      $datavalues{htmlabove} = $defaulthtmlabove if $params{setdefaultabove};
      $datavalues{htmlitem} = $defaulthtmlitem if $params{setdefaultitem};
      $datavalues{htmlbelow} = $defaulthtmlbelow if $params{setdefaultbelow};

      $changed++; # assume all changed -- doesn't check for unchanged values
      }


   #
   # *** Save options
   #

   if ($params{saveoptions}) {
      foreach my $vn (@optionfields) {
         $datavalues{$vn} = $params{"edit$vn"} || "";
         }
      $datavalues{maxlistitems} = 0 if $datavalues{maxlistitems} < 0; # make sure in range

      $changed++; # assume all changed -- doesn't check for unchanged values
      }


   #
   # *** Change browse values
   #

   if ($params{changebrowse}) {

      $params{editbrowseftppassword} = $datavalues{browseftppassword}
        if ($datavalues{browseftppassword} && $params{editbrowseftppassword} eq $placeholderpw);

      foreach my $vn (@browsefields) {
         $datavalues{$vn} = $params{"edit$vn"} || "";
         }

      $params{itemmode} = "enclosure";

      $changed++; # assume all changed -- doesn't check for unchanged values
      }


   #
   # *** Create a new item
   #

   if ($params{addone}) {
      $datavalues{numitems}--
         if ((0+$datavalues{optionsmaxsaved}) && $datavalues{numitems} >= $datavalues{optionsmaxsaved});
      for (my $i=$datavalues{numitems}; $i > 0 ; $i--) {
         foreach my $vn (@itemtags) {
            $datavalues{$vn . ($i+1)} = $datavalues{$vn . $i};
            }
         }
      $datavalues{numitems} += 1;

      foreach my $vn (@itemtags) {
         $datavalues{$vn . '1'} = $params{"new$vn"};
         }

      $datavalues{itempubdate1} = $dtstring if $params{newitempubdateusecurrent};

      if (!$params{newitemguid}) {  # do the automatic guid stuff
         if ($params{newitemguidauto} eq 'auto') {
            $datavalues{itemguid1} = sprintf("%s-%04d-%02d-%02d-%02d-%02d-%02d",
               $config_values{feedname}, $year+1900, $mon+1, $mday, $hour, $min, $sec); # add one to zero-based month
            }
         elsif ($params{newitemguidauto} eq 'link') {
            $datavalues{itemguid1} = $datavalues{itemlink1};
            }
         }
      delete $params{listitemnum};

      $changed++;
      }

   #
   # *** Get enclosure info
   #

   if ($params{enclosureinfo}) {
      $params{itemmode} = "enclosureinfo";
      }

   #
   # *** Browse enclosures
   #

   if ($params{browseenclosure}) {
      $params{itemmode} = "enclosure";
      }

   #
   # *** Create a new feed file if requested
   #

   if ($params{createfeed} ||
       ($params{newfeedname} && !$params{editfeedinfo} &&
        !$params{deletefeed} && ($currenttab eq "Feed"))) {

      $config_values{feedname} = $params{newfeedname};
      $config_values{feedname} =~ s/(\W|_)//g; # make sure only alphanumerics
      $changed++;
      %datavalues = ();
      $params{editfeedinfo} = "Edit"; # Since it's empty, start in edit mode
      }

   #
   # *** Pass along feed name, in form 0 and form 1 (two forms to help with making Enter
   # *** "press" the logical button)
   #

   $response .= <<"EOF";
<input type="hidden" name="feedname" value="$config_values{feedname}">
</form>
<table cellpadding="0" cellspacing="0" width="600">
<tr>
<td class="ttbody">
EOF

   #
   # *** Look for per-item operations: Edit, Delete, Move Up, Move Down
   #     These have the item number coded in
   #

   foreach my $p (keys %params) {  # go through all the parameters

      # *** Edit an item

      if ($p =~ /^itemedit(\d+)/) {

         $params{edititemnum} = $1;
         foreach my $vn (@itemtags) {  # Copy each value into edit params
            $params{"edit$vn"} = $datavalues{"$vn$1"};
            }
         $params{itemmode} = "edit"; # set mode
         }

      # *** Delete an item

      if ($p =~ /^itemdelete(\d+)/) {
         for (my $i=$1; $i < $datavalues{numitems}; $i++) {
            foreach my $vn (@itemtags) {  # copy each one after it down one
               $datavalues{$vn . $i} = $datavalues{$vn . ($i + 1)};
               }
            }
         foreach my $vn (@itemtags) {  # Erase last one
            delete $datavalues{$vn . $datavalues{numitems}};
            }
         if ($1 eq $datavalues{numitems} && $1 <= $params{listitemnum}) { # make sure listed page has the moved item
            $params{listitemnum} -= $datavalues{maxlistitems};
            $params{listitemnum} = 1 if $params{listitemnum} < 1;
            }
         $datavalues{numitems} -= 1;
         $changed++;
         }

      # *** Move an item up (to a lower number)

      if ($p =~ /^itemup(\d+)/) {
         if ($1 > 1) {
            foreach my $vn (@itemtags) {  # Switch the two
               my $temp = $datavalues{$vn . ($1 - 1)};
               $datavalues{$vn . ($1 - 1)} = $datavalues{$vn . $1};
               $datavalues{$vn . $1} = $temp;
               }
            if ($1 <= $params{listitemnum}) { # make sure listed page has the moved item
               $params{listitemnum} -= $datavalues{maxlistitems};
               $params{listitemnum} = 1 if $params{listitemnum} < 1;
               }
            }
         $changed++;
         }

      # *** Move an item down (to a higher number)

      if ($p =~ /^itemdown(\d+)/) {
         if ($1 < $datavalues{numitems}) {
            foreach my $vn (@itemtags) {  # Switch the two
               my $temp = $datavalues{$vn . ($1 + 1)};
               $datavalues{$vn . ($1 + 1)} = $datavalues{$vn . $1};
               $datavalues{$vn . $1} = $temp;
               }
            if ($1 + 1 >= $params{listitemnum} + $datavalues{maxlistitems}) { # make sure listed page has the moved item
               $params{listitemnum} ||= 1;
               $params{listitemnum} += $datavalues{maxlistitems};
               }
            }
         $changed++;
         }

      # *** List a section of items

      if ($p =~ /^listitem(\d+)/) {
         $params{listitemnum} = $1;
         }

      # *** Continue from browse

      if ($p =~ /^browsecontinue(\D+)(\d+)(\D*)/) {
         $params{itemmode} = $1;
         if ($2 > 0) { # file selected
            my $prefix = $1 eq "edit" ? "edit" : "new";
            my @files = split(/\|/, $params{browsefilenames});
            my ($name, $len) = split(/@/, @files[$2-1]);
            if ($3 eq "i") { # continue from successful info
               $params{$prefix . "itemenclosuretype"} = $name;
               $params{$prefix . "itemenclosurelength"} = $len;
               }
            else { # normal successful browse
               $params{$prefix . "itemenclosureurl"} = "$datavalues{browseurlprefix}$name";
               $params{$prefix . "itemenclosurelength"} = $len;
               if (!$datavalues{templateenclosuretype}) { # if type doesn't have a default, try to get from server
                  my $ua = LWP::UserAgent->new; # try to get 
                  $ua->agent($programname);
                  my $req = HTTP::Request->new(HEAD => $params{$prefix . "itemenclosureurl"});
                  $req->header('Accept' => '*/*');
                  my $res = $ua->request($req);
                  $params{$prefix . "itemenclosuretype"} = $res->content_type if $res->is_success;
                  }
               }
            }
         }
      }

   #
   # *** Load settings from a URL
   #

   my $loadfeedsettingsstr;

   if ($params{loadfeedsettings}) {
      my $urlsc = special_chars($params{loadfeedsettingsurl});
      $loadfeedsettingsstr = <<"EOF";
<div class="sectionplain">
<div class="itemheader">LOADING FROM URL:</div>
<div class="itemdesc">$urlsc:</div>
EOF

      my $ua = LWP::UserAgent->new; # try to get 
      $ua->agent($programname . "Settings Load");
      my $req = HTTP::Request->new(GET => $params{loadfeedsettingsurl});
      $req->header('Accept' => '*/*');
      my $res = $ua->request($req);
      if ($res->is_success) {
         $loadfeedsettingsstr .= <<"EOF";
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
EOF
         my @lines = split(/\n/, $res->content);
         my %tc = ("\\" => "\\", "n" => "\n", "r" => "\r");
         my %loadablevalues;
         foreach my $of (@optionfields) { # all options are OK to load
            $loadablevalues{$of} = 1;
            }
         my @otherloadablefields = qw(maxpublishitems mintimepublishitems publishsequence
                                   htmlversion htmlabove htmlitem htmlbelow htmlallitems);
         foreach my $of (@otherloadablefields) { # only these other fields are allowed
            $loadablevalues{$of} = 1;
            }
         foreach my $line (@lines) {
            $line =~ s/\r//g;
            $line =~ s/^\x{EF}\x{BB}\x{BF}//;
            my ($valname, $val) = split(/=/, $line, 2);
            my $valnamesc = special_chars($valname);
            $val =~ s/\\(\\|n|r)/$tc{$1}/eg;
            my $valsc = special_chars($val);
            $valsc =~ s/\n/<br>/g;
            if ($loadablevalues{$valname}) {
               $loadfeedsettingsstr .= "<tr><td><b>$valnamesc:&nbsp;</b></td><td>$valsc</td></tr>";
               $datavalues{$valname} = $val; # overwrite with new value
               $changed++;
               }
            else {
               next unless $valname; # ignore blank lines
               if ($valname =~ /^#/) { # comments start with "#", if has an "=" right after, then displayed
                  $loadfeedsettingsstr .= "<tr><td>comment:&nbsp;</td><td>$valsc</td></tr>" if ($valname eq "#");                  
                  }
               else {
                  $loadfeedsettingsstr .= "<tr><td><b>$valnamesc:&nbsp;</b></td><td><i>skipped</i></td></tr>";
                  }
               }
            }
         $loadfeedsettingsstr .= <<"EOF";
</table>
</div>
<div class="itemdesc">Loading complete.</div>
EOF
         }
      else {
         my $emsg = special_chars($res->status_line);
         $loadfeedsettingsstr .= <<"EOF";
<div class="itemdesc"><span class="warning"><b>Unable to load:</b></span><br>$emsg</div>
EOF
         }

      if (!$params{feedname}) {
         $loadfeedsettingsstr .= <<"EOF";
<span class="warning"><b>Feed not set.</b></span>
EOF
         }

      $loadfeedsettingsstr .= <<"EOF";
</div>
EOF
      }

   #
   # *** Write out data file if changed
   #

   if ($changed && $params{feedname}) {
      open (DATAFILEOUT, "> $config_values{datafile}.feed.$config_values{feedname}.txt");
      foreach my $vn (sort keys %datavalues) {

         # escape CR and LF

         my $val = $datavalues{$vn};
         $val =~ s/\\/\\\\/g;
         $val =~ s/\n/\\n/g;
         $val =~ s/\r/\\r/g;

         print DATAFILEOUT "$vn=$val\n"; 

         }
      close DATAFILEOUT;
      }

   #
   # ******
   # *
   # * Output appropriate material for the tab being displayed
   # *
   # ******
   #

   my %htmlvalue;  # hash to hold values as they will be inserted into the HTML

   #
   # Feed
   #

   if ($currenttab eq "Feed") {
      my $fnm = $config_values{feedname} || "*** None ***";
      my $rsstitlesc = special_chars($datavalues{rsstitle});
      $rsstitlesc = " [$rsstitlesc]" if $rsstitlesc;

      $response .= <<"EOF";
<div class="sectiondark">
<div class="pagetitle">SELECT FEED:</div>
<div class="pagefeedinfo">$fnm$rsstitlesc</div>
</div>
<div class="sectionplain">
EOF

      # Go through file names and get list of feeds

      my $feedlist;  # list for selecting
      my $feedlist2; # list for deleting
      my $globstr = $config_values{datafile} . ".feed.*.txt";
      $globstr =~ s/ /?/g; # escape spaces (bsd_glob not available)
                           # Note that "a c" and "abc" will both be found!!!
      my $count;
      foreach my $fname (glob ($globstr)) {
         $fname =~ m/feed\.(.+?)\.txt$/;
         my $sel;
         $count++;
         $sel = " selected" if $1 eq $config_values{feedname};
         my $fnameclean = special_chars($1);
         $feedlist .= <<"EOF";
EOF
         if ($sel) {
            $feedlist .= <<"EOF";
<tr bgcolor="#339933">
<td style="color:white;width:10em;"><b>$fnameclean</b>
</td>
<td>
&nbsp;
</td>
<td>
<input class="small" type="submit" name="listfeed$fnameclean" value="List...">
<input class="small" type="submit" name="addfeed$fnameclean" value="Add...">
</td>
EOF
            }
         else {
            $feedlist .= <<"EOF";
<tr>
<td>$fnameclean
</td>
<td>
<input class="small" type="submit" name="selectfeed$fnameclean" value="Select">
</td>
<td>
<input class="small" type="submit" name="listfeed$fnameclean" value="List...">
<input class="small" type="submit" name="addfeed$fnameclean" value="Add...">
</td>
EOF
            }
         $feedlist .= <<"EOF";
</tr>
EOF
         $feedlist2 .= "<option$sel>$fnameclean</option>\n";
         }

      if ($feedlist && !$params{editfeedinfo}) {
         $response .= <<"EOF";
<form name="f2" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<table cellpadding="3" cellspacing="0">
$feedlist
</table></form>
EOF
      }

         $response .= <<"EOF";
</div>
<div class="sectionplain">
EOF

      html_escape(\%datavalues, \%htmlvalue, @feedtags);

      if ($params{editfeedinfo} eq "Edit") {
         $response .= <<"EOF";
<form name="f1" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="itembuttons">
<input class="small" name="savefeededit" type="submit" value="Save">
<input class="small" name="cancelfeededit" type="submit" value="Cancel">
</div>
<div class="title">Channel Information:</div>
<div class="title">Title</div>
<input name="feededitrsstitle" type="text" size="60" value="$htmlvalue{rsstitle}">
<div class="desc">
The name of the channel. (A "channel" is what an RSS feed describes.)
This is usually the same name as your website or
the list about which the feed gives information (in text, not as a URL).
Example: The Aardvark Project Weblog.
</div>
<div class="title">Link</div>
<input name="feededitrsslink" type="text" size="60" value="$htmlvalue{rsslink}">
<div class="desc">
The URL of the HTML website or web page corresponding to this channel.
Example: http://www.aardvarkproject.com
</div>
<div class="title">Description</div>
<textarea name="feededitrssdesc" rows="3" cols="60" wrap="virtual">$htmlvalue{rssdesc}</textarea>
<div class="desc">
Phrase or sentence describing the channel.
</div>
<br>
<input name="savefeededit" type="submit" value="Save">
<input name="cancelfeededit" type="submit" value="Cancel">
</form>
<script>
<!--
var setf = function() {document.f1.feededitrsstitle.focus();}
// -->
</script>
EOF
         }

      elsif ($config_values{feedname}) {
         my $descbr = $htmlvalue{rssdesc};
         $descbr =~ s/\n/<br>/g;

         my $missingmsg1 = qq! <span class="warning">The required value for!;
         my $missingmsg2 = qq!is missing. Use Edit to correct.</span>!;
         my $rsstitlewarn = $datavalues{rsstitle} ? "" : "$missingmsg1 Title $missingmsg2";
         my $rsslinkwarn = $datavalues{rsslink} ? "" : "$missingmsg1 Link $missingmsg2";
         my $rssdescwarn = $datavalues{rssdesc} ? "" : "$missingmsg1 Description $missingmsg2";
         my $nitemsstr = $datavalues{numitems} || "0";

         $response .= <<"EOF";
<form name="f1" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="itembuttons"><input class="small" name="editfeedinfo" type="submit" value="Edit"></div>
<div class="itemheader">Channel Information:</div>
<div class="itemtitle">$htmlvalue{rsstitle}$rsstitlewarn</div>
<div class="itemlink">$htmlvalue{rsslink}$rsslinkwarn</div>
<div class="itemdesc">$descbr$rssdescwarn</div>
<div class="itemmisc">Number of items: <b>$nitemsstr</b></div>
</form>
EOF
        }

      else {
         $response .= <<"EOF";
<div class="itemheader">Use "Create A New Feed" below to create a feed before proceeding</div>
EOF
         }

      if (!$params{editfeedinfo}) {
         $response .= <<"EOF";
</div>
<br>
<form name="f3" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="sectiondark">
<div class="title">Create A New Feed</div>
<input name="newfeedname" type="text" size="12" maxlength="10" value=""> &nbsp;
<input name="createfeed" type="submit" value="Create">
<div class="desc">
1-10 characters, alphabetic and numeric only, no spaces or special characters
<br><br>This name is used as part of a filename for saving information about
the feed on your system while editing.
It is not used as part of the feed itself when loaded onto a server.
Use a short name that helps you distinguish this feed from any any others you create.
You will be able to assign the feed a title and description after you create it.
Later you can use the Publish screen to specify the filename on the server.
</div>
</div>
</form>
<br>
EOF
         if (!$config_values{feedname}) {
            $response .= <<"EOF";
<script>
<!--
var setf = function() {document.f3.newfeedname.focus();}
// -->
</script>
EOF
            }
         }

      if ($feedlist2 && !$params{editfeedinfo}) {
         $response .= <<"EOF";
<form name="f4" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="sectiondark">
<div class="title">Delete An Existing Feed</div>
<select name="deletefeednamelist" size="1">
$feedlist2
</select>
<input name="deletefeed" type="submit" value="Delete"
onclick="return window.confirm('Delete this feed?')">
</div>
</form>
<br>
EOF
         }

      }

   #
   # Items
   #

   if ($currenttab eq "Items") {

      my $rsstitlesc = special_chars($datavalues{rsstitle});

      $response .= <<"EOF";
<form name="f1" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="sectiondark">
EOF
      if ($params{switchitemdelete}) {
         $params{itemmode} = "delete";
         }

      if ($params{switchitemreorder}) {
         $params{itemmode} = "reorder";
         }

      if ($params{switchitemaddnew}) {
         $params{itemmode} = "add";
         }

      if ($params{switchitemlist}) {
         $params{itemmode} = "";
         }

      if (!$config_values{feedname}) {
         $response .= <<"EOF";
<span class="warning">The Feed Name has not been set.</span>
</div>
<div class="sectionplain">
Before you may edit items, you must specify a Feed Name.
Use the "Feed" screen to create one.
EOF
         }

      elsif ($params{itemmode} eq "edit") {
         my $n = $params{edititemnum};

         html_escape(\%params, \%htmlvalue,
            qw(edititemtitle edititemlink edititemdesc
               edititemenclosureurl edititemenclosurelength edititemenclosuretype
               edititempubdate edititemguid edititemguidispermalink edititemdeschtml edititemaddlxml));

         $htmlvalue{desclines} = $datavalues{desclines} || "5";
         my $usecurrent = $params{edititempubdateusecurrent} ? " CHECKED" : ""; # look for what's passed on from a browse
         my $guidautolink = ($params{edititemguidauto} eq "link") ? " CHECKED" : "";
         my $guidautoauto = ($params{edititemguidauto} eq "auto") ? " CHECKED" : "";
         my $guidautonone = (($params{edititemguidauto} eq "none") || (!defined $params{edititemguidauto})) ? " CHECKED" : "";

         $response .= <<"EOF";
<div style="float:right;">
<input class="small" name="saveitem" type="submit" value="Save">
<input class="small" name="saveitemcancel" type="submit" value="Cancel">
</div>
<div class="pagetitle">EDIT ITEM $params{edititemnum}:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<div class="sectionplain">
<input type="hidden" name="edititemnum" value="$params{edititemnum}">
<div class="title">Title</div>
<input name="edititemtitle" type="text" size="60" value="$htmlvalue{edititemtitle}">
<div class="desc">
The title of the item.
Title, Description, or both must be present.
</div>
<div class="title">Link</div>
<input name="edititemlink" type="text" size="60" value="$htmlvalue{edititemlink}">
<div class="desc">
The URL of the item.
<br>(Optional)
</div>
<div class="title">Description</div>
<textarea name="edititemdesc" rows="$htmlvalue{desclines}" cols="60" wrap="virtual">$htmlvalue{edititemdesc}</textarea>
<br><input name="edititemdeschtml" type="checkbox" value="CHECKED" $htmlvalue{edititemdeschtml}><span class="smallprompt">Includes HTML</span>
<div class="desc">
The text of the item, or a synopsis.
If the box is checked, HTML code in the description controls the text displayed.
If the box is unchecked, then the characters "&amp;", "&lt;", and "&gt;" will display as themselves,
however explicit line breaks (carriage returns) will be shown as line breaks, [b:some text] will be shown in <b>bold</b>,
[i:text] will be shown in <i>italic</i>, [quote:lots of text] will be shown indented,
and [http://some.url Some text] will be made into a link.
</div>
<div class="title">Enclosure</div>
<input name="edititemenclosureurl" type="text" size="60" value="$htmlvalue{edititemenclosureurl}">
<span class="smallprompt">URL</span>
<br>
<input class="small" name="browseenclosure" type="submit" value="Browse"> &nbsp;
<input name="edititemenclosurelength" type="text" size="9" value="$htmlvalue{edititemenclosurelength}">
<span class="smallprompt">Length</span> &nbsp;
<input name="edititemenclosuretype" type="text" size="12" value="$htmlvalue{edititemenclosuretype}">
<span class="smallprompt">Type</span><input name="browsecontinuetype" type="hidden" value="edit">
&nbsp;<input class="small" name="enclosureinfo" type="submit" value="Get Info">
<div class="desc">
Items may include the location of an optional "enclosure".
Some RSS readers/aggregators can use this information to automatically download that enclosure.
It is most commonly used as part of podcasting.
This is where you indicate the URL of the enclosure (which may be anywhere,
including on another website), the length of that file (in bytes), and MIME-type (e.g., audio/mpeg).
The Browse button lets you choose from a list of files already on a server and automatically
get the URL, length, and type.
If you type in a URL directly, the Get Info button lets you query the server for the file length and type.
(Optional, but if the Enclosure URL is non-blank then the Length and Type must also be present.
If the URL is blank then the Length and Type are ignored.)<br>
Example: http://www.domain.com/podcast/show15.mp3
</div>
<div class="title">PubDate</div>
<input name="edititempubdate" type="text" size="60" value="$htmlvalue{edititempubdate}">
<br><input name="edititempubdateusecurrent" type="checkbox" value="1"$usecurrent><span class="smallprompt">Set to current time</span>
<div class="desc">
The date/time when the item was published.
If the box is checked, the current time will be used when you press "Save".
The format must be: "Day, monthday Month year hour:min:sec GMT",<br>(e.g., Wed, 08 Oct 2003 19:29:11 GMT)
<br>(Optional)
</div>
<div class="title">GUID</div>
<input name="edititemguid" type="text" size="60" value="$htmlvalue{edititemguid}"><br>
<input name="edititemguidispermalink" type="checkbox" value="CHECKED" $htmlvalue{edititemguidispermalink}><span class="smallprompt">isPermaLink</span><br>
<span class="smallprompt"><b>If blank:</b></span> <input name="edititemguidauto" type="radio" value="link"$guidautolink><span class="smallprompt">Set to link</span>
&nbsp; <input name="edititemguidauto" type="radio" value="auto"$guidautoauto><span class="smallprompt">Create</span>
&nbsp; <input name="edititemguidauto" type="radio" value="none"$guidautonone><span class="smallprompt">Leave blank</span>
<div class="desc">
A string that uniquely identifies the item.
If "isPermLink" is checked, then readers can assume that the GUID value is a URL
that is a permanent link to the item.
If the GUID text box is left blank you can have a GUID automatically assigned based upon the current date/time
or have the current value of the Link field copied using the radio buttons.
<br>(Optional)
</div>
<div class="title">Item Additional XML</div>
<textarea name="edititemaddlxml" rows="4" cols="60" wrap="virtual">$htmlvalue{edititemaddlxml}</textarea>
<div class="desc">
This text will be added to the XML that makes up the &lt;item&gt;.
It is an advanced feature that should only be used by people who understand RSS and how to write XML.
It is used to add standard RSS elements (such as &lt;category&gt;)
and namespace-specific elements (such as Apple iTunes' &lt;itunes:keywords&gt;) that are not
currently supported by this program.
(You may want to indent the tags with three spaces to line up this XML with the other Item elements in the final XML output.)
</div>
<br>
<input name="saveitem" type="submit" value="Save">
<input name="saveitemcancel" type="submit" value="Cancel">
<input name="listitemnum" type="hidden" value="$params{listitemnum}">
<script>
<!--
var setf = function() {document.f1.edititemtitle.focus();}
// -->
</script> 
EOF
         }

      elsif ($params{itemmode} eq "add") {

         if (!defined $params{browsevalues}) { # if no values from before...
            foreach my $vn (keys %templatefields) {  # ...copy template values
               $params{"new$templatefields{$vn}"} = $datavalues{$vn};
               }
            }

         html_escape(\%params, \%htmlvalue,
            qw(newitemtitle newitemlink newitempubdate newitemdesc newitemdeschtml
               newitemenclosureurl newitemenclosurelength newitemenclosuretype
               newitempubdate newitemguid newitemguidispermalink newitemaddlxml));

         $htmlvalue{desclines} = $datavalues{desclines} || "5";

         my $pubdateusecurrent = (defined $datavalues{templatepubdateusecurrent}) ? $datavalues{templatepubdateusecurrent} : " CHECKED";
         $pubdateusecurrent = ($params{newitempubdateusecurrent} ? " CHECKED" : "") if defined $params{browsevalues}; # use continue value if from browsing

         my $guidradioauto = $datavalues{templateguidradio} eq 'auto' ? " CHECKED" : "";
         $guidradioauto = ($params{newitemguidauto} eq "auto" ? " CHECKED" : "") if defined $params{browsevalues};
         my $guidradionone = (($datavalues{templateguidradio} eq 'none') || !$datavalues{templateguidradio}) ? " CHECKED" : "";
         $guidradionone = ($params{newitemguidauto} eq "none" ? " CHECKED" : "") if defined $params{browsevalues};
         my $guidradiolink = $datavalues{templateguidradio} eq 'link' ? " CHECKED" : "";
         $guidradiolink = ($params{newitemguidauto} eq "link" ? " CHECKED" : "") if defined $params{browsevalues};

         $response .= <<"EOF";
<div style="float:right;">
<input class="small" name="addone" type="submit" value="Add Item">
<input class="small" name="addonepublish" type="submit" value="Add & Publish">
<input class="small" name="addonecancel" type="submit" value="Cancel">
</div>
<div class="pagetitle">ADD NEW ITEM:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<div class="sectionplain">
<div class="title">Title</div>
<input name="newitemtitle" type="text" size="60" value="$htmlvalue{newitemtitle}">
<div class="desc">
The title of the item.
</div>
<div class="title">Link</div>
<input name="newitemlink" type="text" size="60" value="$htmlvalue{newitemlink}">
<div class="desc">
The URL of the item.
<br>(Optional)
</div>
<div class="title">Description</div>
<textarea name="newitemdesc" rows="$htmlvalue{desclines}" cols="60" wrap="virtual">$htmlvalue{newitemdesc}</textarea>
<br><input name="newitemdeschtml" type="checkbox" value="CHECKED" $htmlvalue{newitemdeschtml}><span class="smallprompt">Includes HTML</span>
<div class="desc">
The text of the item, or a synopsis.<br>
If the box is checked, HTML code in the description controls the text displayed.<br>
If the box is unchecked, then the characters '&amp;', '&lt;', '&gt;', and '"' will be esacaped and display as themselves
and explicit line breaks (carriage returns) will be shown as line breaks, [b:some text] will be shown in <b>bold</b>,
[i:text] will be shown in <i>italic</i>, [quote:lots of text] will be shown indented,
and [http://some.url Some text] will be made into a link.
You can insert special characters unescaped with {{amp}}, {{lt}}, {{gt}}, {{quot}}, {{lbracket}}, {{rbracket}}, and {{lbrace}}.
</div>
<div class="title">Enclosure</div>
<input name="newitemenclosureurl" type="text" size="60" value="$htmlvalue{newitemenclosureurl}">
<span class="smallprompt">URL</span><br>
<input class="small" name="browseenclosure" type="submit" value="Browse"> &nbsp;
<input name="newitemenclosurelength" type="text" size="9" value="$htmlvalue{newitemenclosurelength}">
<span class="smallprompt">Length</span> &nbsp;
<input name="newitemenclosuretype" type="text" size="12" value="$htmlvalue{newitemenclosuretype}">
<span class="smallprompt">Type</span><input name="browsecontinuetype" type="hidden" value="add">
&nbsp;<input class="small" name="enclosureinfo" type="submit" value="Get Info">
<div class="desc">
Items may include the location of an optional "enclosure".
Some RSS readers/aggregators can use this information to automatically download that enclosure.
It is most commonly used as part of podcasting.
This is where you indicate the URL of the enclosure (which may be anywhere,
including on another website), the length of that file (in bytes), and MIME-type (e.g., audio/mpeg).
The Browse button lets you choose from a list of files already on a server and automatically
get the URL, length, and type.
If you type in a URL directly, the Get Info button lets you query the server for the file length and type.
(Optional, but if the Enclosure URL is non-blank then the Length and Type must also be present.
If the URL is blank then the Length and Type are ignored.)<br>
Example: http://www.domain.com/podcast/show15.mp3
</div>
<div class="title">PubDate</div>
<input name="newitempubdate" type="text" size="60" value="$htmlvalue{newitempubdate}">
<br><input name="newitempubdateusecurrent" type="checkbox" value="1"$pubdateusecurrent><span class="smallprompt">Set to current time</span>
<div class="desc">
The date/time when the item was published.
If the box is checked, the current time will be used when you press "Save".
The format must be: "Day, monthday Month year hour:min:sec GMT",<br>(e.g., Wed, 08 Oct 2003 19:29:11 GMT)
<br>(Optional)
</div>
<div class="title">GUID</div>
<input name="newitemguid" type="text" size="60" value="$htmlvalue{newitemguid}">
<br>
<input name="newitemguidispermalink" type="checkbox" value="CHECKED" $htmlvalue{newitemguidispermalink}><span class="smallprompt">isPermaLink</span>
<br>
<span class="smallprompt"><b>If blank:</b></span> <input name="newitemguidauto" type="radio" value="link"$guidradiolink><span class="smallprompt">Set to link</span>
&nbsp; <input name="newitemguidauto" type="radio" value="auto"$guidradioauto><span class="smallprompt">Create</span>
&nbsp; <input name="newitemguidauto" type="radio" value="none"$guidradionone><span class="smallprompt">Leave blank</span>
<div class="desc">
A string that uniquely identifies the item.
If "isPermLink" is checked, then readers can assume that the GUID value is a URL
that is a permanent link to the item.
If the GUID text box is left blank you can have a GUID automatically assigned based upon the current date/time
or have the current value of the Link field copied using the radio buttons.
<br>(Optional)
</div>
<div class="title">Item Additional XML</div>
<textarea name="newitemaddlxml" rows="4" cols="60" wrap="virtual">$htmlvalue{newitemaddlxml}</textarea>
<div class="desc">
This text will be added to the XML that makes up the &lt;item&gt;.
It is an advanced feature that should only be used by people who understand RSS and how to write XML.
It is used to add standard RSS elements (such as &lt;category&gt;)
and namespace-specific elements (such as Apple iTunes' &lt;itunes:keywords&gt;) that are not
currently supported by this program.
(You may want to indent the tags with three spaces to line up this XML with the other Item elements in the final XML output.)
</div>
<br>
<input name="addone" type="submit" value="Add Item">
<input name="addonepublish" type="submit" value="Add & Publish">
<input name="addonecancel" type="submit" value="Cancel">
<input name="listitemnum" type="hidden" value="$params{listitemnum}">
<br><br>
<div class="desc">
<i><b>Note:</b> To make adding new items less tedious,
default values for each of the fields may be set using the Options Template settings.
For example, you can make it so that when you add a new item
the PubDate "Set to current time" checkbox will start out being checked
or the Title field will have a particular prefix already entered.</i>
</div>
<script>
<!--
var setf = function() {document.f1.newitemtitle.focus();}
// -->
</script> 
EOF
         }

      elsif ($params{itemmode} eq "enclosureinfo") {
         $response .= <<"EOF";
<div style="float:right;">
<input class="small" name="browsecontinue$params{browsecontinuetype}0" type="submit" value="Cancel">
<input name="browsevalues" type="hidden" value="1"><input name="browsecontinuetype" type="hidden" value="$params{browsecontinuetype}">
</div>
<div class="pagetitle">GET ENCLOSURE INFORMATION:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
EOF
         foreach my $p (keys %params) {  # go through all the parameters and repeat those we want to propagate
            if (($p =~ /^edititem/) || ($p =~ /^newitem/)) {
               my $scp = special_chars($params{$p});
               $response .= <<"EOF";
<input name="$p" type="hidden" value="$scp">
EOF
               }
            }

         my $url = $params{($params{browsecontinuetype} eq "edit" ? "edit" : "new") . "itemenclosureurl"};

         my $ua = LWP::UserAgent->new;
         $ua->agent($programname);

         my $req = HTTP::Request->new(HEAD => $url);
         $req->header('Accept' => '*/*');

         my $res = $ua->request($req);

         $url = special_chars($url);

         if ($res->is_success) {
            my $contenttype = special_chars($res->content_type);
            my $contentlength = special_chars($res->content_length);
            my $modified = localtime($res->last_modified);

            $response .= <<"EOF";
<br>
<div class="sectiondark">
<div class="title">INFORMATION RETRIEVED FROM WEB SERVER:</div>
<div class="itemlink"><b>URL:</b><br>$url<br><br>
<b>Last modified:</b><br>$modified<br><br>
<b>Content Length:</b><br>$contentlength bytes<br><br>
<b>Content Type:</b><br>$contenttype<br><br>
</div>
<div class="desc">
The values above are what the web server returns when you request information about that URL.
If you press the "Save" button below, the Length and Type values will be used for the enclosure.
</div>
<input name="browsefilenames" type="hidden" value="$contenttype\@$contentlength|">
<input name="browsecontinue$params{browsecontinuetype}1i" type="submit" value="Save">
</div>
<br>
<script>
<!--
var setf = function() {document.f1.browsecontinue$params{browsecontinuetype}1i.focus();}
// -->
</script> 
EOF
            }
         else {
            my $emsg = special_chars($res->status_line);
            $response .= <<"EOF";
<br>
<div class="sectiondark">
<div class="title">UNABLE TO RETRIEVE INFORMATION FROM WEB SERVER:</div>
<div class="itemlink"><b>URL:</b><br>$url<br><br>
<b>Error:</b><br>
<span class="warning">$emsg</span>
<br><br>
</div>
<div class="desc">
The values for Length and Type will not be changed.
</div>
<input name="browsecontinue$params{browsecontinuetype}0" type="submit" value="OK">
<br>
<script>
<!--
var setf = function() {document.f1.browsecontinue$params{browsecontinuetype}0[1].focus();}
// -->
</script> 
EOF
            }
         }

      elsif ($params{itemmode} eq "enclosure") {

         html_escape(\%datavalues, \%htmlvalue, @browsefields);

         my $pwplaceholder = $datavalues{browseftppassword} ? $placeholderpw : ""; # Don't let real password be used

         $response .= <<"EOF";
<div style="float:right;">
<input class="small" name="browsecontinue$params{browsecontinuetype}0" type="submit" value="Cancel">
<input name="browsevalues" type="hidden" value="1"><input name="browsecontinuetype" type="hidden" value="$params{browsecontinuetype}">
</div>
<div class="pagetitle">SPECIFY ENCLOSURE:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
EOF

         my $ftp;
         $ftp = Net::FTP->new($datavalues{browseftpurl}, Debug => 0, Passive => 1, Timeout => 30) if $datavalues{browseftpurl};
         if ($ftp) {
            my $ok = $ftp->login($datavalues{browseftpuser}, $datavalues{browseftppassword});
            $ok = $ftp->cwd($datavalues{browseftpdirectory}) if ($ok && $datavalues{browseftpdirectory});
            my @dir;
            @dir = $ftp->dir if $ok;
            my $filetable;
            my $filenumber;
            my $filenames;
            my (@fsize, @fmon, @fday, @fname, @fhour, @fmin, @fyear, @ftime);
            foreach my $line (@dir) { # go through once to find values to sort
               my ($access, $links, $owner, $group, $s, $m, $d, $timeyr, $n) = split(" ", $line, 9);
               next unless $access =~ /^-/;
               $filenumber++;
               ($fsize[$filenumber], $fmon[$filenumber], $fday[$filenumber], $fname[$filenumber]) = ($s, ucfirst lc $m, $d, $n);
               if ($timeyr =~ /:/) {
                  ($fhour[$filenumber], $fmin[$filenumber]) = split(/:/, $timeyr);
                  $fyear[$filenumber] = $year + 1900;
                  }
               else {
                  ($fyear[$filenumber], $fhour[$filenumber], $fmin[$filenumber]) = ($timeyr, 0, 0);
                  }
               $ftime[$filenumber] = Time::Local::timegm(0, $fmin[$filenumber], $fhour[$filenumber], $fday[$filenumber],
                                    $monthnames{$fmon[$filenumber]}, $fyear[$filenumber]-1900);
               }

            my @browsesort = sort { $ftime[$a] <=> $ftime[$b] } 1..$filenumber;

            for (my $j = 1; $j <= $filenumber; $j++) {
               my $i = $browsesort[$filenumber - $j];
               my $fnameclean = special_chars($fname[$i]);
               my $fdatestr = sprintf("%s %d, %04d %02d:%02d", $fmon[$i], $fday[$i], $fyear[$i], $fhour[$i] ,$fmin[$i]);
               $filenames .= "$fname[$i]\@$fsize[$i]|";
               $filetable .=  <<"EOF";
<tr>
<td><input class="small" type="submit" name="browsecontinue$params{browsecontinuetype}$j" value="Select"></td>
<td class="browsefilename">$fnameclean</td>
<td class="browsefilesize">$fsize[$i]</td>
<td class="browsefiledate">$fdatestr</td>
</tr>
EOF

               }
            my $filenamesclean = special_chars($filenames);
            $response .= <<"EOF";
<div class="sectionplain">
<div class="title">Files In Directory: $htmlvalue{browseftpdirectory}</div>
EOF
            if (!$ok) {
               my $msgsc = special_chars($ftp->message);
               $response .= qq!<span class="warning">Unable to access information by FTP.<br>Error status: $msgsc.</span><br><br>!;
               }
            else {
               $response .= <<"EOF";
<br><table>
<tr><td>&nbsp;</td><td class="browsecolumnhead">NAME&nbsp;</td><td class="browsecolumnhead">SIZE&nbsp;</td><td class="browsecolumnhead">DATE&nbsp;</td></tr>
$filetable
</table>
</div>
<input name="browsefilenames" type="hidden" value="$filenamesclean">
EOF
              }
            $ftp->quit;
            }
         else {
            my $msgsc = special_chars($@);
            $msgsc = <<"EOF" unless $datavalues{browseftpurl};
FTP URL not set. Please provide the values below and then press the "Update Browse Values" button.
EOF
            $response .= qq!<span class="warning"><br>Unable to access information by FTP.<br><br>Error status: $msgsc.</span><br><br>!;
            }

         foreach my $p (keys %params) {  # go through all the parameters and repeat those we want to propagate
            if (($p =~ /^edititem/) || ($p =~ /^newitem/)) {
               my $scp = special_chars($params{$p});
               $response .= <<"EOF";
<input name="$p" type="hidden" value="$scp">
EOF
               }
            }

#         foreach my $p (keys %params) {  # display all the parameters for debugging
#            $response .= "$p: '$params{$p}' ";
#            }

          $response .= <<"EOF";
<div class="sectiondark">
<div class="title">FTP URL</div>
<input name="editbrowseftpurl" type="text" size="60" value="$htmlvalue{browseftpurl}">
<div class="desc">
The URL of the FTP host to browse.
This is where you want to browse, which may be a different server than where the RSS file(s) will go.
<br>Example: ftp.domain.com
</div>
<div class="title">FTP Directory</div>
<input name="editbrowseftpdirectory" type="text" size="60" value="$htmlvalue{browseftpdirectory}">
<div class="desc">
The directory on the FTP server to list (in reverse chronological order).
Note that only files are listed.
To change directories, change the value here.
It is assumed that you normally use this browse capability to find a recent addition
to a directory to use as an enclosure (e.g, the latest podcast MP3 file).
<br>Example: htdocs
</div>
<div class="title">FTP User</div>
<input name="editbrowseftpuser" type="text" size="60" value="$htmlvalue{browseftpuser}">
<div class="desc">
The username to use when logging into the FTP server to browse.
<br>Example: jsmith
</div>
<div class="title">FTP Password</div>
<input name="editbrowseftppassword" type="password" size="60" value="$pwplaceholder">
<div class="desc">
The password to use when logging into the FTP server.
</div>
<div class="title">Enclosure URL Prefix</div>
<input name="editbrowseurlprefix" type="text" size="60" value="$htmlvalue{browseurlprefix}">
<div class="desc">
When a file is selected, this prefix is used to create a URL.
It is needed to allow this program to then query the file's server for the Type value and to avoid needing to enter this prefix
each time after you select a file. (The other Browse information does not provide enough information to specify a URL.)
(You can also use the Options Item Enclosure Type Template to provide recurring values for the enclosure Type field.)
<br>For example, http://www.domain.com/mp3/
</div>
<input name="changebrowse" type="submit" value="Update Browse Values">
</div>
<br>
<script>
<!--
var setf = function() {document.f1.browsecontinue$params{browsecontinuetype}0.focus();}
// -->
</script> 
EOF

         }

      else {

         if ($params{itemmode} eq "delete") {
            $response .= <<"EOF";
<input name="itemmode" type="hidden" value="delete">
<div style="float:right;"><input class="small" name="switchitemreorder" type="submit" value="Reorder...">
<input class="small" name="switchitemaddnew" type="submit" value="Add...">
<input class="small" name="switchitemlist" type="submit" value="Done">
</div>
EOF
            }

         elsif ($params{itemmode} eq "reorder") {
            $response .= <<"EOF";
<input name="itemmode" type="hidden" value="reorder">
<div style="float:right;"><input class="small" name="switchitemdelete" type="submit" value="Delete...">
<input class="small" name="switchitemaddnew" type="submit" value="Add...">
<input class="small" name="switchitemlist" type="submit" value="Done">
</div>
EOF
            }

         else {            # *** Normal listing of items

            $response .= <<"EOF";
<div style="float:right;"><input class="small" name="switchitemdelete" type="submit" value="Delete...">
<input class="small" name="switchitemreorder" type="submit" value="Reorder...">
<input class="small" name="switchitemaddnew" type="submit" value="Add...">
</div>
EOF
             }

         my $rsstitlesc = special_chars($datavalues{rsstitle});
         $response .= <<"EOF";
<div class="pagetitle">FULL LIST OF ITEMS IN FEED:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<div class="sectionplain">
EOF

         my $t = time;

         # Break into pages

         my $pagenav;

         $params{listitemnum} ||= 1;
         $datavalues{maxlistitems} = 0 if $datavalues{maxlistitems} <= 0; # make sure in range
         $datavalues{maxlistitems} ||= $defaultmaxlistitems;

         for (my $i = 1; $i <= $datavalues{numitems}; $i += $datavalues{maxlistitems}) {
            my $endi = $datavalues{numitems} < $i + $datavalues{maxlistitems} ?
                          $datavalues{numitems} : $i + $datavalues{maxlistitems} - 1;
            my $label = "$i-$endi";
            $label = "$i" if $i == $endi;
            if ($i == $params{listitemnum}) {
               $pagenav .= qq!<span class="smallprompt"><b>$label</b></span> !;
               }
            else {
               $pagenav .= qq!<input class="small" type="submit" name="listitem$i" value="$label"> !;
               }
            }
         $response .= <<"EOF";
$pagenav
<input name="listitemnum" type="hidden" value="$params{listitemnum}">
<br><br>
EOF

         # Determine publish order

         my (@pubordersort, @puborder);

         if ($datavalues{publishsequence} eq "revchron") { # If using pubDates to order items for publish criteria, do a sort
            my @compvals;
            for (my $i=1; $i <= $datavalues{numitems}; $i++) {
               my ($str, $td) = time_delta(0, $datavalues{"itempubdate$i"});
               $compvals[$i-1] = $str ? $td : $i;
               }
            @pubordersort = sort { $compvals[$a] <=> $compvals[$b] } 0..$datavalues{numitems}-1;
            @puborder[@pubordersort] = 1..$datavalues{numitems};
            }
         else {
            @puborder = 1..$datavalues{numitems};
            }

         for (my $i = $params{listitemnum}; $i <= $datavalues{numitems} && $i < $params{listitemnum}+$datavalues{maxlistitems}; $i++) {
            my %htmlv;

            my ($ago, $timedelta) = time_delta($t, $datavalues{"itempubdate$i"});
            $timedelta = $timedelta / 3600; # convert seconds to hours

            if ($ago) {
               $ago = "(" . $ago . " ago)";
               }
            elsif ($datavalues{"itempubdate$i"}) {
               $ago = qq!<span class="warning">(The date/time is not in standard format)</span>!;
               }
            html_escape(\%datavalues, \%htmlv, ("itemtitle$i", "itemlink$i", "itemdesc$i", "itempubdate$i", "itemguid$i",
                                                "itemenclosureurl$i", "itemenclosurelength$i", "itemenclosuretype$i", "itemaddlxml$i"));
            my $descbr;
            if ($datavalues{"itemdeschtml$i"}) {
               $descbr = $datavalues{"itemdesc$i"};
               }
            else {
               $descbr = $htmlv{"itemdesc$i"};

               # Apply special transformations

               $descbr = expand_desc($descbr);
               }
            my $guidispermalink = $datavalues{"itemguidispermalink$i"} ? " (perm)" : "";
            $htmlv{"itemaddlxml$i"} =~ s/\n/<br>&nbsp;&nbsp;/g;

            # Apply maximum items published and minimum time to publish criteria

            my $included = (($datavalues{maxpublishitems} <= 0)
                            || ($puborder[$i-1] <= $datavalues{maxpublishitems})
                            || ($timedelta && $datavalues{mintimepublishitems} && $timedelta <= $datavalues{mintimepublishitems}))
                           ? "itemselected" : "itemheader";

            my $missingmsg = qq! <span class="warning">You must have either a Title, a Description, or both.</span>!;
            my $itemrequiredwarn = ($datavalues{"itemtitle$i"} || $datavalues{"itemdesc$i"}) ? "" : $missingmsg;

            if ($params{itemmode} eq "delete") {
               $response .= <<"EOF";
<div class="itembuttons"><input class="small" name="itemdelete$i" type="submit" value="Delete"></div>
EOF
               }
            elsif ($params{itemmode} eq "reorder") {
               $response .= <<"EOF";
<div class="itembuttons"><input class="small" name="itemup$i" type="submit" value="Up">
<input class="small" name="itemdown$i" type="submit" value="Down"></div>
EOF
               }
            else {
               $response .= <<"EOF";
<div class="itembuttons"><input class="small" name="itemedit$i" type="submit" value="Edit"></div>
EOF
                }

            $response .= <<"EOF";
<div class="$included">Item $i:</div>
EOF

            $response .= <<"EOF" if ($datavalues{"itemtitle$i"} && ($datavalues{displaytitle} || !defined $datavalues{displaytitle}));
<div class="itemtitle">$htmlv{"itemtitle$i"}$itemrequiredwarn</div>
EOF

            $response .= <<"EOF" if ($datavalues{"itemlink$i"} && ($datavalues{displaylink} || !defined $datavalues{displaylink}));
<div class="itemlink"><a href="$datavalues{"itemlink$i"}" target="_blank">$htmlv{"itemlink$i"}</a></div>
EOF

            $response .= <<"EOF" if (($datavalues{"itempubdate$i"} || $ago) && ($datavalues{displaypubdate} || !defined $datavalues{displaypubdate}));
<div class="itemlink"><i>$htmlv{"itempubdate$i"} $ago</i></div>
EOF

            $response .= <<"EOF" if (($descbr || $itemrequiredwarn) && ($datavalues{displaydesc} || !defined $datavalues{displaydesc}));
<div class="itemdesc">$descbr<!-- "''" -->$itemrequiredwarn</div>
EOF

            $response .= <<"EOF" if (($datavalues{displayenclosure} && $datavalues{"itemenclosureurl$i"}) || ($datavalues{"itemenclosureurl$i"} && (!defined $datavalues{displayenclosure})));
<div class="itemlink">Enclosure  ($htmlv{"itemenclosurelength$i"} bytes, $htmlv{"itemenclosuretype$i"}):
<br><a href="$datavalues{"itemenclosureurl$i"}" target="_blank">$htmlv{"itemenclosureurl$i"}</a></div>
EOF

            $response .= <<"EOF" if ($datavalues{"itemguid$i"} && ($datavalues{displayguid} || !defined $datavalues{displayguid}));
<div class="itemmisc">GUID: $htmlv{"itemguid$i"}$guidispermalink</div>
EOF
            $response .= <<"EOF" if ($datavalues{"itemaddlxml$i"});
<div class="itemmisc">Additional XML:<br>&nbsp;&nbsp;$htmlv{"itemaddlxml$i"}</div>
EOF
            }
         $response .= <<"EOF";
<br><span class="smallprompt">Only <span class="selectedexample">highlighted items</span> are included in the published data.
(See the Publish "Max items" setting.)</span>
<br><br>$pagenav
EOF
         }

      $response .= <<"EOF";
</div>
</form>
EOF

      }

   #
   # Publish
   #

   if ($currenttab eq "Publish") {
      my $rsstitlesc = special_chars($datavalues{rsstitle});
     
      $response .= <<"EOF";
<form name="f1" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<div class="sectiondark">
EOF

      # Check that feed is set...

      if (!$config_values{feedname}) {
         $response .= <<"EOF";
<span class="warning">The Feed Name has not been set.</span>
</div>
<div class="sectionplain">
Before you may publish, you must specify a Feed Name.
Use the "Feed" screen to create one before setting publishing settings.
EOF
         }

      #
      # Publish feed if requested
      #

      elsif ($params{publishftp} || $params{publishfile} || $params{publishboth}) {

         my $publishstatus; # string to hold output describing what happened

         my $rssstream; # string with RSS file contents
         my $htmlstream; # string with HTML Version

         # Add header information, including channel stuff

         html_escape(\%datavalues, \%htmlvalue, @feedtags);
         $htmlvalue{rsstagaddltext} = "$datavalues{rsstagaddltext} " if $datavalues{rsstagaddltext};

         $rssstream .= <<"EOF";
<?xml version="1.0" encoding="UTF-8" ?>
<rss $htmlvalue{rsstagaddltext}version="2.0">
 <channel>
  <title>$htmlvalue{rsstitle}</title>
  <link>$htmlvalue{rsslink}</link>
  <description>$htmlvalue{rssdesc}</description>
  <lastBuildDate>$dtstring</lastBuildDate>
  <generator>$programname</generator>
  <docs>http://blogs.law.harvard.edu/tech/rss</docs>
EOF

         $rssstream .= <<"EOF" if $datavalues{channeladdlxml}; # add explicit stuff if requested
$datavalues{channeladdlxml}
EOF

         # Determine publish order

         my (@pubordersort, @puborder);

         # Do a sort if using pubDates to sequence

         if ($datavalues{publishsequence} eq "revchron") { 
            my @compvals;
            for (my $i=1; $i <= $datavalues{numitems}; $i++) {
               my ($str, $td) = time_delta(0, $datavalues{"itempubdate$i"});
               $compvals[$i-1] = $str ? $td : $i;
               }
            @pubordersort = sort { $compvals[$a] <=> $compvals[$b] } 0..$datavalues{numitems}-1;
            @puborder[@pubordersort] = 1..$datavalues{numitems};
            }

         else { # Otherwise just use listed order
            @pubordersort =  0..$datavalues{numitems}-1;
            @puborder = 1..$datavalues{numitems};
            }

         # add each item

         my $t = time;

         for (my $n = 1; $n <= $datavalues{numitems}; $n++) {
            my %htmlv;

            my $i = $pubordersort[$n-1]+1; # Go through things in publication order

            my ($ago, $timedelta) = time_delta($t, $datavalues{"itempubdate$i"});
            $timedelta = $timedelta / 3600; # convert seconds to hours

            # Apply maximum items published and minumum time to publish criteria

            my $included = (($datavalues{maxpublishitems} <= 0)
                            || ($n <= $datavalues{maxpublishitems})
                            || ($timedelta && $datavalues{mintimepublishitems} && $timedelta <= $datavalues{mintimepublishitems}));

            next unless $included; # skip items that aren't included

            html_escape(\%datavalues, \%htmlv, ("itemtitle$i", "itemlink$i", "itemdesc$i", 
                        "itemenclosureurl$i", "itemenclosurelength$i", "itemenclosuretype$i", "itempubdate$i", "itemguid$i"));

            my ($titletext, $linktext, $desctext, $enclosureurl, $enclosurelength, $enclosuretype, $pubdatetext, $guidtext, $guidispermalink, $addlxml);

            $titletext = $htmlv{"itemtitle$i"};
            $linktext = $htmlv{"itemlink$i"};
            if ($datavalues{"itemdeschtml$i"}) {
               $desctext = $htmlv{"itemdesc$i"}; # single escape if HTML
               }
            else {
               $desctext = $htmlv{"itemdesc$i"}; # if no HTML, start with single escape
               $desctext =~ s/&amp;/&amp;amp;/g; # double escape "&"
               $desctext =~ s/&lt;/&amp;lt;/g; # double escape "<"
               $desctext =~ s/]]&gt;/]]&amp;gt;/g; # double escape "]]>"

               # Apply special transformations

               $desctext =~ s/\n/&lt;br>/g;  # Line breaks are preserved
               $desctext =~ s/\[(http:.+?)\s+(.+?)\]/&lt;a href=\"$1\">$2&lt;\/a>/g; # Wiki-style links
               $desctext =~ s/\[b:(.+?)\]/&lt;b>$1&lt;\/b>/gs; # [b:text] for bold
               $desctext =~ s/\[i:(.+?)\]/&lt;i>$1&lt;\/i>/gs; # [i:text] for italic
               $desctext =~ s/\[quote:(.+?)\]/&lt;blockquote>$1&lt;\/blockquote>/gs; # [quote:text] to indent
               }

            $enclosureurl = $htmlv{"itemenclosureurl$i"}; # As far as I can tell, this should be escaped this way (&amp;, not %26)
            $enclosurelength = $htmlv{"itemenclosurelength$i"};
            $enclosuretype = $htmlv{"itemenclosuretype$i"};
            $pubdatetext = $htmlv{"itempubdate$i"};
            $guidtext = $htmlv{"itemguid$i"};
            $guidispermalink = $datavalues{"itemguidispermalink$i"} ? "true" : "false";

            $addlxml = $datavalues{"itemaddlxml$i"}; # not escaped -- used as is

            $rssstream .= "  <item>\n";
            $rssstream .= "   <title>$titletext</title>\n" if $titletext;
            $rssstream .= "   <link>$linktext</link>\n" if $linktext;
            $rssstream .= "   <description>$desctext</description>\n" if $desctext;
            $rssstream .= "   <enclosure url=\"$enclosureurl\" length=\"$enclosurelength\" type=\"$enclosuretype\" />\n" if $enclosureurl;
            $rssstream .= "   <pubDate>$pubdatetext</pubDate>\n" if $pubdatetext;
            $rssstream .= "   <guid isPermaLink=\"$guidispermalink\">$guidtext</guid>\n" if $guidtext;
            $rssstream .= "$addlxml\n" if $addlxml;
            $rssstream .= "  </item>\n";
            }

         # closing stuff

         $rssstream .= <<"EOF";
 </channel>
</rss>
EOF

         # Get content of HTML Version if requested

         if ($datavalues{htmlversion}) {

            html_escape(\%datavalues, \%htmlvalue, qw(rssfileurl));

            $htmlvalue{rsslink} = $datavalues{rsslink}; # need unescaped version here
            $htmlvalue{rssfileurlraw} = $datavalues{rssfileurl}; # need both escaped and unescaped version of rssfileurl
            $htmlvalue{rsspubdate} = $dtstring; # make special value

            my $hvabove = $datavalues{htmlabove} || $defaulthtmlabove;
            $htmlstream .= expand_template($hvabove, \%htmlvalue);

            # add each item

            my $t = time;
            my $hvitem = $datavalues{htmlitem} || $defaulthtmlitem;

            if ($datavalues{htmlallitems}) { # Override sequence for HTML publish of all items
               @pubordersort =  0..$datavalues{numitems}-1;
               }

            for (my $n = 1; $n <= $datavalues{numitems}; $n++) {
               my %htmlv = %htmlvalue;

               my $i = $pubordersort[$n-1]+1; # Go through things in publication order

               $htmlv{itemnum} = $i;

               my ($ago, $timedelta) = time_delta($t, $datavalues{"itempubdate$i"});
               $timedelta = $timedelta / 3600; # convert seconds to hours

               # Apply maximum items published and minumum time to publish criteria

               my $included = (($datavalues{maxpublishitems} <= 0)
                               || ($n <= $datavalues{maxpublishitems})
                               || ($timedelta && $datavalues{mintimepublishitems} && $timedelta <= $datavalues{mintimepublishitems}));

               next unless ($included || $datavalues{htmlallitems}); # skip items that aren't included unless listing all

               $htmlv{itemtitle} = special_chars($datavalues{"itemtitle$i"});
               $htmlv{itemlink} = $datavalues{"itemlink$i"};
               if ($datavalues{"itemdeschtml$i"}) {
                  $htmlv{itemdesc} = $datavalues{"itemdesc$i"}; # no escape if HTML
                  }
               else {
                  $htmlv{itemdesc} = special_chars($datavalues{"itemdesc$i"}); # escape if not HTML

                  # Apply special transformations

                  $htmlv{itemdesc} =~ s/\n/<br>/g;  # Line breaks are preserved
                  $htmlv{itemdesc} =~ s/\[(http:.+?)\s+(.+?)\]/<a href=\"$1\">$2<\/a>/g; # Wiki-style links
                  $htmlv{itemdesc} =~ s/\[b:(.+?)\]/<b>$1<\/b>/gs; # [b:text] for bold
                  $htmlv{itemdesc} =~ s/\[i:(.+?)\]/<i>$1<\/i>/gs; # [i:text] for italic
                  $htmlv{itemdesc} =~ s/\[quote:(.+?)\]/<blockquote>$1<\/blockquote>/gs; # [quote:text] to indent
                  }
               $htmlv{itemenclosureurl} = special_chars($datavalues{"itemenclosureurl$i"});
               $htmlv{itemenclosureurlraw} = $datavalues{"itemenclosureurl$i"};
               $htmlv{itemenclosurelength} = special_chars($datavalues{"itemenclosurelength$i"});
               $htmlv{itemenclosuretype} = special_chars($datavalues{"itemenclosuretype$i"});
               $htmlv{itempubdate} = special_chars($datavalues{"itempubdate$i"});
               $htmlv{itemguid} = special_chars($datavalues{"itemguid$i"});

               $htmlstream .= expand_template($hvitem, \%htmlv);
               }

            my $hvbelow = $datavalues{htmlbelow} || $defaulthtmlbelow;
            $htmlstream .= expand_template($hvbelow, \%htmlvalue);
            }

         # Output to file if requested

         my $filefailed;

         if ($params{publishfile} || $params{publishboth}) {
            my $ok = open (RSSFILEOUT, "> $datavalues{publishfile}");
            my $fnsc = special_chars($datavalues{publishfile});
            if ($ok) {
               print RSSFILEOUT $rssstream;
               $publishstatus .= "Successfully output RSS information to file: $fnsc.<br><br>";
               }
            else {
               my $stsc = special_chars("$!");
               $publishstatus .= qq!<span class="warning">Unable to output RSS information to file: $fnsc.<br>Error status: $stsc</span><br><br>!;
               $filefailed = 1;
               }
            close RSSFILEOUT;

            if ($datavalues{htmlversion} && $datavalues{publishhtmlfile}) { # HTML version
               my $ok = open (HTMLFILEOUT, "> $datavalues{publishhtmlfile}");
               my $fnsc = special_chars($datavalues{publishhtmlfile});
               if ($ok) {
                  print HTMLFILEOUT $htmlstream;
                  $publishstatus .= "Successfully output HTML information to file: $fnsc.<br><br>";
                  }
               else {
                  my $stsc = special_chars("$!");
                  $publishstatus .= qq!<span class="warning">Unable to output HTML information to file: $fnsc.<br>Error status: $stsc</span><br><br>!;
                  $filefailed = 1;
                  }
               close HTMLFILEOUT;
               }

            }

         # Backup data if requested

         my ($bkupdt, $bkupfnlocal, $doftpbackup, $bkupfnftp);

         if ($datavalues{backuptyperadio} && ($datavalues{backuptyperadio} ne 'none')) {
            $doftpbackup = $datavalues{backupftpfilename}; # remember for FTP - do it if not "none" and there is an FTP filename
            $bkupdt = sprintf(".%04d-%02d-%02d-%02d-%02d-%02d", $year+1900, $mon+1, $mday, $hour, $min, $sec)
               if ($datavalues{backuptyperadio} eq 'multiple');
            if ($datavalues{backuplocalfilename}) {
               $bkupfnlocal = "$datavalues{backuplocalfilename}.backup$bkupdt.$config_values{feedname}.txt";
               }
            else {
               $bkupfnlocal = "$config_values{datafile}.backup.$config_values{feedname}.tmp";
               }
            $bkupfnftp = "$datavalues{backupftpfilename}.backup$bkupdt.$config_values{feedname}.txt";
            my $ok = open (BACKUPFILEOUT, "> $bkupfnlocal");
            if ($ok) {
               foreach my $vn (sort keys %datavalues) {

                  if (!$datavalues{backuppasswords}) { # normally don't output passwords
                     next if $vn eq "ftppassword";
                     next if $vn eq "browseftppassword";
                     }

                  # escape CR and LF

                  my $val = $datavalues{$vn};
                  $val =~ s/\\/\\\\/g;
                  $val =~ s/\n/\\n/g;
                  $val =~ s/\r/\\r/g;

                  print BACKUPFILEOUT "$vn=$val\n"; 

                  }
               $publishstatus .= "Successful backup to file: $bkupfnlocal.<br><br>" if $datavalues{backuplocalfilename};
               }
            else {
               my $stsc = special_chars("$!");
               $publishstatus .= qq!<span class="warning">Unable to output backup file: $bkupfnlocal.<br>Error status: $stsc</span><br><br>!;
               $filefailed = 1;
               }
            close BACKUPFILEOUT;
            }

         # Output by FTP if requested

         if ($params{publishftp} || $params{publishboth}) {

            my ($tmpfn, $ulfn, $tmphtmlfn, $ulhtmlfn);

            if ($params{publishftp} || $filefailed) { # make a temp file if didn't just output to file
               $tmpfn = "$config_values{datafile}.ftp.$config_values{feedname}.tmp";
               my $ok = open (RSSFILEOUT, "> $tmpfn");
               if ($ok) {
                  print RSSFILEOUT $rssstream;
                  }
               else {
                  my $stsc = special_chars("$!");
                  $publishstatus .= <<"EOF";
<span class="warning">Unable to output RSS information to temp file: $tmpfn.<br>
Error status: $stsc</span><br>
Without temp file unable to output RSS information by FTP.<br><br>
EOF
                  $filefailed = 1;
                  }
               close RSSFILEOUT;
               $ulfn = $tmpfn;

               $tmphtmlfn = "$config_values{datafile}.html.$config_values{feedname}.tmp";
               my $ok = open (HTMLFILEOUT, "> $tmphtmlfn");
               if ($ok) {
                  print HTMLFILEOUT $htmlstream;
                  }
               else {
                  my $stsc = special_chars("$!");
                  $publishstatus .= <<"EOF";
<span class="warning">Unable to output HTML information to temp file: $tmphtmlfn.<br>
Error status: $stsc</span><br>
Without temp file unable to output HTML information by FTP.<br><br>
EOF
                  $filefailed = 1;
                  }
               close HTMLFILEOUT;
               $ulhtmlfn = $tmphtmlfn;
               }

            else { # otherwise upload from recently published local file(s)
               $tmpfn = $datavalues{publishfile};
               $tmphtmlfn = $datavalues{publishhtmlfile};
               }

            if ($tmpfn) {
               my $ftp = Net::FTP->new($datavalues{ftpurl}, Debug => 0, Passive => 1, Timeout => 30);
               if ($ftp) {
                  my $ok = $ftp->login($datavalues{ftpuser}, $datavalues{ftppassword});
                  $ok = $ftp->cwd("/$datavalues{ftpdirectory}") if $ok;
                  $ok = $ftp->put($tmpfn, $datavalues{ftpfilename}) if $ok;
                  $publishstatus .= "Successfully output RSS XML file by FTP: $datavalues{ftpfilename}.<br><br>" if $ok;
                  $ok = $ftp->cwd("/$datavalues{ftphtmldirectory}") if ($ok && $datavalues{htmlversion});
                  $ok = $ftp->put($tmphtmlfn, $datavalues{ftphtmlfilename}) if ($ok && $datavalues{htmlversion} && $datavalues{ftphtmlfilename});
                  $publishstatus .= "Successfully output RSS HTML file by FTP: $datavalues{ftphtmlfilename}.<br><br>" if ($ok && $datavalues{htmlversion} && $datavalues{ftphtmlfilename});
                  $ok = $ftp->cwd("/$datavalues{backupftpdirectory}") if ($ok && $doftpbackup);
                  $ok = $ftp->put($bkupfnlocal, $bkupfnftp) if ($ok && $doftpbackup);
                  $publishstatus .= "Successfully output Backup Data file by FTP: $bkupfnftp.<br><br>" if ($ok && $doftpbackup);
                  if ($ok) {
                     $publishstatus .= "Successfully output information by FTP.<br><br>";
                     }
                  else {
                     my $msgsc = special_chars($ftp->message);
                     $publishstatus .= qq!<span class="warning">Unable to output information by FTP.<br>Error status: $msgsc.</span><br><br>!;
                     }
                  $ftp->quit; # Moved to after status output DSB 2005-05-17
                  }
               else {
                  my $msgsc = special_chars("$@");
                  $publishstatus .= qq!<span class="warning">Unable to output information by FTP.<br>Error status: $msgsc.</span><br><br>!;
                  }

               unlink $ulfn if $ulfn; # delete RSS temp file if created
               unlink $ulhtmlfn if $ulhtmlfn; # delete HTML temp file if created
               unlink $bkupfnlocal if ($doftpbackup && !$datavalues{backuplocalfilename}); # delete backup temp file if created

               }
            }

         $response .= <<"EOF";

$publishstatus
<input type="submit" name="continuepublish" value="Continue">
<input type="submit" name="newtab" value="Quit">
EOF
         }

      #
      # Edit publish information if in edit mode
      #

      elsif ($params{publishmode} eq "Edit") {

         html_escape(\%datavalues, \%htmlvalue, @publishfields);

         my $pwplaceholder = $datavalues{ftppassword} ? $placeholderpw : ""; # Don't let real password be used

         $htmlvalue{mintimepublishitems} = "000" if !defined $datavalues{mintimepublishitems};
         my %mtp;
         $mtp{$htmlvalue{mintimepublishitems}} = " CHECKED";

         my $publishsequenceradiolisted = (($htmlvalue{publishsequence} eq 'listed') || !$htmlvalue{publishsequence}) ? " CHECKED" : "";
         my $publishsequenceradiorevchron = $htmlvalue{publishsequence} eq 'revchron' ? " CHECKED" : "";

         my $backuptyperadionone = ($htmlvalue{backuptyperadio} eq "none" || !$htmlvalue{backuptyperadio}) ? " CHECKED" : "";
         my $backuptyperadiosingle = $htmlvalue{backuptyperadio} eq "single" ? " CHECKED" : "";
         my $backuptyperadiomultiple = $htmlvalue{backuptyperadio} eq "multiple" ? " CHECKED" : "";

         $response .= <<"EOF";
<div style="float:right;">
<input class="small" name="savepublish" type="submit" value="Save">
<input class="small" name="savepublishcancel" type="submit" value="Cancel">
</div>
<div class="pagetitle">EDIT PUBLISH INFORMATION:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<br>
<div class="sectiondark">
<div class="title">FTP URL</div>
<input name="editftpurl" type="text" size="60" value="$htmlvalue{ftpurl}">
<div class="desc">
The URL of the FTP host to receive the RSS file.
Leave blank if not doing FTP publishing.
<br>Example: ftp.domain.com
</div>
<div class="title">FTP Filename</div>
<input name="editftpfilename" type="text" size="60" value="$htmlvalue{ftpfilename}">
<div class="desc">
The filename to use when writing the RSS XML data on the server (or nothing if not doing FTP publishing).
Any existing file is overwritten.
<br>Example: rss.xml
</div>
<div class="title">FTP Directory</div>
<input name="editftpdirectory" type="text" size="60" value="$htmlvalue{ftpdirectory}">
<div class="desc">
The directory on the FTP server (or nothing if not doing FTP publishing).
This is sometimes blank even when doing FTP publishing if the home FTP directory ("/")
is where you want the file to go.
<br>Example: htdocs/
</div>
<div class="title">FTP User</div>
<input name="editftpuser" type="text" size="60" value="$htmlvalue{ftpuser}">
<div class="desc">
The username to use when logging into the FTP server (or nothing if not doing FTP publishing).
<br>Example: jsmith
</div>
<div class="title">FTP Password</div>
<input name="editftppassword" type="password" size="60" value="$pwplaceholder">
<div class="desc">
The password to use when logging into the FTP server (or nothing if not doing FTP publishing).
</div>
</div>
<br>

<div class="sectiondark">
<div class="title">Local Filename</div>
<input name="editpublishfile" type="text" size="60" value="$htmlvalue{publishfile}">
<div class="desc">
The filename (with path, if not in the local directory) to receive the RSS file on the local computer.
Any existing file is overwritten.
Leave blank if not doing local publishing.
<br>Example: rss.xml, or ../data/rss_feed.xml
</div>
</div>
<br>

<div class="sectiondark">
<div class="title">Maximum Items</div>
<input name="editmaxpublishitems" type="text" size="60" value="$htmlvalue{maxpublishitems}">
<div class="desc">
The maximum number of items to list in the RSS file.
The items listed in this program and displayed below those first items will be remembered but not put in the RSS file.
If this field is blank all items will be included.
<br>Example: 7
</div>
<div class="title">Minimum Time To Publish Items</div>
EOF
         foreach my $val (sort keys %mintimemapping) {
            my $mtm = $mintimemapping{$val};
            $response .= <<"EOF";
<input name="editmintimepublishitems" type="radio" value="$val"$mtp{$val}><span class="smallprompt">$mtm</span> &nbsp;
EOF
            }
         $response .=<<"EOF";
<div class="desc">
All items at least this recent will be listed in the RSS file,
even if that results in more than the Maximum Items number of items being listed.
The date of an item is determined by the PubDate, if present.
The items listed in this program but not selected for publication will be remembered but not put in the RSS file.
</div>
<div class="title">Item Sequence</div>
<input name="editpublishsequence" type="radio" value="listed"$publishsequenceradiolisted><span class="smallprompt">As listed</span> &nbsp;
<input name="editpublishsequence" type="radio" value="revchron"$publishsequenceradiorevchron><span class="smallprompt">Reverse chronological</span>
<div class="desc">
Normally the items are selected (and counted towards "Maximum Items") during publishing in the same sequence as the
items are displayed in the Items list, starting at the top of the list.
There are times, though, when the items in the list have been manually reordered (for example to display in a particular
sequence in the optional HTML file) that lead to the selection of inappropriate items for the RSS XML file.
Setting this "Item Sequence" option to "Reverse Chronological" will use a sequence derived from the "PubDate" instead
of the listing order to determine which items are published which may lead to a more appropriate order
(all items without a date/time are sequenced after those with one).
</div>
</div>
<br>

<div class="sectiondark">
<div class="title">Fill In The Following Fields Only If You Want The Optional HTML File</div>
<input name="edithtmlversion" type="checkbox" value="CHECKED" $htmlvalue{htmlversion}>
<div class="desc">
If this box is checked a "human readable" version of the feed will be produced in HTML for reading with a browswer.
</div>
<div class="title">RSS File URL</div>
<input name="editrssfileurl" type="text" size="60" value="$htmlvalue{rssfileurl}">
<div class="desc">
The URL of the published XML file containing the RSS information.
This URL may be shown in the HTML file so that readers can give it to an RSS aggregator to "subscribe" to this feed.
The file is created on the web server using the settings above either by FTP or by saving as a local file.
In either case, a URL is used to access it from outside the web server.
This program cannot derive the URL just from the FTP/file information and needs to be told
the actual URL, hence the need for this field.
<br>Example: http://www.aardvarkproject.com/rss.xml
</div>
<div class="title">HTML FTP Filename</div>
<input name="editftphtmlfilename" type="text" size="60" value="$htmlvalue{ftphtmlfilename}">
<div class="desc">
The filename to use when writing the feed HTML file on the server
(may be blank if not doing FTP publishing or not producing the optional HTML file).
Any existing file is overwritten.
<br>Example: rss.html
</div>
<div class="title">HTML FTP Directory</div>
<input name="editftphtmldirectory" type="text" size="60" value="$htmlvalue{ftphtmldirectory}">
<div class="desc">
The directory on the FTP server for the HTML file (or nothing if not doing FTP publishing).
This is sometimes blank even when doing FTP publishing if the home FTP directory
is where you want the file to go.
This must be set if doing FTP publishing of the HTML file even if it is the same as the XML FTP directory.
<br>Example: htdocs/
</div>
<div class="title">HTML Local Filename</div>
<input name="editpublishhtmlfile" type="text" size="60" value="$htmlvalue{publishhtmlfile}">
<div class="desc">
The filename (with path, if not in the local directory) to receive the HTML file on the local computer.
Any existing file is overwritten.
Leave blank if not doing local publishing or not producing the optional HTML file.
<br>Example: rss.html, or ../status/rss_feed.html
</div>
<div class="title">HTML Template Above</div>
<textarea name="edithtmlabove" rows="4" cols="60" wrap="virtual">$htmlvalue{htmlabove}</textarea>
<br>
<input name="setdefaultabove" type="checkbox" value="1"><span class="smallprompt">Set to default</span>
<br>
<div class="desc">
The HTML code to be put in the HTML file before the section with the items.
If blank, a default is used.
If you want to see the default: Check the box, click "Save", and then edit again.
The following "variables" expressed in the form "{{name}}" may be used:
rsstitle, rsslink, rssdesc, rsspubdate, rssfileurl, rssfileurlraw (special characters not escaped).
</div>
<div class="title">HTML Template For Each Item</div>
<textarea name="edithtmlitem" rows="4" cols="60" wrap="virtual">$htmlvalue{htmlitem}</textarea>
<br>
<input name="setdefaultitem" type="checkbox" value="1"><span class="smallprompt">Set to default</span>
<br>
<div class="desc">
The HTML code to be put in the HTML file for each item.
If blank, a default is used.
If you want to see the default: Check the box, click "Save", and then edit again.
The following "variables" expressed in the form "{{name}}" may be used
(in addition to those for Above and Below):
itemtitle, itemlink, itemdesc, itemenclosureurl, itemenclosureurlraw, itemenclosurelength, itemenclosuretype,
itempubdate, itemguid, itemnum (in this listing: 1, 2, ...).
</div>
<div class="title">HTML Template Below</div>
<textarea name="edithtmlbelow" rows="4" cols="60" wrap="virtual">$htmlvalue{htmlbelow}</textarea>
<br>
<input name="setdefaultbelow" type="checkbox" value="1"><span class="smallprompt">Set to default</span>
<br>
<div class="desc">
The HTML code to be put in the HTML file after the section with the items.
If blank, a default is used.
If you want to see the default: Check the box, click "Save", and then edit again.
The following "variables" expressed in the form "{{name}}" may be used:
rsstitle, rsslink, rssdesc, rsspubdate, rssfileurl, rssfileurlraw (special characters not escaped).
</div>
<div class="title">HTML List All Items</div>
<input name="edithtmlallitems" type="checkbox" value="CHECKED" $htmlvalue{htmlallitems}>
<div class="desc">
If this box is checked all items in the feed will be included in the HTML file, not just those listed in the XML file.
In addition, the order they are listed in the HTML file will be the same order as they are listed in the Items list
(even if the Item Sequence option is set to "Reverse Chronological").
This has no effect on the XML RSS file (which is controlled by the Maximum Items,
Minimum Time To Publish Items, and Item Sequence settings above).
</div>
</div>
<br>
<div class="sectiondark">
<div class="title">Backup Type</div>
<input name="editbackuptyperadio" type="radio" value="none"$backuptyperadionone><span class="smallprompt">No backup</span>
&nbsp; <input name="editbackuptyperadio" type="radio" value="single"$backuptyperadiosingle><span class="smallprompt">Single backup file</span>
&nbsp; <input name="editbackuptyperadio" type="radio" value="multiple"$backuptyperadiomultiple><span class="smallprompt">Multiple -- a new one each time</span>
<br>
<input name="editbackuppasswords" type="checkbox" value="CHECKED" $htmlvalue{backuppasswords}><span class="smallprompt">Include passwords</span>
<br>
<div class="desc">
This determines whether or not to save backup copies of the current feed data at the same time as publishing.
A single backup will repeatedly save to the same file.
A multiple backup will save to a new file each time, with a filename that includes the date and time.
Normally the FTP password values are NOT backed up and will need to be reentered if you use a backup file.
If you want to save the passwords, too, then check the box.<br><br>
To restore from a backup file, copy it into the directory where you keep the feed data file(s), give it a legal feed filename, and then run this program.
</div>
<div class="title">Backup Data FTP Filename</div>
<input name="editbackupftpfilename" type="text" size="60" value="$htmlvalue{backupftpfilename}">
<div class="desc">
The filename on the server to receive the Backup Data file by FTP.
Leave blank if not doing FTP backup.
The text "backup", the optional date/time (GMT), the feed name, and an extension will be appended to this name.<br>
For example, if the filename given here is "rss", then the backup file will be "rss.backup.$config_values{feedname}.txt"
or "rss.2005-07-26-14-43.backup.$config_values{feedname}.txt".
</div>
<div class="title">Backup Data FTP Directory</div>
<input name="editbackupftpdirectory" type="text" size="60" value="$htmlvalue{backupftpdirectory}">
<div class="desc">
The directory on the FTP server for the Backup Data file (or nothing if not doing FTP backup).
This is sometimes blank even when doing FTP backup if the home FTP directory
is where you want the file to go.
This must be set if doing FTP backup even if it is the same as the XML or HTML FTP directories.
The FTP URL, User, and Password are the same as used for FTP Publish.
<br>Example: htdocs/
</div>
<div class="title">Backup Data Local Filename</div>
<input name="editbackuplocalfilename" type="text" size="60" value="$htmlvalue{backuplocalfilename}">
<div class="desc">
The filename (with path, if not in the local directory) to receive the Backup Data file on the local computer.
Leave blank if not doing local backup.
The text "backup", the optional date/time (GMT), the feed name, and an extension will be appended to this name.<br>
For example, if the filename given here is "rss", then the backup file will be "rss.backup.$config_values{feedname}.txt"
or "rss.2005-07-26-14-43.backup.$config_values{feedname}.txt".
Another example value would be "../status/rss_feed".
</div>
</div>

<div class="sectionplain">
<input name="savepublish" type="submit" value="Save">
<input name="savepublishcancel" type="submit" value="Cancel">
<script>
<!--
var setf = function() {document.f1.editftpurl.focus();}
// -->
</script> 
EOF
         }

      #
      # Othewise display publish information and buttons to start publish
      #

      else {

         $response .= <<"EOF";
<div class="pagetitle">PUBLISH RSS FEED:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
<br>
EOF

         if ($datavalues{ftpurl} && $datavalues{publishfile}) {
            $response .= <<"EOF";
<input class="small" name="publishftp" type="submit" value="Publish FTP">
<input class="small" name="publishfile" type="submit" value="Publish Local File">
<input class="small" name="publishboth" type="submit" value="Publish Both">
EOF
            }
         elsif ($datavalues{ftpurl}) {
            $response .= <<"EOF";
<input class="small" name="publishftp" type="submit" value="Publish FTP">
EOF
            }
         elsif ($datavalues{publishfile}) {
            $response .= <<"EOF";
<input class="small" name="publishfile" type="submit" value="Publish Local File">
EOF
            }
         else {
            $response .= <<"EOF";
<span class="warning">In order to publish, you need to set either FTP information, local file information, or both.
Use the "Edit" button, below.</span>
EOF
            }

         html_escape(\%datavalues, \%htmlvalue, @publishfields);

         $htmlvalue{ftpurl} ||= "<i>There will be no publishing to a remote server using FTP.</i>";
         $htmlvalue{publishfile} ||= "<i>A local XML file will not be published.</i>";
         $htmlvalue{maxpublishitems} += 0 if $htmlvalue{maxpublishitems}; # convert to number
         $htmlvalue{maxpublishitems} ||= "<i>All items will be published.</i>";
         $htmlvalue{publishsequence} = "As listed" if ($htmlvalue{publishsequence} eq 'listed' || !$htmlvalue{publishsequence});
         $htmlvalue{publishsequence} = "Reverse Chronological" if $htmlvalue{publishsequence} eq 'revchron';
         $htmlvalue{htmlversion} = $htmlvalue{htmlversion} ? "Yes" : "No";
         $htmlvalue{backuptyperadio} = $htmlvalue{backuptyperadio} ? $htmlvalue{backuptyperadio} : "none";

         $response .= <<"EOF";
</div>
EOF

         $htmlvalue{ftppassword} = "******" if $htmlvalue{ftppassword};
         $response .= <<"EOF";
<div class="sectionplain">
<div class="itembuttons"><input class="small" name="publishmode" type="submit" value="Edit"></div>
<div class="itemheader">FTP Information:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="100"><b>URL:</b></td><td>$htmlvalue{ftpurl}</td></tr>
<tr><td><b>Filename:</b></td><td>$htmlvalue{ftpfilename}</td></tr>
<tr><td><b>Directory:</b></td><td>$htmlvalue{ftpdirectory}</td></tr>
<tr><td><b>User:</b></td><td>$htmlvalue{ftpuser}</td></tr>
<tr><td><b>Password:</b></td><td>$htmlvalue{ftppassword}</td></tr>
</table>
</div>

<div class="itemheader">File Information:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="100"><b>File:</b></td><td>$htmlvalue{publishfile}</td></tr>
</table>
</div>

<div class="itemheader">Miscellaneous:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="100"><b>Max items:</b></td><td>$htmlvalue{maxpublishitems}</td></tr>
<tr><td width="100"><b>Minimum time:</b></td><td>$mintimemapping{$datavalues{mintimepublishitems}}</td></tr>
<tr><td width="100"><b>Item Sequence:</b></td><td>$htmlvalue{publishsequence}</td></tr>
</table>
</div>

<div class="itemheader">Optional HTML File:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="100"><b>Produced:</b></td><td>$htmlvalue{htmlversion}</td></tr>
</table>
</div>

<div class="itemheader">Optional Backup:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="100"><b>Backup Data Type:</b></td><td>$htmlvalue{backuptyperadio}</td></tr>
</table>
</div>
EOF
         }

      $response .= <<"EOF";
</div>
</form>
EOF

      }

   #
   # Options
   #

   if ($currenttab eq "Options") {
      my $rsstitlesc = special_chars($datavalues{rsstitle});
     
      $response .= <<"EOF";
<form name="f1" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
EOF

      # Check that feed is set...

      if (!$config_values{feedname}) {
         $response .= <<"EOF";
<div class="sectiondark">
<span class="warning">The Feed Name has not been set.</span>
</div>
<div class="sectionplain">Before you may set options, you must specify a Feed Name.
Use the "Feed" screen to create one.
</div>
EOF
         }

      # Edit mode

      elsif ($params{optionsmode} eq "Edit") {

         $response .= <<"EOF";
<div class="sectiondark">
EOF

         html_escape(\%datavalues, \%htmlvalue, @optionfields);

         my $guidradioauto = $htmlvalue{templateguidradio} eq 'auto' ? " CHECKED" : "";
         my $guidradionone = (($htmlvalue{templateguidradio} eq 'none') || !$htmlvalue{templateguidradio}) ? " CHECKED" : "";
         my $guidradiolink = $htmlvalue{templateguidradio} eq 'link' ? " CHECKED" : "";

         $htmlvalue{templatepubdateusecurrent} = "CHECKED" if !defined $datavalues{templatepubdateusecurrent};

         $htmlvalue{displaytitle} = "CHECKED" if !defined $datavalues{displaytitle};
         $htmlvalue{displaylink} = "CHECKED" if !defined $datavalues{displaylink};
         $htmlvalue{displaypubdate} = "CHECKED" if !defined $datavalues{displaypubdate};
         $htmlvalue{displaydesc} = "CHECKED" if !defined $datavalues{displaydesc};
         $htmlvalue{displayguid} = "CHECKED" if !defined $datavalues{displayguid};
         $htmlvalue{displayenclosure} = "CHECKED" if !defined $datavalues{displayenclosure};

         $htmlvalue{desclines} = "5" if !defined $datavalues{desclines};
         my %dlines;
         $dlines{$htmlvalue{desclines}} = " CHECKED";

         $response .= <<"EOF";
<script>
<!--
var setf = function() {document.f1.editoptionsmaxsaved.focus();}
// -->
</script> 
<div style="float:right;">
<input class="small" name="saveoptions" type="submit" value="Save">
<input class="small" name="saveoptionscancel" type="submit" value="Cancel">
</div>
<div class="pagetitle">EDIT FEED OPTIONS:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<br>
<div class="sectiondark">
<div class="title">Maximum Items Saved</div>
<input name="editoptionsmaxsaved" type="text" size="60" value="$htmlvalue{optionsmaxsaved}">
<div class="desc">
The maximum number of items to remember for an RSS Feed.
Adding an item that makes the number larger than this will cause the bottom-most item to be deleted.
If this field is blank or 0, then there is no maximum and items will not be deleted.
</div>
<div class="title">Items Per Page</div>
<input name="editmaxlistitems" type="text" size="60" value="$htmlvalue{maxlistitems}">
<div class="desc">
Maximum number of items to show per page on the listing in this program for this RSS Feed.
If blank or zero, then a default is used.
</div>
<div class="title">Fields To Display</div>
<input name="editdisplaytitle" type="checkbox" value="CHECKED" $htmlvalue{displaytitle}>
<span class="smallprompt">Title</span>
&nbsp;
<input name="editdisplaylink" type="checkbox" value="CHECKED" $htmlvalue{displaylink}>
<span class="smallprompt">Link</span>
&nbsp;
<input name="editdisplaypubdate" type="checkbox" value="CHECKED" $htmlvalue{displaypubdate}>
<span class="smallprompt">PubDate</span>
&nbsp;
<input name="editdisplaydesc" type="checkbox" value="CHECKED" $htmlvalue{displaydesc}>
<span class="smallprompt">Description</span>
&nbsp;
<input name="editdisplayguid" type="checkbox" value="CHECKED" $htmlvalue{displayguid}>
<span class="smallprompt">GUID</span>
&nbsp;
<input name="editdisplayenclosure" type="checkbox" value="CHECKED" $htmlvalue{displayenclosure}>
<span class="smallprompt">Enclosure</span>
<div class="desc">
Which fields to display in the listing.
All fields with non-blank data are published, no matter what the setting is here.
</div>
<div class="title">Edit Lines For Description</div>
<input name="editdesclines" type="radio" value="3"$dlines{3}><span class="smallprompt">3</span> &nbsp;
<input name="editdesclines" type="radio" value="4"$dlines{4}><span class="smallprompt">4</span> &nbsp;
<input name="editdesclines" type="radio" value="5"$dlines{5}><span class="smallprompt">5</span> &nbsp;
<input name="editdesclines" type="radio" value="6"$dlines{6}><span class="smallprompt">6</span> &nbsp;
<input name="editdesclines" type="radio" value="7"$dlines{7}><span class="smallprompt">7</span> &nbsp;
<input name="editdesclines" type="radio" value="8"$dlines{8}><span class="smallprompt">8</span> &nbsp;
<input name="editdesclines" type="radio" value="9"$dlines{9}><span class="smallprompt">9</span> &nbsp;
<input name="editdesclines" type="radio" value="10"$dlines{10}><span class="smallprompt">10</span> &nbsp;
<input name="editdesclines" type="radio" value="15"$dlines{15}><span class="smallprompt">15</span> &nbsp;
<input name="editdesclines" type="radio" value="20"$dlines{20}><span class="smallprompt">20</span> &nbsp;
<input name="editdesclines" type="radio" value="25"$dlines{25}><span class="smallprompt">25</span> &nbsp;
<div class="desc">
The number of lines of text displayed in the text edit box when editing an item description.
If the length of the description is generally long, you may want a larger value;
if the length is generally short, then you may want a smaller value.
</div>
</div>
<br>

<div class="sectiondark">
<div class="title">Item Title Template</div>
<input name="edittemplatetitle" type="text" size="60" value="$htmlvalue{templatetitle}">
<div class="desc">
This text will be the initial value for the Title field when a new item is added.
Normally left blank, it may be used to add a prefix or suffix, or to add initial HTML.
</div>
<div class="title">Item Link Template</div>
<input name="edittemplatelink" type="text" size="60" value="$htmlvalue{templatelink}">
<div class="desc">
This text will be the initial value for the Link field when a new item is added.
Normally left blank, it may be used to add a prefix or suffix, or to add text
like "http://" when you type in links instead of pasting them.
</div>
<div class="title">Item Description Template</div>
<textarea name="edittemplatedesc" rows="4" cols="60" wrap="virtual">$htmlvalue{templatedesc}</textarea>
<div class="desc">
This text will be the initial value for the Description field when a new item is added.
Normally left blank, it may be used to add some boilerplate to be filled in.
</div>
<div class="title">Item HTML In Description Initial Value</div>
<input name="edittemplatedeschtml" type="checkbox" value="CHECKED" $htmlvalue{templatedeschtml}>
<span class="smallprompt">Includes HTML</span>
<div class="desc">
This is the initial value for the "Includes HTML" checkbox when a new item is added.
If you normally include HTML in the description and want the item
rendered with the HTML active (instead of displaying the "&lt;" and "&gt;"), turn this on.
</div>
<div class="title">Item Enclosure Type Template</div>
<input name="edittemplateenclosuretype" type="text" size="60" value="$htmlvalue{templateenclosuretype}">
<div class="desc">
This text will be the initial value for the Enclosure Type field when a new item is added.
This is normally left blank, especially when you are not including enclosures.
It may be used to enter the file MIME-type if the enclosure's file server does not
report the correct value. (If blank, this program tries to determine the type automatically just like it does with the file length).
(For podcasting a typical value would be "audio/mpeg".)
</div>
<div class="title">Item PubDate Template</div>
<input name="edittemplatepubdate" type="text" size="60" value="$htmlvalue{templatepubdate}">
<br><input name="edittemplatepubdateusecurrent" type="checkbox" value=" CHECKED"$htmlvalue{templatepubdateusecurrent}><span class="smallprompt">Set to current time</span>
<div class="desc">
The initial value for the date/time when the item was published.
If the box is checked, the current time will be used when you press "Save" for a new added item.
The final field's format must be: "Day, monthday Month year hour:min:sec GMT",<br>(e.g., Wed, 08 Oct 2003 19:29:11 GMT)
</div>
<div class="title">Item GUID Template</div>
<input name="edittemplateguid" type="text" size="60" value="$htmlvalue{templateguid}"><br>
<input name="edittemplateguidispermalink" type="checkbox" value="CHECKED" $htmlvalue{templateguidispermalink}><span class="smallprompt">isPermaLink</span>
<br>
<span class="smallprompt"><b>If blank:</b></span> <input name="edittemplateguidradio" type="radio" value="link"$guidradiolink><span class="smallprompt">Set to link</span>
&nbsp; <input name="edittemplateguidradio" type="radio" value="auto"$guidradioauto><span class="smallprompt">Create</span>
&nbsp; <input name="edittemplateguidradio" type="radio" value="none"$guidradionone><span class="smallprompt">Leave blank</span>
<div class="desc">
The text will be the initial value for the GUID field when a new item is added.
Normally left blank, it may be used to add a prefix or suffix, or to add text
like "http://" when you type in GUIDs instead of pasting them.
The checkbox is the initial value for "isPermaLink" for the GUID.
If checked, then readers can assume that the GUID is a URL that is a permanent (unchanging over time)
link to the item.
The radio buttons are the default value for the GUID radio buttons which set
the behavior when the GUID text is blank.
</div>
<div class="title">Item Additional XML Template</div>
<textarea name="edittemplateaddlxml" rows="4" cols="60" wrap="virtual">$htmlvalue{templateaddlxml}</textarea>
<div class="desc">
This text will be the initial value for the Item Additional XML field when a new item is added.
Normally left blank, it may be used to add XML to use as is or to be edited (e.g., "&lt;itunes:keywords&gt;words&lt;/itunes:keywords&gt;").
</div>
</div>
<br>

<div class="sectiondark">
<div class="title">RSS Tag Additional Text</div>
<input name="editrsstagaddltext" type="text" size="60" value="$htmlvalue{rsstagaddltext}">
<div class="desc">
This text will be added as part of the &lt;RSS&gt; tag enclosing the feed information.
It is an advanced feature that should only be used by people who understand how to write XML.
It is used to add attributes, such as namespace declarations, that are not handled by this program otherwise.
An example of use would be the text: xmlns:itunes="http://www.itunes.com/DTDs/Podcast-1.0.dtd"
</div>
<div class="title">Channel Additional XML</div>
<textarea name="editchanneladdlxml" rows="4" cols="60" wrap="virtual">$htmlvalue{channeladdlxml}</textarea>
<div class="desc">
This text will be added to the XML that makes up the &lt;channel&gt; part of the feed.
It is an advanced feature that should only be used by people who understand how to write XML.
It is used to add elements, such as &lt;copyright&gt; and &lt;image&gt;, that are not
currently supported by this program.
</div>
</div>

<div class="sectionplain">
<input name="saveoptions" type="submit" value="Save">
<input name="saveoptionscancel" type="submit" value="Cancel">
</div>
</form>
<script>
<!--
var setf = function() {document.f1.editoptionsmaxsaved.focus();}
// -->
</script>
EOF
         }

      else {

         $response .= <<"EOF";
<div class="sectiondark">
<div class="pagetitle">FEED OPTIONS:</div>
<div class="pagefeedinfo">[$rsstitlesc]</div>
</div>
<br>
$loadfeedsettingsstr
EOF

         html_escape(\%datavalues, \%htmlvalue, @optionfields);

         $htmlvalue{optionsmaxsaved} += 0 if $htmlvalue{optionsmaxsaved}; # convert to number
         $htmlvalue{optionsmaxsaved} ||= "<i>There is no maximum above which old items will be deleted.</i>";
         $htmlvalue{maxlistitems} += 0 if $htmlvalue{maxlistitems}; # convert to number
         $htmlvalue{maxlistitems} ||= "<i>The default number of items will be listed.</i>";
         $htmlvalue{templatedeschtml} = $htmlvalue{templatedeschtml} ? "Yes" : "No";
         $htmlvalue{templatepubdateusecurrent} = ($htmlvalue{templatepubdateusecurrent} || !defined $datavalues{templatepubdateusecurrent}) ? "Yes" : "No";
         $htmlvalue{templateguidispermalink} = $htmlvalue{templateguidispermalink} ? "Yes" : "No";
         $htmlvalue{templateguidradio} = "Set to link" if $htmlvalue{templateguidradio} eq 'link';
         $htmlvalue{templateguidradio} = "Create" if $htmlvalue{templateguidradio} eq 'auto';
         $htmlvalue{templateguidradio} = "Leave blank" if ($htmlvalue{templateguidradio} eq 'none' || !$htmlvalue{templateguidradio});
         $htmlvalue{templateaddlxml} =~ s/\n/<br>/g;

         $htmlvalue{displaytitle} = "Title" if ($datavalues{displaytitle} || !defined $datavalues{displaytitle});
         $htmlvalue{displaylink} = "Link" if ($datavalues{displaylink} || !defined $datavalues{displaylink});
         $htmlvalue{displaypubdate} = "PubDate" if ($datavalues{displaypubdate} || !defined $datavalues{displaypubdate});
         $htmlvalue{displaydesc} = "Description" if ($datavalues{displaydesc} || !defined $datavalues{displaydesc});
         $htmlvalue{displayguid} = "GUID" if ($datavalues{displayguid} || !defined $datavalues{displayguid});
         $htmlvalue{displayenclosure} = "Enclosure" if $datavalues{displayenclosure};

         $htmlvalue{desclines} = "5" if !defined $datavalues{desclines};

         $response .= <<"EOF";
<div class="sectionplain">
<div class="itembuttons"><input class="small" name="optionsmode" type="submit" value="Edit"></div>
<div class="itemheader">Item Options:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="150"><b>Maximum items saved:</b></td><td>$htmlvalue{optionsmaxsaved}</td></tr>
<tr><td><b>Items per page:</b></td><td>$htmlvalue{maxlistitems}</td></tr>
<tr><td><b>Fields displayed:</b></td><td>$htmlvalue{displaytitle} $htmlvalue{displaylink}
$htmlvalue{displaypubdate} $htmlvalue{displaydesc} $htmlvalue{displayguid} $htmlvalue{displayenclosure}</td></tr>
<tr><td><b>Description lines:</b></td><td>$htmlvalue{desclines}</td></tr>
</table>
</div>

<div class="itemheader">Templates for new items:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
<tr><td width="150"><b>Title:</b></td><td>$htmlvalue{templatetitle}</td></tr>
<tr><td><b>Link:</b></td><td>$htmlvalue{templatelink}</td></tr>
<tr><td><b>Description:</b></td><td>$htmlvalue{templatedesc}</td></tr>
<tr><td><b>Enclosure Type:</b></td><td>$htmlvalue{templateenclosuretype}</td></tr>
<tr><td><b>PubDate:</b></td><td>$htmlvalue{templatepubdate}</td></tr>
<tr><td><b>Use current time:</b></td><td>$htmlvalue{templatepubdateusecurrent}</td></tr>
<tr><td><b>HTML in description:</b></td><td>$htmlvalue{templatedeschtml}</td></tr>
<tr><td><b>GUID:</b></td><td>$htmlvalue{templateguid}</td></tr>
<tr><td><b>GUID isPermaLink:</b></td><td>$htmlvalue{templateguidispermalink}</td></tr>
<tr><td><b>GUID option:</b></td><td>$htmlvalue{templateguidradio}</td></tr>
<tr><td><b>Item Additional XML:</b></td><td>$htmlvalue{templateaddlxml}</td></tr>
</table>
</div>
EOF

         if ($datavalues{channeladdlxml} || $datavalues{rsstagaddltext}) {
            $response .= <<"EOF";
<div class="itemheader">Advanced Features:</div>
<div class="itemmisc">
<table cellpadding="0" cellspacing="0">
EOF
            $response .= <<"EOF" if $datavalues{rsstagaddltext};
<tr><td width="150"><b>RSS Tag Additional Text:</b></td><td>$htmlvalue{rsstagaddltext}</td></tr>
EOF
            $htmlvalue{channeladdlxml} =~ s/\n/<br>/g; # make look like the text in HTML
            $htmlvalue{channeladdlxml} =~ s/<br> /<br>&nbsp;/g;
            $htmlvalue{channeladdlxml} =~ s/  / &nbsp;/g;
            $response .= <<"EOF" if $datavalues{channeladdlxml};
<tr><td width="150"><b>Channel Additional XML:</b></td><td>$htmlvalue{channeladdlxml}</td></tr>
EOF
            $response .= <<"EOF";
</table>
</div>
</div>
EOF
            }

         $response .= <<"EOF";
</form>
EOF

         $response .= <<"EOF";
<form name="fload" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<br>
<div class="sectiondark">
<div class="title">Load Feed Settings From URL</div>
<input name="loadfeedsettingsurl"  type="text" size="60" value="">
<input name="loadfeedsettings" type="submit" value="Load"
onclick="return window.confirm('Overwrite feed settings and data with contents of '+document.fload.loadfeedsettingsurl.value+'?')">
<div class="desc">
URL<br><br>
Websites that provide support for this program may have specially constructed files to load settings as part of examples,
especially the Options values and the Publish HTML File Template settings.
This will save you the tedium of typing in many values or long strings of HTML or XML code and is especially helpful
for setting up a podcast RSS feed with an Optional HTML file or additional XML information in the feed.
Enter the URL of such a file (it usually starts with "http://" and has a ".txt" extension) and press Load to overwrite the current
feed values with those set in that file.<br><br>
Note: This is not for loading data from an RSS file.
It should only be done from websites you trust and you should examine the results carefully.
</div>
</div>
</form>
<br>
EOF
         }

      }

   #
   # Show License
   #

   if ($currenttab eq "Show License") {

         use ListGardenLicense;

         $response .= <<"EOF";
<div class="sectiondark">
$sgilicensetext
</div>
<br>
<div class="sectiondark">
$gpllicensetext
</div>
EOF

      }

   # *** Output common stuff

   $response .= <<"EOF";
</td>
</tr>
EOF

   # Finish -- output closing stuff

   my $end_time = times();
   my $time_string = sprintf ("Runtime %.2f seconds at $start_clock_time",
                              $end_time - $start_program_time);
   #
   # *********
   #
   # If you modify the program, add your copyright and modification notices here.
   # Do not remove previous ones.
   #
   # *********
   #

   $response .= <<"EOF";
<tr><td>
<div class="footer">
$time_string<br><br>
(c) Copyright 2004, 2005 Software Garden, Inc.
<br>All Rights Reserved.
<br>Garden is a registered trademark of Software Garden, Inc.
<br>ListGarden is a trademark of Software Garden, Inc.
<br>The original version of this program is from <a href="http://www.softwaregarden.com">Software Garden</a>.
EOF

   $response .= <<"EOF";
<br><br>
<form name="fsl" action="" method="POST">
<input type="hidden" name="securitycode" value="$securitycode">
<input type="hidden" name="currenttab" value="$currenttab">
<input type="hidden" name="feedname" value="$config_values{feedname}">
<input style="font-size:xx-small;" type="submit" name="newtab" value="Show License">
</form>
</div>
</td></tr>
EOF

   $response .= <<"EOF";
</table>
</body>
</html>
EOF

   return $response;

   }

# # # # # # # # # #
# html_escape(\%instrings, \%outstrings, @stringkeys)
#
# Accesses @stringkeys elements of %instrings,
# does HTML escaping for &, <, >, "
# and then adds the results to %outstrings
# 

sub html_escape {
   my $instrings = shift @_;
   my $outstrings = shift @_;

   foreach my $skey (@_) {
      my $string = $$instrings{$skey};
      $string =~ s/&/&amp;/g;
      $string =~ s/</&lt;/g;
      $string =~ s/>/&gt;/g;
      $string =~ s/"/&quot;/g;

      $$outstrings{$skey} = $string;
      }

   return;
}

# # # # # # # # # #
# special_chars($string)
#
# Returns $estring where &, <, >, " are HTML escaped
# 

sub special_chars {
   my $string = shift @_;

   $string =~ s/&/&amp;/g;
   $string =~ s/</&lt;/g;
   $string =~ s/>/&gt;/g;
   $string =~ s/"/&quot;/g;

   return $string;
}


# # # # # # # # # #
# expand_desc($string)
#
# Returns $estring with non-HTML Description formatting
# 

sub expand_desc {
   my $string = shift @_;

   $string =~ s/\n/<br>/g;  # Line breaks are preserved
   $string =~ s/\[(http:.+?)\s+(.+?)\]/<a href=\"$1\">$2<\/a>/g; # Wiki-style links
   $string =~ s/\[b:(.+?)\]/<b>$1<\/b>/gs; # [b:text] for bold
   $string =~ s/\[i:(.+?)\]/<i>$1<\/i>/gs; # [i:text] for italic
   $string =~ s/\[quote:(.+?)\]/<blockquote>$1<\/blockquote>/gs; # [quote:text] to indent
   $string =~ s/\{\{amp}}/&/gs; # {{amp}} for ampersand
   $string =~ s/\{\{lt}}/</gs; # {{lt}} for less than
   $string =~ s/\{\{gt}}/>/gs; # {{gt}} for greater than
   $string =~ s/\{\{quot}}/>/gs; # {{quot}} for quote
   $string =~ s/\{\{lbracket}}/[/gs; # {{lbracket}} for left bracket
   $string =~ s/\{\{rbracket}}/]/gs; # {{rbracket}} for right bracket
   $string =~ s/\{\{lbrace}}/{/gs; # {{lbrace}} for brace

   return $string;
}


# # # # # # # # # #
# $outstring = expand_template($template, \%valuestrings)
#
# Copies $templatestring to result, and for
# {{key}} accesses %valuestrings.
# 

sub expand_template {
   my $template = shift @_;
   my $valuestrings = shift @_;
   my $outstring = $template;

   $outstring =~ s/\{\{(\w+?)}}/$$valuestrings{$1}/eg;

   return $outstring;
}


# # # # # # # # # #
# ($string, $deltaseconds) = time_delta($now, $then)
#
# Returns a string for the time delta
# and the number of seconds for it.
# $now is in seconds (the time Perl function)
# $then is a date string in the format:
#   dayname, mday monname year hour:min:sec GMT
# If the date string is not of correct format it returns nothing.
# 

sub time_delta {
   my ($now, $then) = @_;

   my $string;

   my ($day, $mday, $monname, $year, $hour, $min, $sec, $gmt) =
      split(/,\s+|\s+|:/, $then);

   $day = ucfirst lc $day;
   $monname = ucfirst lc $monname;
   $gmt = lc $gmt;

   if (!$daynames{$day} || $mday < 1 || $mday > 31 || !exists($monthnames{$monname}) || $year < 1900 ||
         $hour < 0 || $hour > 23 || $min < 0 || $min > 59 || $sec < 0 || $sec > 59 || $gmt ne 'gmt') {
      return;
      }

   my $thenseconds = Time::Local::timegm($sec, $min, $hour, $mday, $monthnames{$monname}, $year-1900);
   my $delta = $now - $thenseconds;

   $string = sprintf("%1.1f minutes", $delta/60) if $delta < 60*60;
   $string = sprintf("%1.1f hours", $delta/3600) if $delta < 24*60*60 && $delta > 60*60;
   $string = sprintf("%1.1f days", $delta/(24*3600)) if $delta < 365*24*60*60 && $delta >= 24*60*60;
   $string = sprintf("%1.1f years", $delta/(365*24*3600)) if $delta >= 365*24*60*60;

   return ($string, $delta);
}

1; # For use

__END__

=head1 NAME

ListGarden.pm

=head1 VERSION

This is ListGarden.pm v1.3.1.

=head1 AUTHOR

Dan Bricklin, Software Garden, Inc.

=head1 COPYRIGHT

(c) Copyright 2004, 2005 Software Garden, Inc.
All Rights Reserved.

See Software License in the program file.

=cut

#
# HISTORY
#
# Version 1.3
# $Date: 2005/08/04 18:04:44 $
# $Revision: 1.14 $
#
# Version 1.3.1 2 Aug 2005 9:50 EDT
#   Fixed some bugs with missing {{name}}'s in HTML output
#   Cleaned up comments about {{name}}'s
#   Added {{itemenclosureurlraw}}
#
# Version 1.3Beta2 31 Jul 2005 15:44 EDT
#   Added Load Feed Setting From URL functionality
#
# Version 1.3Beta2 30 Jul 2005 20:41 EDT
#   Added enclosure Get Info and auto type retrieval
#   Changed Description Template to textarea
#   Added expand_desc with all non-HTML mode plus:
#   {{amp}}, {{lt}}, {{gt}}, {{quot}}, {{lbracket}}, {{rbracket}}, {{lbrace}}
#
# Version 1.3Beta1 27 Jul 2005 16:15 EDT
#   Added enclosures to the list of item elements
#   Added ability to browse for enclosure information,
#    including FTP URL, directory, user, password, and prefix
#   Added the Backup Data feature to publishing, both by FTP and local,
#    single and multiple file, with and without password saving
#   Added Item Additional XML
#   Added RSS Tag Additional Text
#   Fixed GUID creation to use months starting with 1, not 0
#   Added GUID radio buttons to Edit Item
#   Upgraded non-HTML mode of item description to create HTML:
#    Line breaks preserved as <br>, [b:bold text], [i:italic text],
#    [quote:block quote text], and [http://some.url link text]
#   Upgraded displayed doc for HTML Template For Each Item to
#    refer to other variables and added enclosure values
#   Added better FTP progress messages and fixed spurious error report
#
# Version 1.02 21 Sep 2004 16:17 EDT
#   File::Glob removed (not in enough distributions) and
#   spaces in datafile pathname are wildcarded with ? instead
#   of exact match
#
# Version 1.02 20 Sep 2004 17:01 EDT
#   Added Channel Additional XML (channeladdlxml) feature
#
# Version 1.02 20 Sep 2004 15:18 EDT
#   Added File::Glob to handle pathnames with spaces
#
# Version 1.02 8 Jul 2004 16:03 EDT
#   Moved <script> tags to after target defined for cleanliness
#
# Version 1.01 7 Jul 2004 11:50 EDT
#   Multiple forms and button reordering to fix "text and Enter" problem
#   Better browser compatibility with DOCTYPE and CSS tweaks
#   Clean up HTML in various places to look better
#   UTF-8 BOM handling
#   When no feeds, focus is put in Create text field
#   Handle text in numeric fields better
#
# Version 1.00 28 Jun 2004 22:35 EDT
#   Dan Bricklin, Software Garden, Inc. (http://www.softwaregarden.com/)
#   -Intitial version
#
#
# TODO:
#
#

=begin license

SOFTWARE LICENSE

This software and documentation is
Copyright (c) 2004, 2005 Software Garden, Inc.
All rights reserved. 

1. The source code of this program is made available as free software;
you can redistribute it and/or modify it under the terms of the GNU
General Public License, version 2, as published by the Free Software
Foundation.

2. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details. You should have received a
copy of the GNU General Public License along with this program; if not,
write to the Free Software Foundation, Inc., 59 Temple Place - Suite
330, Boston, MA  02111-1307, USA.

3. If the GNU General Public License is restrictive in a way that does
not meet your needs, contact the copyright holder (Software Garden,
Inc.) to inquire about the availability of other licenses, such as
traditional commercial licenses. 

4. The right to distribute this software or to use it for any purpose
does not give you the right to use Servicemarks or Trademarks of
Software Garden, Inc., including Garden, Software Garden, and
ListGarden. 

5. An appropriate copyright notice will include the Software Garden,
Inc., copyright, and a prominent change notice will include a
reference to Software Garden, Inc., as the originator of the code
to which the changes were made.

Exception for Executable Bundle 

In some cases this program is distributed together with programs and
libraries of ActiveState Corporation as a single executable file (an
"Executable Bundle") produced using ActiveState Corporation's "Perl Dev
Kit" PerlTray program ("PDK PerlTray"). This free software license does
not apply to those programs and libraries of ActiveState Corporation
that are part of the Executable Bundle. You only have a license to use
those programs and libraries of ActiveState Corporation for runtime
purposes in order to execute this software of Software Garden, Inc. In
order to create and distribute similar executable files from modified
source files, you will need to license your own copy of PDK PerlTray. 

As a specific exception for this product to the terms and conditions of
the GNU General Public License version 2, you are free to distribute
this software (modified or unmodified) in an Executable Bundle created
with PDK PerlTray as long as you adhere to the GNU General Public
License in all respects for all software components except for those of
PDK PerlTray added by that program when used to create the Executable
Bundle. 

Disclaimer 

THIS SOFTWARE IS PROVIDED BY SOFTWARE GARDEN, INC., "AS IS" AND ANY
EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
WARRANTIES OF INFRINGEMENT AND THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL SOFTWARE GARDEN, INC. NOR ITS EMPLOYEES AND OFFICERS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
OTHERWISE) ARISING IN ANY WAY OUT OF THE DISTRIBUTION OR USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 

Software Garden, Inc.
PO Box 610369
Newton Highlands, MA 02461 USA
www.softwaregarden.com

License version: 1.2/2005-07-27 

=end

=cut
