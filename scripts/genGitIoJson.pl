#!/usr/bin/env perl
#============================================================
#
#         FILE: extjsons.pl
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#  DESCRIPTION:
#      Created: Sat 06/12/21 14:04:27
#============================================================
use strict;
use warnings;
use Data::Dumper;
use JSON::PP;

##  paste keys
opendir( my $dir, '../archive_7/')
    or die "Cannot open directory: $!";
    my @files = readdir $dir;
closedir( $dir );


##  gitio urls
my @pasteKeys     = grep { $_ =~ /\w{6}/  } @files;
my $head          = 'https://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/';
my %gitIoHash     = map {
                            my $gitIoUrl =  `./gitio.pl ${head}${_}`;
                            chomp $gitIoUrl;
                            $_ => $gitIoUrl;
                        } @pasteKeys;


## generate jsons
my $json = JSON::PP->new->ascii->pretty->allow_nonref;
my $txt  = $json->encode(\%gitIoHash);
open( my $fh, '>' ,'../code/json/gitIo.json2') or die $!;
    print $fh $txt;
    truncate $fh, tell( $fh ) or die;
close( $fh );

