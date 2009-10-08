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
# by doing local HTTP serving
#
# Execute this file to start listening for
# a browser to access the UI.
#

   use strict;

   use ListGarden;

   use URI;
   use HTTP::Daemon;
   use HTTP::Status;
   use HTTP::Response;
   use Socket;

#
# Get options.
#
# Start by going through each command line option and saving values.
#
# The short definition of the options is in the "--help" text
# here.
#

   my %commandmap = (d => "datafile", s => "socket");

   while (@ARGV) {
      if ($ARGV[0] eq '--help' || $ARGV[0] eq '-h') {
         print <<"EOF";
Usage: $0 [options]
  --datafile=filename, -d filename
                      Prefix of file for saving values (default: $config_values{datafile})
  --help, -h          Show this help info
  --socket=n, -s n    Socket to listen to for browser (default: $config_values{socket})
EOF
         exit;
         }

      elsif ($ARGV[0] =~ /^--(datafile|socket)=(.*)/) {
         $config_values{$1} = $2;
         shift @ARGV;
         }

      elsif ($ARGV[0] =~ /^-(d|s)$/) {
         shift @ARGV;
         $config_values{$commandmap{$1}} = shift @ARGV;
         }
      }

# # # # # # # # # #
#
# Main program to act as a simple local web server
# It calls process_request to do the work.
#
# # # # # # # # # #

   my $quit;

   my $d = HTTP::Daemon->new (
                    LocalPort => $config_values{socket},
                    Reuse => 1);

   if (!$d) {
      print <<"EOF";
$programname
Unable to create a listener on local port $config_values{socket}.
Use the "-s number" command option to specify a
different socket number (1024 < number < 65536).
EOF

      exit;
      }

   print "$programname\nTo access UI, display in browser: http://127.0.0.1:$config_values{socket}/\n";

   while (my $c = $d->accept) {

      # Make sure the request is from our machine

      if ($c) {
         my ($port, $host) = sockaddr_in(getpeername($c));
         if ($host ne inet_aton("127.0.0.1")) {
            $c->close;  # no - ignore request completely
            undef($c);
            next;
            }
         }

      # Process the request

      while ((defined $c) && (my $r = $c->get_request)) {
         if ($r->method eq 'POST' || $r->method eq 'GET') {
            $c->force_last_request;
            if ($r->uri =~ /favicon/) {   # if this is a request for favicon.ico, ignore
               $c->send_error(RC_NOT_FOUND);
               next;
               }
            my $res = new HTTP::Response(200);
            $res->content_type("text/html; charset=UTF-8");
            $res->expires("-1d");

            my $responsecontent;
            if ($r->method eq 'POST') {
               $responsecontent = process_request($r->content());
               }
            else {
               $responsecontent = process_request($r->uri->query());
               }

            if ($responsecontent) {
               $res->content($responsecontent);
               }
            else {
               $res->content(<<"EOF");
<html>
<head>
<title>Quitting</title>
<body>
Quitting.<br><br><b>You may close the browser window.</b>
<br><br>
<a href="">Retry</a>
</body>
</html>
EOF
               $quit = 1;
               }

            $c->send_response($res);

            }

         else {
            $c->send_error(RC_FORBIDDEN);
            }

         if ($quit) {
            $c->close;
            undef($c);
            exit;
            }
         }

      $c->close;
      undef($c);
      }


__END__

=head1 NAME

listgarden.pl

=head1 VERSION

This is listgarden.pl v1.02.

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
# Version 1.02 20 Sep 2004 15:23 EDT
#   Added check to ignore favicon.ico requests to fix problem with Firefox 1.0PR
#
# Version 1.00 25 Jun 2004 15:05 EDT
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
