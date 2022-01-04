#!/usr/bin/perl

use YAML::Syck;
use Data::Dumper;
use Modern::Perl;
use MARC::File::XML;
use Test2::V0;
use Test2::Bundle::More;
plan 8;

use lib 'lib';
use Util;

my $yaml = do { local $/; <main::DATA> };
my $config = Load $yaml;

my $record = _get_record();
my $merged_record = $record->clone;
$merged_record = Util::delete_fields( $merged_record, $config->{ 'delete_fields' }, 0 );

# diag( $record->as_formatted );
# diag( '-----------------------------------------------------------' );
# diag( $merged_record->as_formatted );

isa_ok( $record,        'MARC::Record' );
isa_ok( $merged_record, 'MARC::Record' );

# Check deleted fields are no longer present
foreach my $field ( @{ $config->{ 'delete_fields' } } ) {

    my @fields_in_old_record    = $record->field( $field->{ 'field' } );
    my @fields_in_merged_record = $merged_record->field( $field->{ 'field' } );

    if ( !defined $field->{ 'subfield' } ) {

        my $num_fields_in_old_record    = scalar @fields_in_old_record;
        my $num_fields_in_merged_record = scalar @fields_in_merged_record;

        ok( $num_fields_in_old_record > 0, "we have $num_fields_in_old_record $field->{ 'field' } field(s) in old record" );
        is( $num_fields_in_merged_record, 0, "we have 0 $field->{ 'field' } field(s) in merged record" );

    } else {

        my $num_subfields_in_old_record       = 0;
        my $num_subfields_in_merged_record = 0;

        foreach my $field_in_old_record ( @fields_in_old_record ) {
            my @subfields_in_old_record = $field_in_old_record->subfield( $field->{ 'subfield' } );
            $num_subfields_in_old_record += scalar @subfields_in_old_record;
        }
        foreach my $field_in_merged_record ( @fields_in_merged_record ) {
            my @subfields_in_merged_record = $field_in_merged_record->subfield( $field->{ 'subfield' } );
            $num_subfields_in_merged_record += scalar @subfields_in_merged_record;
        }
        ok( $num_subfields_in_old_record > 0, "we have $num_subfields_in_old_record subfields $field->{ 'field' } $field->{ 'subfield' } in old record" );
        is( $num_subfields_in_merged_record, 0, "we have $num_subfields_in_merged_record subfields $field->{ 'field' } $field->{ 'subfield' } in merged record" );

    }

}

sub _get_record {

    my $xml = 
 '<record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
  <leader>     cam a       3a 4500</leader>
  <controlfield tag="001">14404979</controlfield>
  <controlfield tag="003">SE-LIBR</controlfield>
  <controlfield tag="005">20160906170825.0</controlfield>
  <controlfield tag="007">cr |||   |||||         </controlfield>
  <controlfield tag="008">130622s2014    sw |||||o|||||000 0|swe|d</controlfield>
  <datafield ind1=" " ind2=" " tag="020">
   <subfield code="a">9789127136472</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="035">
   <subfield code="a">Elib1014537</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="040">
   <subfield code="e">a</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="040">
   <subfield code="f">a</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="041">
   <subfield code="a">swe</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="100">
   <subfield code="a">Cain, Susan</subfield>
   <subfield code="4">aut</subfield>
   <subfield code="0">https://libris.kb.se/fcrv2f3z3786dds#it</subfield>
  </datafield>
  <datafield ind1="1" ind2="0" tag="245">
   <subfield code="a">Tyst</subfield>
   <subfield code="h">[Elektronisk resurs]</subfield>
  </datafield>
  <datafield ind1=" " ind2="1" tag="264">
   <subfield code="b">Natur &amp; Kultur,</subfield>
   <subfield code="c">2014</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="380">
   <subfield code="a">Psykologi</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="520">
   <subfield code="a">I en tid då...</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="599">
   <subfield code="a">Ändrad av Elib 2013-09-24</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="700">
   <subfield code="a">Wallin, Bitte</subfield>
   <subfield code="4">trl</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="600">
   <subfield code="a">X</subfield>
   <subfield code="b">Y</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="600">
   <subfield code="c">X</subfield>
   <subfield code="d">Y</subfield>
  </datafield>
  <datafield ind1="4" ind2="2" tag="856">
   <subfield code="u">https://images.elib.se/cover/1014537/1014537_201602091540.jpg</subfield>
   <subfield code="x">digipic</subfield>
   <subfield code="z">Omslagsbild</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="887">
   <subfield code="a">{"@id":"m5z3dggz1qw4qr3","modified":"2016-09-06T17:08:25+02:00","checksum":"55007571632"}</subfield>
   <subfield code="2">librisxl</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="841">
   <subfield code="5">BinE</subfield>
   <subfield code="a">x  a</subfield>
   <subfield code="b">160120||0000|||||000||||||000000</subfield>
   <subfield code="e">u</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="599">
   <subfield code="5">BinE</subfield>
   <subfield code="a">deleted</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="852">
   <subfield code="5">BinE</subfield>
   <subfield code="b">BinE</subfield>
   <subfield code="h">Ej tillgänglig</subfield>
   <subfield code="x">origin:Elib</subfield>
   <subfield code="x">deleted</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="887">
   <subfield code="5">BinE</subfield>
   <subfield code="a">{"@id":"x296wcb30fxxkmm","modified":"2021-12-07T17:39:38.247+01:00","checksum":"20706258244"}</subfield>
   <subfield code="2">librisxl</subfield>
  </datafield>
 </record>';

    return MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );

}

__DATA__
---
delete_fields:
  - field: 040
  - field: 041
  - field: 600
    subfield: b
