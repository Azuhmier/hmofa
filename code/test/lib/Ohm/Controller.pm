package Ohm::Controller;
use warnings;
use strict;
use File::Glob;
use Cwd;
use File::Basename;
use Carp qw(croak carp);
my $erreno;
#./.ohm dir; basically like git;
  # history; full, like git
# repo
  # dspts
  # jsons
  # drsr
  # stdout

sub new { #{{{1
    my ( $class, @args ) = @_;
    my $self = bless {}, $class;
    $self->__init( \@args );
    return $self;
}

sub __init { #{{{1
    my ( $self, $args ) = @_;
    my $class = ref $self;
    unless (UNIVERSAL::isa($args->[0], 'HASH')) {
        $args->[0] = {
            name => $args->[0],
            base => $args->[1],
        };
    }
    my %args  = $args->[0]->%*;


    #%--------ARGS--------#%
    # CHECK NAME
    my $name = delete $args{name};
    unless ($name) {
        $name = 'ohm_lib';
    } elsif (ref $name) {
        croak("$class requires a name that is a scalar string");
    }
    $self->{name} = $name;

    # CHECK BASE
    my $base = delete $args{base};
    unless ($base) {
        $base = Cwd::abs_path('.');
    } elsif (ref $base) {
        croak("$class requires a base that is a scalar string");
    } else {
        $base = Cwd::abs_path( glob $base =~ s/\/$//r );
    }
    $self->{paths}{base} = $base;


    #%--------NON ARGS--------#%
    # CHECK KEYS
    if ( my $remaining = join ', ', keys %args ) {
        croak("Unknown keys to $class\::new: $remaining");
    }

    # LIB_DIR
    my $lib_dir = $base.'/'.$name;
    $lib_dir = __genUniqueDir($lib_dir);
    $self->{paths}{lib_dir} = $lib_dir;

    # DEBUG
    $self->{debug} = [];
    $SIG{__DIE__} = sub {
        print $_ for $self->{debug}->@*;
        print $erreno if $erreno;
    };
}

sub __checkChgArgs { #{{{1
    my ($arg, $cond, $type) = @_;
    unless ( defined $arg ) {
        croak( (caller(1))[3] . " requires an input" );
    } elsif (ref $arg ne $cond) {
        croak( (caller(1))[3] . " requires a $type" );
    }
}

sub __genUniqueDir { #{{{1
    my $dir = shift @_;
    my $cnt = 0;
    my $new_dir = $dir;
    while (-d $new_dir) {
        $cnt++;
        $new_dir = $dir.'-'.$cnt;
    }
    return $new_dir;
}

1;

### SETUP
#my $CWD = Cwd::cwd();
#my $CONFIG_DIR = glob '~/.ohm/.config';
#my $BASE_DIR = 0;
#{
#    open my $fh, '<', $CONFIG_DIR
#        or die 'something happened';
#    while (my $line = <$fh>)  {
#        if ($line =~ m/^BASE=(.*)/) {
#            $BASE_DIR = glob $1;
#            last;
#        }
#    }
#}
#my $LIB_DIR = $BASE_DIR.'/lib';
#
#print $BASE_DIR,"\n";
#print $LIB_DIR,"\n";
#print $CWD,"\n";
#print "\n";
#
#1;
