#!/usr/bin/perl

use YAML::Syck;
use Data::Dumper;
use Modern::Perl;
use MARC::File::XML;
use Test2::V0;
use Test2::Bundle::More;
plan 30;

use lib 'lib';
use Util;

# _get_isbn_from_record

my $record1 = _get_record1();
my $record2 = _get_record2();
# Check type
isa_ok( $record1, 'MARC::Record' );
isa_ok( $record2, 'MARC::Record' );

my $isbn1_1 = '9789127136472';
my @found_isbns1 = Util::_get_isbns_from_record( $record1 );
is( $found_isbns1[0], $isbn1_1, 'found the right single ISBN' );

my $isbn2_1 = '9788862085694';
my $isbn2_2 = '9788862085687';
my $isbn2_3 = '9788862085700';
my @found_isbns2 = Util::_get_isbns_from_record( $record2 );
is( $found_isbns2[0], $isbn2_1, 'found the right ISBN' );
is( $found_isbns2[1], $isbn2_2, 'found the right ISBN' );
is( $found_isbns2[2], $isbn2_3, 'found the right ISBN' );

# _do_isbn_match

# Arrays of different length should fail
my @fail_list1 = qw( a );
my @fail_list2 = qw( a b );
is( Util::_do_isbn_match( \@fail_list1, \@fail_list2 ), 0, 'fail on arrays of different length' );

# Single ISBNs

my @one_list1 = qw( 9788862085694 );
my @one_list2 = qw( 9788862085687 );
# Simple case, identical ISBNs
is( Util::_do_isbn_match( \@one_list1, \@one_list1 ), 1, 'identical ISBNs' );
# Simple case, different ISBNs
is( Util::_do_isbn_match( \@one_list1, \@one_list2 ), 0, 'different ISBNs' );

# Lists of ISBNs

my @two_list1_same_order = qw( 9788862085694 9788862085687 );
my @two_list2_same_order = qw( 9788862085694 9788862085687 );
is( Util::_do_isbn_match( \@two_list1_same_order, \@two_list2_same_order ), 1, 'two identical ISBNs, same order' );

# Same as above, but order is switched in the second array
my @two_list1_diff_order = qw( 9788862085694 9788862085687 );
my @two_list2_diff_order = qw( 9788862085687 9788862085694 );
is( Util::_do_isbn_match( \@two_list1_diff_order, \@two_list2_diff_order ), 1, 'two identical ISBNs, different order' );

# Two ISBNs are the same, two are different from each other
my @two_list1_not_same = qw( 9789185283736 9789185283910 );
my @two_list2_not_same = qw( 9789185283736 9789100132651 );
is( Util::_do_isbn_match( \@two_list1_not_same, \@two_list2_not_same ), 0, 'different ISBNs in lists' );

# ISBNs with variations

# Same ISBN, with and without hyphens
my @one_var1 = qw( 978-91-7166-116-6 );
my @one_var2 = qw( 9789171661166 );
is( Util::_do_isbn_match( \@one_var1, \@one_var2 ), 1, 'same ISBN, with and without hyphens' );

# Different ISBNs, one with and one without hyphens
my @one_var1_fail = qw( 978-91-7166-116-6 );
my @one_var2_fail = qw( 9789100132651 );
is( Util::_do_isbn_match( \@one_var1_fail, \@one_var2_fail ), 0, 'different ISBNs, with and without hyphens' );

# Compare ISBN10 and ISBN13

my @one_13_hyph = qw( 978-91-85283-97-2 );
my @one_10_hyph = qw( 91-85283-97-5 );
is( Util::_do_isbn_match( \@one_13_hyph, \@one_10_hyph ), 1, 'compare isbn13 to isbn10, with hyphens' );

my @one_13_nohyph = qw( 9789185283972 );
my @one_10_nohyph = qw( 9185283975 );
is( Util::_do_isbn_match( \@one_13_nohyph, \@one_10_nohyph ), 1, 'compare isbn13 to isbn10, without hyphens' );
is( Util::_do_isbn_match( \@one_13_hyph, \@one_10_nohyph ), 1, 'compare isbn13 to isbn10, with some hyphens' );
is( Util::_do_isbn_match( \@one_13_nohyph, \@one_10_hyph ), 1, 'compare isbn13 to isbn10, with some hyphens' );

