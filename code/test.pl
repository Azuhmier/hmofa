#!/usr/bin/env perl


#!/usr/bin/env perl
#============================================================
#
#         FILE: hasher.pl
#        USAGE: ./hasher.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: Fri 10/08/21 07:55:11
#===========================================================
use strict;
use warnings;
use utf8;
use Storable qw(dclone);
use JSON::XS;
use B::Deparse;
my $fuck = 1;
print $main::fuck;
my $deparse = B::Deparse->new;
my $code = sub {print "hello, world!"};
print $SIG{__DIE__}, "\n";
do {};
do {};
