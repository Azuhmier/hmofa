package Ohm::Controller;

use parent 'Ohm::Main';

use warnings;
use strict;
use utf8;
use Carp qw(croak);
use Storable qw(dclone);
use Cwd qw (getcwd abs_path);
#use Array::Utils qw(:all);

use lib ($ENV{HOME}.'/progs/ohm/lib');
    use Ohm::Main qw(:constants);
    use Ohm::Hasher;

#############################################################
#  PUBLIC
#############################################################
sub genDb #{{{1
{
    my ($self, $args) = @_;
    unless ($args)
    {
        $args = $self->__importFromPaths;
        $args->{opts} = $self->{args}{db_opts};
    }


    my $input = delete $args->{input};
    $self->{db} = Ohm::Hasher->new($args);
    $self->input( $input );
    return $self;
}#}}}



#############################################################
# PRIVATE
#############################################################
sub __importFromPaths #{{{1
{
    my ($self) = @_;
    $self->__private(caller);

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
                    push $data->{$key}->@*, $self->importJson($path);
                }
                elsif ($ext eq '.txt')
                {
                    importTxt($path);
                    push $data->{$key}->@*, $self->importTxt($path);
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
                $data->{$key} = $self->importJson($path);
            }

            elsif ($ext eq '.txt')
            {
                $data->{$key} = $self->importTxt($path);
            }

            else
            {
                croak "ERROR: Invalid file type '$ext'";
            }
        }

    }

    return $data;
}#}}}



#############################################################
#  WRAPPERS
#############################################################
sub out #{{{1
{
    my $self = shift;
    return $self->db->{stdout}->@*;
}




sub validate #{{{1
{
    my ($self, $mode, $old, $new) = @_;

    $self->db->validate($mode, $old, $new);
    return $self;
}


sub input #{{{1
{
    my $self = shift;
    $self->db->{input} = shift;
    return $self;
}




sub get_matches #{{{1
{
    my $self = shift;
    $self->db->get_matches( shift );
    return $self;
}

sub genWrite #{{{1
{
    my $self = shift;
    $self->db->__genWrite( shift );
    return $self;
}




sub sweep #{{{1
{
    my ($self, $args, $hash) = @_;
    $self->db->__sweep( $args, $hash );
    return wantarray ? ($hash) : $self;
}




sub divy #{{{1
{
    my $self = shift;
    $self->db->__divy();
}




sub find #{{{1
{
    my ($self, $args, $format, $hash) = @_;
    my $results = $self->db->__find($args, $hash);
    return $results
        unless $format;
    my @output;
    for my $subname (keys %$results)
    {
    push @output, '---------------';
    push @output, $subname;
        for my $result ($results->{$subname}->@*)
        {
            my $objHash = shift @$result;
            push @output, shift @$result;

            for my $item (@$format)
            {
                push @output, map {''.($_->{val} // 'error' )} $objHash->{childs}{$item}->@[0 .. $objHash->{childs}{$item}->$#*];

            }
            push @output, '';

        }
    }
    return join "\n", @output;
}




sub db #{{{1
{
    my $self = shift;
    return $self->{db};
}




sub hash #{{{1
{
    my $self = shift;
    return $self->db->{hash};
}#}}}



#############################################################
# OVERIDES
#############################################################
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




sub __init #{{{1
{
    my ( $self, $args ) = @_;
    $self->__private(caller);

    $self->__use_args();

    $self->__set_status
    ({
        state => 'ok',
        init => TRUE,
    });

    return $self;
}

sub __bps #{{{1
{
    my $self = shift @_;
    $self->__private(caller);

    my $bps =
    {
        ## REQUIRED
        init => sub #{{{2
        {
            start =>
            {
                args    =>
                {
                    default => {},
                    strict_type => 1,
                },
                status  =>
                {
                    default => {},
                    strict_type => 1,
                    params => 'status',
                },
            },
            member => {},
            fill => [0],
        },


        args => sub #{{{2
        {
            start =>
            {
                db_opts =>
                {
                    default => {},
                    strict_type => 1,
                },
                flags   =>
                {
                    default => {},
                    strict_type => 1,
                    params => 'flags',
                },
                opts    =>
                {
                    default => {},
                    strict_type => 1,
                    params => 'opts',
                },
                paths   =>
                {
                    default => {},
                    strict_type => 1,
                    params => 'paths',
                },
            },
            member => {},
            fill => [0],
        },


        status => sub #{{{2
        {
            start =>
            {
                state =>
                {
                    default => '',
                    strict_type => 1,
                },
                init =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
                args =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
                base =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
                sync =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
            },
            member => {},
            fill => [0],
        },


        paths => sub #{{{2
        {
            start =>
            {
                drsr      =>
                {
                    default => $self->{paths}{baseDir}
                                   ? $self->{paths}{baseDir}.'/'.BASE.'/db/drsr.json'
                                   : undef,
                    strict_type => 1,
                },

                dspt      =>
                {
                    default => $self->{paths}{baseDir}
                                   ? $self->{paths}{baseDir}.'/'.BASE.'/db/dspt.json'
                                   : undef,
                    strict_type => 1,
                },

                input     =>
                {
                    default => $self->{paths}{baseDir}
                                   ? $self->{paths}{baseDir}.'/'.BASE.'/db/input.txt'
                                   : undef,
                    strict_type => 1,
                },

                mask =>
                {
                    default => $self->{paths}{baseDir}
                                   ? $self->{paths}{baseDir}.'/'.BASE.'/db/mask.json'
                                   : undef,
                    strict_type => 1,
                },

                smask     =>
                {
                    default => [],
                    strict_type => 1,
                },

                sdrsr     =>
                {
                    default => [],
                    strict_type => 1,
                },

                extern    =>
                {
                    default => [],
                    strict_type => 1,
                },

                his       =>
                {
                    default => $self->{paths}{baseDir}
                                   ? $self->{paths}{baseDir}.'/'.BASE.'/db/his'
                                   : undef,
                    strict_type => 1,
                },

                baseDir   =>
                {
                    default => undef,
                    strict_type => 1,
                },
            },
            member => {},
            fill => [0],
        },


        prsv_opts => sub #{{{2
        {
            start =>
            {
                till =>
                {
                    default =>
                    [
                        'section',
                        0,
                    ],
                },
                strict_type => 1,
            },
            member => {},
            fill => [0],
        },


        flags => sub #{{{2
        {
            start =>
            {
                launch   =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
                commit   =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
                writable =>
                {
                    default => FALSE,
                    strict_type => 1,
                },
            },
            member => {},
            fill => [0],
        },


        opts => sub #{{{2
        {
            start =>
            {
            },

            member => {},
            fill => [0],
        },#}}}


        ## UTILITES
        ohminfo => sub #{{{2
        {
            start =>
            {
                updated =>
                {
                    default => '',
                    strict_type => 1,
                },
                created =>
                {
                    default => '',
                    strict_type => 1,
                },
                name    =>
                {
                    default => '',
                    strict_type => 1,
                },
            },
            member => {},
            fill => [0],
        },#}}}

    };

    return $bps;
}#}}}



1;
