package Util;

use Modern::Perl;
use MARC::Record;
use Data::Dumper;

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
