#!/usr/bin/env perl

use strict;
use warnings;
use feature qw(say);
use JSON;

our $var;
local $var;
my %hash = (
    a => {
        a => 1,
        b => 2,
        c => 3,
    },
    b => {
        a => 1,
        b => 2,
        c => 3,
    },
    c => {
        a => 1,
        b => 2,
        c => 3,
    },
);

my $json = JSON::XS->new->utf8->encode ({a => [1,2]});
my $json4 = JSON::XS->new->encode(\%hash);

do {};
do {};
