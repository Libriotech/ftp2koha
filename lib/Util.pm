=pod

=encoding UTF-8

=head1 Util.pm

Utility functions for ftp2koha.

=cut

package Util;

use Modern::Perl;
use MARC::Record;
use Data::Dumper;
use Business::ISBN;
use List::Compare;

=head2 make_fields

Takes a piece of configuration like this:

  add_fields:
    - field: 942
      subfields:
        c: BOK

And returns a list of MARC fields that can be inserted into a record like this:

  $record->insert_fields_ordered( Util:make_fields( $config->{'add_fields'} ) );

=cut

sub make_fields {

    my ( $config ) = @_;

    my @outfields;
    foreach my $field ( @{ $config } ) {
        # Create a new field
        my $field = MARC::Field->new( $field->{ 'field' }, '', '', %{ $field->{ 'subfields' } } );
        push @outfields, $field;
    }

    return @outfields;

}

=head2 match_on_isbn

  my $got_match = match_on_isbn( $koha_record, $incoming_record, $debug );

Takes two records, checks if they have ISBNs and does a match on them. All
forms of the ISBNs are considered.

Returns:

=over 4

=item * 1 = We have a match.

=item * 0 = We do not have a match.

=back

=cut

sub match_on_isbn {

    my ( $koha_record, $incoming_record, $debug ) = @_;

    # Check if Koha record has ISBN
    my @koha_isbns = _get_isbns_from_record( $koha_record );
    return 0 unless @koha_isbns;

    # Check if incoming record has ISBN
    my @incoming_isbns = _get_isbns_from_record( $incoming_record );
    return 0 unless @incoming_isbns;

    # Compare ISBNs
    return _do_isbn_match( \@koha_isbns, \@incoming_isbns );

}

=head2 _do_isbn_match

  my $bool = _do_isbn_match( \@koha_isbns, \@incoming_isbns );

Do the actual matching of ISBNs. Rules:

=over 4

=item * Match on any form of an ISBN

=item * If there are more than one ISBN on either side, the number must match,
ans every ISBN must have a matching counterpart.

=back

Returns:

=over 4

=item * 1 = We have a match.

=item * 0 = We do not have a match.

=back

=cut

sub _do_isbn_match {

    my ( $isbns1, $isbns2 ) = @_;

    # Check we have an equal number
    return 0 unless scalar @{ $isbns1 } == scalar @{ $isbns2 };

    # Check the simple case - we have 1 ISBN
    if ( scalar @{ $isbns1 } == 1 ) {
        if ( $isbns1->[0] eq $isbns2->[0] ) {
            return 1;
        }
    }

    my @norm1 = map { _normalize_isbn( $_ ) } @{ $isbns1 };
    my @norm2 = map { _normalize_isbn( $_ ) } @{ $isbns2 };

    my $lc = List::Compare->new( \@norm1, \@norm2 );
    # From the docs: "Get those items which appear at least once in either the
    # first or the second list, but not both."
    # So if we get an empty list, that means we have a match!
    my @result = $lc->get_symmetric_difference;
    if ( scalar @result == 0 ) {
        return 1;
    } else {
        return 0;
    }

}

=head2 _normalize_isbn

  my $normalized_isbn = _normalize_isbn( $some_isbn );

Takes an ISBN in some form and returns a normalized version.

=cut

sub _normalize_isbn {

    my ( $isbn_in ) = @_;

    my $isbn = Business::ISBN->new( $isbn_in );

    return $isbn->as_isbn10->as_string;

}

=head2 _get_isbns_from_record

  my @isbns = _get_isbns_from_record( $marc_record );

Takes a MARC::Record as input. Returns an array of ISBN-numbers from 020$a (and
nothing more).

=cut

sub _get_isbns_from_record {

    my ( $record ) = @_;

    my @isbns;
    my @fields = $record->field( '020' );
    foreach my $field ( @fields ) {
        my $isbn = $field->subfield( 'a' );
        if ( $isbn ) {
            push @isbns, $isbn;
        }
    }

    return @isbns;

}

=head2 _make_isbn_variations

  my $variations = _make_isbn_variations( @isbns );

