#!/usr/bin/perl

# Copyright 2015 Magnus Enger Libriotech

=head1 NAME

ftp2koha.pl - Download MARC records from an FTP site and load them into Koha.

=head1 SYNOPSIS

 perl ftp2koha.pl --config my_config.yml -v

=cut

use C4::Context;
use C4::Barcodes::ValueBuilder;
use C4::Biblio qw( AddBiblio ModBiblio GetMarcFromKohaField );
use Koha::Biblios;
use Koha::Item;
use Koha::DateUtils qw( dt_from_string output_pref );

use MARC::File::USMARC;
use MARC::File::XML ( BinaryEncoding => 'utf8', RecordFormat => 'MARC21' );
use MARC::Field;
use Text::Diff;
use Text::Diff::Table;
use YAML::Syck;
use Getopt::Long;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use DateTime;
use Pod::Usage;
use Modern::Perl;

use FindBin qw($Bin);
use lib "$Bin/lib";
use Util;

binmode STDOUT, ":utf8";
$|=1; # Flush output

my $dt = DateTime->now;
my $date = $dt->ymd;

# Get options
my ( $config_file, $filename, $local_file, $test, $comment, $limit, $verbose, $debug ) = get_options();

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
say "Using config from $config_file" if $debug;
# Load the config
my $config = LoadFile( $config_file );

my @done;

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
    say "Going to download $filename to $local_path" if $debug;

    # Do the actual download (with wget)
    my $ftp = "wget -O $local_path ftp://" . $config->{'ftp_host'} . $config->{'ftp_path'} . $filename;
    say "Going to do $ftp" if $debug;
    `$ftp`;

    # Check that the file now exists locally, and has a non-zero size
    if ( ! -s $local_path ) {
        die "$local_path does not exist or is empty!";
    } else {
        say "Local file $local_path exists" if $debug;
    }

}

say "Going to use $local_path" if $debug;

## Import the data into Koha

say "Starting to massage MARC records" if $debug;
my $records_count = 0;
my $records;

if ( $config->{'marc_format'} && $config->{'marc_format'} eq 'xml' ) {
    say "Got a MARCXML file" if $debug;
    $records = MARC::File::XML->in( $local_path );
} else {
    say "Got an ISO2709 file" if $debug;
    $records = MARC::File::USMARC->in( $local_path );
}

my $dbh = C4::Context->dbh;

## Loop over the records in the file

