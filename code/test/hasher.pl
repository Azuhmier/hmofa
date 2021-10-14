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
use Data::Dumper;
use List::Util qw( uniq );
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');
my $erreno;
my $CONFIG = '~/.hmofa';
sub mes;

$db = {
    debug => [],
    dspt => {}
    m => {}
    matches => {}
    meta => {}
    opts => {},
    result => {}
}
$db = {
    debug => [],
    matches => {}
    meta => {}
    result => {}
    m => {
        reffArray => [$db->{result}],
        point => [1],
        pointer => [];
    }
    dspt => {
        %$dspt,
        meta => {
            ord_max => $max,
            ord_limit => $limit,
            ord_map => {}
        }
    }
    opts => {
        name => 'hmofa_lib',
        args => $args,
        drsr => $drsr_C,
        prsv => {
            till => ['section', 1]
        },
        fnames => {
            input => './hmofa_lib.json',
            dspt => './deimos.json',
            output => './db',
        },
    },
}

# MAIN {{{1
#------------------------------------------------------
{
    ## --- DRESSERS  {{{
    ## drsr_M {{{
        my $drsr_M = {
            libName => {libName => ['', '']},
            preserve => {
                preserve => ['', '', '', '', '', {section => 1}],
            },
            title => {
                title           => [">", '', '', '', ''],
                title_attribute => [' (', ')'],
            },
            author => {
              author           => [('-'x110)."\nBy ", '', '', '', '', 3],
              author_attribute => [' (', ')'],
            },
            series => {
                series => ["===== " , ' ====='],
            },
            section => {
                section => [
                    "\n".('-'x126)."\n".('-'x53)."% ",
                    " %".('-'x49)."\n".('-'x126),
                    '',
                    '',
                    '',
                    {preserve => 2},
                ],
            },
            url => {
                url           => ['', '',],
                url_attribute => [' (', ')',],
            },
        }; #}}}
    ## drsr_C {{{
        my $drsr_C = {
            libName => {libName => ['', '']},
            preserve => {
                preserve => ['', '', '', '', '', { section => 1 }],
            },
            title => {
                title           => ["\n>", '', '', '', '', {series => 1}],
                title_attribute => [' (', ')'],
            },
            author => {
              author => [
                  "\n".('-' x 125)."\n".('-' x 125)."\nby ",
                  '',
                  '',
                  '',
                  '',
                  3,
              ],
              author_attribute => [' (', ')'],
            },
            series  => {
                series => ["\n=============/ ", " /============="],
            },
            section => {
                section => [
                    "\n".('—' x 82)."\n%%%%% ",
                    " %%%%%\n".('—' x 82),
                    '',
                    '',
                    '',
                    {preserve => 2},
                ],
            },
            tags => {
                anthro  => ['[', ']', ';', ';', ' '],
                general => ['[', ']', ';', ';', ' '],
                ops     => ['', '', '', '', ''],
            },
            url => {
                url           => ['', ''],
                url_attribute => [' (', ')'],
            },
            description => {
                description => ['#', ''],
            },
        }; #}}}
    ## drsr_H {{{
        my $drsr_H = {
            libName => {libName => ['', '']},
            preserve => {
                preserve => ['', '', '', '', '', { section => 1 }],
            },
            title => {
                title           => ["\n`", '`', '', '', '', {series => 1}],
                title_attribute => [' (', ')'],
            },
            author => {
              author => [
                  "\n‌\n\n".('-' x 3)."\n\n".('-' x 3)."\n"."#####",
                  '',
                  '',
                  '',
                  '',
                  3,
              ],
              author_attribute => [' (', ')'],
            },
            series  => {
                series => ["\n-> **=== ", " ===** <-"],
            },
            section => {
                section => [
                    "\n!!!info\n    ##",
                    "",
                    '',
                    '',
                    '',
                    {preserve => 2},
                ],
            },
            tags => {
                anthro  => ['[', ']', ';', ';', ' '],
                general => ['[', ']', ';', ';', ' '],
                ops     => ['', '', '', '', ''],
            },
            url => {
                url           => ['', ''],
                url_attribute => [' (', ')'],
            },
            description => {
                description => ['*', '*'],
            },
        }; #}}}
    #}}}
    ## Opts
    my $args = {
        attribs  => '01',
        delims   => '01',
        prsv     => '01',
        mes      => '01',
    };
    ## masterbin
        hasher({
            name => 'masterbin',
            args => $args,
            drsr => $drsr_M,
            prsv => {
                till => ['section', 1]
            },
            fnames => {
                input => './masterbin.txt',
                dspt => './deimos.json',
                output => './db',
            },
        });

    ## tagCatalog
        hasher({
            name => 'catalog',
            args => $args,
            drsr => $drsr_C,
            prsv => {
                till => ['section', 1]
            },
            fnames => {
                input => './catalog.txt',
                dspt => './deimos.json',
                output => './db',
            },
        });

    ## hmofa_lib
        hasher({
            name => 'hmofa_lib',
            args => $args,
            drsr => $drsr_C,
            prsv => {
                till => ['section', 1]
            },
            fnames => {
                input => './hmofa_lib.json',
                dspt => './deimos.json',
                output => './db',
            },
        });

}
# SUBROUTINES {{{1
#------------------------------------------------------