Takes a list of ISBNs as input and returns an arrayref of possible variants (with
and without hyphens, isbn10/13).

=cut

sub _make_isbn_variations {

    my ( @isbns_in ) = @_;

    my %isbns;

    foreach my $raw_isbn ( @isbns_in ) {
        $isbns{ $raw_isbn }++;
        my $isbn = Business::ISBN->new( $raw_isbn );
        return undef unless $isbn;
        # TODO Make sure we have a valid ISBN
        if ( $isbn->error ) {
            say "ISBN error: " . $isbn->error_text;
            say "ISBN error code: " . $isbn->error;
            return undef;
        }
        # With hyphens
        if ( $isbn->as_isbn10 && $isbn->as_isbn10->as_string ) {
            $isbns{ $isbn->as_isbn10->as_string }++;
        }
        if ( $isbn->as_isbn13 && $isbn->as_isbn13->as_string ) {
            $isbns{ $isbn->as_isbn13->as_string }++;
        }
        # Without hyphens
        if ( $isbn->as_isbn10 && $isbn->as_isbn10->as_string([]) ) {
            $isbns{ $isbn->as_isbn10->as_string([]) }++;
        }
        if ( $isbn->as_isbn13 && $isbn->as_isbn13->as_string([]) ) {
            $isbns{ $isbn->as_isbn13->as_string([]) }++;
        }
    }

    my @keys = sort keys %isbns;
    my $keys_ref = \@keys;

    return $keys_ref;

}

sub preserve_fields {

    my ( $koha_record, $incoming_record, $preserve_fields, $summary, $debug ) = @_;

    # Delete these fields from the Libris record
    foreach my $field_num ( @{ $preserve_fields } ) {
        say "Deleting $field_num" if $debug;
        my @fields = $incoming_record->field( $field_num );
        say Dumper \@fields if $debug;
        $incoming_record->delete_fields( @fields );
    }
    # Now copy the same fields from the Koha record to the incoming record
    foreach my $field_num ( @{ $preserve_fields } ) {
        say "Copying $field_num" if $debug;
        my @fields = $koha_record->metadata->record->field( $field_num );
        say Dumper \@fields if $debug;
        $summary->{'preserved_fields'} += scalar @fields;
        $incoming_record->insert_fields_ordered( @fields );
    }

    return $incoming_record;

}

sub delete_fields {

    my ( $record, $delete_fields, $debug ) = @_;

    foreach my $delete_field ( @{ $delete_fields } ) {

        my $delete_field_num = $delete_field->{ 'field' };

        # Delete a whole field
        if ( !defined $delete_field->{ 'subfield' } ) {

            say "Deleting $delete_field_num" if $debug;
            my @fields = $record->field( $delete_field_num );
            say Dumper \@fields if $debug;
            $record->delete_fields( @fields );

        # Only delete one subfield
        } else {

            say "Deleting $delete_field_num $delete_field->{ 'subfield' }" if $debug;
            foreach my $field ( $record->field( $delete_field_num ) ) {
                $field->delete_subfield( code => $delete_field->{ 'subfield' } );
            }

        }
    }

    return $record;

}

=head2 filter_on_852b

Takes a list of values (defined as a hash with 1 as values, for convenience):

  filter_on_852b:
    x: 1
    y: 1

Select all 852-fields and checks if the value in subfield b is in the list above.
If it is, the field is kept. If it is not, the field is deleted.

Returns the record, sans the deleted fields.

If the filter_values is undef, the record is returned unchanged.

=cut

sub filter_on_852b {

    my ( $record, $filter_values, $debug ) = @_;

    # Return the record if the filter_values are not defined
    return $record unless $filter_values;

     # Loop over all 852's
    my @fields = $record->field( '852' );
    foreach my $field ( @fields ) {
        if ( $field->subfield( 'b' ) ) {
            # Delete tjhe whole field if the value of 852$b is not in the filter_values
            my $b = $field->subfield( 'b' );
            unless ( defined $filter_values->{ $b } ) {
                say "Deleting field with 852\$b = $b" if $debug;
                $record->delete_field( $field );
            }
        }
    }

    return $record;

}

1;
