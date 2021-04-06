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
#===========================================================

use strict;
use warnings;
use utf8;
use XML::Simple;
use JSON;
use Data::Dumper;
use Storable qw(dclone);

#----- FILEPATHS -----{{{1
my $fname_MasterBin = '../masterbin.txt';
my $fname_MasterBinXML = '../masterbin.xml';
my $fname_MasterBinjson = '../masterbin.json';


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
for my $a ( reverse $dspt->{author}->{match}->@*) {
  my $lineA = ${$a}{LN};
  my $key_reff = $output->{${$a}{contents}};
  $output->{${$a}{contents}} = {LN => ${$a}{LN}};
  #$output->{${$a}{contents}}->{titles} = {};
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
#print Dumper($output);
#----- BEAUTIFY -----
my $DP_output = dclone($output); # Deep Copy of $output
my $output2 = [];                # New Better Hash
for my $author (keys %$DP_output) {
  #print $author, "\n";
  my @titles;
  for my $title (keys %{$DP_output->{$author}->{titles}}) {
    #print $title, "\n";
    my %title_hash = ( 
      title => $title,
      urls => $DP_output->{$author}->{titles}->{$title}->{urls},
    );
    push @titles, \%title_hash;
  }
  my %author_hash = ( 
    author => $author,
    titles => \@titles,
    LineNumber => $DP_output->{$author}->{LN},
  );

  push @$output2, \%author_hash;
}
#print Dumper($output2);
#----- EXTERNAL DATASTRUCTS -----
#==|| XML
my $xml = XMLout($output);
my $xml2 = XMLout($output2,NoAttr => 1);
#==|| JSON
my $json_obj = JSON->new->allow_nonref;
my $json = $json_obj->pretty->encode($output);
my $json_obj2 = JSON->new->allow_nonref;
my $json2 = $json_obj2->pretty->encode($output2);
#----- WRITING TO FILES -----
open(my $fh_MasterBinXML, '>' , $fname_MasterBinXML) or die $!;
  print $fh_MasterBinXML $xml2;
close($fh_MasterBinXML);
open(my $fh_MasterBinjson, '>' , $fname_MasterBinjson) or die $!;
  print $fh_MasterBinjson $json2;
close($fh_MasterBinjson);

#----- META -----{{{1
my $cmd = q{sed -n 's/^>\(.*\)/\1/p' ../masterbin.txt > ../story_list.txt};
system($cmd);
my $cmd2 = q{sed -n 's/^[Bb]y \(.*\)/\1/p' ../masterbin.txt > ../author_list.txt};
system($cmd2);

#----- SUBROUTINES -----{{{1
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}
