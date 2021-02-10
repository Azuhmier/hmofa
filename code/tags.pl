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

#----- VARIABLES -----{{{1
my $Result = {};


#----- FILEPATHS -----{{{1
my $fname_MasterBin = '../masterbin.txt';
my $fname_MasterBinXML = '../masterbin.xml';


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
my $reff = [];
for my $key (keys %$dspt) {
   my $key_reff = $dspt->{$key};
   push  @$reff, [$key_reff->{order},$key];
   delete $key_reff->{re};
   delete $key_reff->{order};
}
@$reff = sort {@$a[0] cmp @$b[0]} @$reff;
my $output = {};
#for (@$reff) {
#  my $key = @{$_}[1];
#  my $key_reff = $dspt->{$key};
#  my @match = $key_reff->{match}->@*;
#  print @match;
#  #JKJJHHmy $LN = $match->{LN};
#  #print $LN;
##  $output->{$key} = shift $dspt->{$key};
#}
for my $a ( reverse $dspt->{author}->{match}->@*) {
  my $lineA = ${$a}{LN};

  my $key_reff = $output->{${$a}{contents}};
  $output->{${$a}{contents}} = {LN => [${$a}{LN}]};
  $output->{${$a}{contents}}->{titles} = {};
  for my $b ( reverse $dspt->{title}->{match}->@*) {
    my $lineB = ${$b}{LN};
    #print "LINEA: ",$lineA,"\n";
    #print "LINEB: ",$lineB,"\n";
    #print "RESULT: ", ($lineA < $lineB);
    #print "\n";
    if ($lineA < $lineB) {
      my $nameB = ${$b}{contents};
      $output->{${$a}{contents}}->{title}->{$nameB}->{url}= [];
      for my $c ( reverse $dspt->{url}->{match}->@*) {
        my $lineC = ${$c}{LN};
        print "LINEB: ",$lineB,"\n";
        print "LINEC: ",$lineC,"\n";
        print "RESULT: ", ($lineB < $lineC);
        print "\n";
        if ($lineB < $lineC) {
          my $nameC = ${$c}{contents};
          push $output->{${$a}{contents}}->{title}->{$nameB}->{url}->@*, $nameC;
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
#for ($dspt->{title}->{match}->@*) {
#  #my $key = @{$_}[1];
#  my $key_reff = $output->{${$_}{contents}};
#  $output->{${$_}{contents}} = {LN => [${$_}{LN}]};
#}
#for ($dspt->{author}->{match}->@*) {
#  #my $key = @{$_}[1];
#  my $key_reff = $output->{${$_}{contents}};
#  $output->{${$_}{contents}} = {LN => [${$_}{LN}],
#    titles => [
#      {df => {
#        urls => [1,2,3,4]
#      }},
#    {qf => {
#        urls => [1,2,3,4]
#      }},
#    ]
#  };
#}
#print @{$_}[0]," ",@{$_}[1],"\n" for @$reff;
#my $xml = XMLout($dspt);
#my $json = encode_json $output;
#print $json;
my $xml = XMLout($output);
open(my $fh_MasterBinXML, '>' , $fname_MasterBinXML) or die $!;
  print $fh_MasterBinXML $xml;
close($fh_MasterBinXML);
#----- SUBROUTINES -----{{{1
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}
