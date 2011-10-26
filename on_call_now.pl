#!/usr/bin/env perl

# on_call_now.pl: retrieve the name of the person on call now
#
# (C) 2011 Linode, LLC <mgreb@linode.com>
# ***************************************************************************
# * This program is free software; you can redistribute it and/or modify it *
# * under the terms of the GNU General Public License as published  by  the *
# * Free Software Foundation; either version 2 of the License, or (at  your *
# * option) any later version.                                              *
# *                                                                         *
# * This program is distributed in the hope that it  will  be  useful,  but *
# * WITHOUT ANY WARRANTY; without the implied warranty  of  MERCHANTABILITY *
# * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License *
# * for more details.                                                       *
# *                                                                         *
# * You should have received a copy of the GNU General Public License along *
# * with this program; if not, write to the Free Software Foundation, Inc., *
# * 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA                   *
# ***************************************************************************

use 5.010;
use strict;
use warnings;

use DateTime;
use Mojo::UserAgent;

my $user       = 'username@domain.com';    # pagerduty login email
my $pass       = 'open-sesame';            # pagerduty password
my $sub_domain = 'subdomain';              # pagerduty sub domain
my $ical_path  = '/srv/www/icals/';        # output path for ical file
my %schedules  = (
    Primary   => 'PF6U36S',                # keys are schedule names,
    Secondary => 'PBX62U2'                 # values are pagerduty schedule ids
);

my $now_string = DateTime->now()->format_cldr('yyyy-MM-ddTHH:mmZ');
my $ua = Mojo::UserAgent->new;
my $url = Mojo::URL->new( 'https://' . $sub_domain . '.pagerduty.com' );
$url->userinfo( $user . ':' . $pass );
$url->query( since => $now_string, until => $now_string );

my %on_call;
for my $sched ( keys %schedules ) {
    $url->path( '/api/v1/schedules/' . $schedules{$sched} . '/entries' );
    my $result = $ua->get($url);
    die "Something went wrong! " . $result->res->body
        unless $result->res->json && $result->res->json->{entries};
    $on_call{$sched} = $result->res->json->{entries}[0]{user}{name};
}

# $on_call{ Primary }  is now the name of the person currently on call for the primary scedule
