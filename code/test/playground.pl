#!/usr/bin/env perl
use warnings;
use strict;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Ohm::Hasher;

#my $lib  = Ohm::Hasher->new({
#    input => './output.txt',
#    dspt => './dspt_deimos.json',
#    drsr => './drsr_lib.json',
#    mask => './mask_lib.json',
#    prsv => {till => ['section', 0]},
#    sdrsr => [
#        './sdrsr_rentry.json'
#    ],
#    smask =>
#    [
#        [ './smask_masterbin.json', 'sdrsr_rentry' ],
#        [ './smask_catalog.json', 'sdrsr_rentry' ],
#    ],
#});
#$lib->gen_dspt();
#$lib->check_matches();

my $lib2  = Ohm::Hasher->new();
$lib2->gen_dspt();
$lib2->check_matches();
#$lib2->launch();


do {};
