#!/usr/bin/env perl
#============================================================
#
#        FILE: tags3.pl
#       USAGE: perl ./tags3.pl
#  DESCRIPTION: ---
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#===========================================================
use strict;
use warnings;
use utf8;
use JSON;
use Storable qw(dclone);
use Data::Dumper;

##Assumptions
# no backslashes in dspt key names
# all dspt key names are unique

#----- FILEPATHS -----{{{1
my $fname_IN = '../tagCatalog.txt';

#----- REGEX CONFIG -----{{{1
my $dspt = {
  section => {
    order => '1',
    re => qr/^\s*%+\s*(.*?)\s*%+/,
    match => [],
  },
  author => {
    order => '1.1',
    re => qr/^\s*[Bb]y\s+(.*)/,
    partion => {
      author_attribute => qr/\((.*)\)/,
    },
    match => [],
  },
  series => {
    order => '1.1.1',
    re => qr/^\s*=+\/\s*(.*)\s*\/=+/,
    match => [],
  },
  title => {
    order => '1.1.1.1',
    re => qr/^\s*>\s*(.*)/,
    partion => {
      title_attribute => qr/\((.*)\)/,
    },
    match => [],
  },
  tags => {
    order => '1.1.1.1.1',
    re => qr/^\s*(\[.*)/,
    partion => {
      anthro  => qr/(?x) ^\[  ([^\[\]])\+ \]\[/,
      general => qr/(?x) \]\[ ([^\[\]])\+ \]/,
      ops     => qr/(?x) \]   ([^\[\]])\+ $/,
      all     => [ qw( anthro general ) ],
    },
    match => [],
  },
  url => {
    order => '1.1.1.1.2',
    re => qr/^\s*(https?:\/\/[^\s]+)\s+\((.*)\)/,
    partion => {
      label => [ qw( \2 ) ],,
    },
    match => [],
  },
  description => {
    order => '1.1.1.1.3',
    re => qr/^\s*#(.*)/,
    match => [],
  },
  test => {
    order => '2',
    match => [],
  },
  test2 => {
    order => '2.1',
    match => [],
  },
  test3 => {
    order => '2.1.1',
    match => [],
  },
  test4 => {
    order => '2.1.1.1',
    match => [],
  },
  test5 => {
    order => '2.1.1.2',
    match => [],
  },
  test6 => {
    order => '2.1.1.2.1',
    match => [],
  },
  test33 => {
    order => '2.1.2',
    match => [],
  },
  test333 => {
    order => '2.1.2.1',
    match => [],
  },
};


#----- Main -----{{{1
my $capture_hash  = file2hash( $fname_IN );
my $formated_hash = hash_delegate( { capture_hash => $capture_hash, dspt => $dspt } );
print Dumper($formated_hash);


#----- Subroutines -----{{{1
sub hash_delegate {
  my $args = shift @_;
  my $capture_hash = $args->{capture_hash};
  my $dspt         = $args->{dspt};

  return leveler ({
    dspt          => $dspt,
    capture_hash  => $capture_hash,
    result        => {},
  });
}


sub getObj {
  my $dspt  = shift @_;
  my $point = shift @_;
  my $point_str = join '.', $point->@*;

  if ($point_str eq '') { return 'TOP' }

  else {
    my @match = grep { $dspt->{$_}->{order} =~ /^$point_str$/ } keys $dspt->%*;

    if    ( !$match[0] )        { return 0 }
    elsif ( scalar @match > 1 ) { die( "more than one objects have the point: \'${point_str}\', for ${0} at line: ".__LINE__ ) }
    else                        { return $match[0] }
  }
}


sub leveler {
  my $args = shift @_;
  my $data =  $args;
  $data->{result} = exists $args->{result} ? $args->{result} : {};
  $data->{reff}   = exists $args->{reff}   ? $args->{reff}   : {};
  $data->{point}  = exists $args->{point}  ? $args->{point}  : [];

  my $obj = getObj( $data->{dspt}, $data->{point} );
  my $mat;

  #----- Exists? -----
  if   ( $obj ) { }
  else          { return }

  #----- Sybling? -----
  while ( $obj ) {
    print "\'${obj}\'\n";

    #----- Populate Parent -----
    if (exists $data->{parent} ) {
      my $parent = $data->{parent};
      print "  PARENT found: \'${parent}\', will POPULATE\n";

      if ( !defined $mat ) {
        $data->{reff}->{$parent}={};
        $data->{reff} = $data->{reff}->{$parent};
        $mat = $data->{reff};
      }

      $mat->{$obj}={};
    }
    else {
      print "  No PARENT found, will NOT POPULATE\n";
      #$data->{result}->{save} = 1;
      $data->{result} = {};
      $data->{reff} = $data->{result};
    }

    #----- CHILDS? -----
    print "  CHILDS for: \'${obj}\'\n";
    $data->{parent} = $obj;
    push $data->{point}->@*, 1;
    leveler($data);
    pop $data->{point}->@*, 1;
    $data->{reff} = $mat;
    print "  END of CHILDS for: \'${obj}\'\n";
    if ( scalar $data->{point}->@* ) { $data->{point}->[-1]++ }
    else { last }
    $obj = getObj( $data->{dspt}, $data->{point} );
  }
  return $data->{result};;
}


sub file2hash {
  my $fname = shift @_;
  my $output;

  open( my $fh, '<', $fname )  #Open Masterbin for reading
    or die $!;

  while ( my $line = <$fh> ) {

    for my $obj_key ( keys %$dspt ) {
      my $obj = $dspt->{$obj_key};

      if ($obj->{re} && $line =~ /$obj->{re}/ ) {
        my $match = {
          LN       => $.,
          $obj_key => $1, };

        push  $output->{$obj_key}->@*, $match;
      }
    }
  }
  close($fh);
  return $output;
}
