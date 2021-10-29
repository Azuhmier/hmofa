#!/usr/bin/evn perl
use warnings;
use strict;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Ohm::Hasher;

my $hash = Ohm::Hasher->new('./catalog.txt', './deimos.json');
$hash->chg_prsv([]);
#$hash->chg_prsv({ till => ['section', 1]});
do {};
