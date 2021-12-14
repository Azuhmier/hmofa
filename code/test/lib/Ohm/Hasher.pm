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
use utf8;
use feature 'current_sub';
use Cwd;
use File::Basename;
use JSON::XS;
use Storable qw(dclone);
use Carp qw(croak carp);

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
use Hash::Flatten qw(:all);
my $erreno;

sub get_sum { #{{{1
# output a summary hash for data dumping.

    my ( $self, $args ) = @_;

    my $copy = dclone $self;

    # DSPT
    if ( exists $copy->{dspt} ) {
        my $dspt = $copy->{dspt};

        for my $obj (keys %$dspt) {

            # Creaated Value String for each key in dspt obj.
            my $str = '';
            for my $key (sort keys $dspt->{$obj}->%*) {

                my $value = $dspt->{$obj}{$key};
                my $ref   = ref $value;

                if ( $ref eq 'HASH' ) {
                    $value = '['.( join ',', sort keys %$value ).']';
                }

                $str .= ';'.$key.':'.( $value // 'n/a' ).'; ';
            }
            $dspt->{$obj} = $str;
        }
        $copy->{dspt} = $dspt;
    }
    $copy->{dspt} = exists $copy->{dspt} ?1 :0;

    # MATCHES
    if ( exists $copy->{matches} ) {
        my $matches = $copy->{matches};

        if ( exists $matches->{miss} ) {
            $matches->{miss} = scalar $matches->{miss}->@*;
        }

        $matches->{obj_count} = scalar keys $matches->{objs}->%*;
        $matches->{objs}{$_}  = scalar $matches->{objs}{$_}->@* for keys $matches->{objs}->%*;
        $copy->{matches}      = $matches;
    }

    # META
    if (exists $copy->{meta}) {
        my $meta = $copy->{meta};
        $meta->{dspt}{ord_map} = scalar keys $meta->{dspt}{ord_map}->%*;
        $copy->{meta} = $meta;
    }

    # META
    if (exists $copy->{circ}) {
        $copy->{circ} = scalar $copy->{circ}->@*;
    }

    # STDOUT
    if (exists $copy->{stdout}) {
        $copy->{stdout} = scalar $copy->{stdout}->@*;
    }

    # HASH
    $copy->{hash} = exists $copy->{hash} ?1 :0;



    return $copy;
}

sub new { #{{{1

    my ($class, $args) = @_;

    # Convert '$args' into type 'HASH', if not already
    unless ( UNIVERSAL::isa($args, 'HASH') ) {
        $args = {
            input => $_[1],
            dspt  => $_[2],
            drsr  => $_[3],
            mask  => $_[4],
            prsv  => $_[5],
        };
    }

    # Create Object
    my $self = {};
    bless $self, $class;

    # init and form circular hash check
    $self->__init( $args );
    $self->__gen_dspt();
    $self->__check_matches();

    return $self;
}

sub gen_config { #{{{1
    #generates complex configurations
    my ( $self, $args ) = @_;

    my $bp_name   = $args->{bp_name};
    my $init_hash = $args->{init_hash};
    my @EXL_KEYS = ();
    if (exists $args->{exclude_keys}) {
        @EXL_KEYS = $args->{exclude_keys}->@*;
    }

    my $bp = dclone $self->__gen_bp($bp_name) // die;

    my $populate = sub { #{{{2
        my ( $self, $bp, $config, $OBJ ) = @_;

        my $type    = delete $bp->{type} // return $config;
        #die if $type ne 'config';
        my $fill    = delete $bp->{fill} // die;
        my $general = delete $bp->{general};
        my $member  = delete $bp->{member};
        $config  = dclone $general if $general;


        if ( %$member ) {

            my @KEYS;
            if ($OBJ) {
                @KEYS = keys $self->{dspt}{$OBJ}{attr}->%*;
                push @KEYS, $OBJ if $fill->[1];
            } else {
                @KEYS = keys $self->{dspt}->%*;
            }

            for my $key ( @KEYS ) {
                $config->{$key} = __SUB__->(
                    $self,
                    dclone $member,
                    $config->{$key},
                    $key,
                );
            }
        }

        for my $key ( keys %$bp ) {
            $config->{$key} = __SUB__->(
                $self,
                dclone $bp->{$key},
                $config->{$key},
                $OBJ,
            );
        }

        if ($config eq 'HASH') {
            my $flatConfig  = flatten(dclone $general) if $general;
            my $flatConfig2 = flatten $config;
            for my $key (keys %$flatConfig) {
                $flatConfig2->{$key} = $flatConfig->{$key};
            }
            return unflatten $flatConfig2;
        } else {
            return $config;
        }
        #return $config;
    }; #}}}

    my $config = $populate->($self, $bp, {});
    if ($init_hash) {
        my $flatConfig  = flatten $init_hash;
        my $flatConfig2 = flatten $config;
        for my $key (keys %$flatConfig) {
            $flatConfig2->{$key} = $flatConfig->{$key};
        }
        for my $key (@EXL_KEYS) {
            delete $flatConfig2->{$key};
        }
        $config = unflatten $flatConfig2;

        for my $key (@EXL_KEYS) {
            delete $config->{$key};
        }
    }
    return $config;

    #my $json = JSON::XS->new->allow_nonref->pretty->encode( $config );
    #my $dir  = '/Users/azuhmier/hmofa/hmofa/code/test/';
    #
    #open my $fh, '>:utf8', $dir.$fname.'.json' or die $!;
    #    print $fh $json;
    #    truncate $fh, tell($fh) or die;
    #    seek $fh,0,0 or die;
    #close $fh;

}

sub write { #{{{1
    my ( $self, $args ) = @_;
    my $writeArray = $self->{stdout};
    my $dir = '/Users/azuhmier/hmofa/hmofa/code/test/reezoli/';
    open my $fh, '>:utf8', $dir . $self->{name} . '.txt' or die $!;
        for (@$writeArray) {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
    close $fh;
}

sub see { #{{{1
    my ($self, $key) = @_;
    return $self->__see(
        $self->{$key},
        'lib',
        [],
    );

}

sub rm_reff { #{{{1

    my ( $self, $args ) = @_;

    my $CIRCS = $self->{circ} // return;

    for my $circ ( @$CIRCS ) {

        my $ref = $circ->{'.'};

        if ( UNIVERSAL::isa($ref,'HASH') ) {
            delete $ref->{circ};
        } elsif ( UNIVERSAL::isa($ref,'ARRAY') ) {
            $ref->[0] = {};
        } else {
            die
        }
    }
    $self->{circ} = [];
}

sub __see {#{{{1
    my ( $self, $item, $prefix, $flat) = @_;

    if ( UNIVERSAL::isa($item,'HASH' ) ) {
        for my $key ( keys %$item) {
            my $flatkey = $prefix . '.' . $key;
            $flat = $self->__see($item->{$key}, $flatkey, $flat);
        }
    } elsif ( UNIVERSAL::isa($item,'ARRAY' ) ) {
        for my $idx (0 .. $item->$#*) {
            my $flatkey = $prefix . ':' . $idx;
            $flat = $self->__see( $item->[$idx], $flatkey, $flat);
        }
    } else {
            my $flatkey = $prefix . '=' . ($item // 'NULL');
            push @$flat, $flatkey;
    }
    return $flat;
}

sub __flatten {
    my ($self, $key) = @_;
    return flatten $self->{$key};
}

sub __unflatten {
    my ($self, $key) = @_;
    return unflatten $self->{$key};
}

sub __gen_bp { #{{{1
    my ( $self, $bp_name ) = @_;
    my %bps = (
        objhash => {
            type => 'struct',
            fill => [''],
            member => {},
            general => {
                obj => undef,
                val => undef,
                childs => {},
                attrs  => {},
                meta   => {},
                circs  => {
                    '.'  => undef,
                    '..' => undef,
                },
            },
        },
        meta => {
            type => 'config',
            fill => [''],
            member => {},
            general => {
                dspt => {
                   ord_limit => undef,
                   ord_map => undef,
                   ord_max => undef,
                },
            },
        },
        params => {
            type => 'config',
            fill => [''],
            member => {},
            general => {
                attribs => 1,
                delims => 1,
                mes => 1,
                prsv => 1,
            },
        },
        paths => {
            type => 'config',
            fill => [''],
            member => {},
            general => {
                drsr => undef,
                dspt => undef,
                input => undef,
                mask => undef,
                output => undef,
            },
        },
        prsv => {
            type => 'config',
            fill => [''],
            member => {},
            general => {
                till => [
                    'section',
                    0,
                ],
            },
        },
        self => {
            type => 'config',
            fill => [''],
            member => {},
            general => {
                circs => [],
                dspt => {},
                hash => {},
                matches => {},
                meta => {},
                name => undef,
                stdout => [],
                params => {},
                paths  => {},
                prsv => {},
            },
        },
        matches => {
            type => 'config',
            fill => ['obj'],
            member => {},
            general => {
                miss => [],
                objs => {},
            },
            objs => {
                type => 'config',
                fill => ['obj'],
                general => {},
                member => {
                    type => 'config',
                    fill => ['obj'],
                    general => [],
                    member => {},
                },
            },
        },
        drsr => {
            type => 'config',
            fill => ['obj'],
            general => {},
            member => {
                type => 'config',
                fill => ['attr',1],
                general => {},
                member => {
                    type => 'config',
                    fill => [''],
                    member => {},
                    general => {
                        r => '',
                        l => '',
                        dr => '',
                        dl => '',
                        n => '',
                        o => {},
                    },
                },
            },
        },
        dspt => {
            type => 'config',
            fill => [''],
            general => {
                lib => {
                    order => 0,
                },
                prsv => {
                    order => -1,
                    mask => {},
                    drsr => {},
                },
            },
            member => {
                type => 'config',
                fill => ['obj'],
                member => {},
                general => {
                    re => undef,
                    order => undef,
                    attrs => {},
                    drsr  => {},
                    mask  => {},
                },
                attrs => {
                    type => 'config',
                    fill => ['attr'],
                    general => {},
                    member => {
                        type => 'config',
                        fill => ['attr'],
                        member => {},
                        general => {
                            re => undef,
                            ord => undef,
                            delims => [],
                        },
                    },
                },
            },
        },
        mask => {
            fill => ['obj'],
            type => 'config',
            general => {
                lib => {},
                prsv => {},
            },
            member => {
                fill => ['obj'],
                type => 'config',
                member => {},
                general => {
                    supress => {
                        all => 0,
                        vals => [],
                    },
                    sort => -1,
                    place_holder => {
                        enable => 0,
                        childs => [],
                    },
                },
            },
        },
    );

    return dclone $bps{lc $bp_name};
}

sub __init { #{{{1

    my ( $self, $args ) = @_;

    my $class = ref $self;


    #%--------PATHS--------#
    # INPUT
    my $paths_input = delete $args->{input};
    __checkChgArgs( $paths_input,'','string scalar' );
    $self->{paths}{input} = $paths_input;

    # DSPT - DISPATCH TABLE
    my $paths_dspt = delete $args->{dspt};
    __checkChgArgs( $paths_dspt,'','string scalar' );
    $self->{paths}{dspt} = $paths_dspt;

    # OUTPUT
    my $output = delete $args->{output};
    unless ( defined $output ) { $output = getcwd }
    __checkChgArgs( $output,'','string scalar' );
    $self->{paths}{output} = $output;

    # DRSR - DRESSER
    my $paths_drsr = delete $args->{drsr};
    __checkChgArgs( $paths_drsr,'','string scalar' );
    $self->{paths}{drsr} = $paths_drsr;

    # MASK
    my $paths_mask = delete $args->{mask};
    __checkChgArgs( $paths_mask,'','string scalar' );
    $self->{paths}{mask} = $paths_mask;


    #%--------OTHER ARGS--------#
    # NAME
    my $name = delete $args->{name};
    unless ( defined $name ) {
        my $fname = basename( $self->{paths}{input} );
        $name = $fname =~ s/\..*$//r;
    }
    __checkChgArgs( $name,'','string scalar' );
    $self->{name} = $name;

    # PARAMS - PRAMEMTERS
    my $params = delete $args->{params};
    my $defaults = {
        attribs  => '1',
        delims   => '1',
        prsv     => '1',
        mes      => '1',
    };
    $defaults->{$_} = $params->{$_} for keys %$params;
    $self->{params} = $defaults;

    # PRSV - PRESERVES
    my $prsv = delete $args->{prsv};
    $self->{prsv} = $prsv;


    #%--------NON ARGS--------#
    # KEYS
    if ( my $remaining = join ', ', keys %$args ) {
        croak( "Unknown keys to $class\::new: $remaining" );
    }

    # DEBUG
    $self->{debug} = [];
    $SIG{__DIE__} = sub {
        print $_ for $self->{debug}->@*;
        print $erreno if $erreno;
    };

}

sub __gen_dspt { #{{{1

    my ( $self, $args ) = @_;

    # Import DSPT FILE
    my $dspt = do {
        open my $fh, '<:utf8', $self->{paths}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    # Add intrisice DSPT keys
    $dspt->{lib}  = { order =>'0'};
    $dspt->{prsv} = { order =>'-1'};

    # Generate Line and Attr Regexs
    for my $obj (keys %$dspt) {

        my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT) {

            #line regexes
            if ( $key eq 're' ) { $objDSPT->{re} = qr/$objDSPT->{re}/ }

            #attribute regexes
            if ( $key eq 'attr' ) {

                my $dspt_attr = $objDSPT->{attr};
                for my $attr (keys %$dspt_attr) {

                    $dspt_attr->{$attr}[0] = qr/$dspt_attr->{$attr}[0]/;
                    if (scalar $dspt_attr->{$attr}->@* >= 3) {

                        my $delims = join '', $dspt_attr->{$attr}[2][0];
                        $dspt_attr->{$attr}[3] = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
                                                                 : '';

                    }
                }
            }
        }
    }

    ## --- VALIDATE
    # check for duplicates: order
    my @keys  =
        sort
        map {
            exists $dspt->{$_}{order}
                and
            $dspt->{$_}{order}
        } keys %{$dspt};
    my %dupes;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $dupes{$_}++ }

    ## --- META
    # max
    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $self->{meta}{dspt}{ord_max} = (
        sort {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];

    # limit
    my @pntstr = split /\./, $self->{meta}{dspt}{ord_max};
    $pntstr[$#pntstr]++;
    $self->{meta}{dspt}{ord_limit} = join '.', @pntstr;

    # ordMap
    $self->{meta}{dspt}{ord_map}->%* =
        map  {$dspt->{$_}{order} => $_}
        grep {exists $dspt->{$_}{order} }
        keys %$dspt;

    # drsr
    my $drsr = do {
        open my $fh, '<:utf8', $self->{paths}{drsr}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    for my $obj (keys %$drsr) {
        $dspt->{$obj} // die;
        $dspt->{$obj}{drsr} = $drsr->{$obj};
        for my $attr (grep {$_ ne $obj} keys $drsr->{$obj}->%*) {
            $dspt->{$obj}{attr}{$attr} // die "$attr for $self->{name}" ;

        }
    }

    # mask
    my $mask = do {
        open my $fh, '<:utf8', $self->{paths}{mask}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    for my $obj (keys %$mask) {
        $dspt->{$obj} // die;
        $dspt->{$obj}{mask} = $mask->{$obj};
    }

    $self->{dspt} = $dspt;

    return $self;
}


sub __check_matches #{{{1
{
    # have option presverses be 2nd option
    my ( $self, $args ) = @_;

    # without the 'g' modifier and the array context the regex exp will return
    # a boolean instead of the first match
    #
    my ($fext) = $self->{paths}{input} =~ m/\.([^.]*$)/g;
    $self->{matches} = {} unless exists $self->{matches};

    if ($fext eq 'txt')
    {
        delete $self->{matches};
        delete $self->{circ};
        delete $self->{stdout};
        #$self->__get_matches;
        $self->get_matches;
        $self->__divy();
        $self->__sweep(['reffs','plhd']);
        $self->__genWrite();
        $self->write();
        $self->__validate($fext);

    }

    elsif ($fext eq 'json')
    {
        delete $self->{matches};
        delete $self->{circ};
        delete $self->{stdout};
        $self->{hash} = do
        {
            open my $fh, '<:utf8', $self->{paths}{input};
            local $/;
            decode_json(<$fh>);
        };
        $self->__sweep(['reffs','matches','plhd']);
        $self->__genWrite();
        $self->write();
        $self->__validate($fext);

    }

    else
    {
        die "$fext is not a valid file extesion, must either be 'txt' or 'json'"
    }

    return $self;
}

sub __sweep { #{{{1

    my ( $self, $subs ) = @_;

    my $sub_list = {
        reffs   => \&gen_reffs,
        matches => \&gen_matches,
        plhd    => \&place_holder,
    };

    $self->{m} = {};

    walk (
        {
            wanted => sub {
                for my $name (@$subs) {
                    $sub_list->{$name}->($self);
                }
            },
        }, $self->{hash} // die " No hash has been loaded for object '$self->{name}'"
    );

    delete $self->{m};
    return $self;

    sub gen_reffs { #{{{2
    # inherits from Data::Walk module

        my ( $self, $args ) = @_;

        $self->{circ} = [] unless exists $self->{circ};


        if ( UNIVERSAL::isa($_, 'HASH') ) {
            my $objHash = $_;
            my $objArr  = $Data::Walk::container;
            my $obj = $objHash->{obj} // 'NULL'; # need to have NULL be
                                              # error or something

            $objHash->{circ}{'.'}   = $objHash;
            $objHash->{circ}{'..'}  = $objArr // 'NULL';
            push $self->{circ}->@*, $objHash->{circ};

        } elsif ( UNIVERSAL::isa($_, 'ARRAY') ) {
            my $objArr = $_;
            my $ParentHash  = $Data::Walk::container;
            unshift @$objArr, {
                '.'   => $_,
                '..'  => $ParentHash // 'NULL',
            };
            push $self->{circ}->@*, $objArr->[0];
        }
    }

    sub gen_matches { #{{{2
    # inherits from Data::Walk module

        my ( $self, $args ) = @_;

        unless ( exists $self->{matches} ) {
            $self->{matches} = { objs => {}, miss => [{a => 2}] }
        }

        if ( UNIVERSAL::isa($_, 'HASH') ) {
            my $objHash = $_;
            my $obj = $objHash->{obj};
            push $self->{matches}{objs}{ $obj }->@*, $objHash;
        }

    }

    sub place_holder { #{{{2
    # inherits from Data::Walk module

        my $self = shift @_;

        if ( UNIVERSAL::isa($_, 'HASH') ) {

            my $objHash = $_;
            my $obj     = $objHash->{obj};
            my $objMask = $self->{dspt}{$obj}{mask} // return 1;

            if ( $objMask->{place_holder}{enable} ) {

                for my $child ( $objMask->{place_holder}{childs}->@* ) {

                    unless ( exists $objHash->{childs}{$child} ) {

                        my $childHash = $objHash->{childs}{$child}[0] = {};
                        %$childHash = (
                            obj => $child,
                            val => [],
                            meta => undef,
                        );

                        # attributes
                        my $childDspt = $self->{dspt}{$child};
                        if ( defined $childDspt->{attr} ) {
                            for my $attr ( keys $childDspt->{attr}->%* ) {
                                if (exists $childDspt->{attr}{$attr}[2]) {
                                    $childHash->{attr}{$attr} = [];
                                } else {
                                    $childHash->{attr}{$attr} = '';
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

sub __get_matches #{{{1
{
    my ( $self, $line, $FR_prsv ) = @_;

    my $dspt = $self->{dspt};


    ## --- OBJS
    my $match;
    for my $obj (keys %$dspt)
    {
        $self->{matches}{objs}{$obj} = [] unless exists $self->{matches}{objs}{$obj};

        my $regex = $dspt->{$obj}{re} // 0;
        if ($regex and $line =~ $regex)
        {

            last if _isPrsv($self,$obj,$1,$FR_prsv);

            $match =
            {
                obj => $obj,
                val => $1,
                meta =>
                {
                    raw => $line,
                    LN  => $.,
                },
            };
            push $self->{matches}{objs}{$obj}->@*, $match;
        }
    }

    ## --- PRESERVES
    if (!$match and _isPrsv($self,'NULL','',$FR_prsv))
    {
        $self->{matches}{objs}{prsv} = [] unless exists $self->{matches}{objs}{prsv};
        $match =
        {
            obj => 'prsv',
            val => $line,
            meta =>
            {
                LN  => $.,
            },
        };
        push $self->{matches}{objs}{prsv}->@*, $match;
    }

    ## --- MISS
    elsif (!$match)
    {
        $self->{matches}{miss} = [] unless exists $self->{matches}{miss};
        $match =
        {
            obj => 'miss',
            val => $line,
            meta =>
            {
                LN  => $.,
            },
        };
        push $self->{matches}{miss}->@*, $match;
    }

    ## -- subroutnes
    sub _isPrsv2 #{{{
    {
        my ($self, $obj, $match, $FR_prsv) = @_;
        my $dspt = $self->{dspt};

        if ( defined $self->{prsv} and $obj eq $self->{prsv}{till}[0] )
        {
            $FR_prsv->{F} = 0, if $FR_prsv->{cnt} eq $self->{prsv}{till}[1];
            $FR_prsv->{cnt}++;
        }

        if ( defined $self->{prsv} )
        {
          return $FR_prsv->{F};
        }

        else
        {
            return 0;
        }

    } #}}}

    return $FR_prsv;
}


sub get_matches { #{{{1
    my ( $self, $args, $tmp ) = @_;
    my $dspt = $self->{dspt};

    my $FR_prsv = {
        cnt => 0,
        F   => 1,
    };

    if ($tmp)
    {
        for my $line ($self->{stdout}->@*)
        {
            $FR_prsv = $self->__get_matches($line, $FR_prsv);
        }
    }

    else
    {
        open my $fh, '<:utf8', $self->{paths}{input}
            or die $!;
        {
            while ( my $line = <$fh> )
            {
                $FR_prsv = $self->__get_matches($line, $FR_prsv);
            }
        }
        close $fh ;
    }

    return $self;
}

sub __get_matches3 { #{{{1
    my ( $self, $args ) = @_;
    my $dspt = $self->{dspt};

    open my $fh, '<:utf8', $self->{paths}{input}
        or die $!;
    {
        my $FR_prsv = {
            cnt => 0,
            F   => 1,
        };

        while (my $line = <$fh>) {

            ## --- OBJS
            my $match;
            for my $obj (keys %$dspt) {
                $self->{matches}{objs}{$obj} = [] unless exists $self->{matches}{objs}{$obj};

                my $regex = $dspt->{$obj}{re} // 0;
                if ($regex and $line =~ $regex) {

                    last if _isPrsv($self,$obj,$1,$FR_prsv);

                    $match = {
                        obj => $obj,
                        val => $1,
                        meta => {
                            raw => $line,
                            LN  => $.,
                        },
                    }; push $self->{matches}{objs}{$obj}->@*, $match;
                }
            }
            ## --- PRESERVES
            if (!$match and _isPrsv($self,'NULL','',$FR_prsv)) {
                $self->{matches}{objs}{prsv} = [] unless exists $self->{matches}{objs}{prsv};
                $match = {
                    obj => 'prsv',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $self->{matches}{objs}{prsv}->@*, $match;

            ## --- MISS
            } elsif (!$match) {
                $self->{matches}{miss} = [] unless exists $self->{matches}{miss};
                $match = {
                    obj => 'miss',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $self->{matches}{miss}->@*, $match;
            }
        }
    } close $fh ;

    ## -- subroutnes
    sub _isPrsv { #{{{
        my ($self, $obj, $match, $FR_prsv) = @_;
        my $dspt = $self->{dspt};

        if ( defined $self->{prsv} and $obj eq $self->{prsv}{till}[0] ) {
            $FR_prsv->{F} = 0, if $FR_prsv->{cnt} eq $self->{prsv}{till}[1];
            $FR_prsv->{cnt}++
        }

        if ( defined $self->{prsv} ) {
          return $FR_prsv->{F};
        }
        else {return 0};
    } #}}}
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

sub __divy { #{{{1

    my ( $self, $args ) = @_;

    #initiate hash
    $self->{hash} = $self->gen_config({
        init_hash => {
            val => $self->{name},
            obj => 'lib',
         },
        bp_name => 'objHash',
        exclude_keys => ['circs'],
    });
    #$self->{hash} = {
    #    val => $self->{name},
    #    obj => 'lib',
    #};

    # method variables
    $self->{m}{reffArray} = [$self->{hash}];
    $self->{m}{point}     = [1];
    $self->{m}{pointer}   = [];

    __leveler( $self );

    delete $self->{m};

    return $self;

    sub __leveler { #{{{2
    # iterates in 2 dimensions the order of the dspt

        my ( $self ) = @_;

        ## check existance of OBJ at current point
        my $obj = __getObj( $self );
        return unless $obj;

        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ( $obj ) {

            ## Checking existance of recursionReffArray
            unless ( defined $recursionReffArray ) {
                $recursionReffArray->@* = $self->{m}{reffArray}->@*
            }

            ## divy
            __divyMatches( $self );

            ## Check for CHILDREN
            __changePointLvl( $self->{m}{point}, 1 );
            __leveler( $self );
            __changePointLvl( $self->{m}{point });
            $self->{m}{reffArray}->@* = $recursionReffArray->@*;

            ## Check for SYBLINGS
            if ( scalar $self->{m}{point}->@* ) {
                $self->{m}{point}[-1]++;
            } else { last }

            $obj = __getObj( $self );

        }
        ## Preserves
        if ( __getPointStr( $self ) eq $self->{meta}{dspt}{ord_limit} ) {
            $self->{m}{point}->@* = (-1);
            __divyMatches( $self );
        }

        return $self;
    }


    sub __divyMatches { #{{{2

        my ( $self ) = @_;
        my $obj = __getObj( $self );

        return unless exists $self->{matches}{objs}{$obj};
        my @objMatches = $self->{matches}{objs}{$obj}->@*;

        ## --- REFARRAY LOOP
        my $refArray = $self->{m}{reffArray};
        my $ind = ( scalar @$refArray ) - 1;
        for my $ref ( reverse @$refArray ) {
            my $ref_LN = $ref->{meta}{LN} // 0;

            ## --- MATCHES LOOP
            my $childObjs;
            for my $match ( reverse @objMatches ) {

                if ( $match->{meta}{LN} > $ref_LN ) {
                    my $match = pop @objMatches;
                    __genAttributes( $self, $match );
                    push @$childObjs, $match;

                } else { last }
            }

            ## --- MATCHES TO REF ARRAY
            # todo: while loop that checks neighboring LN, and corrects if
            # necessary
            if ( $childObjs ) {

                @$childObjs = reverse @$childObjs;
                $refArray->[$ind]{childs}{$obj} = $childObjs;

                #add matches to ref array
                splice( @$refArray, $ind, 1, ( $refArray->[$ind], @$childObjs ) );
            }

            $ind--;
        }
    }

    sub __genAttributes { #{{{2

        my ($self, $match) = @_;

        my $obj = $self->__getObj;
        $match->{meta}{raw} = $match->{$obj};

        if (exists $self->{dspt}{$obj}{attr}) {
            my $attrsDspt = $self->{dspt}{$obj}{attr};
            my @ATTRS = sort {
                $attrsDspt->{$a}[1] cmp $attrsDspt->{$b}[1];
                } keys %$attrsDspt;

            for my $attr (@ATTRS) {
                my $success = $match->{val} =~ s/$attrsDspt->{$attr}[0]//;
                if ( $success ) {
                    $match->{attr}{$attr} = $1;

                    if (scalar $attrsDspt->{$attr}->@* >= 3) {
                        $self->__delimitAttr($attr, $match);
                    }
                }
            }
            unless ($match->{val}) {
                $match->{val} = [];
                for my $attr(@ATTRS) {
                    if (exists $match->{attr}{$attr}) {
                        push $match->{val}->@*, $match->{attr}{$attr}->@*;
                    }
                }
            }
        }
    }

    sub __delimitAttr { #{{{2

        ## Attributes
        my ( $self , $attr, $match ) = @_;
        my $objKey   = __getObj( $self );
        my $dspt_attr = $self->{dspt}{$objKey}{attr};

        ## Regex for Attribute Delimiters
        my $delimsRegex = $dspt_attr->{$attr}[3];

        ## Split and Grep Attribute Match-
        $match->{attr}{$attr} = [
            grep { $_ ne '' }
            split( /$delimsRegex/, $match->{attr}{$attr} )
        ];
    }



    sub __changePointLvl { #{{{2

        my $point = shift @_;
        my $op    = shift @_;

        if ($op) { push $point->@*, 1 }
        else     { pop $point->@*, 1 }

        return $point;

    }


    sub __getObj { #{{{2
    # return OBJECT at current point
    # return '0' if OBJECT doesn't exist for CURRENT_POINT!
    # die if POINT_STR generated from CURRENT_POINT is an empty string!

        my ( $self ) = @_;
        my $pntstr = join( '.', $self->{m}{point}->@* )
            or  die "pointStr cannot be an empty string!";
        return $self->{meta}{dspt}{ord_map}{$pntstr} // 0;

    }


    sub __getPointStr { #{{{2
        # return CURRENT POINT
        # return '0' if poinStr is an empty string!

        my $self = shift @_;
        my $pointStr = join('.', $self->{m}{point}->@*);
        return ($pointStr ne '') ? $pointStr
                                 : 0;
    }


}

sub __genWrite { #{{{1
    my ( $self, $args ) = @_;

    $self->{stdout} = [] unless exists $self->{stdout};
    my $dspt = $self->{dspt};
    $self->{m}{prevDepth} = '';
    $self->{m}{prevObj} = 'NULL';

    walk(
        {
            wanted => sub {
                my $item       = $_;
                my $container  = $Data::Walk::container;
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') {
                    my $obj = $item->{obj};

                    my $drsr       = $self->{dspt}{$obj}{drsr};
                    my $depth      = $Data::Walk::depth;
                    my $str        = '';

                    ## --- String: d0, d1 #{{{3
                    if (ref $item->{val} ne 'ARRAY') {
                        $str .= $drsr->{$obj}[0]
                             .  $item->{val}
                             .  $drsr->{$obj}[1];
                    }

                    ## --- Attributes String: d0, d1, d2, d3, d4{{{3
                    my $attrStr = '';
                    # this should be solved in sweep
                    my $attrDspt = $dspt->{$obj}{attr};
                    if ($attrDspt) {
                        for my $attr (
                            sort {
                                $attrDspt->{$a}[1]
                                    cmp
                                $attrDspt->{$b}[1]
                            } keys %$attrDspt
                        ) {

                            ## Check existence of attributes
                            if (exists $item->{attr}{$attr}) {
                                my $attrItem = $item->{attr}{$attr} // '';

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}[2]) {
                                    my @itemPartArray = ();
                                    for my $part (@$attrItem) {
                                        $part = $drsr->{$attr}[2]
                                              . $part
                                              . $drsr->{$attr}[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $drsr->{$attr}[4], @itemPartArray;
                                }

                                $attrStr .= $drsr->{$attr}[0]
                                         .  $attrItem
                                         .  $drsr->{$attr}[1];

                            }
                        }
                    }

                    ## --- Line Striping: d5,d6 #{{{3
                    my $F_empty;
                    if (exists $drsr->{$obj} and exists $drsr->{$obj}[5] and $self->{m}{prevDepth}) {

                        my $prevObj   = $self->{m}{prevObj};
                        my $prevDepth = $self->{m}{prevDepth};

                        my $ref = ref $drsr->{$obj}[5];
                        my $tgtObjs = ($ref eq 'HASH') ?$drsr->{$obj}[5]
                                                       :0;

                        ## strip lines only after target object
                        if ($tgtObjs && exists $tgtObjs->{$prevObj}) {
                            my $cnt = $tgtObjs->{$prevObj};

                            # descending lvl
                            if ($prevDepth < $depth) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                                $F_empty = 1 if $str eq '';
                            }

                            # ascending lvl
                            elsif ($prevDepth > $depth) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                            }

                            # maintaining lvl
                            elsif ($prevDepth == $depth) {

                                # Preserve
                                if ($obj eq 'prsv') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }

                                # Post Preserve
                                elsif ($prevObj eq 'prsv') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }
                            }
                        }

                        ## strip lines after all objects
                        # descending lvl
                        elsif (!$tgtObjs and $prevDepth < $depth) {
                            my $cnt = $drsr->{$obj}[5];
                            $str =~ s/.*\n// for (1 .. $cnt);
                        }

                    }

                    ## --- String Concatenation {{{3
                    $str = ($str) ?$str . $attrStr
                                  :$attrStr;
                    chomp $str if $obj eq 'prsv';

                    #}}}
                    unless ($F_empty) { push $self->{stdout}->@*, $str if $obj ne 'lib'}
                    $self->{m}{prevDepth} = $depth;
                    $self->{m}{prevObj}   = $obj;
                }
            },
            preprocess => sub {
                my $type = $Data::Walk::type;
                my @children = @_;

                if ($type eq 'HASH') {
                    my @values   = map {$children[$_]} grep {$_ & 1} (0..$#children);
                    my @keys = map {$children[$_]} grep {!($_ & 1)} (0..$#children);
                    my @var    = map {[$keys[$_],$values[$_]]} (0..$#keys);
                    @children =
                        map {@$_}
                        sort {
                            if (scalar (split /\./, $dspt->{$b->[0]}{order}) != scalar (split /\./,$dspt->{$a->[0]}{order})) {
                                join '', $dspt->{$b->[0]}{order} cmp join '', $dspt->{$a->[0]}{order}
                            } else {
                                join '', $dspt->{$a->[0]}{order} cmp join '', $dspt->{$b->[0]}{order}
                            }
                        }
                        @var;
                }
                return @children;
            },
        },
        $self->{hash}
    );
    delete $self->{m};
    return $self;
}

sub __validate { #{{{1

    my ( $self, $type ) = @_;

    if ($type eq 'txt')
    {
        #$self->{tmp}{matches} = self->__gen_matches ($self->{stdout})
        #self->{matches};
    }

    elsif ( $type eq 'json' )
    {
        $self->rm_reff;
        $self->see('hash');
        $self->__sweep(['reffs']);
        #do thing all over again
    }

    elsif ( $type eq 'change' )
    {
        #$self->{tmp}{matches} = self->__gen_matches ($self->{stdout})
        #self->{matches};

        $self->rm_reff;
        $self->see('hash');
        $self->__sweep(['reffs']);
        $self->see('hash');
    }


    ##INITS
    # txt -> json -> txt
    # json -> txt -> json
    # +
    # -

    #CHANGE
    # json1 -> txt1 -> txt1* -> json2 -> txt2
    # see if the txt files are the same
    # flatten jsons and find unique btw them
    # +
    # -

}

sub __longest { #{{{1
    my $max = -1;
    my $max_ref;
    for (@_) {
        if (length > $max) {  # no temp variable, length() twice is faster
            $max = length;
            $max_ref = \$_;   # avoid any copying
        }
    }
    $$max_ref
}
#}}}

1;