#===| hasher() {{{2
sub hasher {

    my $db = _init(shift @_);

    genDspt($db,'pathtodspt');
    getMatches($db,'pathtomatches');
    divy($db);

    return $db;
}


#===| _init() {{{2
sub _init {

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
    unless ($opts->{drsr}) {die "User did not provide 'drsr'!"};
    unless ($opts->{prsv}) {die "User did not provide 'prsv'!"};
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


#===| genDspt() {{{2
sub genDspt {

    my $db = shift @_;
    my $dspt = do {
        open my $fh, '<', $db->{opts}{fnames}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{libName} = { order =>'0'};
    $dspt->{prsv} = { order =>'-1'};

    ## --- Generate Regexs
    for my $obj (keys %$dspt) {

        my $objDSPT = $dspt->{$obj};
        for my $key (keys %$objDSPT) {
            if ($key eq 're') { $objDSPT->{re} = qr/$objDSPT->{re}/ }
            if ($key eq 'attributes') {

                my $attrDSPT = $objDSPT->{attributes};
                for my $attr (keys %$attrDSPT) {
                    $attrDSPT->{$attr}[0] = qr/$attrDSPT->{$attr}[0]/;
                    if (scalar $attrDSPT->{$attr}->@* >= 3) {
                        my $delims = join '', $attrDSPT->{$attr}[2][0];
                        $attrDSPT->{$attr}[3] = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
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
    $dspt->{meta}{ord_max} = (
        sort {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];

    # limit
    my @pntstr = split /\./, $dspt->{meta}{ord_max};
    $pntstr[$#pntstr]++;
    $dspt->{meta}{ord_limit} = join '.', @pntstr;

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
    open my $fh, '<', $db->{fnames}{input}
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
                        raw => $line,
                        LN  => $.,
                    }; push $db->{matches}{objs}{$obj}->@*, $match;
                }
            }
            ## --- PRESERVES
            if (!$match and _isPrsv($db,'NULL','',$FR_prsv)) {
                $match = {
                    obj => 'preserve',
                    val => $line,
                    LN  => $.,
                }; push $db->{matches}{objs}{preserve}->@*, $match;

            ## --- MISS
            } elsif (!$match) {
                $match = {
                    obj => 'miss',
                    val => $line,
                    LN  => $.,
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

    $db->{result} = { libName => $db->{opts}{name}};
    $db->{m} = {};

    $db->{m}{reffArray} = [$db->{result}];
    $db->{m}{point} = [1];
    $db->{m}{pointer} = [];

    _leveler($db);

    delete $db->{m};

    return $db;
}
#===| _leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub _leveler {

    my ($db) = @_;

    ## check existance of OBJ at current point
    my $obj = _getObj( $db );
    unless ($obj) { return }

    ## Reverence Arrary for the current recursion
    my $recursionReffArray;
    while ($obj) {

        ## Checking existance of recursionReffArray
        unless (defined $recursionReffArray) { $recursionReffArray->@* = $db->{reffArray}->@* }

        ## divy
        divyMatches( $db );

        ## Check for CHILDREN
        _changePointLvl($db->{m}{point}, 1);
        _leveler($db);
        _changePointLvl($db->{m}{point});
        $db->{m}{reffArray}->@* = $recursionReffArray->@*;

        ## Check for SYBLINGS
        if (scalar $db->{m}{point}->@*) {
            $db->{m}{point}[-1]++;
        } else { last }

        $obj = _getObj($db);
    }
    ## Preserves
    if (_getPointStr($db) eq $db->{dspt}{meta}{ord_limit}) {
        $db->{m}{point}->@* = (-1);

        divyMatches($db);
    }

    return $db;
}


#===| _checkMatches() {{{2
sub _checkMatches {

    my $db = shift @_;
    my $obj  = _getObj($db);
    my $divier  = \&divyMatches;

    if (exists $db->{matches}{$obj}) {
        $divier->($db);
    }
}


#===| _divyMatches() {{{2
sub _divyMatches {

    my $db = shift @_;
    my $obj = _getObj($db); #db->get_obj()
    my @objMatches = $db->{m}{matches}{objs}{$obj}->@*;

    ## --- REFARRAY LOOP
    my $refArray = $db->{m}{reffArray};
    my $ind = (scalar @$refArray) - 1;
    for my $ref (reverse @$refArray) {
        my $ref_LN = $ref->{LN} // 0;

        ## --- MATCHES LOOP
        my $childObjs;
        for my $match (reverse @objMatches) {

            if ($match->{LN} > $ref_LN) {
                my $match = pop @objMatches;
                genAttributes( $db, $match);
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

#===| _genAttributes() {{{2
sub _genAttributes {

    my $db  = shift @_;
    my $match = shift @_;

    my $obj       = _getObj($db);
    $match->{raw} = $match->{$obj};

    if (exists $db->{dspt}{$obj}{attributes}) {
        my $attrDSPT = $db->{dspt}{$obj}{attributes};
        my @attrORDS = sort {
            $attrDSPT->{$a}[1] cmp $attrDSPT->{$b}[1];
            } keys $attrDSPT->%*;

        for my $attr (@attrORDS) {
            my $sucess   = $match->{$obj} =~ s/$attrDSPT->{$attr}[0]//;
            my $fish     = {};
            $fish->{caught} = $1 if $1;
            if ($sucess and !$1) {$fish->{caught} = '' }
            if ($fish->{caught} || exists $fish->{caught}) {
                $match->{$attr} = $fish->{caught};

                if (scalar $attrDSPT->{$attr}->@* >= 3) {
                    _delimitAttr($db, $attr, $match);
                }
            }
        }
        unless ($match->{$obj}) {
            $match->{$obj} = [];
            for my $attr(@attrORDS) {
                if (exists $match->{$attr}) {
                    push $match->{$obj}->@*, $match->{$attr}->@*;
                }
            }
        }
    }
}

#===| _delimitAttr() {{{2
sub _delimitAttr {

    ## Attributes
    my $db       = shift @_;
    my $objKey   = _getObj($db);
    my $attrDSPT = $db->{dspt}{$objKey}{attributes};

    ## Regex for Attribute Delimiters
    my $attr = shift @_;
    my $delimsRegex = $attrDSPT->{$attr}[3];

    ## Split and Grep Attribute Match-
    my $match = shift @_;
    $match->{$attr} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attr} )
    ];
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



#===| _changePointLvl() {{{2
sub _changePointLvl {

    my $point = shift @_;
    my $op    = shift @_;

    if ($op) { push $point->@*, 1 }
    else     { pop $point->@*, 1 }

    return $point;

}


#===| _changePointStrInd() {{{2
sub _changePointStrInd {

    my $pointStr = ($_[0] ne '') ?$_[0]
                                 :{ die("pointStr cannot be an empty str! In ${0} at line: ".__LINE__) };
    my @point    = split /\./, $pointStr;
    my $op       = $_[1];

    if ($op) { $point[-1]++ }
    else     { $point[-1]-- }

    $pointStr = join '.', @point;
    return $pointStr;
}


#===| _getObj() {{{2
# return OBJECT at current point
# return '0' if OBJECT doesn't exist for CURRENT_POINT!
# die if POINT_STR generated from CURRENT_POINT is an empty string!
sub _getObj {

    my $db = shift @_;
    my $pntstr = join( '.', $db->{m}{point}->@* )
        or  die "pointStr cannot be an empty string!";
    return $db->{dspt}{meta}{ord_map}{$pntstr} // 0;

}


#===| _getPointStr() {{{2
sub _getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $db = shift @_;
    my $pointStr = join('.', $db->{m}{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| _longest() {{{2
sub _longest {
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