my @other_10_hyph = qw( 91-7001-661-5 );
my @other_10_nohyph = qw( 9170016615 );
is( Util::_do_isbn_match( \@one_13_hyph, \@other_10_hyph ), 0, 'compare non-matching isbn13 to isbn10, with hyphens' );
is( Util::_do_isbn_match( \@one_13_nohyph, \@other_10_nohyph ), 0, 'compare non-matching isbn13 to isbn10, without hyphens' );

# ISBN10 and ISBN13 in a list
my @long_list1 = qw( 978-91-7166-116-6 9789185283972 91-7001-661-5 );
my @long_list2 = qw( 978-91-7166-116-6 9185283975    9170016615 );
is( Util::_do_isbn_match( \@long_list1, \@long_list2 ), 1, 'matching, misc variatons' );

my @fail_long_list1 = qw( 978-91-7166-116-6 9789185283972 91-7001-661-5 );
my @fail_long_list2 = qw( 978-91-7166-116-6 9185283975    9185283975 );
is( Util::_do_isbn_match( \@fail_long_list1, \@fail_long_list2 ), 0, 'non-matching, misc variatons' );

# Make ISBN variations

my $variations1 = [ '91-7166-116-6', '9171661166', '978-91-7166-116-6', '9789171661166' ];
is_deeply( Util::_make_isbn_variations( '978-91-7166-116-6' ), $variations1, 'one ISBN13 with hyphens' );
is_deeply( Util::_make_isbn_variations( '9789171661166' ),     $variations1, 'one ISBN13 without hyphens' );

my $variations2 = [ '91-7001-661-5', '9170016615', '978-91-7001-661-5', '9789170016615' ];
is_deeply( Util::_make_isbn_variations( '91-7001-661-5' ), $variations2, 'one ISBN10 with hyphens' );
is_deeply( Util::_make_isbn_variations( '9170016615' ),    $variations2, 'one ISBN10 without hyphens' );

my $variations3 = [ '91-7001-661-5', '91-7166-116-6', '9170016615', '9171661166', '978-91-7001-661-5', '978-91-7166-116-6', '9789170016615', '9789171661166' ];
is_deeply( Util::_make_isbn_variations( '978-91-7166-116-6', '9170016615' ), $variations3, 'one ISBN13 with hyphens, one ISBN10 without' );
is_deeply( Util::_make_isbn_variations( '9789171661166', '91-7001-661-5' ),  $variations3, 'one ISBN13 without hyphens, one ISBN10 with' );

# ISBNs that have caused trouble in the wild
my $variations4 = [ '91-8033-188-2', '9180331882', '978-91-8033-188-3', '9789180331883' ];
is_deeply( Util::_make_isbn_variations( '9789180331883' ), $variations4, 'problematic ISBN 9789180331883' );

# At least this one was causing trouble because of an out of date RangeMessage.xml
# See the README for how to avoid this
my $variations5 = [ '91-8033-452-0', '9180334520', '978-91-8033-452-5', '9789180334525' ];
is_deeply( Util::_make_isbn_variations( '9789180334525' ), $variations5, 'problematic ISBN 9789180334525' );

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

sub _get_record2 {

    my $xml = 
 '<record xmlns="http://www.loc.gov/MARC21/slim" type="Bibliographic">
  <leader>     cam a       3a 4500</leader>
  <controlfield tag="001">14404979</controlfield>
  <controlfield tag="003">SE-LIBR</controlfield>
  <controlfield tag="005">20160906170825.0</controlfield>
  <controlfield tag="007">cr |||   |||||         </controlfield>
  <controlfield tag="008">130622s2014    sw |||||o|||||000 0|swe|d</controlfield>

  <datafield ind1=" " ind2=" " tag="020">
   <subfield code="a">9788862085694</subfield>978862085694 978862085687 978862085700
  </datafield>
  <datafield ind1=" " ind2=" " tag="020">
   <subfield code="a">9788862085687</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="020">
   <subfield code="a">9788862085700</subfield>
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
   <subfield code="a">X</subfield>
   <subfield code="b">Y</subfield>
  </datafield>
  <datafield ind1=" " ind2=" " tag="887">
   <subfield code="5">BinE</subfield>
   <subfield code="a">{"@id":"x296wcb30fxxkmm","modified":"2021-12-07T17:39:38.247+01:00","checksum":"20706258244"}</subfield>
   <subfield code="2">librisxl</subfield>
  </datafield>
 </record>';

    return MARC::Record->new_from_xml( $xml, 'UTF-8', 'MARC21' );

}
