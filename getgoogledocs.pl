#!/usr/bin/perl
#============================================================
#
#        FILE: getgoogledocs.pl
#
#       USAGE: ./getgoogledocs.pl
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0?
#      Created: https://pdf.co/how-to-get-direct-download-links
#============================================================
use strict;
use warnings;
use LWP::UserAgent;

# define the googledoc ID's
my $masterbin_ID   = '1uTaenno7gn5ZCX5X4NPCcWRqTa_U4d7rtOXZOMuIT0k';
my $download_url   = "https://docs.google.com/document/d/".$masterbin_ID."/export?format=txt";

# get googledoc as txt
my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent('Mozilla/5.0');
my $response = $ua->get($download_url);

# clean up txt and export to file
my $txt = $response->decoded_content;
$txt =~ s/\x{000D}//g;
$txt =~ s/\n\n\n+/\n\n/g;
open(my $fh, '+<', 'masterbin.txt') or die;
  print $fh $txt;
  seek $fh,0,0 or die;
  my @COPY;
  while (my $line = <$fh>) {
    $line =~ s/^\[\w{1,2}\].[^\]]*$//;
    $line =~ s/\[\w{1,2}\]$//;
    $line =~ s/\s+(\n)$/$1/; # '\s' includes newlines, contrary to what it does in vim
    push @COPY, $line;
  }
  seek $fh,0,0 or die;
  for my $line (@COPY) {
    print $fh $line;
  }
  truncate $fh, tell($fh) or die;
close $fh;

##----- REFFS -----
## https://pdf.co/how-to-get-direct-download-links
## (not used) https://perlmaven.com/slurp
## (not used) https://metacpan.org/source/MSCHILLI/Net-Google-Drive-Simple-0.03/lib%2FNet%2FGoogle%2FDrive%2FSimple.pm
