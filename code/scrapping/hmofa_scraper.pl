#!/usr/bin/env perl
#============================================================
#
#        FILE: hmofa_scraper.pl
#
#       USAGE: ./hmofa_scraper.pl
#
#  DESCRIPTION:  
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0
#      Created: Tue 06/08/21 09:27:28
#============================================================
use strict;
use warnings;
use utf8;
use LWP::UserAgent;
use HTML::SimpleLinkExtor;
use DBD::DBM;
use XML::LibXML;
use Web::Scraper;
use Mojo::UserAgent;

# MAIN {{{1
#------------------------------------------------------

delegate({
    dirname => 'scrapes',
    outputDir => '~/test',
    FileNumber => 2,
    urls => {
        stories => [qw(
            https://archiveofourown.org/works/30760076
            https://www.furaffinity.net/view/33514307/
            https://www.sofurry.com/view/1503206
            https://archiveofourown.org/works/21123266
            https://ghostbin.com/paste/vTAxw
            https://docs.google.com/document/d/1LvkkTDoS5elYTJIYNlERkqERgSIs2sMNJFBgexQNKQ0
            https://www.literotica.com/s/accidental-summoning
            https://rentry.co/pynpz
            https://www.fanfiction.net/s/13772551/1/Advent-Provides
        )],
        misc => [qw(
            https://furchan.net/fg/
            https://hmofa.fandom.com/wiki/Writer_Link_Archive
            https://desuarchive.org/trash/search/text/hmofa/type/op/
            https://snootgame.xyz/
        )],
    },
});






#------------------------------------------------------
# SUBROUTINES {{{1
#------------------------------------------------------
#===| delegate() {{{2
sub delegate {
    my $data = shift @_;

    ## Set up LWP object
    my $ua = LWP::UserAgent->new(timeout => 10);
    $ua->agent('Mozilla/5.0');

    ## start timer
    my $start = time;
    my $duration = time - $start; print "Execution Time: $duration s\n";

    ##
    checkDir($data);

    ##
    storeFiles($data);
}


#===| checkDir() {{{2
sub checkDir{
  my $data = shift @_;
  #my $outputDir = '~/test'.$dirname;
  #my $FileNumber = 2;

  #if (-d $outputDir) {
  #    while (-d $outputDir . '_' . $FileNumber ) {
  #        $FileNumber++;
  #    }
  #    $outputDir = $outputDir . '_' . $FileNumber;
  #}

  #print $outputDir;
  #mkdir $outputDir;
}

#===| storeFiles() {{{2
sub storeFiles {
  my $data = shift @_;
  #my $outputDir = '~/test'.$dirname;
  #my $FileNumber = 2;
  #my @fh; # will store the filehandles.
  #my @html;
  #my $i=0;
  #for my $link (@urls) {
  #    my $response = $ua->get($link);
  #    $link =~ s/https:\/\/pastebin.com\/raw\/([^\s]+)/$1/;
  #    my $name = $1;
  #    push @html, $response->decoded_content;
  #    my $start = time;

  #    open $fh[$i], '>', $outputDir . "/$name" or die $!;
  #      if ($html[$i]) {
  #      print {$fh[$i]} $html[$i];
  #      }
  #      else {
  #        my $DeadString = $_ . "\n" . "DEAD_LINK";
  #      print {$fh[$i]} $DeadString;
  #      }
  #    close $fh[$i];

  #    $i++;
  #    while ( (time - $start) < 2){}
  #}
}
