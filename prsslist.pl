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
# by doing local HTTP serving
#
# Execute this file to start listening for
# a browser to access the UI.
#

   use strict;

   use pRSSlist;

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

prsslist.pl

=head1 VERSION

This is prsslist.pl v2.0.

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
