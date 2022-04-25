package Ohm::HasherWIP;
use parent 'Ohm::Main';

use strict;
use warnings;
use feature qw( current_sub );
use Storable qw(dclone);
use Carp qw(croak carp);
use Cwd;
use Data::Dumper;
#$Data::Dumper::Maxdepth = 1;

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;

#############################################################
#  PUBLIC
#############################################################

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
        #$self->__sweep(['plhd']);
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
        while ( $self->{input}->@* )
        {
            my $line = shift $self->{input}->@*;
            $FR_prsv = $self->__get_matches($line, $FR_prsv);
        }
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
} #}}}

#############################################################
# PRIVATE
#############################################################

sub __init #{{{1
{
    my ( $self, $args ) = @_;
    $self->__private(caller);



        if (exists $self->{args}{dspt})
        {
            $self->{dspt} = $self->{args}{dspt};
        }
        elsif (exists $args->{dspt})
        {
            $self->{dspt} = $args->{dspt};
        }
        else
        {
            croak "ERROR: no 'dspt' arg was supplied";
        }

    $self->__set_args( $args , 1);
    $self->__use_args();
    $self->__gen_dspt();

    my $class = ref $self;

    return $self;
}




sub __use_args #{{{1
{

    my ( $self ) = @_;
    $self->__private(caller);

    ## NAME
    $self->{name} = $self->{args}{name};
    ## DSPT
    $self->{dspt} = $self->{args}{dspt};
    ## EXTERN
    $self->{extern} = $self->{args}{extern};
    ## DRSR
    $self->{drsr} = $self->{args}{drsr};
    ## SDRS
    $self->{sdrsr} = $self->{args}{sdrsr};
    ## MASK
    $self->{mask} = $self->{args}{mask};
    ## SMASK
    $self->{smask} = $self->{args}{smask};
    ## OPTS
    $self->{opts} = $self->{args}{opts};
    ## FLAGS
    $self->{flags} = $self->{args}{flags};


    return $self;
}




sub __divy #{{{1
{

    my ( $self, $args ) = @_;

    #initiate hash
    $self->{hash} = $self->__gen_config( 'objHash', { val => $self->{name}, obj => 'lib', } );

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
            my $objMask = $self->{mask}{$obj} // return 1;

            if ( $objMask->{place_holder}{enable} )
            {

                for my $child ( $objMask->{place_holder}{childs}->@* )
                {

                    unless ( exists $objHash->{childs}{$child->[0]} )
                    {

                        my $childHash = $objHash->{childs}{$child->[0]}[0] = {};
                        %$childHash =
                        (
                            obj => $child->[0],
                            val => $child->[1],
                            meta => undef,
                        );

                        # attributes
                        my $childDspt = $self->{dspt}{$child->[0]};
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


sub __get_matches #{{{1
{
    my ( $self, $line, $FR_prsv, $tmp, $LN) = @_;
    $LN = 0 unless $LN;
    $LN++;

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
                    LN  => $LN,
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
                LN  => $LN,
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
                LN  => $LN,
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
        use ExtUtils::MakeMaker qw(prompt);
        my $ans = '';
        unless ($ans eq 'y' || $ans eq 'n')
        {
            $ans = prompt( "contiue?", "y/n" );
            $self->{state} = $ans eq 'y' ? 'ok' : '';
        } #}}}
    }
    else {
        $self->{state} = 'ok'
    }

}




sub __gen_dspt #{{{1
{
    my ( $self ) = @_;

    ## DSPT
    my $dspt = $self->{dspt};
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
                circs   => [],
                dspt    => {},
                matches => {},
                meta    => {},
            },
        },

        args => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {

                drsr    => {},
                dspt    => {},
                extern  => [],
                flags   => {},
                input   => [],
                mask    => {},
                name    => '',
                opts    => {},
                sdrs    => [],
                smask   => [],
            },
        },

        dspt => #{{{2
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
        },

        drsr => #{{{2
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
        },

        mask => #{{{2
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
        },

        delims => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {

            },
        },

        opts => #{{{2
        {
            fill => 0,
            member => {},
            general =>
            {
                plhd => {},
                prsv_opts => {},
            },
        },#}}}

        ## UTILITIES
        matches => #{{{2
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
        },

        objhash => #{{{2
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
        },#}}}

    );



    return \%bps;
}#}}}

1;

#############################################################
#  UTILITIES
#############################################################

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
}#}}}

