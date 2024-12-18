#!/usr/bin/perl

use YAML::Syck;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use Modern::Perl;
use MARC::File::XML;
use Test2::V0;
use Test2::Bundle::More;
plan 6;

use lib 'lib';
use Util;

my $yaml = do { local $/; <main::DATA> };
my $config = Load $yaml;

my $record = _get_record1();
# Show formatted record
# diag( $koha_record->as_formatted );
# Check type
isa_ok( $record, 'MARC::Record' );

my @fields = $record->field( '650' );
is ( scalar @fields, 3, 'we have three fields' );

# Process the record
$record = Util::delete_fields_on_content( $record, $config->{ 'delete_fields_on_content' } );

# Check type
isa_ok( $record, 'MARC::Record' );

# diag( $record->as_formatted );

# Check there is just one 650 field
my @fields_after = $record->field( '650' );
# diag( Dumper @fields_after );
is ( scalar @fields_after, 1, 'we have one field' );

# Check field has expected data
is ( $record->subfield( '650', '2' ), 'X', '$2 is X' );
is ( $record->subfield( '650', 'a' ), 'Y', '$a is Y' );

sub _get_record1 {

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
  <datafield ind1="1" ind2=" " tag="650">
   <subfield code="2">qlit</subfield>
   <subfield code="a">A</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="650">
   <subfield code="2">Qlit</subfield>
   <subfield code="a">A</subfield>
  </datafield>
  <datafield ind1="1" ind2=" " tag="650">
   <subfield code="2">X</subfield>
   <subfield code="a">Y</subfield>
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
   <subfield code="5">A</subfield>
   <subfield code="b">B</subfield>
   <subfield code="h">C</subfield>
   <subfield code="x">D</subfield>
   <subfield code="x">E</subfield>
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
delete_fields_on_content:
  - field: 650
    subfield: 2
    contains: qlit
