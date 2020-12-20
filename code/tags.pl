#!/usr/bin/perl
#============================================================
#
#        FILE: tags.pl
#
#       USAGE: perl ./tags.pl
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0
#      Created: Sun 12/20/20 16:47:38
#============================================================

use strict;
use warnings;
use List::MoreUtils 'uniq';
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');
no warnings 'utf8';

my $d = ',';
my $nb = qr/[^\]\[]/;
my $dspt = {
  section => {
    order => '1a',
    re => qr/^\s+%+\s+(.*)\s+%+/,
  },
  author => {
    order => '2a',
    re => qr/^\s*By\s+(.*)/,
  },
  series => {
    order => '3a',
    re => qr/^=+\/\s*(.*)\s*\/=+/,
  },
  title => {
    order => '4a',
    re => qr/^(\s*)>\s*(.*)/,
  },
  tags => {
    order => '4b',
    re => qr{(?x)
      ^\s*\[($nb*)\]\s*\[($nb*)\]($nb*)\n$
      |^\s*\[($nb*)\]($nb*)\n$
      |^\s*([~OX\$\*]+)\s*\n$
    },
  },
  url => {
    order => '4c',
    re => qr/(https?:\/\/[^\s]+)\s+(.*)/,
  },
  description => {
    order => '4d',
    re => qr/^#(.*)/,
  },
};
