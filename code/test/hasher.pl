#!/usr/bin/env perl
#============================================================
#
#         FILE: hasher.pl
#        USAGE: ./hasher.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: Fri 10/08/21 07:55:11
#===========================================================
use strict;
use warnings;
use utf8;
use Storable qw(dclone);
use JSON::XS;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Data::Walk;

my $erreno;
my $CONFIG = '~/.hmofa';
sub mes;

# MAIN {{{1
#------------------------------------------------------
{
    my $name = 'catalog';

    hasher({
        name => $name,
        prsv => {
            till => ['section', 1]
        },
        fnames => {
            input => "./$name.txt",
            dspt => './deimos.json',
            output => './result',
            drsr => './drsr_C.json',
        },
        args => {
            attribs  => '01',
            delims   => '01',
            prsv     => '01',
            mes      => '01',
        },
    });

}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| hasher() {{{2
sub hasher {

    my $db = __init(shift @_);

    genDspt($db,'pathtodspt');
    getMatches($db,'pathtomatches');
    divy($db);
    {
        my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
        $json_obj    = $json_obj->allow_blessed(['true']);
        my $json     = $json_obj->encode($db->{result});
        my $fname    = './'.$db->{result}->{val}.'_part'.'.json';
        open my $fh, '>', $fname or die "Error in opening file $fname\n";
            print $fh $json;
            truncate $fh, tell( $fh ) or die;
        close $fh;
    }

    genReff($db);
    __genWrite($db);

    {
        my $writeArray = $db->{stdout};
        open my $fh, '>', './result/'.$db->{result}{val}.'.txt' or die $!;
            #binmode($fh, "encoding(UTF-8)");
            for (@$writeArray) {
                print $fh $_,"\n";
            }
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
        close $fh;
    }

    my $cmd = `diff ./catalog.txt ./result/catalog.txt`;
    print $cmd;


    return $db;
}

#===| genDspt() {{{2
sub genDspt {

    my $db = shift @_;
    my $dspt = do {
        open my $fh, '<', $db->{opts}{fnames}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{lib} = { order =>'0'};
    $dspt->{prsv} = { order =>'-1'};

    ## --- Generate Regexs
    for my $obj (keys %$dspt) {

        my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT) {
            if ($key eq 're') { $objDSPT->{re} = qr/$objDSPT->{re}/ }
            if ($key eq 'attr') {

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
    $db->{meta}{dspt}{ord_max} = (
        sort {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];

    # limit
    my @pntstr = split /\./, $db->{meta}{dspt}{ord_max};
    $pntstr[$#pntstr]++;
    $db->{meta}{dspt}{ord_limit} = join '.', @pntstr;

    # ordMap
    $db->{meta}{dspt}{ord_map}->%* =
        map  {$dspt->{$_}{order} => $_}
        grep {exists $dspt->{$_}{order} }
        keys %$dspt;

    # drsr
    my $drsr = do {
        open my $fh, '<', $db->{opts}{fnames}{drsr}
            or die;
        local $/;
        decode_json(<$fh>);
    };
    for my $obj (keys %$drsr) {
        $dspt->{$obj} // die;
        $dspt->{$obj}{drsr} = $drsr->{$obj};
        for my $attr (grep {$_ ne $obj} keys $drsr->{$obj}->%*) {
            $dspt->{$obj}{attr}{$attr} // die;

        }
    }

    $db->{dspt} = $dspt;

    return $db;
}


#===| getMatches() {{{2
#db->getMatches(fname), returns $obj
# default dspt is that of OV.
# check
# - dspt
# - filename
# - matches
sub getMatches {

    my $db = shift @_;
    my $dspt = $db->{dspt};

    ## --- open tgt file for regex parsing
    open my $fh, '<', $db->{opts}{fnames}{input}
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

                my $regex = $dspt->{$obj}{re} // 0;
                if ($regex and $line =~ $regex) {

                    last if _isPrsv($db,$obj,$1,$FR_prsv);

                    $match = {
                        obj => $obj,
                        val => $1,
                        meta => {
                            raw => $line,
                            LN  => $.,
                        },
                    }; push $db->{matches}{objs}{$obj}->@*, $match;
                }
            }
            ## --- PRESERVES
            if (!$match and _isPrsv($db,'NULL','',$FR_prsv)) {
                $match = {
                    obj => 'prsv',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $db->{matches}{objs}{prsv}->@*, $match;

            ## --- MISS
            } elsif (!$match) {
                $match = {
                    obj => 'miss',
                    val => $line,
                    meta => {
                        LN  => $.,
                    },
                }; push $db->{matches}{miss}->@*, $match;
            }
        }
    } close $fh ;

    ## -- subroutnes
    sub _isPrsv { #{{{
        my ($db, $obj, $match, $FR_prsv) = @_;
        my $dspt = $db->{dspt};

        if ( $obj eq $db->{opts}{prsv}{till}[0] ) {
            $FR_prsv->{F} = 0, if $FR_prsv->{cnt} eq $db->{opts}{prsv}{till}[1];
            $FR_prsv->{cnt}++
        }

        return $FR_prsv->{F};
    } #}}}
    return $db;
}


#===| divy() {{{2
sub divy {

    my $db = shift @_;

    $db->{result} = {
        val => $db->{opts}{name},
        obj => 'lib',
    };
    $db->{m} = {};

    $db->{m}{reffArray} = [$db->{result}];
    $db->{m}{point} = [1];
    $db->{m}{pointer} = [];

    __leveler($db);

    delete $db->{m};

    return $db;
}
#===| genReff() {{{2
sub genReff {
    my $db = shift @_;
    my %seen;
    walk (
        {
            wanted => sub {
                my $type      = $Data::Walk::type;
                my $index     = $Data::Walk::index;
                my $container = $Data::Walk::container;
                my $item      = $_;
                if (ref $item eq 'HASH') {

                    my $obj = $item->{obj} // 'NULL';
                    # need to have NULL be error or something

                    $seen{$obj}++;
                    $item->{circ}{'.'}   = $item;
                    $item->{circ}{'..'}  = $container // 'NULL';

                } elsif (ref $_ eq 'ARRAY'){
                    unshift @$_, {
                        '.'   => $_,
                        '..'  => $container // 'NULL',
                    };
                }
            },
            preprocess => sub {
                my $type = $Data::Walk::type;
                my $lvl  = $Data::Walk::depth;
                my @children = @_;
                if ($type eq 'HASH') {
                } else { }
                return @children;
            },
        },
        $db->{result}
    );
    return $db;
}

#===| mes() {{{2
sub mes {
    my ($mes, $db, $opts, $bool) = @_;
    $bool = 1 unless scalar @_ >= 4;

    if ($db->{opts}->{verbose} and $bool) {
        my ($cnt, $NewLineDisable, $silent) = @$opts if $opts;
        my $indent = "    ";

        $mes = ( $cnt ? $indent x (1 + $cnt) : $indent )
             . $mes
             . ( !($NewLineDisable) ? "\n" : "" );

        push $db->{debug}->@*, $mes unless $silent;
        return $mes;
    }
}



#===| __init() {{{2
sub __init {

    my $db = {};

    # --- properties
    $db->{opts} = {};
    $db->{debug} = [];

    # --- ERRENO
    $SIG{__DIE__} = sub {
        print $_ for $db->{debug}->@*;
        print $erreno if $erreno;
    };

    # --- OPTS
    my $opts = shift @_;
    unless ($opts->{name}) {die "User did not provide 'Name'!"};
    unless ($opts->{prsv}) {die "User did not provide 'prsv'!"};
    unless ($opts->{fnames}{drsr}) {die "User did not provide 'drsr'!"};
    unless ($opts->{fnames}{dspt}) {die "User did not provide filename for 'dspt'!"};
    unless ($opts->{fnames}{input}) {die "User did not provide filename for 'fname'!"};
    unless (exists $opts->{fnames}{output}) {
        $opts->{fnames}{output} = './';
    }

    #args
    my $defaults = {
        attribs  => '01',
        delims   => '01',
        prsv     => '01',
        mes      => '01',
    };
    $defaults->{$_} = $opts->{args}{$_} for keys $opts->{args}->%*;
    $opts->{args} = $defaults;


    $db->{opts} = $opts;

    return $db;
}


#===| __leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub __leveler {

    my ($db) = @_;

    ## check existance of OBJ at current point
    my $obj = __getObj( $db );
    unless ($obj) { return }

    ## Reverence Arrary for the current recursion
    my $recursionReffArray;
    while ($obj) {

        ## Checking existance of recursionReffArray
        unless (defined $recursionReffArray) { $recursionReffArray->@* = $db->{m}{reffArray}->@* }

        ## divy
        __divyMatches( $db );

        ## Check for CHILDREN
        __changePointLvl($db->{m}{point}, 1);
        __leveler($db);
        __changePointLvl($db->{m}{point});
        $db->{m}{reffArray}->@* = $recursionReffArray->@*;

        ## Check for SYBLINGS
        if (scalar $db->{m}{point}->@*) {
            $db->{m}{point}[-1]++;
        } else { last }

        $obj = __getObj($db);
    }
    ## Preserves
    if (__getPointStr($db) eq $db->{meta}{dspt}{ord_limit}) {
        $db->{m}{point}->@* = (-1);

        __divyMatches($db);
    }

    return $db;
}


#===| __divyMatches() {{{2
sub __divyMatches {

    my $db = shift @_;
    my $obj = __getObj($db); #db->get_obj()
    return unless exists $db->{matches}{objs}{$obj};
    my @objMatches = $db->{matches}{objs}{$obj}->@*;

    ## --- REFARRAY LOOP
    my $refArray = $db->{m}{reffArray};
    my $ind = (scalar @$refArray) - 1;
    for my $ref (reverse @$refArray) {
        my $ref_LN = $ref->{meta}{LN} // 0;

        ## --- MATCHES LOOP
        my $childObjs;
        for my $match (reverse @objMatches) {

            if ($match->{meta}{LN} > $ref_LN) {
                my $match = pop @objMatches;
                __genAttributes( $db, $match);
                push @$childObjs, $match;

            } else { last }
        }

        ## --- MATCHES TO REF ARRAY
        # todo: while loop that checks neighboring LN, and corrects if
        # necessary
        if ($childObjs) {

            @$childObjs = reverse @$childObjs;
            $refArray->[$ind]{childs}{$obj} = $childObjs;

            #add matches to ref array
            splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjs) );
        }

        $ind--;
    }
}

#===| __genAttributes() {{{2
sub __genAttributes {

    my ($db, $match) = @_;
    #my $db = shift @_;
    #my $match = shift @_;

    my $obj       = __getObj($db);
    $match->{meta}{raw} = $match->{$obj};

    if (exists $db->{dspt}{$obj}{attr}) {
        my $dspt_attr = $db->{dspt}{$obj}{attr};
        my @ATTRS = sort {
            $dspt_attr->{$a}[1] cmp $dspt_attr->{$b}[1];
            } keys %$dspt_attr;

        for my $attr (@ATTRS) {
            my $sucess   = $match->{val} =~ s/$dspt_attr->{$attr}[0]//;
            my $fish     = {};
            $fish->{caught} = $1 if $1;
            if ($sucess and !$1) {$fish->{caught} = '' }
            if ($fish->{caught} || exists $fish->{caught}) {
                $match->{attr}{$attr} = $fish->{caught};

                if (scalar $dspt_attr->{$attr}->@* >= 3) {
                    __delimitAttr($db, $attr, $match);
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

#===| __delimitAttr() {{{2
sub __delimitAttr {

    ## Attributes
    my $db       = shift @_;
    my $objKey   = __getObj($db);
    my $dspt_attr = $db->{dspt}{$objKey}{attr};

    ## Regex for Attribute Delimiters
    my $attr = shift @_;
    my $delimsRegex = $dspt_attr->{$attr}[3];

    ## Split and Grep Attribute Match-
    my $match = shift @_;
    $match->{attr}{$attr} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{attr}{$attr} )
    ];
}



#===| __changePointLvl() {{{2
sub __changePointLvl {

    my $point = shift @_;
    my $op    = shift @_;

    if ($op) { push $point->@*, 1 }
    else     { pop $point->@*, 1 }

    return $point;

}


#===| __getObj() {{{2
# return OBJECT at current point
# return '0' if OBJECT doesn't exist for CURRENT_POINT!
# die if POINT_STR generated from CURRENT_POINT is an empty string!
sub __getObj {

    my $db = shift @_;
    my $pntstr = join( '.', $db->{m}{point}->@* )
        or  die "pointStr cannot be an empty string!";
    return $db->{meta}{dspt}{ord_map}{$pntstr} // 0;

}


#===| __getPointStr() {{{2
sub __getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $db = shift @_;
    my $pointStr = join('.', $db->{m}{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| __longest() {{{2
sub __longest {
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
#------------------------------------------------------

#===| __genwrite() {{{2
sub __genWrite {
    my $db = shift @_;
    my $dspt = $db->{dspt};
    $db->{m}{prevDepth} = '';
    $db->{m}{prevObj} = 'NULL';
    walk(
        {
            wanted => sub {
                my $item       = $_;
                if (ref $item eq 'HASH' && $item->{obj} ne 'lib') {
                    my $container  = $Data::Walk::container;
                    my $depth      = $Data::Walk::depth;
                    my $obj        = $item->{obj};
                    my $drsr       = $db->{dspt}{$obj}{drsr};

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
                    if (exists $drsr->{$obj}[5] and $db->{m}{prevDepth}) {

                        my $prevObj   = $db->{m}{prevObj};
                        my $prevDepth = $db->{m}{prevDepth};

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
                    unless ($F_empty) { push $db->{stdout}->@*, $str if $obj ne 'lib'}
                    $db->{m}{prevDepth} = $depth;
                    $db->{m}{prevObj}   = $obj;
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
        $db->{result}
    );
    return $db;
}
