#!/usr/bin/perl

use YAML::Syck;
use Data::Dumper;
use Modern::Perl;
use MARC::File::XML;
use Test2::V0;
use Test2::Bundle::More;
plan 10;

use lib 'lib';
use Util;

# make_fields

my $yaml = do { local $/; <main::DATA> };
my $config = Load $yaml;

my @fields = Util::make_fields( $config->{'add_fields'} );

is( scalar @fields, 2, 'got 2 fields' );

my $field1 = $fields[0];
isa_ok( $field1, 'MARC::Field' );
is( $field1->tag(), '942', 'tag is right' );
is( scalar $field1->subfields(), 1, 'got 1 subfield' );
is( $field1->subfield( 'c' ), 'BOK', 'content in subfield c is right' );

my $field2 = $fields[1];
isa_ok( $field2, 'MARC::Field' );
is( $field2->tag(), '943', 'tag is right' );
is( scalar $field2->subfields(), 2, 'got 2 subfields' );
is( $field2->subfield( 'a' ), '1', 'content in subfield a is right' );
is( $field2->subfield( 'b' ), '2', 'content in subfield b is right' );

__DATA__
---
add_fields:
  - field: 942
    subfields:
      c: BOK
  - field: 943
    subfields:
      a: 1
      b: 2
