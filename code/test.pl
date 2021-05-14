#!/usr/bin/env perl
use strict;
use warnings;

my $txt = "ta I tell youa what a a";
my @mat = $txt =~ /\w*a/g;
print "@mat\n";
print "@-\n";
print "@+\n";
print "$+[0]\n";
print "$-[0]\n";

while ($txt =~ m/\w*a/g) { print "@-,@+\n"; }
