#!/usr/bin/perl

#
# Original software (c) Copyright 2004, 2005 Software Garden, Inc. All Rights Reserved.
# pRSSlist Copyright (c) 2009, lantrix, TechDebug.com
# Subject to Software License at the end of this file
#

#
# prsslist RSS Generator Program
#
# This is the interface for using the program
# through a normal web server.
#
# Put this file in a cgi-bin directory or equivalent
# and use a browser to access the UI.
#

   use strict;

   use pRSSlist;

   use CGI::Carp qw(fatalsToBrowser);


   # Output header

   print <<"EOF";
Content-type: text/html; charset=UTF-8
Expires: Thu, 01 Jan 1970 00:00:00 GMT

EOF

   # Get query parameters

   my $query;
   if ($ENV{REQUEST_METHOD} eq 'POST') {
      read(STDIN, $query, $ENV{CONTENT_LENGTH});
      }
   else {
      $query = $ENV{QUERY_STRING};
      }

   # Process the request and output the results

   my $content = process_request($query, 1);

   if ($content) {
      print $content;
      }
   else {
      print <<"EOF";
<html>
<head>
<title>Quitting</title>
<body>
Quitting.<br><br><b>You may close the browser window.</b>
<br><br>
<a href="$ENV{SCRIPT_NAME}">Restart</a>
</body>
</html>
EOF
      }

__END__

=head1 NAME

prsslistcgi.pl

=head1 VERSION

This is prsslistcgi.pl v2.0.

=head1 AUTHOR

Originally authored by Dan Bricklin, Software Garden, Inc.
pRSSlist author lantrix, Techdebug.com

=head1 COPYRIGHT

Original Software (c) Copyright 2004, 2005 Software Garden, Inc. All Rights Reserved.
pRSSlist Copyright (c) 2009, lantrix, TechDebug.com

See Software License in the program file.

=cut

#
# HISTORY
#
# Version 2.0 17 Nov 2009
#   Created inital version of pRSSlist from ListGarden
#
#
# TODO:
#
#

=begin license

SOFTWARE LICENSE

Original software (c) Copyright 2004, 2005 Software Garden, Inc. All Rights Reserved.
pRSSlist Copyright (c) 2009, lantrix, TechDebug.com

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

3. An appropriate copyright notice will include the original Software Garden,
Inc. copyright plus the pRSSlist copyright, and a prominent change notice will include a
reference to Software Garden, Inc., as the originator of the code
to which the changes were made.

Disclaimer 

THE SOFTWARE IS PROVIDED “AS IS” AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Original Software Creator:
Software Garden, Inc.
PO Box 610369
Newton Highlands, MA 02461 USA
www.softwaregarden.com

=end

=cut
