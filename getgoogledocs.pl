#!/usr/bin/env perl
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

#----- FILE VARS -----{{{1
# masterbin
my $ID_masterbin      = '1uTaenno7gn5ZCX5X4NPCcWRqTa_U4d7rtOXZOMuIT0k';
my $url_masterbin     = "https://docs.google.com/document/d/".$ID_masterbin."/export?format=txt";
# tagCatalouge
my $ID_tagCatalog     = '1QsVTOiryr2rb6rXCguZB5apxR04E_1i6PpnAX4CaO3Y';
my $url_tagCatalog    = "https://docs.google.com/document/d/".$ID_tagCatalog."/export?format=txt";

#----- GET GOOGLEDOC AS TXT -----{{{1
my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent('Mozilla/5.0');
my $response_masterbin  = $ua->get($url_masterbin);
my $response_tagCatalog = $ua->get($url_tagCatalog);

##----- CLEAN UP TXT AND EXPORT TO FILE -----{{{1
# masterbin
fetch2file ([
  {
    response => $response_masterbin->decoded_content,
    fname  => "masterbin.txt",
  },
  {
    response  => $response_tagCatalog->decoded_content,
    fname  => "tagCatalog.txt",
  }
]);

##----- SUBROUTINES -----{{{1
sub fetch2file {
  my $argList = shift;
  for my $args ($argList->@*) {
    my $fname = $args->{fname};
    my $response = $args->{response};
    $response =~ s/\x{000D}//g;
    $response =~ s/\n\n\n+/\n\n/g;
    open(my $fh, '+<',$fname) or die;
      print $fh $response;
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
  }
}

##----- REFFS -----{{{1
## https://pdf.co/how-to-get-direct-download-links
## (not used) https://perlmaven.com/slurp
## (not used) https://metacpan.org/source/MSCHILLI/Net-Google-Drive-Simple-0.03/lib%2FNet%2FGoogle%2FDrive%2FSimple.pm
## (not used) https://www.perlmonks.org/?node_id=1198601
