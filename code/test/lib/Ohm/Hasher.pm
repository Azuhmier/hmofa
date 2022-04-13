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
use feature qw( current_sub );

use File::Basename;
use JSON::XS;
use Storable qw(dclone);
use Carp qw(croak carp);
use Cwd;
use Data::Dumper;
#$Data::Dumper::Maxdepth = 1;

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
use Hash::Flatten qw(:all);

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

        # Remove args with undefined values
        delete $args->{$_} for grep { !(defined $args->{$_}) } keys %$args;
    }

    # Create Object
    my $self = {};
    bless $self, $class;

    # init
    $self->__init( $args );

    return $self;
}

sub __init #{{{1
{
    my ( $self, $args ) = @_;
    my $class = ref $self;
    $self->{state} = '';

    use Cwd 'abs_path';  $self->{cwd} = getcwd;  # get CWD
    my $isBase = $self->__checkDir();            # is dir ./ohm?

    #%-------- RESUME --------#
    # get the 'self' hash from the db
    my $old_args = do
    {
        open my $fh, '<:utf8', $self->{cwd}.'/.ohm/db/self.json';
        local $/;
        decode_json(<$fh>);
    };
    delete $old_args->{paths}{cwd}; # this is not set by the user
    delete $old_args->{state};      # this is not set by the user

    # reshape "old_args" to the form of "args"
    for my $key (keys $old_args->{paths}->%*)
    {
        $old_args->{$key} = $old_args->{paths}{$key};
    }
    delete $old_args->{paths}; # we no longer need it

    # apply flat mask
    my $flat_config = flatten $old_args;
    $flat_config    = $self->__mask($flat_config, flatten $args);
    $args           = unflatten $flat_config;

    #%-------- PATHS --------#
    # INPUT
    my $paths_input = delete $args->{input} || die "No path to input provided";
    __checkChgArgs( $paths_input, '' , 'string scalar' );
    if ($paths_input) { $self->{paths}{input} = abs_path $paths_input }

    # DSPT - DISPATCH TABLE
    my $paths_dspt = delete $args->{dspt} || die "No path to dspt provided";
    __checkChgArgs( $paths_dspt, '' , 'string scalar' );
    if ($paths_dspt) { $self->{paths}{dspt} = abs_path $paths_dspt }

    # OUTPUT
    my $paths_output = delete $args->{output} // '';
    __checkChgArgs( $paths_output,'','string scalar' );
    if ($paths_output) { $self->{paths}{output} = abs_path $paths_output }

    # DIR
    my $paths_dir = delete $args->{dir} // '';
    __checkChgArgs( $paths_dir,'','string scalar' );
    if ($paths_dir) { $self->{paths}{dir} = $paths_dir }

    # DRSR - DRESSER
    my $paths_drsr = delete $args->{drsr} // '';
    __checkChgArgs( $paths_drsr, '' , 'string scalar' );
    if ($paths_drsr) { $self->{paths}{drsr} = abs_path $paths_drsr }

    # MASK
    my $paths_mask = delete $args->{mask} // '';
    __checkChgArgs( $paths_mask, '' , 'string scalar' );
    if ($paths_mask) { $self->{paths}{mask} = abs_path $paths_mask }

    # SMASK - SUBMASKS
    my $paths_SMASK = delete $args->{smask} // [];
    __checkChgArgs( $paths_SMASK, 'ARRAY' , 'ARRAY REF' );
    if ( $paths_SMASK )
    {
        $self->{paths}{smask} = [ map { abs_path $_[0]; $_[0] } @$paths_SMASK ]
    }

    # SDRSR - SUBDRESSERS
    my $paths_SDRSR = delete $args->{sdrsr} // [];
    __checkChgArgs( $paths_SDRSR, 'ARRAY' , 'ARRAY REF' );
    if ( $paths_SDRSR )
    {
        $self->{paths}{sdrsr} = [ map { abs_path $_; $_ } @$paths_SDRSR ]
    }

    # generate path config
    $self->{paths} = $self->gen_config( 'paths', $self->{paths} );


    #%-------- OTHER ARGS --------#
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
    $self->{params} = $self->gen_config( 'params', $params  );


    #%-------- CHECK --------#
    # KEYS
    if ( my $remaining = join ', ', keys %$args )
    {
        croak( "Unknown keys to $class\::new: $remaining" );
    }

    return $self;
}

