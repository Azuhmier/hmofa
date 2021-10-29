#============================================================
#
#        FILE: Hasher.pm
#
#       USAGE: ./Hasher.pm
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: ---
#      VERSION: 1.0
#      Created: Thu 10/28/21 10:15:17
#============================================================
package Ohm::Hasher;
use strict;
use warnings;
use File::Basename;
use Cwd;
use Carp qw(croak carp);
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
my $erreno;

sub new { #{{{1
    my ( $class, @args ) = @_;
    my $self = bless {}, $class;
    $self->__init( \@args );
    return $self;
}
sub get_matches { #{{{1
    # have option presverses be 2nd option
    my ( $self ) = @_;
    return $self;
}

sub divy { #{{{1
    # check if matches exists
    # if not, run get_matches
    my ( $self ) = @_;
    return $self;
}

sub dress_Hash { #{{{1
    my ( $self ) = @_;
    return $self;
}

sub chg_dspt { #{{{1
    my ( $self, $paths_dspt ) = @_;
    __checkChgArgs($paths_dspt,'','string scalar');
    $self->{paths}{dspt} = $paths_dspt;
    return $self;
}

sub chg_drsr { #{{{1
    my ( $self, $paths_drsr ) = @_;
    __checkChgArgs($paths_drsr,'','string scalar');
    $self->{paths}{drsr} = $paths_drsr;
    return $self;
}

sub chg_name { #{{{1
    my ( $self, $name ) = @_;
    __checkChgArgs($name,'','string scalar');
    $self->{name} = $name;
    return $self;
}

sub chg_output { #{{{1
    my ( $self, $paths_output ) = @_;
    __checkChgArgs($paths_output,'','string scalar');
    $self->{paths}{output} = $paths_output;
    return $self;
}

sub chg_prsv { #{{{1
    my ( $self, $prsv ) = @_;
    __checkChgArgs($prsv,'HASH','hash');
    $self->{prsv} = $prsv;
    return $self;
}

sub __checkChgArgs { #{{{1
    my ($arg, $cond, $type) = @_;
    unless ( defined $arg ) {
        croak( (caller(1))[3] . " requires an input" );
    } elsif (ref $arg ne $cond) {
        croak( (caller(1))[3] . " requires a $type" );
    }
}
sub __gen_reffs { #{{{1
    my ( $self ) = @_;
    return $self;
}

sub __init { #{{{1
    my ( $self, $args ) = @_;
    my $class = ref $self;
    unless (UNIVERSAL::isa($args->[0], 'HASH')) {
        $args->[0] = {
            input => $args->[0],
            dspt => $args->[1],
        };
    }
    my %args  = $args->[0]->%*; # make a shallow copy


    #%--------PATHS--------#%
    # CHECK INPUT
    my $input = delete $args{input};
    __checkChgArgs($input,'','string scalar');
    $self->{paths}{input} = $input;

    # CHECK DSPT
    my $paths_dspt = delete $args{dspt};
    __checkChgArgs($paths_dspt,'','string scalar');
    $self->{paths}{dspt} = $paths_dspt;

    # CHECK OUTPUT
    my $output = delete $args{output};
    unless ( defined $output ) {
        $output = getcwd;
    } $self->{paths}{output} = $output;

    # CHECK DRSR
    my $paths_drsr = delete $args{drsr};
    $self->{paths}{drsr} = $paths_drsr;

    #%--------OTHER ARGS--------#%
    # CHECK NAME
    my $name = delete $args{name};
    unless ( defined $name ) {
        my $fname = basename($self->{paths}{input});
        $name = $fname =~ s/\..*$//r;
    } $self->{name} = $name;

    # CHECK PRSV
    my $prsv = delete $args{prsv};
    $self->{prsv} = $prsv;

    # CHECK PARAMS
    my $params = delete $args{params};
    my $defaults = {
        attribs  => '01',
        delims   => '01',
        prsv     => '01',
        mes      => '01',
    };
    $defaults->{$_} = $params->{$_} for keys %$params;
    $self->{params} = $defaults;

    #%--------NON ARGS--------#%
    # CHECK KEYS
    if ( my $remaining = join ', ', keys %args ) {
        croak("Unknown keys to $class\::new: $remaining");
    }

    # SET PROPERTIES
    $self->{debug} = [];
    $SIG{__DIE__} = sub {
        print $_ for $self->{debug}->@*;
        print $erreno if $erreno;
    };
}

1;
