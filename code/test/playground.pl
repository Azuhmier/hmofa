#!/usr/bin/env perl
use warnings;
use strict;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Ohm::Hasher;

#my $mst  = Ohm::Hasher->new({
#    input => './masterbin.txt',
#    dspt => './deimos.json',
#    drsr => './drsr_M.json',
#    mask => './mask_M.json',
#    prsv => {till => ['section', 1]},
#});
#my $cat  = Ohm::Hasher->new(
#    './catalog.txt',
#    './deimos.json',
#    './drsr_C.json',
#    './mask_C.json',
#    {till => ['section', 1]},
#);
#my $cat2 = Ohm::Hasher->new(
#    '/Users/azuhmier/hmofa/hmofa/code/test/catalog_part.json',
#    './deimos.json',
#    './drsr_C.json',
#    './mask_C.json',
#);

my $lib  = Ohm::Hasher->new(
    '/Users/azuhmier/hmofa/hmofa/code/result/libby.txt',
    './deimos.json',
    './drsr_C.json',
    './mask_C.json',
);
my $lib2  = Ohm::Hasher->new();
do {};
