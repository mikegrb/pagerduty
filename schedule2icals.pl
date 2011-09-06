#!/usr/bin/env perl

# schedule2icals.pl: create ical files for pagerduty schedules
#
# Output:
#   * file per defined Pagerduty schedule with events for each user
#   * file per seen user with events for the periods they are on call named
#       for the schedule
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
use File::Slurp;
use Mojo::UserAgent;
use Storable 'dclone';
use Data::ICal::DateTime;
use Mojo::Util 'url_escape';
use DateTime::Format::W3CDTF;
use Data::ICal::Entry::Event;

my $user       = 'username@domain.com';    # pagerduty login email
my $pass       = 'open-sesame';            # pagerduty password
my $sub_domain = 'subdomain';              # pagerduty sub domain
my $ical_path  = '/srv/www/icals/';        # output path for ical file
my %schedules  = (
    Primary   => 'PF6U36S',                # keys are schedule names,
    Secondary => 'PBX62U2'                 # values are pagerduty schedule ids
);

my $first_of_month = DateTime->now->set( day => 1 );
my $ua = Mojo::UserAgent->new;

my $url = Mojo::URL->new( 'http://' . $sub_domain . '.pagerduty.com' );
$url->userinfo( $user . ':' . $pass );
$url->query(
    since => $first_of_month->format_cldr('yyyy-MM-dd'),
    until => $first_of_month->add( months => 3 )->format_cldr('yyyy-MM-dd') );

for my $sched ( keys %schedules ) {
    $url->path( '/api/v1/schedules/' . $schedules{$sched} . '/entries' );
    my $result = $ua->get($url);
    die "Something went wrong! " . $result->res->body
        unless $result->res->json && $result->res->json->{entries};
    $schedules{$sched} = $result->res->json->{entries};
}

my %user_schedules;

my $dt = DateTime::Format::W3CDTF->new();
for my $sched ( keys %schedules ) {
    my $cal = Data::ICal->new();
    for my $shift ( @{ $schedules{$sched} } ) {
        my $event = Data::ICal::Entry::Event->new();
        $event->start( $dt->parse_datetime( $shift->{start} ) );
        $event->end( $dt->parse_datetime( $shift->{end} ) );
        $event->summary( $shift->{user}{name} );
        $cal->add_entry($event);

        $event = dclone($event);
        $event->summary( $sched . ' on Call' );
        push @{ $user_schedules{ $shift->{user}{name} } }, $event;
    }
    overwrite_file( $ical_path . lc($sched) . '.ics', $cal->as_string );
}

for my $user ( keys %user_schedules ) {
    my $cal = Data::ICal->new();
    $cal->add_entry($_) for @{ $user_schedules{$user} };
    ( my $filename = $user ) =~ tr/ /_/;
    overwrite_file( $ical_path . lc($filename) . '.ics', $cal->as_string );
}
