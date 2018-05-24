#!/usr/bin/perl 

# Copyright 2015 Magnus Enger Libriotech

=head1 NAME

ftp2koha.pl - Download MARC records from an FTP site and load them into Koha.

=head1 SYNOPSIS

 perl ftp2koha.pl --config my_config.yml -v

=cut

# use Net::FTP;
use MARC::File::USMARC;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'UNIMARC' );
use YAML::Syck;
use Getopt::Long;
use Data::Dumper;
use DateTime;
use Pod::Usage;
use Modern::Perl;

binmode STDOUT, ":utf8";
$|=1; # Flush output

my $dt = DateTime->now;
my $date = $dt->ymd;

# Get options
my ( $config_file, $filename, $local_file, $test, $verbose, $debug ) = get_options();

=pod

=head1 CONFIGURATION

Most of the configuration of this script is done with a configuration file. See
the F<sample_config.yml> file provided with this script for an example, and 
read the comments in that file for details on how to configure it. 

=cut

# Check that the config file exists
if ( !-e $config_file ) {
    print "The file $config_file does not exist...\n";
    exit;
}
say "Using config from $config_file" if $verbose;
# Load the config
my $config = LoadFile( $config_file );

my $local_path;
if ( $local_file ) {

    # We are using a local file
    $local_path = $local_file;

} else {

    # Figure out the filename and the local path for saving it
    if ( $filename eq '' ) {
        # Construct the filename from the ftp_file config variable
        $filename = DateTime->now->subtract( hours => $config->{'subtract_hours'} )->strftime( $config->{'ftp_file'} );
    }
    $local_path = $config->{'local_dir'} . $filename;
    say "Going to download $filename to $local_path" if $verbose;

    # Do the actual download (with wget)
    my $ftp = "wget -O $local_path ftp://" . $config->{'ftp_host'} . $config->{'ftp_path'} . $filename;
    say "Going to do $ftp" if $verbose;
    `$ftp`;

    # Check that the file now exists locally, and has a non-zero size
    if ( ! -s $local_path ) {
        die "$local_path does not exist!";
    } else {
        say "Local file $local_path exists" if $verbose;
    }

}

say "Going to use $local_path" if $verbose;

## Import the data into Koha

say "Starting to massage MARC records" if $verbose;
my $records_count = 0;
my $records;

if ( $local_path =~ m/xml$/i ) {
    say "Got a MARCXML file" if $verbose;
    $records = MARC::File::XML->in( $local_path );
} else {
    say "Got an ISO2709 file" if $verbose;
    $records = MARC::File::USMARC->in( $local_path );
}

while ( my $record = $records->next() ) {

    my $itemdetails = '';
    my $field952;

    # Check if there are items that should be treated in a special way
    if ( $config->{'special_items'} ) {
        foreach my $special ( @{ $config->{'special_items'} } ) {
            if ( $record->field( $special->{'field'} ) && $record->subfield( $special->{'field'}, $special->{'subfield'} ) && $record->subfield( $special->{'field'}, $special->{'subfield'} ) =~ m/$special->{'text'}/gi ) {
                $field952 = MARC::Field->new( 952, ' ', ' ',
                    'a' => $special->{'952a'}, # Homebranch
                    'b' => $special->{'952b'}, # Holdingbranch
                    'y' => $special->{'952y'}, # Item type
                    '7' => $special->{'9527'}, # Not for loan
                );
                $itemdetails = "$special->{'952a'} $special->{'952b'} $special->{'952y'}";
                last; # Make sure we only add an item for the first match
            }
        }
    }

    # If $itemdetails is still empty, none of the special cases took effect
    if ( $itemdetails eq '' ) {
        # The rest of the items get the default values
        $field952 = MARC::Field->new( 952, ' ', ' ',
            'a' => $config->{'952a'}, # Homebranch
            'b' => $config->{'952b'}, # Holdingbranch
            'y' => $config->{'952y'}, # Item type
            '7' => $config->{'9527'}, # Not for loan
        );
        $itemdetails = "$config->{'952a'} $config->{'952b'} $config->{'952y'}";
    }

    $record->insert_fields_ordered( $field952 );
    $records_count++;
    say "$records_count: " . $record->title . " [$itemdetails]" if $verbose;

}
say "Done ($records_count records)" if $verbose;

## Import the records into Koha

## Optional cleanup

if ( $config->{'cleanup'} ) {
    unlink $local_path;
    say "$local_path deleted" if $verbose;
}

say "*** This was a test run, no records were imported ***" if $test;

=head1 OPTIONS

=over 4

=item B<-c, --config_file>

Path to config file.

=item B<-f, --filename>

Provide a specific filename to look for on the FTP server. This will override
the filename created from the B<ftp_file> config variable.

This is useful if you need to download files that are older than the current
date, or if the remote file always has the same name, regardless of the date.

=item B<-l, --localfile>

Use a local file for testing and development.

=item B<-t, --test>

Perform all steps, except the actual import of records. Also turns on verbose
mode.

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
    my $config_file = '';
    my $filename    = '';
    my $local_file  = '';
    my $test        = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';

    GetOptions (
        'c|config=s'    => \$config_file,
        'f|filename=s'  => \$filename,
        'l|localfile=s' => \$local_file,
        't|test'        => \$test,
        'v|verbose'     => \$verbose,
        'd|debug'       => \$debug,
        'h|?|help'      => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n", -exitval => 1 ) if !$config_file;
    
    # Test mode should always be verbose
    $verbose = 1 if $test;

    return ( $config_file, $filename, $local_file, $test, $verbose, $debug );

}

=head1 AUTHOR

Magnus Enger, magnus [at] libriotech.no

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
