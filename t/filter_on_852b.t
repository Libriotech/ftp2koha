#!/usr/bin/perl

use YAML::Syck;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Modern::Perl;
use MARC::File::XML;
use Test2::V0;
use Test2::Bundle::More;
plan 8;

use lib 'lib';
use Util;

my $yaml = do { local $/; <main::DATA> };
my $config = Load $yaml;

# diag( Dumper $config );

my $record = _get_record();
my $filtered_record = $record->clone;
$filtered_record = Util::filter_on_852b( $filtered_record, $config->{ 'filter_on_852b' }, 0 );

# diag( $record->as_formatted );
# diag( '-----------------------------------------------------------' );
# diag( $filtered_record->as_formatted );

isa_ok( $record,          'MARC::Record' );
isa_ok( $filtered_record, 'MARC::Record' );

my @fields_in_old_record      = $record->field( '852' );
my @fields_in_filtered_record = $filtered_record->field( '852' );

my $num_fields_in_old_record      = scalar @fields_in_old_record;
my $num_fields_in_filtered_record = scalar @fields_in_filtered_record;

is( $num_fields_in_old_record,      3, "we have $num_fields_in_old_record fields in old record" );
is( $num_fields_in_filtered_record, 2, "we have $num_fields_in_filtered_record field in filtered record" );

my @fields_852 = $filtered_record->field( '852' );
is( $fields_852[0]->subfield( 'b' ), 'x', "first field is \$b = x" );
is( $fields_852[1]->subfield( 'b' ), 'y', "second field is \$b = y" );
is( $fields_852[2], undef, 'no more fields' );

my $filtered_record2 = $record->clone;
$filtered_record2 = Util::filter_on_852b( $filtered_record2, undef, 0 );
is_deeply( $filtered_record2, $record, 'no change on undefined config' );

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
  <datafield ind1=" " ind2=" " tag="852">
   <subfield code="5">x</subfield>
   <subfield code="b">x</subfield>
   <subfield code="h">Ej tillgänglig</subfield>
   <subfield code="x">origin:Elib</subfield>
   <subfield code="x">deleted</subfield>
  </datafield>
    <datafield ind1=" " ind2=" " tag="852">
   <subfield code="5">y</subfield>
   <subfield code="b">y</subfield>
   <subfield code="h">Ej tillgänglig</subfield>
   <subfield code="x">origin:Elib</subfield>
   <subfield code="x">deleted</subfield>
  </datafield>
    <datafield ind1=" " ind2=" " tag="852">
   <subfield code="5">z</subfield>
   <subfield code="b">z</subfield>
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
filter_on_852b:
  x: 1
  y: 1
