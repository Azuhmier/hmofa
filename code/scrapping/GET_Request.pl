#!/usr/bin/perl;
use warnings;
use strict;
use LWP::Simple;
use LWP::UserAgent;
use utf8;
no warnings 'utf8';
use List::MoreUtils 'uniq';

# Set up LWP object
my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent('Mozilla/5.0');

# Start timer
my $start = time;

# Get urls from 'url_only.txt'
my @url;
my $fname_urls = glob('~/hmofa/pastebin/code_examples/goto_files/url_only.txt');
open my $fh, '<' , $fname_urls ;
  while (my $line = <$fh>) {
    $line =~ m/https:\/\/pastebin.com\/[^\s]+/;
    push @url, $&;
  }
close $fh;

# Check if $dirname is available
my $dirname = 'archive';
my $DestFolder = glob('~/hmofa/pastebin/Pastebin_Archives/' . $dirname);
my $FileNumber = 2;

if (-d $DestFolder) {
  while (-d $DestFolder . '_' . $FileNumber ) {
    $FileNumber++;
  }
  $DestFolder = $DestFolder . '_' . $FileNumber;
}

print $DestFolder;
mkdir $DestFolder;

#Store files
my @fh; # will store the filehandles.
my @html;
my $i=0;

for (@url) {
    my $response = $ua->get($_);
    push @html, $response->decoded_content;
    my $start = time;

    open $fh[$i], '>', $DestFolder . "/file-$i" or die $!;
      if ($html[$i]) {
      print {$fh[$i]} $html[$i];
      }
      else {
        my $DeadString = $_ . "\n" . "DEAD_LINK";
      print {$fh[$i]} $DeadString;
      }
    close $fh[$i];

    $i++;
    while ( (time - $start) < 2){}
}

my $duration = time - $start; print "\nExecution Time: $duration s\n";



