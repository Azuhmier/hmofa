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
    name => 'sections',
    order => '1',
    re => qr/^\s*%+\s*(.*?)\s*%+/,
  },
  author => {
    name => 'authors',
    order => '1.1',
    re => qr/^\s*[Bb]y\s+(.*)/,
    partion => {
      author_attribute => qr/\((.*)\)/,
    },
  },
  series => {
    order => '1.1.1',
    re => qr/^\s*=+\/\s*(.*)\s*\/=+/,
  },
  title => {
    name => 'stories',
    order => '1.1.1.1',
    re => qr/^\s*>\s*(.*)/,
    partion => {
      title_attribute => qr/\((.*)\)/,
    },
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
  },
  url => {
    name => 'urls',
    order => '1.1.1.1.2',
    re => qr/^\s*(https?:\/\/[^\s]+)\s+\((.*)\)/,
    partion => {
      label => [ qw( \2 ) ],,
    },
  },
  description => {
    order => '1.1.1.1.3',
    re => qr/^\s*#(.*)/,
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
#print Dumper($capture_hash);
my $formated_hash = hash_delegate( { capture_hash => $capture_hash, dspt => $dspt } );
print Dumper($formated_hash);


#----- Subroutines -----{{{1
#----- hash_delegate -----{{{2
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


#----- leveler -----{{{2
sub leveler {
  my $data = shift @_;
  if ( !exists $data->{reff}   ) { $data->{reff}   = {} }
  if ( !exists $data->{point}  ) { $data->{point}  = [] }
  if ( !exists $data->{result} ) { $data->{result} = {} }

  #----- Exists? -----
  my $obj = getObj( $data->@{'dspt', 'point'} );
  if ( !$obj ) { return }

  #----- Sweep Level -----
  my $lvl_reff;
  while ( $obj ) {
    print "\'${obj}\'\n";

    #----- Parent? -----
    if ( exists $data->{parent} ) {
      print "  PARENT found: \'".$data->{parent}."\', will POPULATE\n";
      my $parent = $data->{parent};

      #----- lvl_reff? -----
      if ( !defined $lvl_reff ) {
        $data->{reff}->{$parent} = {};                       # 'reff.parent' --> {}    , declare 'reff' reference
        $data->{reff}            = $data->{reff}->{$parent}; # 'reff' --> 'reff.parent', set 'reff' to 'reff.parent' reference
        $lvl_reff                = $data->{reff};            # 'lvl_reff' --> 'reff'   , set 'lvl_reff' to 'reff.parent'' reference
      }
      #----- Polulate Parent Members -----
      populate($obj, $data);

      #----- Linewise -----
      $lvl_reff->{$obj} = {};                                # 'lvl_reff.obj' --> {}   , declare 'lvl_reff.obj' refference
      linewise($data);

    }
    else {
      print "  No PARENT found, will NOT POPULATE\n";
      $data->{result} = {};              # 'result' -- > {}   , Declare 'result' reference
      $data->{reff}   = $data->{result}; # 'reff' --> 'result', set 'reff' to 'result' reference
    }

    #----- CHILDS? -----
    print "  CHILDS for: \'${obj}\'\n";

    $data->{parent} = $obj;     # set 'parent' to current 'obj'
    push $data->{point}->@*, 1; # Go to Order Address of the first CHILD
    leveler($data);             # Recurse into CHILD
    pop $data->{point}->@*, 1;  # Restore previous Order Address
    $data->{reff} = $lvl_reff;  # 'reff' --> 'lvl_reff', return 'reff' to...
                                # ...'lvl_reff' as program ascends to top of hash after recursion

    print "  END of CHILDS for: \'${obj}\'\n";

    #----- SYBLINGS? -----
    if   ( scalar $data->{point}->@* ) { $data->{point}->[-1]++ }
    else                               { last }
    $obj = getObj( $data->@{'dspt', 'point'} );                   # set 'obj' to new 'obj' (next SYBLINGO)

  }
  return $data->{result};
}


#----- populate -----{{{2
sub populate {

  my $obj  = shift @_;
  my $data = shift @_;
  #print Dumper($data->{capture_hash}->{$obj});

}


#----- linewise -----{{{2
sub linewise {
  my $data = shift @_;
}


#----- getObj -----{{{2
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

#----- file2hash -----{{{2
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
