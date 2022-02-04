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

use File::Basename;
use JSON::XS;
use Storable qw(dclone);
use Carp qw(croak carp);
use Cwd;

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
use Hash::Flatten qw(:all);

sub get_sum #{{{1
{ # output a summary hash for data dumping.

    my ( $self, $args ) = @_;

    my $copy = dclone $self;
    delete $copy->{tmp};

    # DSPT
    if ( exists $copy->{dspt} )
    {
        my $dspt = $copy->{dspt};

        for my $obj (keys %$dspt)
        {

            # Creaated Value String for each key in dspt obj.
            my $str = '';
            for my $key (sort keys $dspt->{$obj}->%*)
            {

                my $value = $dspt->{$obj}{$key};
                my $ref   = ref $value;

                if ( $ref eq 'HASH' )
                {
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
    if ( exists $copy->{matches} )
    {
        my $matches = $copy->{matches};
        my $total = 0;

        if ( exists $matches->{miss} )
        {
            $matches->{miss} = scalar $matches->{miss}->@*;
            $total += $matches->{miss};
        }

        $matches->{obj_count} = scalar keys $matches->{objs}->%*;
        for (keys $matches->{objs}->%*)
        {
            $matches->{objs}{$_} = scalar $matches->{objs}{$_}->@*;
            $total += $matches->{objs}{$_};
        }
        $matches->{total} = $total;
        $copy->{matches} = $matches;
    }

    # META
    if (exists $copy->{meta})
    {
        my $meta = $copy->{meta};
        $meta->{dspt}{ord_map} = scalar keys $meta->{dspt}{ord_map}->%*;
        $copy->{meta} = $meta;
    }

    # META
    if (exists $copy->{circ})
    {
        $copy->{circ} = scalar $copy->{circ}->@*;
    }

    # STDOUT
    if (exists $copy->{stdout})
    {
        $copy->{stdout} = scalar $copy->{stdout}->@*;
    }

    # HASH
    $copy->{hash} = exists $copy->{hash} ?1 :0;



    return $copy;
}

sub gen_config #{{{1
{
    #generates complex configurations
    my ( $self, $args ) = @_;

    # Convert '$args' into type 'HASH', if not already
    unless ( UNIVERSAL::isa($args, 'HASH') )
    {
        $args =
        {
            bp_name        => $_[1],
            init_hash      => $_[2],
            excluded_keys  => $_[3],
        };
    }

    # Name and Init
    my $bp_name   = $args->{bp_name};
    my $init_hash = $args->{init_hash};

    # EXL KEYS
    my @EXL_KEYS  = ();
    if (exists $args->{exclude_keys})
    {
        @EXL_KEYS = $args->{exclude_keys}->@*;
    }

    # get boilerplate
    my $bp = dclone $self->__gen_bp($bp_name) // die;

    # genconfig
    my $config = populate($self, $bp, {});

    # Use init hash
    if ($init_hash)
    {
        my $flat_mask  = flatten $init_hash;
        my $flat_config = flatten $config;

        $flat_config = $self->__mask($flat_config, $flat_mask);

        for my $key (@EXL_KEYS)
        {
            delete $flat_config->{$key};
        }
        $config = unflatten $flat_config;

    }

    # RETURN
    return $config;

    # subroutines
    sub __mask #{{{
    {
        my ($self, $flat_config, $flat_mask) = @_;

        #for my $key ( keys %$flat_config )
        for my $key ( keys %$flat_mask )
        {
            my $str = $key;
            my $pat;
            my $delim;
            my $end;
            if ( $str =~ s/((?:\\\:|\\\.|[_[:alnum:]])+)((?:\.|:)*)// )
            {
                $pat = $1;
                $delim = $2 // '';
                $end = $delim ? '' : '$' ;
            }
            else { die }

            #my @KEYS = grep {$_ =~ /^\Q$pat\E$end/} keys %$flat_config;
            my @KEYS = grep {$_ =~ /^\Q$pat\E($|:|\.)/ } keys %$flat_config;
            my @CLN  = grep {$_ !~ m/^\Q$pat$delim\E$end/ } @KEYS;

            while ( scalar @KEYS > 1 || scalar @CLN )
            {
                if ( $str =~ s/((?:\\\:|\\\.|[_[:alnum:]])+)((?:\.|:)*)// )
                {
                    $pat  .= $delim.$1;
                    $delim = $2 // '';
                    $end = $delim ? '' : '$' ;

                }

                #@KEYS = grep {$_ =~ /\Q$pat\E$end/ } keys %$flat_config;
                @KEYS = grep {$_ =~ /^\Q$pat\E($|:|\.)/ } keys %$flat_config;
                @CLN  = grep {$_ !~ m/^\Q$pat$delim\E$end/ } @KEYS;
                delete $flat_config->{$_} for @CLN;
                #print "$pat ($delim) $end\n";
                #print( "    KEYS: " .(join ' ', @KEYS) , "\n");
                #print( "     CLN:" .(join ' ', @CLN) , "\n");
            }

            #delete $flat_mask->{$_} for @CLN;
            $flat_config->{$key} = $flat_mask->{$key};

        }
        return $flat_config;
    }

    sub populate #{{{
    {
        my ( $self, $bp, $config, $OBJ ) = @_;

        my $type    = delete $bp->{type} // return $config;
        my $fill    = delete $bp->{fill} // die;
        my $general = delete $bp->{general};
        my $member  = delete $bp->{member};
        my @RemKeys = keys %$bp;
        $config  = dclone $general if $general;


        # MEMBER
        if ( %$member )
        {

            # KEYS
            my @KEYS;
            if ($OBJ)
            {
                @KEYS = keys $self->{dspt}{$OBJ}{attrs}->%*;
                push @KEYS, $OBJ if $fill->[1];
            }
            else
            {
                @KEYS = keys $self->{dspt}->%*;
            }

            # Recurse with keys
            for my $key ( @KEYS )
            {
                $config->{$key} = populate
                (
                    $self,
                    dclone $member,
                    $config->{$key},
                    $key,
                );
            }
        }

        # REMAINING KEYS
        for my $key ( @RemKeys )
        {
            $config->{$key} = populate
            (
                $self,
                dclone $bp->{$key},
                $config->{$key},
                $OBJ,
            );
        }

        # GENERAL
        if (ref $config eq 'HASH')
        {
            my $flat_mask  = flatten(dclone $general) if $general;
            my $flat_config = flatten $config;

            $flat_config = $self->__mask($flat_config, $flat_mask);
            #for my $key (keys %$flatConfig)
            #{
            #    # do not fill in remainder keys
            #    if ( (grep {$key eq $_} @RemKeys)[0] ) { next }
            #    $flatConfig2->{$key} = $flatConfig->{$key};
            #}

            return unflatten $flat_config;
        }

        return $config;
    } #}}}

}

sub write #{{{1
{
    my ( $self, $args ) = @_;
    my $writeArray = $self->{stdout};

    my $dir = $self->{paths}{output}
    . $self->{paths}{dir}
    . '/output/';

    mkdir($dir) unless(-d $dir);

    open my $fh, '>:utf8', $dir . $self->{name} . '.txt' or die $!;
        for (@$writeArray)
        {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
    close $fh;
}

sub see #{{{1
{
    my ($self, $key) = @_;
    return $self->__see(
        $self->{$key},
        'lib',
        [],
    );

}

sub rm_reff #{{{1
{

    my ( $self, $args ) = @_;

    my $CIRCS = $self->{circ} // return;

    for my $circ ( @$CIRCS )
    {

        my $ref = $circ->{'.'};

        if ( UNIVERSAL::isa($ref,'HASH') )
        {
            delete $ref->{circ};
        }
        elsif ( UNIVERSAL::isa($ref,'ARRAY') )
        {
            $ref->[0] = {};
        }
        else
        {
            die
        }
    }
    $self->{circ} = [];
}

sub get_matches #{{{1
{
    my ( $self, $tmp ) = @_;
    my $dspt = $self->{dspt};

    my $FR_prsv =
    {
        cnt => 0,
        F   => 1,
    };

    if ($tmp)
    {
        $self->{tmp} = {};
        $self->{tmp}{matches} = {};
        for my $line ($self->{stdout}->@*)
        {
            $FR_prsv = $self->__get_matches($line, $FR_prsv, $tmp);
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

sub new #{{{1
{
    my ($class, $args) = @_;

    # Convert '$args' into type 'HASH', if not already
    unless ( UNIVERSAL::isa($args, 'HASH') )
    {
        $args =
        {
            input => $_[1],
            dspt  => $_[2],
            drsr  => $_[3],
            mask  => $_[4],
            prsv  => $_[5],
        };
        delete $args->{$_} for grep {!(defined $args->{$_})} keys %$args;
    }

    # Create Object
    my $self = {};
    bless $self, $class;

    # check if cwd has .ohm directory

    # init and form circular hash check
    $self->__init( $args );

    return $self;
}

sub __init #{{{1
{
    my ( $self, $args ) = @_;
    my $class = ref $self;

    $self->{cwd} = getcwd;
    my $isBase = $self->__checkDir();
    my $db = $self->__importJson('./.ohm/db/self.json');



    #%--------PATHS--------#
    use Cwd 'abs_path';
    my $paths = {};

    # CWD
    $paths->{cwd} = getcwd;

    # TEST
    my $args2 = do
    {
        open my $fh, '<:utf8', $self->{cwd}.'/.ohm/db/self.json';
        local $/;
        decode_json(<$fh>);
    };
    delete $args2->{paths}{cwd};
    for my $key (keys $args2->{paths}->%*)
    {
        $args2->{$key} = $args2->{paths}{$key};
    }
    delete $args2->{paths};
    my $flat_mask  = flatten $args;
    my $flat_config = flatten $args2;
    $flat_config = $self->__mask($flat_config, $flat_mask);
    $args = unflatten $flat_config;

    # INPUT
    my $paths_input = delete $args->{input} || die "No path to input provided";
    __checkChgArgs( $paths_input, '' , 'string scalar' );
    if ($paths_input) { $paths->{input} = abs_path $paths_input }

    # DSPT - DISPATCH TABLE
    my $paths_dspt = delete $args->{dspt} || die "No path to dspt provided";
    __checkChgArgs( $paths_dspt, '' , 'string scalar' );
    if ($paths_dspt) { $paths->{dspt} = abs_path $paths_dspt }

    # OUTPUT
    my $paths_output = delete $args->{output} // '';
    __checkChgArgs( $paths_output,'','string scalar' );
    if ($paths_output) { $paths->{output} = abs_path $paths_output }

    # DIR
    my $paths_dir = delete $args->{dir} // '';
    __checkChgArgs( $paths_dir,'','string scalar' );
    if ($paths_dir) { $paths->{dir} = $paths_dir }

    # DRSR - DRESSER
    my $paths_drsr = delete $args->{drsr} // '';
    __checkChgArgs( $paths_drsr, '' , 'string scalar' );
    if ($paths_drsr) { $paths->{drsr} = abs_path $paths_drsr }

    # MASK
    my $paths_mask = delete $args->{mask} // '';
    __checkChgArgs( $paths_mask, '' , 'string scalar' );
    if ($paths_mask) { $paths->{mask} = abs_path $paths_mask }

    # generate path config
    $self->{paths} = $self->gen_config
    ({
        init_hash => $paths,
        bp_name => 'paths',
    });


    #%--------OTHER ARGS--------#
    # NAME
    my $name = delete $args->{name};
    unless ( defined $name )
    {
        my $fname = basename( $self->{paths}{input} );
        $name = $fname =~ s/\..*$//r;
    }
    __checkChgArgs( $name,'','string scalar' );
    $self->{name} = $name;

    # PRSV - PRESERVES
    my $prsv = delete $args->{prsv};
    $self->{prsv} = $prsv;

    # PARAMS - PRAMEMTERS
    my $params = delete $args->{params};
    if ( defined $params )
    {
        __checkChgArgs( $params, 'HASH', 'hash' )
    }
    $self->{params} = $self->gen_config
    ({
        init_hash => $params,
        bp_name => 'params',
    });


    #%-------- CHECK --------#
    # KEYS
    if ( my $remaining = join ', ', keys %$args )
    {
        croak( "Unknown keys to $class\::new: $remaining" );
    }


    #%-------- DSPT --------#
    $self->__gen_dspt();


    #%-------- Check Matches --------#
    $self->__check_matches();


    return $self;
}

sub __importJson
{
    my ($self, $path) = @_;
    my $json = do
    {
        open my $fh, '<:utf8', $path;
        local $/;
        decode_json(<$fh>);
    };
    return $json;
}

sub __gen_dspt #{{{1
{
    my ( $self, $args ) = @_;

    ## --- IMPORT DSPT FILE
    my $dspt = do
    {
        open my $fh, '<:utf8', $self->{paths}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    # generate dspt config
    $dspt = $self->gen_config
    ({
        init_hash => $dspt,
        bp_name => 'dspt',
    });

    # assign DSPT
    $self->{dspt} = $dspt;


    ## --- GENERATE LINE AND ATTR REGEXS FOR DSPT
    for my $obj (keys %$dspt)
    {

        my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT)
        {

            #line regexes
            if ( $key eq 're' )
            {
                $objDSPT->{cre} = qr/$objDSPT->{re}/
            }

            #attribute regexes
            if ( $key eq 'attrs' )
            {

                my $dspt_attr = $objDSPT->{attrs};
                for my $attr (keys %$dspt_attr)
                {

                    $dspt_attr->{$attr}{cre} = qr/$dspt_attr->{$attr}{re}/;
                    if (defined $dspt_attr->{$attr}{delims})
                    {

                        my $delims = join '', $dspt_attr->{$attr}{delims}->@*;
                        $dspt_attr->{$attr}{cdelims} = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
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
        map
        {
            exists $dspt->{$_}{order}
                and
            $dspt->{$_}{order}
        }
        keys %{$dspt};
    my %dupes;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $dupes{$_}++ }


    ## --- META
    # max
    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $self->{meta}{dspt}{ord_max} =
    (
        sort
        {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        }
        @orders
    )[0];

    # limit
    my @pntstr = split /\./, $self->{meta}{dspt}{ord_max};
    $pntstr[$#pntstr]++;
    $self->{meta}{dspt}{ord_limit} = join '.', @pntstr;

    # ordMap
    $self->{meta}{dspt}{ord_map}->%* =
        map  { $dspt->{$_}{order} => $_ }
        grep { exists $dspt->{$_}{order} }
        keys %$dspt;

    # sortMap
    my @sorted_ords  =
        sort
        {
            ( $a eq 'lib' ?-1 :0 )
                ||
            ( $b eq 'lib' ?1 :0 )
                ||
            scalar (split /\./, $dspt->{$a}{order}) <=> scalar (split /\./, $dspt->{$b}{order})
                ||
            ($dspt->{$a}{order} =~ m/-*\d+$/g)[0] <=> ($dspt->{$b}{order} =~ m/-*\d+$/g)[0]
        }
        keys %$dspt;
    $self->{meta}{dspt}{ord_sort_map} = [@sorted_ords];

    # sortMap2
    my @sorted_ords2  =
        sort
        {
            ( $a eq 'lib' ?1 :0 )
                ||
            ( $b eq 'lib' ?-1 :0 )
                ||
            scalar (split /\./, $dspt->{$b}{order}) <=> scalar (split /\./, $dspt->{$a}{order})
                ||
            ($dspt->{$a}{order} =~ m/-*\d+$/g)[0] <=> ($dspt->{$b}{order} =~ m/-*\d+$/g)[0]
        }
        keys %$dspt;
    $self->{meta}{dspt}{ord_sort_map2} = [@sorted_ords2];


    ## --- DRSR
    my $drsr = do
    {
        #open my $fh, '<:utf8', $self->{paths}{drsr}
        open my $fh, '<', $self->{paths}{drsr}
            or die;
        local $/;
        decode_json(<$fh>);
    };

    # generate drsr config
    $drsr = $self->gen_config
    ({
        init_hash => $drsr,
        bp_name => 'drsr',
    });

    for my $obj (keys %$drsr)
    {
        $dspt->{$obj} // die;
        $dspt->{$obj}{drsr} = $drsr->{$obj};
        for my $attr (grep {$_ ne $obj} keys $drsr->{$obj}->%*)
        {
            $dspt->{$obj}{attrs}{$attr} // die "$attr for $self->{name}" ;

        }
    }


    ## --- MASK
    my $mask = do
    {
        open my $fh, '<:utf8', $self->{paths}{mask}
            or die;
        local $/;
        decode_json(<$fh>);
    };

    # generate mask config
    $mask = $self->gen_config
    ({
        init_hash => $mask,
        bp_name => 'mask',
    });

    for my $obj (keys %$mask)
    {
        $dspt->{$obj} // die;
        $dspt->{$obj}{mask} = $mask->{$obj};
    }


    ## --- RETURN
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
        $self->get_matches;
        $self->__divy();
        $self->__sweep(['reffs']);
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
        $self->__sweep(['reffs','matches']);
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

sub __get_matches #{{{1
{
    my ( $self, $line, $FR_prsv, $tmp ) = @_;

    my $tgt = $tmp ? $self->{tmp} : $self;
    my $dspt = $self->{dspt};


    ## --- OBJS
    my $match;
    for my $obj (keys %$dspt)
    {
        $tgt->{matches}{objs}{$obj} = [] unless exists $tgt->{matches}{objs}{$obj};

        my $regex = $dspt->{$obj}{cre} // 0;
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
            $self->_checks($match);
            push $tgt->{matches}{objs}{$obj}->@*, $match;
        }
    }

    ## --- PRESERVES
    if ( !$match and _isPrsv( $self, 'NULL', '', $FR_prsv ) )
    {
        $tgt->{matches}{objs}{prsv} = [] unless exists $tgt->{matches}{objs}{prsv};
        $match =
        {
            obj => 'prsv',
            val => $line,
            meta =>
            {
                raw => $line,
                LN  => $.,
            },
        };
        $self->_checks($match,'prsv');
        push $tgt->{matches}{objs}{prsv}->@*, $match;
    }

    ## --- MISS
    elsif ( !$match )
    {
        $tgt->{matches}{miss} = [] unless exists $tgt->{matches}{miss};
        $match =
        {
            obj => 'miss',
            val => $line,
            meta =>
            {
                raw => $line,
                LN  => $.,
            },
        };
        $self->_checks( $match,'miss' );
        push $tgt->{matches}{miss}->@*, $match;
    }

    ## -- subroutnes
    sub _isPrsv #{{{2
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

    }
    sub _checks #{{{2
    {
        my ($self, $match, $type);
        if ( $type and $type eq 'miss' )
        {
            if ( $match->{line} =~ /\w/ )
            {
            }
        }
    }#}}}
    return $FR_prsv;
}


sub __divy #{{{1
{

    my ( $self, $args ) = @_;

    #initiate hash
    $self->{hash} = $self->gen_config
    (
        {
            init_hash =>
            {
                val => $self->{name},
                obj => 'lib',
            },
            bp_name => 'objHash',
            exclude_keys => ['circs'],
        }
    );

    # method variables
    $self->{m}{reffArray} = [$self->{hash}];
    $self->{m}{point}     = [1];
    $self->{m}{pointer}   = [];

    __leveler( $self );

    delete $self->{m};

    return $self;

    sub __leveler #{{{2
    {
    # iterates in 2 dimensions the order of the dspt

        my ( $self ) = @_;

        ## check existance of OBJ at current point
        my $obj = __getObj( $self );
        return unless $obj;

        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ( $obj )
        {

            ## Checking existance of recursionReffArray
            unless ( defined $recursionReffArray )
            {
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
            if ( scalar $self->{m}{point}->@* )
            {
                $self->{m}{point}[-1]++;
            }
            else
            {
                last
            }

            $obj = __getObj( $self );

        }
        ## Preserves
        if ( __getPointStr( $self ) eq $self->{meta}{dspt}{ord_limit} )
        {
            $self->{m}{point}->@* = (-1);
            __divyMatches( $self );
        }

        return $self;
    }


    sub __divyMatches #{{{2
    {

        my ( $self ) = @_;
        my $obj = __getObj( $self );

        return unless exists $self->{matches}{objs}{$obj};
        my @objMatches = $self->{matches}{objs}{$obj}->@*;

        ## --- REFARRAY LOOP
        my $refArray = $self->{m}{reffArray};
        my $ind = ( scalar @$refArray ) - 1;
        for my $ref ( reverse @$refArray )
        {
            my $ref_LN = $ref->{meta}{LN} // 0;

            ## --- MATCHES LOOP
            my $childObjs;
            for my $match ( reverse @objMatches )
            {

                if ( $match->{meta}{LN} > $ref_LN )
                {
                    my $match = pop @objMatches;
                    __genAttributes( $self, $match );
                    push @$childObjs, $match;

                }
                else
                {
                    last
                }
            }

            ## --- MATCHES TO REF ARRAY
            # todo: while loop that checks neighboring LN, and corrects if
            # necessary
            if ( $childObjs )
            {

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

        if (exists $self->{dspt}{$obj}{attrs})
        {
            my $attrsDspt = $self->{dspt}{$obj}{attrs};
            my @ATTRS =
            sort
            {
                $attrsDspt->{$a}{order} cmp $attrsDspt->{$b}{order};
            }
            keys %$attrsDspt;

            for my $attr (@ATTRS)
            {
                my $success = $match->{val} =~ s/$attrsDspt->{$attr}{cre}//;
                if ( $success )
                {
                    $match->{attrs}{$attr} = $1;

                    if ( defined $attrsDspt->{$attr}{delims} )
                    {
                        $self->__delimitAttr($attr, $match);
                    }
                }
            }
            unless ($match->{val})
            {
                $match->{val} = [];
                for my $attr(@ATTRS)
                {
                    if (exists $match->{attrs}{$attr})
                    {
                        push $match->{val}->@*, $match->{attrs}{$attr}->@*;
                    }
                }
            }
        }
    }

    sub __delimitAttr #{{{2
    {

        ## Attributes
        my ( $self , $attr, $match ) = @_;
        my $objKey   = __getObj( $self );
        my $dspt_attr = $self->{dspt}{$objKey}{attrs};

        ## Regex for Attribute Delimiters
        my $delimsRegex = $dspt_attr->{$attr}{cdelims};

        ## Split and Grep Attribute Match-
        $match->{attrs}{$attr} =
        [
            grep { $_ ne '' }
            split( /$delimsRegex/, $match->{attrs}{$attr} )
        ];
    }



    sub __changePointLvl #{{{2
    {

        my $point = shift @_;
        my $op    = shift @_;

        if ($op) { push $point->@*, 1 }
        else     { pop $point->@*, 1 }

        return $point;

    }


    sub __getObj #{{{2
    {
    # return OBJECT at current point
    # return '0' if OBJECT doesn't exist for CURRENT_POINT!
    # die if POINT_STR generated from CURRENT_POINT is an empty string!

        my ( $self ) = @_;
        my $pntstr = join( '.', $self->{m}{point}->@* )
            or  die "pointStr cannot be an empty string!";
        return $self->{meta}{dspt}{ord_map}{$pntstr} // 0;

    }


    sub __getPointStr #{{{2
    {
        # return CURRENT POINT
        # return '0' if poinStr is an empty string!

        my $self = shift @_;
        my $pointStr = join('.', $self->{m}{point}->@*);
        return ($pointStr ne '') ? $pointStr
                                 : 0;
    }


}

sub __sweep #{{{1
{

    my ( $self, $subs ) = @_;

    my $sub_list =
    {
        reffs   => \&gen_reffs,
        matches => \&gen_matches,
        plhd    => \&place_holder,
    };

    $self->{m} = {};

    walk
    (
        {
            wanted => sub
            {
                for my $name (@$subs)
                {
                    $sub_list->{$name}->($self);
                }
            },
        },
        $self->{hash} // die " No hash has been loaded for object '$self->{name}'"
    );

    delete $self->{m};
    return $self;

    sub gen_reffs #{{{2
    {
    # inherits from Data::Walk module

        my ( $self, $args ) = @_;

        $self->{circ} = [] unless exists $self->{circ};


        if ( UNIVERSAL::isa($_, 'HASH') )
        {
            my $objHash = $_;
            my $objArr  = $Data::Walk::container;
            my $obj = $objHash->{obj} // 'NULL'; # need to have NULL be
                                              # error or something

            $objHash->{circ}{'.'}   = $objHash;
            $objHash->{circ}{'..'}  = $objArr // 'NULL';
            push $self->{circ}->@*, $objHash->{circ};

        }

        elsif ( UNIVERSAL::isa($_, 'ARRAY') )
        {
            my $objArr = $_;
            my $ParentHash  = $Data::Walk::container;
            unshift @$objArr,
            {
                '.'   => $_,
                '..'  => $ParentHash // 'NULL',
            };
            push $self->{circ}->@*, $objArr->[0];
        }
    }

    sub gen_matches #{{{2
    {
    # inherits from Data::Walk module

        my ( $self, $args ) = @_;

        unless ( exists $self->{matches} )
        {
            $self->{matches} =
            {
                objs => {},
                miss => [{a => 2}]
            }
        }

        if ( UNIVERSAL::isa($_, 'HASH') )
        {
            my $objHash = $_;
            my $obj = $objHash->{obj};
            push $self->{matches}{objs}{ $obj }->@*, $objHash;
        }

    }

    sub place_holder #{{{2
    {
    # inherits from Data::Walk module

        my $self = shift @_;

        if ( UNIVERSAL::isa($_, 'HASH') )
        {

            my $objHash = $_;
            my $obj     = $objHash->{obj};
            my $objMask = $self->{dspt}{$obj}{mask} // return 1;

            if ( $objMask->{place_holder}{enable} )
            {

                for my $child ( $objMask->{place_holder}{childs}->@* )
                {

                    unless ( exists $objHash->{childs}{$child} )
                    {

                        my $childHash = $objHash->{childs}{$child}[0] = {};
                        %$childHash =
                        (
                            obj => $child,
                            val => [],
                            meta => undef,
                        );

                        # attributes
                        my $childDspt = $self->{dspt}{$child};
                        if ( defined $childDspt->{attrs} )
                        {
                            for my $attr ( keys $childDspt->{attrs}->%* )
                            {
                                if (exists $childDspt->{attrs}{$attr}{delims})
                                {
                                    $childHash->{attrs}{$attr} = [];
                                }
                                else
                                {
                                    $childHash->{attrs}{$attr} = '';
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

sub __genWrite #{{{1
{
    my ( $self, $args ) = @_;

    $self->{stdout} = [] unless exists $self->{stdout};
    my $dspt = $self->{dspt};
    $self->{m}{prevDepth} = '';
    $self->{m}{prevObj} = 'NULL';

    walk
    (
        {
            wanted => sub
            {
                my $item       = $_;
                my $container  = $Data::Walk::container;
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') {

                    my $obj = $item->{obj};

                    my $drsr       = $self->{dspt}{$obj}{drsr};
                    my $depth      = $Data::Walk::depth;
                    my $str        = '';

                    ## --- String: d0, d1
                    if (ref $item->{val} ne 'ARRAY')
                    {
                        $str .= $drsr->{$obj}[0]
                             .  $item->{val}
                             .  $drsr->{$obj}[1];
                    }

                    ## --- Attributes String: d0, d1, d2, d3, d4{{{3
                    my $attrStr = '';
                    my $attrDspt = $dspt->{$obj}{attrs};

                    if ($attrDspt)
                    {
                        for my $attr
                        (
                            sort {
                                $attrDspt->{$a}{order}
                                    cmp
                                $attrDspt->{$b}{order}
                            } keys %$attrDspt
                        )
                        {
                            if ( exists $item->{attrs}{$attr} )
                            {
                                my $attrItem = $item->{attrs}{$attr} // '';

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}{delims})
                                {
                                    my @itemPartArray = ();
                                    for my $part (@$attrItem)
                                    {
                                        unless (defined $drsr->{$attr}[2] || defined $drsr->{$attr}[3]) { die " obj '$obj' does not have delims drsrs" }
                                        $part = $drsr->{$attr}[2]
                                              . $part
                                              . $drsr->{$attr}[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $drsr->{$attr}[4], @itemPartArray;
                                }

                                #if (!$attrItem || $drsr->{$attr}[1] || $drsr->{$attr}[0]) {
                                #    die;
                                #}

                                $attrStr .= $drsr->{$attr}[0]
                                         .  $attrItem
                                         .  $drsr->{$attr}[1];

                            }
                        }
                    }

                    ## --- Line Striping: d5,d6 #{{{3
                    my $F_empty;
                    if (exists $drsr->{$obj} and exists $drsr->{$obj}[5] and $self->{m}{prevDepth})
                    {

                        my $prevObj   = $self->{m}{prevObj};
                        my $prevDepth = $self->{m}{prevDepth};

                        my $ref = ref $drsr->{$obj}[5];
                        my $tgtObjs = ($ref eq 'HASH') ?$drsr->{$obj}[5]
                                                       :0;

                        ## strip lines only after target object
                        if ($tgtObjs && exists $tgtObjs->{$prevObj})
                        {
                            my $cnt = $tgtObjs->{$prevObj};

                            # descending lvl
                            if ($prevDepth < $depth)
                            {
                                $str =~ s/.*\n// for (1 .. $cnt);
                                $F_empty = 1 if $str eq '';
                            }

                            # ascending lvl
                            elsif ($prevDepth > $depth)
                            {
                                $str =~ s/.*\n// for (1 .. $cnt);
                            }

                            # maintaining lvl
                            elsif ($prevDepth == $depth)
                            {

                                # Preserve
                                if ($obj eq 'prsv')
                                {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }

                                # Post Preserve
                                elsif ($prevObj eq 'prsv')
                                {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }
                            }
                        }

                        ## strip lines after all objects
                        # descending lvl
                        elsif (!$tgtObjs and $prevDepth < $depth)
                        {
                            my $cnt = $drsr->{$obj}[5];
                            $str =~ s/.*\n// for (1 .. $cnt);
                        }

                    }

                    ## --- String Concatenation {{{3
                    $str = ($str) ? $str . $attrStr
                                  : $attrStr;
                    chomp $str if $obj eq 'prsv';

                    #}}}
                    unless ($F_empty)
                    {
                        if ($obj eq 'prsv') {
                            push $self->{stdout}->@*, $str if $obj ne 'lib'
                        }
                        else {
                            push $self->{stdout}->@*, split/\n/, $str if $obj ne 'lib'
                        }
                    }
                    $self->{m}{prevDepth} = $depth;
                    $self->{m}{prevObj}   = $obj;
                }
            },
            preprocess => sub
            {
                my $type = $Data::Walk::type;
                my @children = @_;

                if ($type eq 'HASH')
                {
                    my @values = map { $children[$_] } grep { $_ & 1 } (0..$#children);
                    my @keys   = map { $children[$_] } grep { !($_ & 1) } (0..$#children);
                    my @var    = map { [$keys[$_],$values[$_]] } (0..$#keys);
                    @children =
                        map {@$_}
                        sort
                        {
                            if (scalar (split /\./, $dspt->{$b->[0]}{order}) != scalar (split /\./,$dspt->{$a->[0]}{order}))
                            {
                                join '', $dspt->{$b->[0]}{order} cmp join '', $dspt->{$a->[0]}{order}
                            }
                            else
                            {
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


sub __validate #{{{1
{
    my ( $self, $type ) = @_;

    if ($type eq 'txt')
    {
        my $CHECKS;

        # === TXT DIFF === #{{{

        # OUTPUT FILES
        my $tmpFile = $self->{paths}{output}
        . $self->{paths}{dir}
        . '/output/'
        . $self->{name}
        . '.txt';
        my $file = $self->{paths}{input};

        # TMP DIR
        my $tmpdir = $self->{paths}{output}
        . $self->{paths}{dir}
        . '/tmp/';
        mkdir($tmpdir) unless(-d $tmpdir);

        # CHECKS
        $CHECKS->{txtCmp}{fp}  = $tmpdir . 'diff.txt';
        $CHECKS->{txtCmp}{out} = [`diff $file $tmpFile`];
        #}}}


        # === MATCHES === {{{

        # MATCHES: reformat
        $self->{meta}{tmp}{matches} = {};
        $self->get_matches(1);
        my @matches = map
        {
            [
                $_,
                $self->{matches}{objs}{$_},
                $self->{tmp}{matches}{objs}{$_},
            ]
        } keys $self->{matches}{objs}->%*;

        my $miss_matches = [
                'miss',
                $self->{matches}{miss},
                $self->{tmp}{matches}{miss},
        ];
        push @matches, $miss_matches;

        # MATCHES: compare
        my @OUT;
        for my $part (@matches)
        {
            my ( $obj, $val, $val2 ) = @$part;
            $val = $val // [1];
            $val2 = $val2 // [1];
            if (scalar @$val != scalar @$val2 )
            {
                push @OUT, $obj .
                ':' .
                (scalar @$val) .
                ':' .
                (scalar @$val2) .
                "\n";
            }
        }

        # Matches: checks
        $CHECKS->{matchCmp}{fp}  = $tmpdir.'cnt.txt';
        $CHECKS->{matchCmp}{out} = [@OUT];
        #}}}


        # === HASHES === {{{
        if ( $self->{paths}{input} eq $self->{cwd}.'/.ohm/db/output.txt' )
        {
            # Get HASHES
            my $oldHash = do
            {
                open my $fh, '<', $self->{cwd}.'/.ohm/db/hash.json';
                local $/;
                decode_json(<$fh>);
            };
            $self->rm_reff;
            my $newHash = dclone $self->{hash};

            ## Boolean Data Compare
            #use Data::Compare;
            #my $c = Data::Compare->new($oldHash, $newHash);
            #print 'structures of $newHash and $oldHash are ',
            #$c->Cmp ? "" : "not ", "identical.\n";

            ## Diff Data Compare
            my $newFlat = $self->__see($newHash,'lib',[]);
            my $oldFlat = $self->__see($oldHash,'lib',[]);
            my $newFlat2 = [];
            my $oldFlat2 = [];
            for my $aref ( [$oldFlat, $oldFlat2], [$newFlat, $newFlat2] )
            {
                for my $part ( $aref->[0]->@* )
                {
                    if
                    (
                        $part !~ /LN=/
                        && $part !~ /raw=/
                        && $part !~ /\.obj/
                        && $part !~ /\.tags:\[\d+\]\.attrs/
                    )
                    {
                        $part .= "\n";
                        $part =~ s/\.childs//g;
                        $part =~ s/\.val=.*$//g;
                        $part =~ s/(\.tags:)\[\d+\]\.val:\[\d+\]=(.*)/$1\[$2\]/g;

                        push $aref->[1]->@*, $part;
                    }
                }
            }

            my $oldPath = $tmpdir . 'oldHash';
            my $newPath = $tmpdir . 'newHash';
            my $fh;

            open $fh, ">:utf8", $oldPath;
            print $fh @$oldFlat2;
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
            close $fh;

            open $fh, ">:utf8", $newPath;
            print $fh @$newFlat2;
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
            close $fh;
            #$self->__sweep(['reffs']);

            $CHECKS->{hashCmp}{fp}  = $tmpdir . 'hashDiff.txt';
            $CHECKS->{hashCmp}{out} = [`bash -c "diff <(sort $oldPath) <(sort $newPath)"`];
            #$CHECKS->{hashCmp2}{fp}  = $tmpdir . 'hashDiff2.txt';
            #$CHECKS->{hashCmp2}{out} = [`bash -c "comm -3  <(sort $oldPath) <(sort $newPath)"`];
            #$CHECKS->{hashCmp3}{fp}  = $tmpdir . 'hashDiff3.txt';
            #$CHECKS->{hashCmp3}{out} = [`cat $oldPath $newPath | sed 's/^.*LN=.*\$//' | sed 's/^.*raw=.*\$//' | sort | uniq -u`];
            if ($oldPath =~ /ohm/) {unlink $oldPath};
            if ($newPath =~ /ohm/) {unlink $newPath};
        }
        else
        {
            open my $fh, ">", $tmpdir . 'hashDiff.txt';
            print $fh '';
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
            close $fh;
        }


        # === WRITE === #{{{
        for my $check ( values %$CHECKS )
        {
            my $out = $check->{out};
            my $fp  = $check->{fp};
            open my $fh, '>:utf8', $fp
                or die;
                print $fh @$out;
                truncate $fh, tell($fh) or die;
                seek $fh,0,0 or die;
            close $fh;
        }

        # open non-empty check files in less
        my @files = glob $tmpdir."*";
        my $fileList;

        for my $file (@files)
        {
            unless (-z $file)
            {
                $fileList .= " $file";
            }
        }

        if ($fileList)
        {
            system "less " . $fileList;
        }
        #}}}


        # === COMMIT === #{{{
        $self->__commit;
        #}}}

    }

    elsif ( $type eq 'json' )
    {
        $self->rm_reff;
        $self->see('hash');
        $self->see('hash');
        $self->__sweep(['reffs']);
    }
}

sub __commit #{{{1
{
    my ($self, $args) = @_;

    # set up working dir
    my $db = $self->{paths}{dir}."/db";
    unless ( -d $self->{paths}{dir} )
    {
        mkdir($self->{paths}{dir})
    }
    unless ( -d $db )
    {
        mkdir($db)
    }

    $self->{paths} = $self->gen_config
    ({
        init_hash => {},
        bp_name => 'paths',
    });

    $self->rm_reff;
    use Data::Structure::Util qw( unbless );

    # INDIVDUAL HASHES
    my @KEYS = qw( hash dspt matches );
    for my $key (@KEYS)
    {
        my $hash = dclone $self->{$key};

        # Delteing Child Reffs in MATCHES
        if ($key eq 'matches')
        {
            for my $obj ( keys $hash->{objs}->%* )
            {
                for my $match ( $hash->{objs}{$obj}->@* )
                {
                    delete $match->{childs};
                }
            }
        }

        # Seperating Drsr and mask from dspt
        if ($key eq 'dspt')
        {
            $self->{drsr} = {};
            $self->{mask} = {};
            for my $obj ( keys %{ $hash } )
            {
                for my $key2 ( keys %{ $hash->{$obj} } )
                {
                    if ($key2 eq 'drsr')
                    {
                        $self->{drsr}{$obj} = delete $hash->{$obj}{$key2};
                    }
                    if ($key2 eq 'mask')
                    {
                        $self->{mask}{$obj} = delete $hash->{$obj}{$key2}
                    }
                }
            }
            push @KEYS, qw(drsr mask);
        }

        # write
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( $hash );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/$key.json"
            or die;
            print $fh $json;
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
        close $fh;
    }
    delete $self->{drsr};
    delete $self->{mask};

    # MISC HASH
    {
        my $hash = dclone $self;

        for my $key (@KEYS, 'stdout', 'tmp', 'circ', 'meta', 'cwd')
        {
            delete $hash->{$key};
        }

        # paths, cwd
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( unbless $hash );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/self.json"
            or die;
            print $fh $json;
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
        close $fh;
    }

    # OUTPUT
    use File::Copy;
    my $oldfile = $self->{paths}{output}
    . $self->{paths}{dir}
    . '/output/'
    . $self->{name}
    . '.txt';
    my $newfile = $self->{paths}{cwd} . $db . '/output.txt';
    copy($oldfile, $newfile) or die "failed copy of $oldfile to $newfile: $!";

    # return hash to original state
    $self->__sweep(['reffs']);
    return $self;
}

sub __see #{{{1
{
    my ( $self, $item, $prefix, $flat) = @_;

    if ( UNIVERSAL::isa($item,'HASH' ) )
    {
        for my $key ( keys %$item)
        {
            my $flatkey = $prefix . '.' . $key;
            $flat = $self->__see($item->{$key}, $flatkey, $flat);
        }
    } elsif ( UNIVERSAL::isa($item,'ARRAY' ) )
    {
        for my $idx (1 .. $item->$#*)
        {
            #my $flatkey = $prefix . ':' . $idx;
            my $key;
            if (ref $item->[$idx] ne 'HASH' || ref $item->[$idx]{val} eq 'ARRAY')
            {
                $key = $idx;
            }
            else
            {
                $key = $item->[$idx]{val};
            }
            my $flatkey = $prefix . ':' . "[".$key."]";
            $flat = $self->__see( $item->[$idx], $flatkey, $flat);
        }
    }
    else
    {
            my $flatkey = $prefix . '=' . ($item // 'NULL');
            push @$flat, $flatkey;
    }
    return $flat;
}

sub __see2 #{{{1
{
    my ( $self, $item, $prefix, $flat) = @_;

    if ( UNIVERSAL::isa($item,'HASH' ) )
    {
        for my $key ( keys %$item)
        {
            my $flatkey = $prefix . '.' . $key;
            $flat = $self->__see2($item->{$key}, $flatkey, $flat);
        }
    } elsif ( UNIVERSAL::isa($item,'ARRAY' ) )
    {
        for my $idx (0 .. $item->$#*)
        {
            my $flatkey = $prefix . ':' . $idx;
            $flat = $self->__see2( $item->[$idx], $flatkey, $flat);
        }
    }
    else
    {
            my $flatkey = $prefix . '=' . ($item // 'NULL');
            push @$flat, $flatkey;
    }
    return $flat;
}

sub __flatten #{{{1
{
    my ($self, $key) = @_;
    return flatten $self->{$key};
}

sub __unflatten #{{{1
{
    my ($self, $key) = @_;
    return unflatten $self->{$key};
}

sub __gen_bp #{{{1
{
    my ( $self, $bp_name ) = @_;
    my %bps =
    (
        objhash => #{{{
        {
            type => 'struct',
            fill => [''],
            member => {},
            general =>
            {
                obj => undef,
                val => undef,
                childs => {},
                attrs  => {},
                meta   => {},
                circs  =>
                {
                    '.'  => undef,
                    '..' => undef,
                },
            },
        }, #}}}
        meta => #{{{
        {
            type => 'config',
            fill => [''],
            member => {},
            general =>
            {
                dspt =>
                {
                   ord_limit => undef,
                   ord_map => undef,
                   ord_max => undef,
                   ord_sort_map => undef,
                },
            },
        }, #}}}
        params => #{{{ 
        {
            type => 'config',
            fill => [''],
            member => {},
            general =>
            {
                attribs => 1,
                delims => 1,
                mes => 1,
                prsv => 1,
            },
        }, #}}}
        paths => #{{{
        {
            type => 'config',
            fill => [''],
            member => {},
            general =>
            {
                drsr => $self->{cwd}.'/.ohm/db/drsr.json',
                dspt => $self->{cwd}.'/.ohm/db/dspt.json',
                input => $self->{cwd}.'/.ohm/db/output.txt',
                mask => $self->{cwd}.'/.ohm/db/mask.json',
                cwd => $self->{cwd},
                output => $self->{cwd},
                dir => '/.ohm',
            },
        }, #}}}
        prsv => #{{{
        {
            type => 'config',
            fill => [''],
            member => {},
            general =>
            {
                till =>
                [
                    'section',
                    0,
                ],
            },
        }, #}}}
        self => #{{{
        {
            type => 'config',
            fill => [''],
            member => {},
            general =>
            {
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
        }, #}}}
        matches => #{{{
        {
            type => 'config',
            fill => ['obj'],
            member => {},
            general =>
            {
                miss => [],
                objs => {},
            },
            objs =>
            {
                type => 'config',
                fill => ['obj'],
                general => {},
                member =>
                {
                    type => 'config',
                    fill => ['obj'],
                    general => [],
                    member => {},
                },
            },
        }, #}}}
        drsr => #{{{
        {
            type => 'config',
            fill => ['obj'],
            general => {},
            member =>
            {
                type => 'config',
                fill => ['attrs',1],
                general => {},
                member =>
                {
                    type => 'config',
                    fill => [''],
                    member => {},
                    general =>
                    [
                        '',
                        '',
                        '',
                        '',
                        '',
                        {},
                    ],
                },
            },
        }, #}}}
        dspt => #{{{
        {
            type => 'config',
            fill => [''],
            general =>
            {
                lib =>
                {
                    order => 0,
                },
                prsv =>
                {
                    order => -1,
                    mask => {},
                    drsr => {},
                },
            },
            member =>
            {
                type => 'config',
                fill => ['obj'],
                member => {},
                general =>
                {
                    re => undef,
                    cre => undef,
                    order => undef,
                    attrs => {},
                    drsr  => {},
                    mask  => {},
                },
                attrs =>
                {
                    type => 'config',
                    fill => ['attrs'],
                    general => {},
                    member =>
                    {
                        type => 'config',
                        fill => ['attrs'],
                        member => {},
                        general =>
                        {
                            re => undef,
                            cre => undef,
                            order => undef,
                            delims => [],
                            cdelims => undef,
                        },
                    },
                },
            },
        }, #}}}
        mask => #{{{
        {
            fill => ['obj'],
            type => 'config',
            general =>
            {
                lib => {},
                prsv => {},
            },
            member =>
            {
                fill => ['obj'],
                type => 'config',
                member => {},
                general =>
                {
                    supress =>
                    {
                        all => 0,
                        vals => [],
                    },
                    sort => -1,
                    place_holder =>
                    {
                        enable => 0,
                        childs => [],
                    },
                },
            },
        }, #}}}
    );

    return dclone $bps{lc $bp_name};
}

sub __checkDir #{{{1
{
    my ( $self ) = @_;
    return (-d $self->{cwd} . '/.ohm') ;
}

sub __checkChgArgs #{{{1
{
    my ($arg, $cond, $type) = @_;
    unless ( defined $arg )
    {
        croak( (caller(1))[3] . " requires an input" );
    }
    elsif (ref $arg ne $cond)
    {
        croak( (caller(1))[3] . " requires a $type" );
    }
}

sub __clone #{{{1
{
    my $self = shift;
    $self->{tmp} = bless { %$self }, ref $self;
    $self->{tmp}{tmp} = undef;
    return $self;
}

sub __longest #{{{1
{
    my $max = -1;
    my $max_ref;
    for (@_)
    {
        if (length > $max) # no temp variable, length() twice is faster
        {
            $max = length;
            $max_ref = \$_;   # avoid any copying
        }
    }
    $$max_ref
}
#}}}

1;
# ===  NOTES
# double utf8 encoding
# sweep(['refs'] giving duplicate empty hashes
# put type (dspt, mask, drsr, hash, matches) in lib of jsons
# differientiate b/w main mask and launch masks. May need to create seperate class called filters, launchers, or plan. These "submasks" need a launch command, additional scripts to run and masks of their own. They will be kept in supplement folder.
# changing bp configs.

