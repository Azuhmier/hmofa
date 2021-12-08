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
use Cwd;
use utf8;
use File::Basename;
use JSON::XS;
use Storable qw(dclone);
use Carp qw(croak carp);

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;
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
            prsv  => $_[4],
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

sub gen_config {
    my ( $self, $arg ) = @_;
    my %configs = (
        dspt => '',
        drsr => '',
        mask => {
            sort => -1,
            place_holders => 1;,
        },
    )
    $configs{$arg}

    return $self
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
        attribs  => '01',
        delims   => '01',
        prsv     => '01',
        mes      => '01',
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

    $self->{dspt} = $dspt;

    return $self;
}


sub __check_matches { #{{{1
    # have option presverses be 2nd option
    my ( $self, $args ) = @_;

    # without the 'g' modifier and the array context the regex exp will return
    # a boolean instead of the first match
    #
    my ($fext) = $self->{paths}{input} =~ m/\.([^.]*$)/g;
    $self->{matches} = {} unless exists $self->{matches};

    if ($fext eq 'txt') {
        delete $self->{matches};
        delete $self->{circ};
        delete $self->{stdout};
        $self->__get_matches;
        $self->__divy();
        $self->__sweep(['reffs','popl']);
        $self->__genWrite();
        $self->write();
        #$self->validate();

    } elsif ($fext eq 'json') {
        delete $self->{matches};
        delete $self->{circ};
        delete $self->{stdout};
        $self->{hash} = do {
            open my $fh, '<:utf8', $self->{paths}{input};
            local $/;
            decode_json(<$fh>);
        };
        $self->__sweep(['reffs','matches','popl']);
        $self->__genWrite();
        $self->write();
        #$self->validate();

    } else { die "$fext is not a valid file extesion, must either be 'txt' or 'json'" }

    return $self;
}

sub __sweep { #{{{1

    my ( $self, $subs ) = @_;

    my $sub_list = {
        reffs   => \&gen_reffs,
        matches => \&gen_matches,
        popl => \&populate,
    };

    $self->{m} = exists $self->{m} ?die " key 'm' is already defined"
                                   :{};

    walk (
        {
            wanted => sub {
                for my $name (@$subs) {
                    $sub_list->{$name}->($self);
                }
            },
            preprocess => sub {return @_}
        }, $self->{hash} // die " No hash has been loaded for object '$self->{name}'"
    );

    delete $self->{m};
    return $self;

    sub gen_reffs { #{{{2
        my ( $self, $args ) = @_;

        $self->{circ} = [] unless exists $self->{circ};

        my $item      = $_;
        my $container = $Data::Walk::container;

        if (ref $item eq 'HASH') {
            my $obj = $item->{obj} // 'NULL'; # need to have NULL be
                                              # error or something

            $item->{circ}{'.'}   = $item;
            $item->{circ}{'..'}  = $container // 'NULL';
            push $self->{circ}->@*, $item->{circ};

        } elsif (ref $item eq 'ARRAY'){
            unshift @$item, {
                '.'   => $_,
                '..'  => $container // 'NULL',
            };
            push $self->{circ}->@*, $item->[0];
        }
        return $self;
    }

    sub gen_matches { #{{{2

        my ( $self, $args ) = @_;

        unless ( exists $self->{matches} ) {
            $self->{matches} = { objs => {}, miss => [{a => 2}] }
        }

        my $item      = $_;
        my $container = $Data::Walk::container;

        if (ref $item eq 'HASH' and exists $item->{obj}) {
            my $obj = $item->{obj};
            push $self->{matches}{objs}{ $obj }->@*, $item;
        }

        return $self;
    }

    sub populate { #{{{2

        my ( $self, $args ) = @_;

        my $item      = $_;
        my $container = $Data::Walk::container;
        my $parent    = 'title';
        my $child     = 'tags';

        if ( ref $item eq 'HASH' and exists $item->{obj} ) {
            if ( $item->{obj} eq $parent ) {
                unless ( ( grep { $_ eq $child } keys $item->{childs}->%* )[0] ) {
                    $item->{childs}{$child}[0] = {
                        obj => $child,
                        val => [],
                        attr => {
                            anthro => [],
                            general =>[],
                        },
                        meta => {
                            LN => undef,
                            raw => undef,
                        },
                    };
                }
            }
        }
        return $self;
    }
}

sub __get_matches { #{{{1
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

    $self->{hash} = {
        val => $self->{name},
        obj => 'lib',
    };

    $self->{m}            = {};
    $self->{m}{reffArray} = [ $self->{hash} ];
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
            #my $self = shift @_;
            #my $match = shift @_;

            my $obj       = __getObj($self);
            $match->{meta}{raw} = $match->{$obj};

            if (exists $self->{dspt}{$obj}{attr}) {
                my $dspt_attr = $self->{dspt}{$obj}{attr};
                my @ATTRS = sort {
                    $dspt_attr->{$a}[1] cmp $dspt_attr->{$b}[1];
                    } keys %$dspt_attr;

                for my $attr (@ATTRS) {
                    my $success = $match->{val} =~ s/$dspt_attr->{$attr}[0]//;
                    if ( $success ) {
                        $match->{attr}{$attr} = $1;

                        if (scalar $dspt_attr->{$attr}->@* >= 3) {
                            __delimitAttr($self, $attr, $match);
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
    return $self;
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
