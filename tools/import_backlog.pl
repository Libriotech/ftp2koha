#!/usr/bin/perl

# Copyright 2022 Magnus Enger Libriotech

=head1 NAME

import_backlog.pl - Import batch files from Libris between given dates.

Uses the same config file as the main ftp2koha.pl script.

=head1 SYNOPSIS

 perl import_backlog.pl -c /path/to/config.yaml --start 2022-05-17 --end 2022-06-01

=cut

use Time::Piece;
use Time::Seconds;
use Getopt::Long;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use YAML::Syck;
use Pod::Usage;
use Modern::Perl;
binmode STDOUT, ":utf8";

my $script = "/opt/ftp2koha/ftp2koha.pl";

# Get options
my ( $kohasite, $start, $end, $verbose, $debug ) = get_options();

# Get the config from file
my $configfile = "/etc/koha/sites/$kohasite/ftp2koha-config.yaml";
if ( !-e $configfile ) { die "The file $configfile does not exist..."; }
my $config = LoadFile( $configfile );

my $date_format = '%Y-%m-%d';
my $start_t = Time::Piece->strptime( $start, $date_format );
my $end_t   = Time::Piece->strptime( $end,   $date_format );
my $t = localtime;
my $today = $t->ymd;

while ( $start_t <= $end_t ) {

    my $ymd = $start_t->strftime( $date_format );
    my $filename = $start_t->strftime( $config->{ 'ftp_file' } );
    say "Working on $ymd $filename" if $verbose;

    my $logfilepath = "/etc/koha/sites/$kohasite/ftp2koha/ftp2koha-$kohasite-$today-backlog-$ymd.log";

    my $cmd = "sudo /usr/sbin/koha-shell -c "perl $script -c $configfile --debug --verbose --filename $filename" $kohasite &> $logfilepath";
    say $cmd if $debug;
    `$cmd`;

    $start_t += ONE_DAY;

}

=head1 OPTIONS

=over 4

=item B<-k, --kohasite>

Sitename for the Koha site.

=item B<-s, --start>

Date of first file to process.

=item B<-e, --end>

Date of last file to process

=item B<-v --verbose>

More verbose output.

=item B<-d --debug>

Even more verbose output.

=item B<-h, -?, --help>

Prints this help message and exits.

=back

=cut

sub get_options {

    # Options
    my $kohasite = '';
    my $start    = '';
    my $end      = '';
    my $verbose  = '';
    my $debug    = '';
    my $help     = '';

    GetOptions (
        'k|kohasite=s' => \$kohasite,
        's|start=s'    => \$start,
        'e|end=s'      => \$end,
        'v|verbose'    => \$verbose,
        'd|debug'      => \$debug,
        'h|?|help'     => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -k, --kohasite required\n", -exitval => 1 ) if !$kohasite;
    pod2usage( -msg => "\nMissing Argument: -s, --start required\n",    -exitval => 1 ) if !$start;
    pod2usage( -msg => "\nMissing Argument: -e, --end required\n",      -exitval => 1 ) if !$end;

    return ( $kohasite, $start, $end, $verbose, $debug );

}

=head1 AUTHOR

Magnus Enger, <magnus [at] libriotech.no>

=head1 LICENSE

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut
