package Ohm::Controller;

use parent 'Ohm::Main';

use warnings;
use strict;
use utf8;
use Carp qw(croak carp confess);
use Storable qw(dclone);
use Cwd qw (getcwd abs_path);
use File::Spec;
use File::Basename;
use File::Find;
use JSON::XS;
use Array::Utils qw(:all);
use Data::Dumper;

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Ohm::HasherWIP;

use constant FALSE => 1==0;
use constant TRUE  => not FALSE;
use constant BASE  => '.ohmi';


#############################################################
#  PUBLIC
#############################################################
eval 'sub paths {$self=shift; $self->{args}{paths}; }';
sub init_ohmi #{{{1
{
    my ($self, $baseDir) = @_;

    croak "ERROR: '.ohmi' directory has not been selected\n"
        unless ( $self->get('status','base') );

    $baseDir = $baseDir // $self->{cwd};
    my $basePath = $baseDir . '/' . BASE;

    mkdir $basePath;
    my $fname =  $basePath.'/ohminfo';

    $self->__write($fname,["lol\n", "go away\n"]);

    return $self;

}



sub select_ohmi #{{{1
{
    my ($self, $path, $NONE) = @_;

    die "ERROR: ohmi path not specified\n"
            unless $path;

    unless ($NONE)
    {
        $self->{paths}{baseDir} = $path;
        $self->__set_status('base',TRUE);
    }

    else
    {
        $self->{paths}{baseDir} = undef;
        $self->__set_status('base',FALSE);
    }

    return $self;
}

sub seek_ohmi #{{{1
{
    my ( $self, $path, $mode ) = @_;

    my $baseDirs = $self->__find_ohmi();
    my @basePaths = map { $_.'/'.BASE } @$baseDirs;

    return  \@basePaths;

    # Find .ohm in current dir or upwards
    sub __find_ohmi #{{{
    {
        my $self = shift @_;
        my $dir = $self->{cwd};
        my $baseDirs = [];

        if (-d BASE)
        {
            push @$baseDirs, $dir;
        }
        else
        {

            while ( $dir )
            {
                my $hit_top = $dir eq dirname($dir);
                $dir = dirname($dir);

                my $found  = basename($dir) eq BASE;

                if ($found or $hit_top)
                {
                    push @$baseDirs, $dir if $found;
                }
            }
        }

        return $baseDirs;

    } #}}}

}




sub importFromPaths #{{{1
{
    my ($self) = @_;

    my $paths = dclone $self->{paths};

    delete $paths->@{"his","baseDir"};

    my $data = {};
    for my $key (keys %$paths)
    {
        next unless $paths->{$key};

        my $isArray = UNIVERSAL::isa($paths->{$key}, 'ARRAY' );
        if ($isArray)
        {
            my $paths = $paths->{$key};
            next unless @$paths;

            for my $path ( @$paths )
            {
                my ($ext) = $path =~ /(\.[^.]*$)/g;
                $ext = $ext // '';

                if ($ext eq '.json')
                {
                    push $data->{$key}->@*, $self->__importJson($path);
                }
                elsif ($ext eq '.txt')
                {
                    __read($path);
                    push $data->{$key}->@*, $self->__read($path);
                }
                else
                {
                    croak "ERROR: Invalid file type '$ext'";
                }
            }
        }
        else
        {
            my $path = $paths->{$key};

            my ($ext) = $path =~ /(\.[^.]*$)/g;
            $ext = $ext // '';

            if ($ext eq '.json')
            {
                $data->{$key} = $self->__importJson($path);
            }

            elsif ($ext eq '.txt')
            {
                $data->{$key} = $self->__read($path);
            }

            else
            {
                croak "ERROR: Invalid file type '$ext'";
            }
        }

    }

    return $data;
}




sub launch #{{{1
{
    my ($self) = @_;
    return $self;
}




sub genDb #{{{1
{
    my ($self, $args) = @_;
    $self->{db} = Ohm::HasherWIP->new($args);
    return $self;
}
sub commit #{{{1
{
    my ($self) = @_;
    return $self;
}#}}}




#############################################################
# PRIVATE
#############################################################

sub __init #{{{1
{
    my ( $self, $args ) = @_;
    $self->__private(caller);

    $self->__set_args( $args , 1);
    $self->__use_args();

    $self->__set_status
    ({
        state => 'ok',
        init => TRUE,
    });

    return $self;
}

sub __use_args #{{{1
{

    my ( $self, $args ) = @_;
    $self->__private(caller);

    ## PATHS
    my $paths = $self->{args}{paths};

    for my $key (keys %$paths)
    {
        my $item = $paths->{$key};

        if ( UNIVERSAL::isa($item, 'ARRAY' ) )
        {
            $self->{paths}{$key}->@* = map { abs_path $_ } @$item
        }

        elsif ( $item )
        {
            $self->{paths}{$key} = abs_path $item;
        }
        else
        {
            $self->{paths}{$key} = undef;
        }
    }

    ## OPTS
    $self->{opts} = $self->{args}{opts};

    ## FLAGS
    $self->{flags} = $self->{args}{flags};

    #print Dumper $self;

    return $self;
}




sub __bps #{{{1
{
    my $self = shift @_;
    $self->__private(caller);

    my %bps =
    (
        ## REQUIRED
        self => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                args    => {},
                status  => {
                               state => '',
                               init => FALSE,
                               args => FALSE,
                               base => FALSE,
                               sync => FALSE,
                            },
            },
        },

        args => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                db_opts => {},
                flags   => {},
                opts    => {},
                paths   => {},
            },
        },

        paths => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                drsr      => $self->{paths}{baseDir}
                                 ? $self->{paths}{baseDir}.'/'.BASE.'/db/drsr.json'
                                 : '',
                dspt      => $self->{paths}{baseDir}
                                 ? $self->{paths}{baseDir}.'/'.BASE.'/db/dspt.json'
                                 : '',
                input     => $self->{paths}{baseDir}
                                 ? $self->{paths}{baseDir}.'/'.BASE.'/db/input.txt'
                                 : '',
                mask      => $self->{paths}{baseDir}
                                 ? $self->{paths}{baseDir}.'/'.BASE.'/db/mask.json'
                                 : '',
                smask     => [],

                sdrsr     => [],

                extern    => [],

                his       => $self->{paths}{baseDir}
                                 ? $self->{paths}{baseDir}.'/'.BASE.'/db/his'
                                 : '',
                baseDir   => undef,
            },
        },

        db_opts => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                plhd => {},
                prsv_opts => {},
            },
        },

        prsv_opts => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                till =>
                [
                    'section',
                    0,
                ],
            },
        },

        flags => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                launch   => FALSE,
                commit   => FALSE,
                writable => FALSE,
            },
        },

        opts => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
            },
        },#}}}


        ## UTILITES
        ohminfo => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                updated => '',
                created => '',
                name    => '',
            },
        },#}}}

    );

    return \%bps;
}#}}}




#############################################################
#  UTILITIES
#############################################################

sub __write #{{{1
{
    my ($self, $fname, $lines) = @_;
    $self->__private(caller);
    open my $fh, '>:utf8', $fname
        or die "cannot open $fname";
        print $fh @$lines;
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
    return $self;
}




sub __writeJson #{{{1
{
    my ($self,$path,$hash) = @_;
    $self->__private(caller);
    my $encoder = JSON::XS->new;
    $encoder->pretty->allow_nonref->allow_blessed(['true']);
    my $json = $encoder->encode( $hash );
    $self->__write($json,$path);
}




sub __fileExist #{{{
{
    my ($self, $path) = @_;
    $self->__private(caller);

    return 0 unless $path;

    my @cwd   = File::Spec->splitdir( $self->{cwd} );
    my @path  = File::Spec->splitdir( $path );

    no warnings 'uninitialized';
    my @isect  = intersect(@path, @cwd);
    use warnings 'uninitialized';

    my $dir = File::Spec->catdir(@isect);
    my $idx = scalar @isect;


    for ( $idx .. $#path )
    {
        chdir $dir;
        unless (-e $path[$_])
        {
            chdir $self->{cwd} or die;
            return 0;
        }
        no warnings 'uninitialized';
        $dir = File::Spec->catdir(@path[0 .. $_]);
        use warnings 'uninitialized';
    }
    chdir $self->{cwd};
    return 1;
}







1 ;