RECORD: while ( my $record = $records->next() ) {

    last RECORD if $limit && $limit == $records_count;

    $record->encoding( 'UTF-8' );

    my $summary;

    say "------------------------------" if $verbose;
    my $id_001 = $record->field('001')->data();
    my $id_003 = $record->field('003')->data();
    say "ID from 001+003: $id_001 $id_003" if $verbose;
    $summary->{ 'id_001' } = $id_001;
    $summary->{ 'id_003' } = $id_003;

    # Check if this is a record we should skip
    if ( defined $config->{'skip_records'} ) {
        foreach my $skip ( @{ $config->{'skip_records'} } ) {
           my @contents = $record->subfield( $skip->{'field'}, $skip->{'subfield'} );
           say Dumper @contents if $debug;
           if ( @contents ) {
                foreach my $content ( @contents ) {
                   if ( defined $skip->{'contains'} && $content =~ m/$skip->{'contains'}/g ) {
                       say "Skipping because '$content' contains '$skip->{'contains'}'" if $verbose;
                       $summary->{'action'} = 'SKIP';
                       next RECORD;
                   }
               }
           }
       }
    }

    my $itemdetails = '';

=head1 MATCHING

We need to check Koha to see if there are records we should merge with or replace,
or if this is a new record that should be inserted.

=head2 Match on Control Number (001) and Control Number Identifier (003)

If we find a record with matching 001 and 003, we merge with/replace that record.
There should only be one matching record.

=cut

    my $sth = $dbh->prepare("
        SELECT biblionumber, metadata
        FROM biblio_metadata
        WHERE
          ExtractValue( metadata, '//controlfield[\@tag=\"001\"]' ) = '$id_001' AND
          ExtractValue( metadata, '//controlfield[\@tag=\"003\"]' ) = '$id_003'
    ");
    $sth->execute();
    my $hits = $sth->fetchall_arrayref;
    say "Matching on 001+003" if $debug;
    say Dumper $hits if $debug;

=head2 Fallback to matching only on Control Number (001)

If

=over 4

=item * we did not find any matches, and

=item * fallback_to_001_matching is set to 1, and

we do another matching, similar to the one above, but matching only on 001, not on
003.

=cut

    if ( scalar @{ $hits } == 0 && defined $config->{'fallback_to_001_matching'} && $config->{'fallback_to_001_matching'} == 1 ) {

        my $sth_fallback = $dbh->prepare("
            SELECT biblionumber, metadata
            FROM biblio_metadata
            WHERE
              ExtractValue( metadata, '//controlfield[\@tag=\"001\"]' ) = '$id_001'
        ");
        $sth_fallback->execute();
        $hits = $sth_fallback->fetchall_arrayref;
        say "Matching on 001" if $debug;
        say Dumper $hits if $debug;

    }

    # Proceed according to the number of hits found
    if ( scalar @{ $hits } > 0 ) {

        say "We have an existing record, going to UPDATE it." if $verbose;
        $summary->{'action'} = 'UPDATE';
        if ( scalar @{ $hits } > 1 ) {
            say "PROBLEM: More than 1 hit for 001 = $id_001" if $verbose;
        }
        # We use the first one, even if there were more than 1
        my $biblionumber = $hits->[0]->[0];

        # Do the update
        my ( $itemdetails, $summary ) = _update_record( $biblionumber, $record, $summary, $config, $verbose, $debug );

        $records_count++;
        say "$records_count: " . $record->title . " [$itemdetails]" if $verbose;
        push @done, $summary;

        say "Found a match based on 001/003, going to look at next record" if $verbose;
        next RECORD;

    } # End of matching on 001+003

=head2 Match on ISBN

Koha stores ISBNs in biblioitems.isbn. Data in this field can look like this:

  9100132659 | 978-91-0-013265-1 | 978-91-7429-346-3 | 91-7429-346-X

We take the ISBNs from our active record, transform them into possible variant
forms and do a very inclusive lookup in biblioitems.isbn, to find potential
candidates for a match. Then we compare ISBNs from the actual records to determine
if we have a match or not.

Matching on ISBNs is activated with the B<match_on_isbn> config variable.

=cut

    if ( defined $config->{'match_on_isbn'} && $config->{'match_on_isbn'} == 1 ) {

        # Get ISBNs from incoming record
        my @isbns = Util::_get_isbns_from_record( $record );
        if ( @isbns ) {

            say Dumper @isbns if $debug;

            # Get all the variants of all the ISBNs
            my $variations = Util::_make_isbn_variations( @isbns );

            if ( $variations ) {

                # Turn ISBNs into SQL
                my $sql = "SELECT biblionumber FROM biblio_metadata WHERE biblionumber IN ( SELECT biblionumber FROM biblioitems WHERE isbn LIKE '";
                $sql .= join( "%' OR isbn LIKE '%", @{ $variations } );
                $sql .= "' );";
                say $sql if $debug;

                my $sth_isbn = $dbh->prepare( $sql );
                $sth_isbn->execute();
                my $hits_isbn = $sth_isbn->fetchall_hashref( 'biblionumber' );
                say Dumper $hits_isbn if $debug;

                # Look trough all the candidates until we find one that matches
                CANDIDATE: foreach my $candidate ( keys %{ $hits_isbn } ) {
                    say "Looking at biblionumber=$candidate" if $verbose;
                    my $biblio = Util::find_biblio( $candidate );
                    if ( $biblio ) {
                        my $result = Util::match_on_isbn( $biblio->metadata->record, $record, $debug );
                        say "match_on_isbn: $result" if $verbose;
                        if ( $result && $result == 1 ) {

                            # We have a match!
                            $summary->{'action'} = 'UPDATEISBN';
                            my ( $itemdetails, $summary ) = _update_record( $candidate, $record, $summary, $config, $verbose, $debug );

                            $records_count++;
                            say "$records_count: " . $record->title . " [$itemdetails]" if $verbose;
                            push @done, $summary;

                            say "Found a match based on ISBN, going to look at next record" if $verbose;
                            next RECORD;

                        }
                    } else {
                        say "Bad biblionumber=$candidate" if $verbose;
                    }
                }

                say "No match on ISBN" if $verbose;

            } else {
                say "Could not create variations on ISBN" if $verbose;
            }

        }

    } else {
        say "No matching on ISBN" if $verbose;
    } # End of matching on ISBN

=head2 Insert a new record

No matches so far, so we insert the active record as a new record.

=cut

    say "We have a new record, going to INSERT it." if $verbose;
    $summary->{'action'} = 'INSERT';

    say "--- INCOMING RECORD ---" if $verbose;
    say $record->as_formatted if $verbose;

    # We should add items according to the config file
    my $item;

    if ( defined $config->{'skip_items'} && $config->{'skip_items'} == 0 ) {

        # Check if there are items that should be treated in a special way
        if ( $config->{'special_items'} ) {
            SPECIAL: foreach my $special ( @{ $config->{'special_items'} } ) {
                # Special treatment for controlfields
                if ( $record->field( $special->{'field'} ) && MARC::Field->is_controlfield_tag( $special->{'field'} ) ) {
                    my $cfield = $record->field( $special->{'field'} )->data;
                    say $cfield if $debug;
                    my $substr_pos = $special->{'position'};
                    my $position_data = substr $cfield, $substr_pos, 1;
                    say $position_data if $debug;
                    if ( $position_data eq $special->{'text'} ) {
                        ( $item, $itemdetails ) = _make_item( $special );
                        $item = Util::item_values_from_record( $item, $record, $config->{'item_values_from_record'} );
                        last SPECIAL; # Make sure we only add an item for the first match
                    }
                }
                if (
                    ! MARC::Field->is_controlfield_tag( $special->{'field'} ) &&
                    $record->field( $special->{'field'} ) &&
                    $record->subfield( $special->{'field'}, $special->{'subfield'} ) &&
                    $record->subfield( $special->{'field'}, $special->{'subfield'} ) =~ m/$special->{'text'}/gi
                ) {
                    ( $item, $itemdetails ) = _make_item( $special );
                    $item = Util::item_values_from_record( $item, $record, $config->{'item_values_from_record'} );
                    last SPECIAL; # Make sure we only add an item for the first match
                }
            }
        } # End special_items

        # If $itemdetails is still empty, none of the special cases took effect so we add a standard item
        if ( $itemdetails eq '' ) {
            # The rest of the items get the default values
            ( $item, $itemdetails ) = _make_item( $config );
            $item = Util::item_values_from_record( $item, $record, $config->{'item_values_from_record'} );
        }

        # Check if we should pick a callnumber from the record
        # Only do this if there isn't one already
        if ( !defined $item->{ 'itemcallnumber' } && $config->{'callnumber_field'} && $config->{'callnumber_subfield'} ) {
            my $field    = $config->{'callnumber_field'};
            my $subfield = $config->{'callnumber_subfield'};
            if ( $record->field( $field ) && $record->subfield( $field, $subfield ) && $record->subfield( $field, $subfield ) ne '' ) {
                $item->{'itemcallnumber'} = $record->subfield( $field, $subfield );
            }
        }
        say Dumper $item if $debug;
        $itemdetails = "$config->{'952a'} $config->{'952b'} $config->{'952y'}";

    } # End config skip_items

    # Check if there is any data we should add
    if ( defined $config->{'add_fields'} ) {
        my @added_fields = Util::make_fields( $config->{'add_fields'} );
        say "Added fields:" if $debug;
        say Dumper @added_fields if $debug;
        $record->insert_fields_ordered( @added_fields );
    }

    # Delete fields that should be deleted from the incoming record
    $record = Util::delete_fields( $record, $config->{'delete_fields'}, $debug );

    # Remove 852-fields that we do not want to keep
    $record = Util::filter_on_852b( $record, $config->{'filter_on_852b'}, $debug );

    say "--- EDITED RECORD ---" if $verbose;
    say $record->as_formatted if $verbose;

    unless ( $test ) {

        # Import the record and the item into Koha
        my ( $biblionumber, $biblioitemnumber ) = AddBiblio( $record, $config->{'frameworkcode'} );
        if ( $biblionumber ) {
            say "New record saved with biblionumber=$biblionumber" if $verbose;
            $summary->{'biblionumber'} = $biblionumber;
        } else {
            say "Ooops, something went wrong while saving the record!" if $verbose;
        }

        # Import the item, if we have defined it
        if ( $item ) {
            # Set the biblionumber
            $item->{ 'biblionumber' } = $biblionumber;
            # Set 952$x to "ftp2koha"
            if ( $comment ) {
                $item->{ 'itemnotes_nonpublic' } = 'ftp2koha';
            }
            # Add the new item
            my $new_item = Koha::Item->new( $item )->store;
            # Get the itemnumber
            my $itemnumber = $new_item->itemnumber;
            if ( $itemnumber  ) {
                say "Added item with itemnumber = $itemnumber" if $verbose;
            } else {
                say "Ooops, something went wrong while saving the item" if $verbose;
            }
        } else {
            say "No item to add" if $verbose;
        }

    } else {

        say "Item data not imported (because of --test):" if $verbose;
        say Dumper $item if $debug;
        $summary->{'biblionumber'} = 'test';
    }

    $records_count++;
    say "$records_count: " . $record->title . " [$itemdetails]" if $verbose;
    push @done, $summary;

} # End of record loop

say "------------------------------" if $verbose;
say "Done ($records_count records)" if $verbose;

## Optional cleanup

if ( $config->{'cleanup'} ) {
    unlink $local_path;
    say "$local_path deleted" if $debug;
}

say "*** This was a test run, no records were imported ***" if $test;
say "Summary:" if $verbose;
foreach my $rec ( @done ) {
    $rec->{'preserved_fields'} = 0 unless defined $rec->{'preserved_fields'};
    say "$rec->{ 'action' } $rec->{ 'biblionumber' } ($rec->{ 'id_001' } $rec->{ 'id_003' }) [$rec->{'preserved_fields'}]" if $verbose;
}

# This should be the last thing we output, so we can test for it in the log to
# see if the script completed or not
say "DONE" if $verbose;

=head1 INTERNAL FUNCTIONS

=head2 _update_record

Takes:

=over 4

=item * a biblionumber for a biblio in Koha

=item * a MARC::Record object for the record from the external source

=item * config

=item * verbose flag

=item * debug flag

=back

=cut

sub _update_record {

    my ( $biblionumber, $record, $summary, $config, $verbose, $debug ) = @_;

    say "biblionumber=$biblionumber" if $verbose;
    $summary->{'biblionumber'} = $biblionumber;

    say "--- KOHA RECORD ---" if $verbose;
    my $biblio = Util::find_biblio( $biblionumber );
    if ( $biblio ) {
        say $biblio->metadata->record->as_formatted if $verbose;
    } else {
        say "Bad biblionumber=$biblionumber" if $verbose;
    }

    say "--- LIBRIS RECORD ---" if $verbose;
    say $record->as_formatted if $verbose;

    ## Delete fields that should be deleted from the incoming record
    $record = Util::delete_fields( $record, $config->{'delete_fields'}, $debug );

    # Remove 852-fields that we do not want to keep
    $record = Util::filter_on_852b( $record, $config->{'filter_on_852b'}, $debug );

    if ( $biblio ) {
        ## Preserve fields that should be preserved
        $record = Util::preserve_fields( $biblio, $record, $config->{'preserve_fields'}, $summary, $debug );
    }

    # Check if there are any fields we should add
    if ( defined $config->{'add_fields'} ) {
        # Generate the fields from the config
        my @added_fields = Util::make_fields( $config->{'add_fields'} );
        # Loop through the fields
        foreach my $added_field ( @added_fields ) {
            # Get fields with the same tag from the record
            my @existing_fields = $record->field( $added_field->tag );
            # Get the number of fields with the same tag
            my $num_existing = scalar @existing_fields;
            # Insert the field if it is not already there
            if ( $num_existing == 0 ) {
                say "Added field:" if $debug;
                say Dumper $added_field if $debug;
                $record->insert_fields_ordered( $added_field );
            }
        }
    }

    say "--- MERGED RECORD ---" if $verbose;
    say $record->as_formatted if $verbose;

    if ( $biblio ) {
        # Diff
        say "--- DIFF ---" if $debug;
        say diff \$biblio->metadata->record->as_formatted, \$record->as_formatted, { STYLE => "Text::Diff::Table" } if $debug;
    }

    # Save the changed record
    unless ( $test ) {

        my $res = ModBiblio( $record, $biblionumber, $config->{'frameworkcode'} );
        if ( $res == 1 ) {
            say "Record with biblionumber = $biblionumber was UPDATED" if $verbose;
        } else {
            say "Record with biblionumber = $biblionumber was NOT updated" if $verbose;
        }

    } else {
        say "In test mode, no changes made" if $verbose;
    }

    my $itemdetails = 'No items changed';

    return ( $itemdetails, $summary );

}

=head2 _make_item

Takes a configuration for an item:

  - field: 008
    position: 22
    text: j
    952a: 'SBI'   # Homebranch
    952b: 'SBI'   # Holdingbranch
    952c: 'BARNB' # Shelving location code. LOC
    952y: 'LASE'  # Item type
    9527: '0'    # Not for loan. -1 = Ordered
    9528: 'BARN'  # Collection code. CCODE
    barcode: auto

And returns a hashref of item data plus a string to show home- and holdinglibrary,
and itemtype.

=cut

sub _make_item {

    my ( $config ) = @_;

    my $item = {
        'homebranch'     => $config->{'952a'}, # Homebranch
        'holdingbranch'  => $config->{'952b'}, # Holdingbranch
        'location'       => $config->{'952c'}, # Shelving location code
        'itype'          => $config->{'952y'}, # Item type
        'notforloan'     => $config->{'9527'}, # Not for loan
        'ccode'          => $config->{'9528'}, # Collection code
        'itemcallnumber' => $config->{'952o'}, # Koha full call number
    };
    if ( defined $config->{'barcode'} && $config->{'barcode'} eq 'auto' ) {
        my $newbarcode = _get_next_barcode();
        say "Going to add barcode=$newbarcode" if $debug;
        $item->{ 'barcode' } = $newbarcode;
    }
    my $itemdetails = "$config->{'952a'} $config->{'952b'} $config->{'952y'}";

    return ( $item, $itemdetails );

}

=head2 _get_next_barcode

Generate the next barcode.

=cut

sub _get_next_barcode {


    my %args;

    # find today's date
    my $dt = DateTime->today;
    ($args{year}, $args{mon}, $args{day}) = split('-', output_pref({ dt => $dt, dateformat => 'iso', dateonly => 1 }));
    ($args{tag},$args{subfield})       =  GetMarcFromKohaField( "items.barcode" );
    ($args{loctag},$args{locsubfield}) =  GetMarcFromKohaField( "items.homebranch" );

    my $nextnum;
    my $scr;
    my $autoBarcodeType = C4::Context->preference("autoBarcode");
    if ((not $autoBarcodeType) or $autoBarcodeType eq 'OFF') {
        # don't return a value unless we have the appropriate syspref set
        return '';
    }
    if ($autoBarcodeType eq 'annual') {
        ($nextnum, $scr) = C4::Barcodes::ValueBuilder::annual::get_barcode(\%args);
        return $nextnum;
    }

    return undef;

}

=head1 OPTIONS

=over 4

=item B<-c, --config_file>

Path to config file. See F<sample_config.yml> for an example with extensive
comments describing all the config variables.

=item B<-f, --filename>

Provide a specific filename to look for on the FTP server. This will override
the filename created from the B<ftp_file> config variable.

This is useful if you need to download files that are older than the current
date, or if the remote file always has the same name, regardless of the date.

=item B<-l, --localfile>

Use a local file for testing and development, or if you are fetching records by
some other means than FTP.

=item B<-t, --test>

Perform all steps, except the actual import of records. Also turns on verbose
mode.

=item B<--comment>

Put a comment with the text "ftp2koha" in 952$x, to make it easy to pick out
items added by this script.

=item B<--limit>

Limit to x records.

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
    my $comment     = '';
    my $limit       = '';
    my $verbose     = '';
    my $debug       = '';
    my $help        = '';

    GetOptions (
        'c|config=s'    => \$config_file,
        'f|filename=s'  => \$filename,
        'l|localfile=s' => \$local_file,
        't|test'        => \$test,
        'comment=s'     => \$comment,
        'limit=i'       => \$limit,
        'v|verbose'     => \$verbose,
        'd|debug'       => \$debug,
        'h|?|help'      => \$help
    );

    pod2usage( -exitval => 0 ) if $help;
    pod2usage( -msg => "\nMissing Argument: -c, --config required\n", -exitval => 1 ) if !$config_file;

    # Test mode should always be verbose
    $verbose = 1 if $test;

    return ( $config_file, $filename, $local_file, $test, $comment, $limit, $verbose, $debug );

}

=head1 TIPS AND TRICKS

=head2 Find new records and items in the logs

  $ sudo grep -n -e "New record saved" -e "Added item" *

=head2 Find items added by this script in the database

If you run it with --comment, at least.

  SELECT itemnumber, barcode, itype, location, ccode FROM items WHERE itemnotes_nonpublic = 'ftp2koha';

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