sub gen_dspt #{{{1
{
    my ( $self, $args ) = @_;

    ## --- IMPORT DSPT FILE
    my $dspt = do
    {
        open my $fh, '<:utf8', $self->{paths}{dspt};
        local $/;
        decode_json(<$fh>);
    };
    $dspt = $self->gen_config( 'dspt', $dspt  );
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
    $self->{drsr} = do
    {
        #open my $fh, '<:utf8', $self->{paths}{drsr}
        open my $fh, '<', $self->{paths}{drsr}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    $self->{drsr} = $self->gen_config( 'drsr', $self->{drsr}  );

    ## --- MASK
    $self->{mask} = do
    {
        open my $fh, '<:utf8', $self->{paths}{mask}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    $self->{mask} = $self->gen_config( 'mask', $self->{mask}  );

    ## --- SMASK
    $self->{smask} = [];
    for my $path ( $self->{paths}{smask}->@* )
    {
        my $smask = do
        {
            open my $fh, '<:utf8', $path[0]
                or die;
            local $/;
            decode_json(<$fh>);
        };

        $smask = $self->gen_config( 'mask', $smask  );
        unless ( $path[1] ) {
            $path[1] = 'drsr';
        }

        push $self->{smask}->@*, [$smask $path[1]];
    }

    ## --- SDRSR
    $self->{sdrsr} = [];
    for my $path ( $self->{paths}{sdrsr}->@* )
    {
        my $sdrsr = do
        {
            open my $fh, '<:utf8', $path
                or die;
            local $/;
            decode_json(<$fh>);
        };

        $sdrsr = $self->gen_config( 'mask', $sdrsr  );

        push $self->{smask}->@*, $sdrsr;
    }

    ## --- RETURN
    $self->{dspt} = $dspt;
    return $self;
}


sub check_matches #{{{1
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

        # should be it's own object
        $self->get_matches;
        $self->__divy();
        $self->__sweep(['reffs']);
        #

        $self->__genWrite();
        $self->__validate();
        $self->__commit();

    }

    else
    {
        die "$fext is not a valid file extesion, must either be 'txt' or 'json'"
    }

    return $self;
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
    $self->{hash} = $self->gen_config( 'objHash', { val => $self->{name}, obj => 'lib', } );

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
    my ( $self, $mask, $sdrsr ) = @_;

    $self->{stdout} = [];
    my $dspt = $self->{dspt};
    $self->{m}{prevDepth} = '';
    $self->{m}{prevObj} = 'NULL';

    # expand mask
    unless ( $mask )
    {
        $mask = $self->{mask}
    }

    walk
    (
        {
            wanted => sub
            {
                my $item       = $_;
                my $container  = $Data::Walk::container;
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') {

                    my $obj = $item->{obj};

                    # establish drsr
                    my $drsr       = $self->{drsr};
                    if ($sdrsr) { $drsr = $sdrsr };

                    my $depth      = $Data::Walk::depth;
                    my $str        = '';

                    # SMASK
                    if ($mask->{$obj}{supress} )
                    {
                        if ( $mask->{$obj}{supress}{all} )
                        {
                            $self->{m}{prevDepth} = $depth;
                            $self->{m}{prevObj}   = $obj;
                            return;
                        }
                    }


                    ## --- String: d0, d1
                    if (ref $item->{val} ne 'ARRAY')
                    {
                        $str .= $drsr->{$obj}{$obj}[0]
                             .  $item->{val}
                             .  $drsr->{$obj}{$obj}[1];
                    }

                    ## --- Attributes String: d0, d1, d2, d3, d4{{{
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

                                # if $attrItem is a ref, clone it
                                if (ref $attrItem) { $attrItem = dclone $item->{attrs}{$attr} }

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}{delims})
                                {
                                    my @itemPartArray = ();
                                    for my $part (@$attrItem)
                                    {
                                        unless (defined $drsr->{$obj}{$attr}[2] || defined $drsr->{$obj}{$attr}[3]) { die " obj '$obj' does not have delims drsrs" }
                                        $part = $drsr->{$obj}{$attr}[2]
                                              . $part
                                              . $drsr->{$obj}{$attr}[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $drsr->{$obj}{$attr}[4], @itemPartArray;
                                }

                                #if (!$attrItem || $drsr->{$attr}[1] || $drsr->{$attr}[0]) {
                                #    die;
                                #}

                                $attrStr .= $drsr->{$obj}{$attr}[0]
                                         .  $attrItem
                                         .  $drsr->{$obj}{$attr}[1];

                            }
                        }
                    }#}}}

                    ## --- Line Striping: d5,d6 #{{{
                    my $F_empty;
                    if (exists $drsr->{$obj}{$obj} and exists $drsr->{$obj}{$obj}[5] and $self->{m}{prevDepth})
                    {

                        my $prevObj   = $self->{m}{prevObj};
                        my $prevDepth = $self->{m}{prevDepth};

                        my $ref = ref $drsr->{$obj}{$obj}[5];
                        my $tgtObjs = ($ref eq 'HASH') ?$drsr->{$obj}{$obj}[5]
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
                            my $cnt = $drsr->{$obj}{$obj}[5];
                            $str =~ s/.*\n// for (1 .. $cnt);
                        }

                    } #}}}

                    ## --- Line Chopping d7 #{{{
                    if ( ref $drsr->{$obj}{$obj}[6] eq 'HASH' and exists $drsr->{$obj}{$obj}[6]{chop})
                    {
                        my $last = $self->{matches}{objs}{$obj}->$#*;

                        my $cnt = -1;
                        for my $reff ( $self->{matches}{objs}{$obj}->@* )
                        {
                            $cnt++;
                            if ( $reff == $item )
                            {
                                last;
                            }
                        }
                        if ($cnt == $last) { return }
                    }
                    #}}}

                    ## --- String Concatenation {{{
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
                if ( ref $item eq 'ARRAY' )
                {
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
                elsif ($type eq 'ARRAY')
                {
                    my $item = \@children;
                    my $idx_0 =  ( exists  $item->[0]{obj} ) ?0 :1;
                    my $obj = $item->[$idx_0]{obj};
                    if ( scalar $mask->{$obj}{supress}{vals}->@* )
                    {
                        for my $idx ($mask->{$obj}{supress}{vals}->@*)
                        {
                            splice @$item, ($idx+$idx_0),1;
                        }
                    }
                    if ( $mask->{$obj}{sort} != 0 )
                    {
                        @children = 
                        sort
                        {
                            lc $a->{val}
                            cmp
                            lc $b->{val}
                        }
                        @children
                    }
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
    my ( $self ) = @_;

    # --------- Dummy File --------{{{2

    # TMP DIR
    my $tmpdir =
        $self->{paths}{output}
        . $self->{paths}{dir}
        . '/tmp/';
    mkdir($tmpdir) unless(-d $tmpdir);

    # tgt filepath
    my $dir =
        $self->{paths}{output}
        . $self->{paths}{dir}
        . '/tmp/';

    # create filepath
    mkdir($dir) unless(-d $dir);

    # write to filepath
    open my $fh_22, '>:utf8', $dir . $self->{name} . '.txt' or die $!;
        for ($self->{stdout}->@*)
        {
            print $fh_22 $_,"\n";
        }
        truncate $fh_22, tell($fh_22) or die;
        seek $fh_22,0,0 or die;
    close $fh_22;
    my $CHECKS;

    # DIFF DIR
    my $Diffdir = $tmpdir.'/diffs/';
    mkdir($Diffdir) unless(-d $Diffdir);

    # --------- TXT DIFF --------{{{2

    # OUTPUT FILES
    my $tmpFile =
        $self->{paths}{output}
        . $self->{paths}{dir}
        . '/tmp/'
        . $self->{name}
        . '.txt';
    my $file = $self->{paths}{input};


    # CHECKS
    $CHECKS->{txtCmp}{fp}  = $Diffdir . 'diff.txt';
    $CHECKS->{txtCmp}{out} = [`diff $file $tmpFile`];


    # --------- MATCHES ---------- {{{2

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
    $CHECKS->{matchCmp}{fp}  = $Diffdir.'cnt.txt';
    $CHECKS->{matchCmp}{out} = [@OUT];


    # --------- HASHES ---------{{{2

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

        my $oldPath = $Diffdir . 'oldHash';
        my $newPath = $Diffdir . 'newHash';
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

        $CHECKS->{hashCmp}{fp}  = $Diffdir . 'hashDiff.txt';
        $CHECKS->{hashCmp}{out} = [`bash -c "diff <(sort $oldPath) <(sort $newPath)"`];
        if ($oldPath =~ /ohm/) {unlink $oldPath};
        if ($newPath =~ /ohm/) {unlink $newPath};
    }
    else
    {
        open my $fh, ">", $Diffdir . 'hashDiff.txt';
        print $fh '';
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
        close $fh;
    }


    # --------- WRITE ---------{{{2

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
    my @files = glob $Diffdir."*";
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

    # --------- PROMPT ---------{{{2

    use ExtUtils::MakeMaker qw(prompt);
    my $ans = '';
    unless ($ans eq 'y' || $ans eq 'n')
    {
        $ans = prompt( "contiue?", "y/n" );
        $self->{state} = $ans eq 'y' ? 'ok' : '';
    } #}}}

}


