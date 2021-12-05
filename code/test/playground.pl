#!/usr/bin/evn perl
use warnings;
use strict;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Ohm::Hasher;

my $mst = Ohm::Hasher->new('./masterbin.txt',  './deimos.json', './drsr_M.json', {till => ['section', 1]});
my $cat = Ohm::Hasher->new('./catalog.txt',    './deimos.json', './drsr_C.json', {till => ['section', 1]});
my $lib = Ohm::Hasher->new('./hmofa_lib.json', './deimos.json', './drsr_H.json');
#$hash->chg_prsv({ till => ['section', 1]});
#$hash->chg_prsv('section', 1);
#$hash->chg_prsv(['section', 1]);
#$hash->chg_prsv(['section', 'masterbin']);
#be strict on name: [A-Za-z0-9_]; case insesitive; treat _ as nonexistant
#make creating a dir a big deal
do {};
