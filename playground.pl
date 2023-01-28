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
https://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@github.com/azuhmier/hmofa.git
