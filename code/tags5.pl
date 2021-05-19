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
    name => 'SECTIONS',
    order => '1',
    re => qr/^\s*%+\s*(.*?)\s*%+/,
  },
  author => {
    name => 'AUTHORS',
    order => '1.1',
    re => qr/^\s*[Bb]y\s+(.*)/,
    partion => {
      author_attribute => qr/\((.*)\)/,
    },
  },
  series => {
    name => 'SERIES',
    order => '1.1.1',
    re => qr/^\s*=+\/\s*(.*)\s*\/=+/,
  },
  title => {
    name => 'STORIES',
    order => '1.1.1.1',
    re => qr/^\s*>\s*(.*)/,
    partion => {
      title_attribute => qr/\((.*)\)/,
    },
  },
  tags => {
    name => 'TAGS',
    order => '1.1.1.1.1',
    re => qr/^\s*(\[.*)/,
    partion => {
      anthro  => qr/(?x) ^\[  ([^\[\]])\+ \]\[/,
      general => qr/(?x) \]\[ ([^\[\]])\+ \]/,
      ops     => qr/(?x) \]   ([^\[\]])\+ $/,
      all     => [ qw( anthro general ) ],
    },
    scalar => 1,
  },
  url => {
    name => 'URLS',
    order => '1.1.1.1.2',
    re => qr/^\s*(https?:\/\/[^\s]+)\s+\((.*)\)/,
    partion => {
      label => [ qw( \2 ) ],,
    },
  },
  description => {
    name => 'DESCRIPTIONS',
    order => '1.1.1.1.3',
    re => qr/^\s*#(.*)/,
    scalar => 1,
  },
  test => {
    order => '2',
  },
  test2 => {
    order => '2.1',
  },
  test3 => {
    order => '2.1.1',
  },
  test4 => {
    order => '2.1.1.1',
  },
  test5 => {
    order => '2.1.1.2',
  },
  test6 => {
    order => '2.1.1.2.1',
  },
  test33 => {
    order => '2.1.2',
  },
  test333 => {
    order => '2.1.2.1',
  },
};


#----- Main -----{{{1
my $capture_hash  = file2hash( $fname_IN );

#----- TESTS -----
my $num = 1;
$capture_hash->{test} = [
  {
    'LN' => 76,
    'test' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
$capture_hash->{test33} = [
  {
    'LN' => 76,
    'test33' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test33' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
$capture_hash->{test3} = [
  {
    'LN' => 76,
    'test3' => 'MINNIE: HIGH VELOCITY COURTING '
  },
  {
    'LN' => 76,
    'test3' => 'MINNIE: HIGH VELOCITY COURTING '
  },
];
for my $key ( keys $capture_hash->%* ) {
  if ( exists $capture_hash->{$key}->[$num] ) {
    $capture_hash->{$key}->@* = $capture_hash->{$key}->@[0..$num];
    #$capture_hash->{$key}->@* = map { delete $_->{LN} } $capture_hash->{$key}->@*;
  }
  else {
    my @array = $capture_hash->{$key}->@*;
    $capture_hash->{$key}->@* = $capture_hash->{$key}->@[0..$#array];
    #$capture_hash->{$key}->@* = map { delete $_->{LN} } $capture_hash->{$key}->@*;
  }
}

my $formated_hash = hash_delegate( { capture_hash => $capture_hash, dspt => $dspt } );
print Dumper($formated_hash);


#----- Subroutines -----{{{1
#-----| hash_delegate -----{{{2
sub hash_delegate {
  my $args = shift @_;
  my $capture_hash = $args->{capture_hash};
  my $dspt         = $args->{dspt};

  return leveler ({
    dspt          => $dspt,
    capture_hash  => $capture_hash,
  });
}


#-----| leveler -----{{{2
sub leveler {
  my $data = shift @_;
  unless ( exists $data->{point}  ) { $data->{point}  = [] }
  unless ( exists $data->{stack}  ) { $data->{stack}  = [] }
  unless ( exists $data->{result} ) { $data->{result} = {} }
  unless ( exists $data->{reff}   ) { $data->{reff}   = [ $data->{result} ] }

  #----- Exists? -----
  my $obj = getObj( $data->@{'dspt', 'point'} );
  if ( !$obj ) { return }

  #----- Sweep Obj -----
  my $lvl_reff;
  while ( $obj ) {
    print "\nCurrent Obj: \'${obj}\'\n";

    #----- lvl_reff? -----
    unless ( defined $lvl_reff ) { $lvl_reff->@* = get_Lvl_reff($data); }

    #----- Populate -----
    populate($data, $obj);

    #----- CHILDS? -----
    push $data->{point}->@*, 1; # Go to Order Address of the first CHILD
    leveler($data);             # Recurse into CHILD
    pop $data->{point}->@*, 1;  # Restore previous Order Address
    $data->{reff}->@* = $lvl_reff->@*;  # 'reff' --> 'lvl_reff', return 'reff' to...
                                # ...'lvl_reff' as program ascends to top of hash after recursion

    #----- SYBLINGS? -----
    if   ( scalar $data->{point}->@* ) { $data->{point}->[-1]++ }
    else                               { last }
    $obj = getObj( $data->@{'dspt', 'point'} ); # set 'obj' to new 'obj' (next SYBLINGO)
  }
  return $data->{result};
}


#-----| getname ----{{{2
sub getname {
  my $dspt = shift @_;
  my $obj  = shift @_;
  my $name = exists $dspt->{$obj}->{name} ? $dspt->{$obj}->{name} : $obj;
  return $name;
}


#-----| get_Lvl_reff -----{{{2
sub get_Lvl_reff {
  my $data = shift @_;
  return $data->{reff}->@*;
}

sub divyMatches {
    my $data = shift @_;
    my $obj  = shift @_;
    my $match_name = getname( $data->{dspt}, $obj );
    my $matches    = dclone( $data->{capture_hash}->{$obj} );

    #----- DIVY MATCHES -----
    $data->{reff}->[0]->{$match_name} = $matches;
    return $match_name;
}

#-----| populate -----{{{2
sub populate {
  my $data      = shift @_;
  my $obj       = shift @_;

  if ($obj ne 'TOP' && ( exists $data->{capture_hash}->{$obj}) ) {

    my $match_name = divyMatches($data,$obj);
    unshift $data->{reff}->@*, $data->{reff}->[0]->{$match_name}->@*;
  }
}


#-----| getObj -----{{{2
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

#-----| file2hash -----{{{2
sub file2hash {
  my $fname = shift @_;
  my $output;

  open( my $fh, '<', $fname )  #Open Masterbin for reading
    or die $!;

  while ( my $line = <$fh> ) {

    for my $obj_key ( keys %$dspt ) {
      my $obj = $dspt->{$obj_key};

      if ( $obj->{re} && $line =~ /$obj->{re}/ ) {
        my $match = {
          LN       => $.,
          $obj_key => $1,
        };
        push  $output->{$obj_key}->@*, $match;
      }
    }
  }
  close($fh);
  return $output;
}
