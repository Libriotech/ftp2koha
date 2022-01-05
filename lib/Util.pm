package Util;

use Modern::Perl;
use MARC::Record;
use Data::Dumper;

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

1;
