#!/usr/bin/env perl
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
use utf8;
use XML::Simple;
use JSON;

#----- VARS -----{{{1
my $reff = [];
my $output = {};

#----- FILEPATHS -----{{{1
my $fname_MasterBin = '../masterbin.txt';
my $fname_MasterBin_XML = '../masterbin.xml';
my $fname_MasterBin_json = '../masterbin.json';

#----- REGEX CONFIG -----{{{1
my $d = ',';
my $nb = qr/[^\]\[]/;
my $logger = {};
my $dspt = {
  #section => {
  #  order => '1a',
  #  re => qr/^\s+%+\s+(.*)\s+%+/,
  #  match => [],
  #},
  author => {
    order => '2a',
    re => qr/^\s*By\s+(.*)/,
    match => [],
  },
  #AuthorBorder => {
  #  order => '2a',
  #  re => qr/^---+$/,
  #  match => [],
  #},
  #series => {
  #  order => '3a',
  #  re => qr/^=+\/\s*(.*)\s*\/=+/,
  #  match => [],
  #},
  title => {
    order => '4a',
    re => qr/^\s*>\s*(.*)/,
    match => [],
  },
  #tags => {
  #  order => '5a',
  #  re => qr{(?x)
  #    ^\s*\[($nb*)\]\s*\[($nb*)\]($nb*)\n$
  #    |^\s*\[($nb*)\]($nb*)\n$
  #    |^\s*([~OX\$\*]+)\s*\n$
  #  },
  #  match => [],
  #},
  url => {
    order => '5b',
    re => qr/(https?:\/\/[^\s]+)\s+(.*)/,
    match => [],
  },
  #description => {
  #  order => '5c',
  #  re => qr/^#(.*)/,
  #  match => [],
  #},
};

#----- FILEHANDLING -----{{{1
open(my $fh_MasterBin, '<' , $fname_MasterBin) or die $!;
  while (my $line = <$fh_MasterBin>) {
    for my $key (keys %$dspt) {
      my $key_reff = $dspt->{$key};
      if ($key_reff->{re} && $line =~ /$key_reff->{re}/) {
        my $hash = {
          LN => $.,
          contents => $1,
        };
        push  @{$key_reff->{match}}, $hash;
      }
    }
  }
close($fh_MasterBin);
#----- HASH MANIPULATION -----{{{1
#reff hash
for my $key (keys %$dspt) {
   my $ov = $dspt->{$key};
   push  @$reff, [$ov->{order},$key];
   delete $ov->{re};
   delete $ov->{order};
}
@$reff = sort {@$a[0] cmp @$b[0]} @$reff;
#hash tree creation
for my $a ( reverse $dspt->{author}->{match}->@*) {
  my $lineA = ${$a}{LN};
  my $ov = $output->{${$a}{contents}};
  for my $b ( reverse $dspt->{title}->{match}->@*) {
    my $lineB = ${$b}{LN};
    if ($lineA < $lineB) {
      my $nameB = ${$b}{contents};
      $output->{${$a}{contents}}->{titles}->{$nameB}->{urls}= [];
      for my $c ( reverse $dspt->{url}->{match}->@*) {
        my $lineC = ${$c}{LN};
        if ($lineB < $lineC) {
          my $nameC = ${$c}{contents};
          push $output->{${$a}{contents}}->{titles}->{$nameB}->{urls}->@*, $nameC;
          pop $dspt->{url}->{match}->@*;
        }
        else {
          last;
        }
      }
      pop $dspt->{title}->{match}->@*;
    }
    else {
      last;
    }
  }
}
#----- DATA STRUCT CONVERSION-----{{{1
my $xml = XMLout($output);
my $json_obj = JSON->new->allow_nonref;
my $json = $json_obj->pretty->encode($output);
print $json;
#----- WRITING TO FILES -----{{{1
#open(my $fh_MasterBin_XML, '>' , $fname_MasterBin_XML) or die $!;
#  print $fh_MasterBin_XML $xml;
#close($fh_MasterBin_XML);
#open(my $fh_MasterBin_json, '>' , $fname_MasterBin_json) or die $!;
#  print $fh_MasterBin_json $json;
#close($fh_MasterBin_json);
#----- SUBROUTINES -----{{{1
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}