sub __commit #{{{1
{
    my ($self, $args) = @_;
    if ( $self->{state} ne 'ok' )
    {
        print "Commit aborted, object state is not ok\n";
        return;
    }

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

    $self->{paths} = $self->gen_config( 'paths', { smask => $self->{paths}{smask} } );

    $self->rm_reff;
    use Data::Structure::Util qw( unbless );

    # INDIVDUAL HASHES
    my @KEYS = qw( hash dspt matches drsr mask);
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

    # SMASK
    unless ( -d $self->{paths}{cwd} . "$db/smask" )
    {
        mkdir($self->{paths}{cwd} . "$db/smask")
    }
    $self->{paths}{smask} = [];
    for my $hash ($self->{smask}->@*)
    {
        push $self->{paths}{smask}->@*, $self->{paths}{cwd} . "$db/smask/" . $hash->{lib}{name}.".json";
        my $json = JSON::XS->new->pretty->allow_nonref->allow_blessed(['true'])->encode( $hash );
        open my $fh, '>:utf8', $self->{paths}{cwd} . "$db/smask/" . $hash->{lib}{name}.".json"
            or die;
            print $fh $json;
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
        close $fh;
    }

    # MISC HASH
    {
        my $hash = dclone $self;

        for my $key (@KEYS, 'stdout', 'tmp', 'circ', 'meta', 'cwd', 'smask')
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
    . '/tmp/'
    . $self->{name}
    . '.txt';
    my $newfile = $self->{paths}{cwd} . $db . '/output.txt';
    copy($oldfile, $newfile) or die "failed copy of $oldfile to $newfile: $!";

    # return hash to original state
    $self->__sweep(['reffs']);
    return $self;
}

sub launch #{{{1
{
    my ( $self, $args ) = @_;
    if ( $self->{state} ne 'ok' )
    {
        print "Launch aborted, object state is not ok\n";
        return;
    }
    my @SMASKS = @{ $self->{smask} };
    my $dspt = $self->{dspt};

    for my $smask ( @SMASKS )
    {
        my $pwds_DirPaths = $smask->{lib}{pwds};
        my @pwds;
        for my $path ( @$pwds_DirPaths )
        {
            my ($CONFIG_DIR) = glob $path->[0];
            my $pwd = 0;
            if ( $CONFIG_DIR )
            {
                open my $fh, '<', $CONFIG_DIR
                    or die 'something happened';
                while (my $line = <$fh>)  {
                    if ($line =~ qr/$path->[1]/) {
                        $pwd = $1;
                        last;
                    }
                }
            }
            push @pwds, $pwd;
        }
        my $sdrsr_name = $smask->{lib}{drsr};

        my $sdrsr = do
        {
            #open my $fh, '<:utf8', $self->{paths}{drsr}
            open my $fh, '<', "./" . $sdrsr_name . ".json"
                or die;
            local $/;
            decode_json(<$fh>);
        };
        # generate drsr config
        $sdrsr = $self->gen_config( 'drsr', $sdrsr  );

        for my $obj (keys %$sdrsr)
        {
            $dspt->{$obj} // die;
            $dspt->{$obj}{drsr} = $sdrsr->{$obj};
            for my $attr (grep {$_ ne $obj} keys $sdrsr->{$obj}->%*)
            {
                $dspt->{$obj}{attrs}{$attr} // die "$attr for $self->{name}" ;

            }
        }

        #print Dumper $sdrsr;
        $self->__genWrite($smask, $sdrsr);

        open my $fh2, '>:utf8', $self->{paths}{output}."/.ohm/output/".$smask->{lib}{name}.".txt"
            or die 'something happened';
            $self->{stdout}[0] = $smask->{lib}{header} // $self->{stdout}[0];

            for ($self->{stdout}->@*)
            {
                print $fh2 $_,"\n";
            }
            truncate $fh2, tell($fh2) or die;
            seek $fh2,0,0 or die;

        close $fh2;
        ## upload to final destination
        $smask->{lib}{cmd} =~ s/\$\{PWD\}/$pwds[0]/g;
        print $smask->{lib}{cmd}, "\n";
        my $cmd = `$smask->{lib}{cmd}`;


    }

    return $self;
}

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
{ # generates and/or enforces configuration hashes

    my
    ( $self,
        $bp_name,  # boilerplate name for 'get_bp' subroutine
        $init_hash # initial hash to mask
    ) = @_;



    my $bp = dclone $self->__gen_bp( $bp_name ) // die;

    # populate config
    my $config = populate
    (
        $self,   # 'hasher'
        $bp,     # boiler plate
        {},      # initial config to be built within recursion
        0,       # obj_flag
        $bp_name,
    );

    # use init hash if provided
    if ($init_hash)
    {
        my $flat_mask  = flatten $init_hash;
        my $flat_config = flatten $config;

        $flat_config = $self->__mask($flat_config, $flat_mask);

        $config = unflatten $flat_config;

    }

    return $config;

    sub populate #{{{2
    {
        my
        (
            $self,    # hasher object
            $bp,      # boiler plate
            $config,  # config being built within recursion
            $OBJ,     # Boolean for 1st lvl recursion
            $bp_name, # Name of boilerplate
        ) = @_;

        my $member  = delete $bp->{member}  // die "no member hash in boiler_plate $bp_name";
        my $fill    = delete $bp->{fill}    // die "no fill hash in boiler_plate $bp_name";
        my $general = delete $bp->{general} // die "no general hash in boiler_plate $bp_name";
        my @RemKeys = keys %$bp;
        $config = dclone $general if $general;

        # MEMBER
        if ( %$member )
        {

            # KEYS
            my @KEYS;
            if ($OBJ)
            {
                @KEYS = keys $self->{dspt}{$OBJ}{attrs}->%*;
                push @KEYS, $OBJ if $fill;
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
                    $bp_name,
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
                $bp_name,
            );
        }

        # GENERAL
        if (ref $config eq 'HASH')
        {
            my $flat_mask  = flatten (dclone $general) if $general;
            my $flat_config = flatten $config;

            $flat_config = $self->__mask($flat_config, $flat_mask);

            return unflatten $flat_config;
        }

        return $config;
    } #}}}
    sub __mask #{{{2
    {
        my
        (
            $self,
            $flat_config,
            $flat_mask
        ) = @_;

        for my $key ( keys %$flat_mask )
        {
            my $str = $key;
            my $pat;
            my $end;
            my @KEYS;
            my $delim = '';
            my @CLN = (0);

            while ( scalar @KEYS > 1 || scalar @CLN )
            {
                if ( $str =~ s/((?:\\\:|\\\.|[_[:alnum:]])+)((?:\.|:)*)// )
                {
                    $pat  .= $delim.$1;
                    $delim = $2 // '';
                    $end = $delim ? '' : '$' ;

                }

                @KEYS = grep {$_ =~ /^\Q$pat\E($|:|\.)/ } keys %$flat_config;
                @CLN  = grep {$_ !~ m/^\Q$pat$delim\E$end/ } @KEYS;
                delete $flat_config->{$_} for @CLN;
            }

            $flat_config->{$key} = $flat_mask->{$key};

        }
        return $flat_config;
    }


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
            #$ref->[0] = {};
            shift @$ref;
        }
        else
        {
            die
        }
    }
    $self->{circ} = [];
}

