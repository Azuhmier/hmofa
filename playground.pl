#!/usr/bin/env perl
use warnings;
use strict;
use lib ($ENV{HOME}.'/hmofa/hmofa/lib');
use Ohm::Hasher;

my $lib  = Ohm::Hasher->new();
$lib->gen_dspt();
$lib->check_matches();
$lib->launch();


do {};
