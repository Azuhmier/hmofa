#!/usr/bin/env perl
use warnings;
use strict;
use LWP::Simple;
use LWP::UserAgent;
use HTML::SimpleLinkExtor;
use List::MoreUtils 'uniq';
use utf8;
no warnings 'utf8';

my $threads_dir=glob('~/hmofa/threads');

## Set up LWP object
#my $ua = LWP::UserAgent->new(timeout => 10);
#$ua->agent('Mozilla/5.0');
#
## Start timer
#my $start = time;
#
## Get urls from 'url_only.txt'
#my $count = 0;
#my @urls;
#my $fh;
#my $fname = glob('~/hmofa/hmofa/code/urls.txt');
#
#while ($count <= 8) {
#  my $response = $ua->get('https://desuarchive.org/trash/search/text/hmofa/type/op/page/' . $count .'/');
#
#  unless ( $response->is_success ) {
#    die $response->status_line;
#  }
#
#  my $html = $response->decoded_content;
#  my $extractor = HTML::SimpleLinkExtor->new; $extractor->parse($html);
#  my @links = $extractor->links;
#  for my $link (uniq grep {m/https:\/\/paste/} @links ) {
#    if ($link !~ m/https:\/\/pastebin.com\/raw[^\s]+/) {
#      $link =~ m/https:\/\/pastebin.com\/[^\s]+/;
#      my $match = $&;
#      $match =~ s/(https:\/\/pastebin.com\/)([^\s]+)/$1raw\/$2/;
#      $link = $match;
#    }
#    push @urls, $link;
#  }
#  $count++;
#}
#
## Get urls from 'url_only.txt'
#my $fname_urls = glob('~/hmofa/hmofa/code/goto_files/url_only.txt');
#open $fh, '<' , $fname_urls ;
#  while (my $line = <$fh>) {
#    $line =~ m/https:\/\/pastebin.com\/[^\s]+/;
#    my $match = $&;
#    $match =~ s/(https:\/\/pastebin.com\/)([^\s]+)/$1raw\/$2/;
#    push @urls, $match;
#  }
#close $fh;
#@urls = uniq @urls;
#
## Check if $dirname is available
#my $dirname = 'archive';
#my $DestFolder = glob('~/hmofa/hmofa/Recent_Scrapes/' . $dirname);
#my $FileNumber = 2;
#
#if (-d $DestFolder) {
#  while (-d $DestFolder . '_' . $FileNumber ) {
#    $FileNumber++;
#  }
#  $DestFolder = $DestFolder . '_' . $FileNumber;
#}
#
#print $DestFolder;
#mkdir $DestFolder;
#
##Store files
#my @fh; # will store the filehandles.
#my @html;
#my $i=0;
#for my $link (@urls) {
#    my $response = $ua->get($link);
#    $link =~ s/https:\/\/pastebin.com\/raw\/([^\s]+)/$1/;
#    my $name = $1;
#    push @html, $response->decoded_content;
#    my $start = time;
#
#    open $fh[$i], '>', $DestFolder . "/$name" or die $!;
#      if ($html[$i]) {
#      print {$fh[$i]} $html[$i];
#      }
#      else {
#        my $DeadString = $_ . "\n" . "DEAD_LINK";
#      print {$fh[$i]} $DeadString;
#      }
#    close $fh[$i];
#
#    $i++;
#    while ( (time - $start) < 2){}
#}
#
#my $duration = time - $start; print "\nExecution Time: $duration s\n";
#
#
#
#
