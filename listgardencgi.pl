#!/usr/bin/perl

#
# (c) Copyright 2004, 2005 Software Garden, Inc.
# All Rights Reserved.
# Subject to Software License at the end of this file
#

#
# ListGarden RSS Generator Program
#
# This is the interface for using the program
# through a normal web server.
#
# Put this file in a cgi-bin directory or equivalent
# and use a browser to access the UI.
#

   use strict;

   use ListGarden;

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

listgardencgi.pl

=head1 VERSION

This is listgardencgi.pl v1.0.

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
# Version 1.00 24 Jun 2004 15:15 EDT
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