sub __see #{{{1
{
    my ( $self, $item, $prefix, $flat) = @_;

    if ( UNIVERSAL::isa($item,'HASH' ) )
    {
        for my $key (keys %$item)
        {
            my $flatkey = $prefix . '.' . $key;
            $flat = $self->__see($item->{$key}, $flatkey, $flat);
        }
    } elsif ( UNIVERSAL::isa($item,'ARRAY' ) )
    {
        for my $idx (0 .. $item->$#*)
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
    my
    (
        $self,    # hasher object
        $bp_name  # boiler plate key name; not case sensitive
    ) = @_;

    # boiler plat dispatch table
    my %bps =
    (
        objhash => #{{{
        {
            fill => 0,
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
            fill => 0,
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
            fill => 0,
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
            fill => 0,
            member => {},
            general =>
            {
                drsr => $self->{cwd}.'/.ohm/db/drsr.json',
                dspt => $self->{cwd}.'/.ohm/db/dspt.json',
                input => $self->{cwd}.'/.ohm/db/output.txt',
                mask => $self->{cwd}.'/.ohm/db/mask.json',
                cwd => $self->{cwd},
                output => $self->{cwd},
                smask => [],
                dir => '/.ohm',
            },
        }, #}}}

        prsv => #{{{
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
        }, #}}}

        self => #{{{
        {
            fill => 0,
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
            fill => 0,
            member => {},
            general =>
            {
                miss => [],
                objs => {},
            },
            objs =>
            {
                fill => 0,
                general => {},
                member =>
                {
                    fill => 0,
                    general => [],
                    member => {},
                },
            },
        }, #}}}

        drsr => #{{{
        {
            fill => 0,
            general => {},
            member =>
            {
                fill => 1,
                general => {},
                member =>
                {
                    fill => 0,
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
            fill => 0,
            general =>
            {
                lib =>
                {
                    order => 0,
                    smask => [],
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
                fill => 0,
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
                    fill => 0,
                    general => {},
                    member =>
                    {
                        fill => 0,
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
            fill => 0,
            general =>
            {
                lib =>
                {
                    cmd => '',
                    scripts => [],
                    pwds => [],
                    name => '',
                },
                #prsv => { akle => 1}, # if defined as '{}, it does not include
                #supress, including 'akle => 1' does include supress
            },
            member =>
            {
                fill => 0,
                member => {},
                general =>
                {
                    supress =>
                    {
                        all => 0,
                        vals => [],
                    },
                    sort => 0,
                    place_holder =>
                    {
                        enable => 0,
                        childs => [],
                    },
                },
            },
        }, #}}}
    );

    # return clone of boiler plate using undercased version of argument key
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


1;
# ===  NOTES
# double utf8 encoding
# sweep(['refs'] giving duplicate empty hashes
# put type (dspt, mask, drsr, hash, matches) in lib of jsons
# differientiate b/w main mask and launch masks. May need to create seperate class called filters, launchers, or plan. These "submasks" need a launch command, additional scripts to run and masks of their own. They will be kept in supplement folder.
# changing bp configs.
# vim autoread not working
# empty spaces for tags
# prsvs, archive, and scraping
