#!/usr/bin/env perl
use warnings;
use strict;
use LWP::Simple;
use LWP::UserAgent;
use utf8;

my $ua = LWP::UserAgent->new(timeout => 10);
$ua->agent('Mozilla/5.0'); 
my $start = time;

my $fh;
my @url;
open $fh, '<' ,  '/Users/Work/hmofa/pastebin/code_examples/urls.txt';
  while (my $line = <$fh>) {
    push @url, $line;
  }
close $fh;

my @html;
my $i=0;
my @fh; # will store the filehandles.
for (@url) {
  my $response = $ua->get($_);
    push @html, $response->decoded_content;
    my $start = time;
    open $fh[$i], '>', "/Users/Work/hmofa/pastebin/code_examples/threads/file-$i" or die $!;
    if ($html[$i]) {
      open $fh[$i], '>', $DestFolder . "/file-$i" or die $!;
        if ($html[$i]) {
        print {$fh[$i]} $html[$i];
        }
        else {
          my $DeadString = $_ . "\n" . "DEAD_LINK";
        print {$fh[$i]} $DeadString;
        }
      close $fh[$i];
    print {$fh[$i]} $html[$i];
    }
    else {
    print {$fh[$i]} $_;
    }
    close $fh[$i];
    $i++;
    while ( (time - $start) < 2){}
}

my $duration = time - $start; print "\nExecution Time: $duration s\n";



