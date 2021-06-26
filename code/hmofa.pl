#============================================================
#
#         FILE: hmofa.pm
#        USAGE: ---
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: Fri 06/25/21 13:26:14
#===========================================================
use strict;
use warnings;
use lib ($ENV{HOME} . '/hmofa/hmofa/code/lib/');
use Hmofa::Controller;

my $archives = '../archive_7/';
my $scripts  = '../scripts/';
my $jsons    = './jsons/';
my $getter   = '../gitgoogledocs.pl/';
my @files    = qw(
    ../tagCatalog.txt/
    ../masterbin.txt/
);

