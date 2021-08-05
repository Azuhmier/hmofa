#!/usr/bin/env perl
#============================================================
#
#         FILE: jsonGen.pl
#        USAGE: ./jsonGen.pl
#   DESCRIPTION: ---
#        AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#       Created: sprig 2021
#===========================================================
use strict;
use warnings;
use utf8;
use Storable qw(dclone);
use JSON::PP;
use Data::Dumper;
use List::Util qw( uniq );
use Data::Walk;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');

my $erreno;
my $CONFIG = '~/.hmofa';
sub mes;


# MAIN {{{1
#------------------------------------------------------
{
    ## --- DRESSERS  {{{
    ## dresser_M {{{
        my $dresser_M = {
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
    ## dresser_C {{{
        my $dresser_C = {
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
    #}}}
    ## --- OPTS {{{
    # ;opts
        my $opts = genOpts({
            ## Processes
            delegate => [1,1,0,0,0,0,0,0],
            leveler  => [1,0,0,0,0,0,0,0],
            divy     => [1,0,0,0,0,0,0,0],
            write    => [1,1,0,0,0.0,0,0],
            attribs  => [1,0,0,0,0,0,0,0],
            delims   => [1,0,0,0,0,0,0,0],
            encode   => [1,0,0,0,0,0,0,0],

            ## STDOUT
            verbose  => 1,

            ## MISC
            sort    => 1,
        });
    my $opts2 = genOpts2({
        ## Processes
        combine  => [1,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0],
        delegate => [1,0,0,0,0,0,0,0],
        cmp      => [1,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => 1,

        ## MISC
        sort    => 1,
    });
    #}}}
    ## --- DELEGATES {{{
    ## masterbin
        delegate({
            opts     => $opts,
            name     => 'masterbin',
            dresser  => $dresser_M,
            preserve => {
                libName => [ ['', [0]], ],
                section => [ ['FOREWORD', [1]], ],
            },
            fileNames => {
                fname  => '../masterbin.txt',
                output => './json/masterbin.json',
                dspt   => './json/deimos.json',
            },
        });

      ## tagCatalog
        delegate({
            opts     => $opts,
            name     => 'catalog',
            dresser  => $dresser_C,
            preserve => {
                libName => [ ['',[0]], ],
                section => [ ['Introduction/Key', [1,1,1]], ],
            },
            fileNames => {
                fname  => '../tagCatalog.txt',
                output => './json/catalog.json',
                dspt   => './json/deimos.json',
            },
        });

     ## hmofa_lib
     delegate2({
         opts => $opts2,
         name => 'hmofa_llib',
         fileNames => {
             fname    => ['./db/catalog/catalog.json', './db/masterbin/masterbin.json',],
             output   => './json/hmofa_lib.json',
             dspt     => './json/deimos.json',
             external => ['./json/gitIO.json'],
         },
     });


}


# SUBROUTINES {{{1
#------------------------------------------------------

#===| delegate() {{{2
sub delegate {

    my $db = shift @_;
    my $delegate_opts = $db->{opts}{delegate};
    if ($delegate_opts->[0]) {


        ## --- sigtrap {{{
        $SIG{__DIE__} = sub {
            if ($db and exists $db->{debug}) {
                print $_ for $db->{debug}->@*;
                print $erreno if $erreno;
            }
        }; #}}}
        ## --- checks  #{{{
        init($db); # }}}
        ## verbose 1 #{{{
        mes "\n...Generating $db->{name}", $db, [-1], $delegate_opts->[1]; #}}}
        ## --- matches {{{
        getMatches($db);
        $db->{matchesByLine}->%* =
            map {
                map {
                    $_->{LN} => $_
                } $db->{matches}{$_}->@*
            } keys $db->{matches}->%*; #}}}
        ## --- convert #{{{
        leveler($db,\&checkMatches); # }}}
        ## --- encode  #{{{
        encodeResult($db); # }}}
        ## --- write array {{{
        my $writeArray = genWriteArray($db);
        open my $fh, '>', './result/'.$db->{result}{libName}.'.txt' or die $!;
        for (@$writeArray) {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
        close $fh; #}}}
        ## --- output {{{

        if ($delegate_opts->[1]) {
            ## Matches Meta
            my $matches_Meta = $db->{meta}{matches};
            my $max = length longest(keys $matches_Meta->%*);

            ## Subs
        }
        #}}}
        ## --- WRITE {{{
        my $headDir = './db';
        my $dirname = $headDir.'/'.$db->{result}{libName};
        mkdir $headDir if (!-d './db');
        mkdir $dirname if (!-d $dirname);

        ## META
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{meta});
            my $fname    = $dirname.'/meta.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## RESULT
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{result});
            my $fname    = $dirname.'/'.$db->{result}->{libName}.'.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{matches});
            my $fname    = $dirname.'/matches.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHESBYLINE
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{matchesByLine});
            my $fname    = $dirname.'/matchesByLine.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## DSPT
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{dspt});
            my $fname    = $dirname.'/dspt.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }

        opendir my $dh, $headDir or die "Error in opening dir $headDir\n";
            while (readdir $dh) {}
        closedir $dh;
        # }}}
        ## verbose 1 #{{{
        my $max = 22;
        mes "...summarizing $db->{name}",   $db, [-1], $delegate_opts->[1];
        mes "KEY ".(' 'x($max-3))." VALUE", $db, [0], $delegate_opts->[1];
        mes "- ".(' 'x($max-1))." -",       $db, [0], $delegate_opts->[1];
        for my $key (sort {$a cmp $b} keys $db->%*) {
            my $S0 = " " x ($max - length $key);
            mes "$key ${S0} $db->{$key}", $db, [0], $delegate_opts->[1];
        }
        print $_ for $db->{debug}->@*; #}}}

        return $db;
    }
}


#===| init() {{{2
sub init {

  my $db = shift @_;

  ## --- properties {{{3
  unless (exists $db->{point})     {$db->{point}     = [1]}
      else {warn "WARNING!: 'point' is already defined by user!"}
  unless (exists $db->{result})    {$db->{result}    = {libName => $db->{name}}}
      else {warn "WARNING!: 'result' is already defined by user!"}
  unless (exists $db->{reffArray}) {$db->{reffArray} = [$db->{result}]}
      else {warn "WARNING!: 'reffArray' is already defined by user!"}
  unless (exists $db->{meta})      {$db->{meta}      = {}}
      else {warn "WARNING!: 'meta' is already defined by user!"}
  unless (exists $db->{debug})     {$db->{debug}     = []}
      else {warn "WARNING!: 'debug' is already defined by user!"}
  unless (exists $db->{pointer})   {$db->{pointer}   = []}
      else {warn "WARNING!: 'index' is already defined by user!"}
  genReservedKeys($db);

  ## --- fnames {{{3
  unless ($db->{fileNames}{dspt})   {die "User did not provide filename for 'dspt'!"}
      genDspt($db);
      validate_Dspt($db);
  unless ($db->{fileNames}{fname})  {die "User did not provide filename for 'fname'!"}
  unless ($db->{fileNames}{output}) {die "User did not provide filename for 'output'!"} #}}}
}
#===| genReservedKeys() {{{2
sub genReservedKeys {

    my $db = shift @_;
    my $ARGS = shift @_;
    my $defaults = {
        raw       => [ 'raw',       1 ],
        LN        => [ 'LN',        2 ],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %$ARGS;

    ## check for duplicates: keys
    my @keys  = sort map  {$defaults->{$_}[0]} keys %$defaults;
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## check for duplicates: order numbers
    my @order = sort map {$defaults->{$_}[1]} keys %$defaults;
    my %DupesOrderNum;
    for (@order) { die "Reserved keys cannot have identical orders!" if $DupesOrderNum{$_}++ }

    $db->{reservedKeys} = $defaults;
}

#===| gendspt {{{2
sub genDspt {

    my $db = shift @_;
    my $dspt = do {
        open my $fh, '<', $db->{fileNames}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{libName} = { order =>'0', groupName =>'LIBS'};
    $dspt->{preserve} = { order =>'-1', groupName =>'PRESERVE'};

    ## Generate Regex's
    for my $obj (keys %$dspt) {

        my %objHash = $dspt->{$obj}->%*;
        for my $key (keys %objHash) {
            if ($key eq 're') { $objHash{re} = qr/$objHash{re}/ }
            if ($key eq 'attributes') {

                my %attribHash = $objHash{attributes}->%*;
                for my $attrib (keys %attribHash) {
                    $attribHash{$attrib}[0] = qr/$attribHash{$attrib}[0]/;
                }
            }
        }
    }

    ## preserve
    if (exists $db->{preserve}) {
       my $preserve = $db->{preserve};
        for my $obj (keys %$preserve) {
            my $preserve_obj          = dclone($preserve->{$obj});
            $dspt->{$obj}{preserve}->@* = @$preserve_obj;
        }
        delete $db->{preserve};
    }
    $db->{dspt} = dclone($dspt);
}
#===| validate_Dspt() {{{2
sub validate_Dspt {

    my $db = shift @_;
    my $dspt = $db->{dspt};
    my %hash = ();

    ## check for duplicates: order
    my @keys  = sort map { exists $dspt->{$_}{order} and  $dspt->{$_}{order} } keys %{$dspt};
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## META
    $db->{meta}{dspt} = {};
    my $dspt_meta = $db->{meta}{dspt};


    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $dspt_meta->{max} = (
        sort {
            length $b <=> length $a
            ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];
}


#===| getMatches() {{{2
sub getMatches {

    my $db = shift @_;
    my $dspt = $db->{dspt};

    ## --- open tgt file for regex parsing
    open my $fh, '<', $db->{fileNames}{fname}
        or die $!;
    {
        while (my $line = <$fh>) {

            ## --- Regex LOOP
            my $F;
            for my $obj (keys %$dspt) {
                if ($dspt->{$obj}{re} and $line =~ /$dspt->{$obj}{re}/) {
                    $F=1;
                    my $match = {
                        LN   => $.,
                        $obj => $1,
                        raw  => $line,
                    }; push $db->{matches}{$obj}->@*, $match;
                }
            }

            ## --- Put MISSES in PRESERVES
            unless ($F) {
                my $match = {
                    LN      => $.,
                    preserve => $line,
                }; push $db->{matches}{preserve}->@*, $match;
            }
        }
    } close $fh ;

    ## -- utilize regex matches
    $db->{static}{matches} = dclone($db->{matches});
    for my $obj (keys %$dspt, 'preserve') {
        $db->{meta}{matches}{$obj}{count} = $db->{matches}{$obj} ? scalar $db->{matches}{$obj}->@*
                                                                 : 0;
    }

}


#===| leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub leveler {

    my ($db,$sub) = @_;
    my $opts_leveler = $db->{opts}{leveler};

    if ($opts_leveler->[0]) {

        ## check existance of OBJ at current point
        my $obj = getObj( $db );
        unless ($obj) { return }

        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ($obj) {

            ## verbose 1 {{{
            mes getPointStr($db)." $obj", $db, [0], $opts_leveler->[1]; #}}}

            ## Checking existance of recursionReffArray
            unless (defined $recursionReffArray) { $recursionReffArray->@* = $db->{reffArray}->@* }

            ## checkMatches
            $sub->( $db );

            ## Check for CHILDREN
            changePointLvl($db->{point}, 1);
            leveler( $db, $sub);
            changePointLvl($db->{point});
            $db->{reffArray}->@* = $recursionReffArray->@*;

            ## Check for SYBLINGS
            if (scalar $db->{point}->@*) {
                $db->{point}[-1]++;
            } else { last }

            $obj = getObj($db);
        }
        return $db->{result};
    }
}


#===| checkMatches() {{{2
sub checkMatches {

    my $db = shift @_;
    my $obj  = getObj($db);
    my $divier  = \&divyMatches;

    if (exists $db->{matches}{$obj}) {
        $divier->($db);
    }
}


#===| divyMatches() {{{2
sub divyMatches {

    my $db = shift @_;
    my $opts_divy = $db->{opts}{divy};
    if ($opts_divy->[0]) {

        my $obj  = getObj($db);
        my $dspt = $db->{dspt};
        my $objMatches = [
            grep {
                exists $_->{LN}
            } $db->{matches}{$obj}->@* ];
        my $matchesByLine = [
            grep {exists $_->{LN}}
            map  {$db->{matchesByLine}->{$_}}
            sort {$a<=>$b}
            keys $db->{matchesByLine}->%*
        ];

        ## verbose: prev_(lvl)obj 0 {{{
        my $prev_lvlObj = '';
        my $prev_obj = ''; #}}}

        ## --- REFARRAY LOOP
        my $refArray = $db->{reffArray};
        my $ind = (scalar @$refArray) - 1;
        for my $ref (reverse @$refArray) {
            my $lvlObj  = getLvlObj($db, $ref);
            my $ref_LN  = $ref->{LN} ?$ref->{LN} :0;
            my @MATCHES = ([ @$objMatches ]);

            ## --- PRESERVE{{{
            my $lvlPreserve = $dspt->{$lvlObj}{preserve} // undef;
            my $F_inclusive=0;
            if ($lvlPreserve) {

                ## INCLUSIVE/EXCLUSIVE
                my $F;
                my $correction;
                if ( (grep { $_->[0] eq $ref->{$lvlObj} } @$lvlPreserve)[0] ) {
                    $F_inclusive=1;
                    $correction=0;
                } elsif ($lvlPreserve->[0][0] eq '' && scalar @$lvlPreserve == 1) {
                    $correction=($lvlObj eq 'libName') ?0 :1;
                } else { $F=1 }

                unless ($F) {

                    ## --- ELEIGBLE_OBJ
                    my @elegible_obj = grep {
                        exists $dspt->{$_}{order}
                            and
                        $_ ne 'preserve'
                            and
                        scalar (split /\./, $dspt->{$_}{order})
                            ==
                        scalar (split /\./, $dspt->{$lvlObj}{order}) + $correction
                    } keys %$dspt;

                    ## --- LN
                    my $LN = $ref_LN;
                    for my $obj (@elegible_obj) {
                        for my $item ($db->{static}{matches}{$obj}->@*) {
                            if ($item->{LN} > $LN) {
                                $LN = $item->{LN}; last;
                            }
                        }
                    }

                    ## --- PRES ARRAY
                    my $pres_ARRAY = [
                        grep {
                            exists $_->{LN}
                                &&
                            $_->{LN} < $LN
                                &&
                            ($F_inclusive ?1 :$_->{LN} > $ref_LN)
                        } @$matchesByLine
                    ];

                    ## --- PRES ARRAY CLEANUP
                    for my $hash (@$pres_ARRAY) {
                        next if exists $hash->{preserve};
                        my $obj = getLvlObj($db,$hash);
                        $hash->{preserve} = $hash->{raw};
                        #delete $hash->{$obj};
                        %$hash =
                            map {
                                $_ => $hash->{$_}
                            }
                            grep {
                                $_ ne $obj
                                    and
                                $_ ne 'raw'
                            } keys %$hash;
                    }

                    ## --- MATCHES
                    if ($F_inclusive) { $MATCHES[0] = $pres_ARRAY}
                    else              { push @MATCHES, $pres_ARRAY}
                }
            } #}}}

            ## --- MATCH ARRAYS LOOP
            my $cnt;
            for my $array (@MATCHES) {
                $cnt++;
                my $F_partial = ($cnt > 1) ?1 :0;

                ## verbose: mes 0{{{
                my $mes = []; #}}}

                ## --- MATCHES LOOP {{{
                my $childObjs;
                my $F = 0;
                for my $match (reverse @$array) {
                    next unless $match;
                    $obj = exists $match->{preserve} ?'preserve' :getLvlObj($db, $match);

                    ## CHECKS
                    unless ($match->{LN}) {
                        $erreno = "$lvlObj ERROR!: undef match->{LN} at $0 line ".__LINE__;
                        die }
                    unless (exists $match->{$obj}) {
                        $erreno = "ERROR!: undef match->{obj} at $0 line ".__LINE__;
                        die }

                    ## --- MATCH FOUND {{{
                    if ($match->{LN} > $ref_LN) {
                        my $match = pop @{ $F_inclusive || $F_partial ?$array :$objMatches };
                        my $attrDebug = genAttributes( $db, $match, [$F_partial, $F_inclusive]);
                        push @$childObjs, $match;
                    } else { last } #}}}
                    ## verbose 1,1 {{{
                    if ($obj ne $prev_obj) {
                        push @$mes, mes "$obj -> $lvlObj", $db, [1,0,1], $opts_divy->[1] == 1;
                        push @$mes, mes "[$ref_LN, $ind]", $db, [1,0,1], $opts_divy->[6] == 1;
                    } $prev_obj = $obj; #}}}
                } #}}}
                ## --- MATCHES TO REFARRAY {{{
                if ($childObjs) {
                    my $childObjsClone = [ reverse @{ dclone($childObjs) } ];

                    if ($F_inclusive) {
                        unless (exists $refArray->[$ind]{PRESERVE}) {
                            $refArray->[$ind]{PRESERVE} = []
                        }
                        @$childObjsClone = map {$db->{matchesByLine}{$_->{LN}} } @$childObjsClone;
                        my $ref = dclone($childObjsClone);
                        push $refArray->[$ind]{PRESERVE}->@*, @$ref;

                    } else {
                        my $groupName =  $F_partial ?'PRESERVE' :getGroupName($db, $obj);
                        $refArray->[$ind]{$groupName} = $childObjsClone;
                        splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjsClone) );

                    }

                    for my $hashRef (@$childObjs) { %$hashRef = () }

                    # verbose 1,1{{{
                    if ($mes and scalar @$mes) {
                        mes "$_", $db, [-1,1,0], $opts_divy->[1] == 1 for @$mes;
                    } #}}}

                } #}}}

            } $ind--;
        }
    }
}

#===| genAttributes() {{{2
sub genAttributes {

    my $db  = shift @_;
    my $match = shift @_;
    my $flags = shift @_;
    my $attr_opts = $db->{opts}{attribs};

    ## verbose {{{
    my $debug     = [];
    #}}}

    if ($attr_opts->[0] and !$flags->[0] and !$flags->[1]) {

        my $obj       = getObj($db);
        my $objReff   = $db->{dspt}{$obj};
        $match->{raw} = $match->{$obj};

        if (exists $objReff->{attributes}) {
            my $attrDSPT       = $objReff->{attributes};
            my @attrOrderArray = sort {
                $attrDSPT->{$a}[1] cmp $attrDSPT->{$b}[1];
                } keys $attrDSPT->%*;

            for my $attrib (@attrOrderArray) {
                my $attrReff = $attrDSPT->{$attrib};
                my $sucess   = $match->{$obj} =~ s/$attrReff->[0]//;
                my $fish     = {};
                $fish->{caught} = $1 if $1;
                if ($sucess and !$1) {$fish->{caught} = '' }
                if ($fish->{caught} || exists $fish->{caught}) {
                    $match->{$attrib} = $fish->{caught};

                    # verbose {{{
                    if ($attr_opts->[1] == 1) {
                        push $debug->@*, mes("|${attrib}|",              $db, [6, 1, 1], $attr_opts->[1] == 1);
                        push $debug->@*, mes(" '".$match->{$attrib}."'", $db, [-1, 0, 1], $attr_opts->[1] == 1);
                    }
                    #}}}

                    if (scalar $attrReff->@* == 3) {
                        delimitAttribute($db, $attrib, $match);
                    }
                }
            }


            unless ($match->{$obj}) {
                $match->{$obj} = [];
                for my $attrib (@attrOrderArray) {
                    if (exists $match->{$attrib}) {
                        push $match->{$obj}->@*, $match->{$attrib}->@*;
                    }
                }
            }
        }
    }
    return $debug;
}


#===| delimitAttribute() {{{2
sub delimitAttribute {

    ## Attributes
    my $db           = shift @_;
    my $objKey         = getObj($db);
    my $attributesDSPT = $db->{dspt}{$objKey}{attributes};

    ## Regex for Attribute Delimiters
    my $attributeKey = shift @_;
    my $delims       = join '', $attributesDSPT->{$attributeKey}[2][0];
    my $delimsRegex  = ($delims ne '') ? qr{\s*[\Q$delims\E]\s*}
                                       : '';

    ## Split and Grep Attribute Match-
    my $match = shift @_;
    $match->{$attributeKey} = [
        grep { $_ ne '' }
        split( /$delimsRegex/, $match->{$attributeKey} )
    ];
}


#===| encodeResult() {{{2
sub encodeResult {

    my $db  = shift @_;
    if  ($db->{opts}{encode}[0]) {
        my $fname = $db->{fileNames}{output};
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            if ($db->{opts}{sort}) {
              $json_obj->sort_by( sub { cmpKeys( $db, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
            }
            my $json  = $json_obj->encode($db->{result});
            open( my $fh, '>' ,$fname ) or die $!;
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close( $fh );
        }
    }
}


#===| genWriteArray(){{{2
sub genWriteArray {

    my $db         = shift;
    my $result     = dclone($db->{result});
    my $dspt       = $db->{dspt};
    my $write_opts = $db->{opts}{write};
    my $writeArray;
    my $verbose;
    my %dresser = $db->{dresser}->%*;

    if ($write_opts->[0]) {
        $db->{pointer}   = [0];  my $pointer   = $db->{pointer};
        $db->{point}     = [-1]; my $point     = $db->{point};
        $db->{objChain}  = [];   my $objChain  = $db->{objChain};
        $db->{objChain2} = [];   my $objChain2 = $db->{objChain2};
        $db->{childs}    = {};   my $childs    = $db->{childs};

        ## verbose 1{{{
        mes "...Writing $db->{name}", $db, [-1], $write_opts->[1];
        # }}}

        ## append DSPT {{{
        #if ($db->{result}->{libName} eq 'catalog') {%dresser = %dresser2}
        for my $obj (keys %$dspt) {
            my $objDspt         = $dspt->{$obj};
            my $dressRef        = $dresser{$obj};
            $objDspt->{dresser} = $dressRef;
        }
        #}}}

        # ===| $preprocess_sorted {{{
        my $preprocess_sorted = sub {

            my @children = @_;

            if ($Data::Walk::type eq 'HASH') {

                ## Tranform array to hash
                my $hash = {};
                my $cnt = 0;
                for (@children) {
                    $hash->{$children[$cnt - 1]} = $_ if ($cnt & 1);
                    $cnt++;
                }

                ## Tranform hash to array whilst sorting keys
                @children = ();
                for (sort {
                            if    ($a eq 'PRESERVE' and $b ne 'libName' and $b ne 'section') {-1}
                            elsif ($a eq 'PRESERVE' and $b eq 'libName' or  $b eq 'section') {1}
                            elsif ($b eq 'PRESERVE' and $a ne 'libName' and $a ne 'section') {1}
                            elsif ($b eq 'PRESERVE' and $a eq 'libName' or  $a eq 'section') {-1}
                            elsif ($a eq 'SERIES' and $b eq 'STORIES') {1}
                            elsif ($b eq 'SERIES' and $a eq 'STORIES') {-1}
                            else { cmpKeys( $db, $a, $b, $hash, [1]) }
                          } keys %{$hash}) { push @children, ($_, $hash->{$_}) }

            }
            return @children;

        }; #}}}
        # ===| $wanted {{{
        my $wanted = sub {
            my $container = $Data::Walk::container;
            my $lvl       = ($Data::Walk::depth - 2)/2;

            if ($Data::Walk::type eq 'HASH' and $lvl >= 0) {
                my $obj = getLvlObj($db, $container);
                if ($_ eq $obj) {
                    my $dresser  = $db->{dspt}{$obj}{dresser};

                    ## --- POINTER #{{{
                    # pop pointer if ascending levels
                    my $prior_lvl = (scalar @$pointer) - 1;
                    if ($lvl < $prior_lvl) {
                        if (scalar @$pointer != 1) {
                            my $cnt = $prior_lvl - $lvl;
                            pop @$pointer for (0 .. $cnt);
                        }
                    } $pointer->[$lvl] = $obj;

                    ## verbose 2{{{
                    # the lvl can not increase while the objlvl decreases
                    # the lvl can not decrease while the objlvl increases

                    $childs->{$obj}++;
                    my $objOrder = $db->{dspt}{$obj}{order};

                    my $F1 = 0;
                    if (getPointStr($db) ne $objOrder) {
                        #@$point = split /\./, $objOrder;
                        $db->{point}->@* = split /\./, $objOrder;
                        $F1 = 1;
                    } my $pointStr = join '.', @$pointer;

                    my $S0 = " " x (47 - length $pointStr);
                    my $S1 = " " x (9 - length $objOrder);
                    my $item = (ref $container->{$obj} eq 'ARRAY') ? '['.(join ', ', $container->{$obj}->@*).']'
                                                                   : $container->{$obj};
                    #$item = $container->{$obj};

                    mes "[$F1, $lvl] $objOrder ${S1} $pointStr ${S0} $item",
                        $db, [0], $write_opts->[2]; #}}}
                    #}}}

                    ## --- String: d0, d1 #{{{
                    my $str = '';
                    my $ref = ref $container->{$obj};
                    if ($ref ne 'ARRAY') {
                        $str .= $dresser->{$obj}[0]
                              . $container->{$obj}
                              . $dresser->{$obj}[1];
                    } #}}}

                    ## --- Attributes String: d0, d1, d2, d3, d4{{{
                    my $attrStr = '';
                    my $attrDspt = getAttrDspt($db, $obj);
                    if ($attrDspt) {

                        for my $attr (
                            sort {
                                $attrDspt->{$a}[1]
                                    cmp
                                $attrDspt->{$b}[1]
                            } keys %$attrDspt
                        ) {

                            ## Check existence of attributes
                            if (exists $container->{$attr}) {
                                my $attrItem = $container->{$attr};

                                ## Item Arrays
                                if (exists $attrDspt->{$attr}[2]) {
                                    my @itemPartArray = ();
                                    for my $part (@$attrItem) {
                                        $part = $dresser->{$attr}[2]
                                              . $part
                                              . $dresser->{$attr}[3];
                                        push @itemPartArray, $part;
                                    }
                                    $attrItem = join $dresser->{$attr}[4], @itemPartArray;
                                }

                                $attrStr .= $dresser->{$attr}[0]
                                         . $attrItem
                                         . $dresser->{$attr}[1];

                            }
                        }
                    } #}}}

                    ## --- Line Striping: d5,d6 #{{{
                    my $F_empty;
                    push @$objChain, [ $lvl, $obj ];
                    if (exists $objChain->[-2] and exists $dresser->{$obj}[5]) {

                        my $prevObj = $objChain->[-2][1];
                        my $prevLvl = $objChain->[-2][0];

                        my $ref = ref $dresser->{$obj}[5];
                        my $tgtObjs = ($ref eq 'HASH') ?$dresser->{$obj}[5]
                                                       :0;

                        ## strip lines only after target object
                        if ($tgtObjs && exists $tgtObjs->{$prevObj}) {
                            my $cnt = $tgtObjs->{$prevObj};

                            # descending lvl
                            if ($prevLvl < $lvl) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                                $F_empty = 1 if $str eq '';
                            }

                            # ascending lvl
                            elsif ($prevLvl > $lvl) {
                                $str =~ s/.*\n// for (1 .. $cnt);
                            }

                            # maintaining lvl
                            elsif ($prevLvl == $lvl) {

                                # Preserve
                                if ($obj eq 'preserve') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }

                                # Post Preserve
                                elsif ($prevObj eq 'preserve') {
                                    $str =~ s/.*\n// for (1 .. $cnt);
                                }
                            }
                        }

                        ## strip lines after all objects
                        # descending lvl
                        elsif (!$tgtObjs and $prevLvl < $lvl) {
                            my $cnt = $dresser->{$obj}[5];
                            $str =~ s/.*\n// for (1 .. $cnt);
                        }

                    } #}}}

                    ## --- String Concatenation {{{
                    $str = ($str) ?$str . $attrStr
                                  :$attrStr;
                    chomp $str if $obj eq 'preserve';
                    unless ($F_empty) { push @$writeArray, $str if $obj ne 'libName'}
                    #}}}

                    if ($db->{dspt}{$obj}{scalar} and $objChain->[-2][1] eq $obj) {
                        $erreno = "ERROR: Scalar obj '$obj' was repeated!";
                        die;
                    }
                }
            }
        }; #}}}

        walkdepth { preprocess => $preprocess_sorted, wanted => $wanted },  $result;

        ## verbose 1 #{{{
        my $max = 11;
        mes "OBJ ".(' 'x($max-3))." CNT", $db, [0], $write_opts->[1];
        mes "- ".(' 'x($max-1))." -",     $db, [0], $write_opts->[1];
        for my $obj (sort {$childs->{$a} <=> $childs->{$b}} keys $childs->%*) {
            my $S0 = " " x ($max - length $obj);
            mes "$obj ${S0} $childs->{$obj}", $db, [0], $write_opts->[1];
        }#}}}
   }
   return $writeArray ?$writeArray :0;
}
#===| delegate2() {{{2
sub delegate2 {

    my $db = shift @_;

    ## --- sigtrap #{{{
    $SIG{__DIE__} = sub {
        if ($db and exists $db->{debug}) {
            print $_ for $db->{debug}->@*;
            print $erreno if $erreno;
        }
    };#}}}

    ## --- checks #{{{
    init2($db);#}}}

    ## --- cmp {{{
    my $catalog   = dclone $db->{hash}[0];
    my $masterbin = dclone $db->{hash}[1];
    {
        ## SETUP #{{{
        my $cmpOpt    = $db->{opts}{cmp};#}}}

        ## REMOVE PRESERVES {{{
        delete $masterbin->{PRESERVE};
        delete $catalog->{PRESERVE};
        my $SECTIONS0 = $catalog->{SECTIONS};
        my $SECTIONS1 = $masterbin->{SECTIONS};
        @$SECTIONS0   = map { $SECTIONS0->[$_] } (1 .. $SECTIONS0->$#*);
        @$SECTIONS1   = map { $SECTIONS1->[$_] } (1 .. $SECTIONS1->$#*);#}}}

        ## --- UO - LO {{{

        ## SETUP #{{{
        my $lo    = 'title';  my $LO = getGroupName($db,$lo);
        my $uo    = 'series'; my $UO = getGroupName($db,$uo);
        my $co    = 'author'; my $CO = getGroupName($db,$co);
        my $uo_uw = 'other';
        my $COs   = [$SECTIONS0->[0]{$CO}, $SECTIONS1->[0]{$CO}];
        my @UOs;
        my @LOs;
        my @COs; #}}}

        ## TAKE A LOOK # {{{
        @UOs = (); for my $CO_ (@$COs) {
            my $UO_;
            @$UO_ =
                map {
                    $_->{$UO}->@*
                }
                grep {
                    exists $_->{$UO}
                } @$CO_;
            push @UOs, $UO_;
        }
        @LOs = (); for my $UO_ (@UOs) { my @LO_ =
            map {
                {$uo => "[$_->{$uo}]"},
                $_->{$LO}->@*,
            } @$UO_;
            push @LOs, \@LO_;
        }

        ## verbose 1{{{
        mes "\n==================",        $db, [-1], $cmpOpt->[1];
        mes "%% TAKE A LOOK %%",           $db, [-1], $cmpOpt->[1];
        for my $LO_ (@LOs) {
            mes( $_->{$uo} || "    $_->{$lo}", $db, [0],  $cmpOpt->[1]) for @$LO_;
            mes "---------",                   $db, [0],  $cmpOpt->[1];
        }#}}}
        #}}}

        ## REMOVE UNWANTED UOs #{{{
        @COs = (); for my $CO_ (@$COs) {
            my $CO__;
            @$CO__ = @$CO_;
            @$CO__ =
                grep {
                    exists $_->{$UO}
                        and
                    (grep {
                        $_->{$uo} =~ /$uo_uw/i
                    } $_->{$UO}->@*)[0]
                } @$CO__;
            push @COs, [@$CO__];
        }

        for my $CO_ (@COs) {
            for my $co (@$CO_) {
                my @LOs = map { $_->{$LO}->@*} grep { $_->{$uo} =~ /$uo_uw/i } $co->{$UO}->@*;
                push $co->{$LO}->@*, @LOs;
                $co->{$UO}->@* = grep { $_->{$uo} !~ /$uo_uw/i } $co->{$UO}->@*;
            }
        } #}}}

        ## LOOK FOR dupes FOR LO #{{{
        @UOs = (); for my $CO_ (@$COs) {
            my $UO_;
            @$UO_ =
                map {
                    $_->{$UO}->@*
                }
                grep {
                    exists $_->{$UO}
                } @$CO_;
            push @UOs, $UO_;
        }
        @LOs = (); for my $UO_ (@UOs) { my @LO_ =
            map {
                $_->{$LO}->@*
            } @$UO_;
            push @LOs, \@LO_;
        }
        # intra
        my @seens; for my $LO_ (@LOs) {
            my $seen_;
            for (@$LO_) {
                $seen_->{$_->{$lo}}++; 
                die if $seen_->{$_->{$lo}} > 1 }
            push @seens, $seen_;
        }
        # inter
        my %seen; $seen{$_->{$lo}}++ for ($LOs[0]->@*, $LOs[1]->@*);
        ## verbose {{{
        mes "\n==================",       $db, [-1], $cmpOpt->[1];
        mes "%% LOOK FOR INTER dupes %%", $db, [-1], $cmpOpt->[1];
        my @dupes = grep {$seen{$_} > 1} keys %seen;
        mes "$_",                         $db, [0], $cmpOpt->[1] for @dupes; #}}}
        #}}}

        ## GET SERIES LO FOR dupes #{{{
        for my $UO_ (@UOs) { @$UO_ =
            grep {
                (grep {
                    my $lo_ = $_->{$lo};
                    (grep {
                        $lo_ eq $_
                    } @dupes)[0]
                } $_->{$LO}->@*)[0]
            } @$UO_
        }
        ## verbose {{{
        mes "\n==================",         $db, [-1], $cmpOpt->[1];
        mes "%% GET UO TITLE FOR dupes %%", $db, [-1], $cmpOpt->[1];
        for my $UO_ (@UOs) {
            mes $_->{$uo},  $db, [0], $cmpOpt->[1] for @$UO_;
            mes "---------", $db, [0], $cmpOpt->[1];
        } #}}}
        #}}}

        ## SEE IF dupes ARE THE ONLY MEMBERS OF THEIR UO #{{{
        for my $UO_ (@UOs) { 
            my $seen_ = shift @seens;
            @$UO_ =
                grep {
                    %$seen_ = ();
                    $seen_->{$_}++ for @dupes;
                    for my $lo_ ($_->{$LO}->@*) {
                        $seen_->{$lo_->{$lo}}++
                    }
                    (grep {
                        $seen_->{$_->{$lo}} == 1
                    } $_->{$LO}->@*)[0]
                } @$UO_;
        }
        ## verbose {{{
        mes "\n==================",                                $db, [-1], $cmpOpt->[1];
        mes "%% SEE IF dupes ARE THE OLNY MEMBERS OF THEIR UO %%", $db, [-1], $cmpOpt->[1];
        for my $UO_ (@UOs) {
            mes $_->{$uo},  $db, [0], $cmpOpt->[1] for @$UO_;
            mes "---------", $db, [0], $cmpOpt->[1];
        } #}}}
        #}}}

        ## CHECK IF UO ARE THE SAME #{{{
        @UOs = (); for my $CO_ (@$COs) {
            my $UO_;
            @$UO_ =
                map {
                    $_->{$UO}->@*
                }
                grep {
                    exists $_->{$UO}
                } @$CO_;
            push @UOs, $UO_;
        }
        for my $UO_ (@UOs) { @$UO_ =
            grep {
                (grep {
                    my $lo_ = $_->{$lo};
                    (grep {
                        $lo_ eq $_
                    } @dupes)[0]
                } $_->{$LO}->@*)[0]
            } @$UO_
        }
        %seen = (); $seen{$_->{$uo}}++ for ($UOs[0]->@*,$UOs[1]->@*);
        my @CONFLICTS = grep {$seen{$_} == 1} keys %seen;
        ## verbose {{{
        mes "\n==================",           $db, [-1], $cmpOpt->[1];
        mes "%% CHECK IF UO ARE THE SAME %%", $db, [-1], $cmpOpt->[1];
        mes  $_,                              $db, [0],  $cmpOpt->[1] for @CONFLICTS;#}}}
        #}}}

        ## CREATE UO PAIR CONFLICTS #{{{
        my @TODOs;
        for my $UO_ (@UOs) {
            my $TODO_;
            @$TODO_ =
                grep {
                    my $uo_ = $_->{$uo};
                    (grep{
                        $_ eq $uo_
                    } @CONFLICTS)[0]
                } @$UO_;
                push @TODOs, $TODO_;
        }
        my @TODO;
        for my $uo0 ($TODOs[0]->@*) {
            $LOs[0]->@* = $uo0->{$LO}->@*;
            my $uo1  =
                (grep {
                    (grep {
                        my $lo1 = $_->{$lo};
                        (grep {
                            $_->{$lo} eq $lo1
                        } $LOs[0]->@*)[0]
                    } $_->{$LO}->@*)[0]
                } $TODOs[1]->@*)[0];
            push @TODO, [$uo0, $uo1];
        }
        ## verbose {{{
        mes "\n==================",       $db, [-1], $cmpOpt->[1];
        mes "|CREATE UO PAIR CONFLICTS|", $db, [-1], $cmpOpt->[1];
        mes "$_->[0]{$uo}, $_->[1]{$uo}", $db, [0], $cmpOpt->[1] for @TODO;#}}}
        #}}}

        ## IF NOT DELELTE SECTION BY LIB PRIORITY #{{{
        for my $hash (@TODO) {
            my $co_ = (grep { (grep{ $_->{$uo} eq $hash->[0]{$uo} } $_->{$UO}->@*)[0] } $COs[0]->@*)[0];
            my $uo0 = (grep { $_->{$uo} eq $hash->[0]{$uo} } $co_->{$UO}->@*)[0];
            $uo0->{$uo} = $hash->[1]{$uo}
        }

        ## GET LO THAT NEED TO BE REMOVED IN EACH HASH
        @LOs = (); for my $UO_ (@UOs) { my @LO_ =
            map {
                {$uo => "[$_->{$uo}]"},
                $_->{$LO}->@*,
            } @$UO_;
            push @LOs, \@LO_;
        }

        my @toDels;
        for (0,1) {
            my $ind = $_;
            my @SEC_LO_ =
                map  { [$_, $_->{$LO}]  }
                map  { $_->{$UO}->@*    }
                grep { exists $_->{$UO} }
                $COs->[($ind ^= 1)]->@*;
            $LOs[$_]->@* =
                map  { $_->{$LO}->@*    }
                grep { exists $_->{$LO} }
                $COs->[$_]->@*;
            my @toDel_;
            for my $part_ (@SEC_LO_) {
                my $ele;
                for my $lo_ ($part_->[1]->@*) {
                    push @$ele,
                        (grep {
                            $_->{$lo} eq $lo_->{$lo}
                        } $LOs[$_]->@*)[0]
                }
                push @toDel_, [$part_->[0], $ele] if scalar @$ele;
            }
            push @toDels, \@toDel_;
        }
        ## verbose {{{
        mes "\n==================",                              $db, [-1], $cmpOpt->[1];
        mes "%% GET lo THAT NEED TO BE REMOVED IN EACH HASH %%", $db, [-1], $cmpOpt->[1];
        for my $toDel_ (@toDels) {
            for my $part (@$toDel_) {
                mes "[$part->[0]{$uo}]", $db, [0], $cmpOpt->[1];
                mes "    ($_->{$lo})",   $db, [0], $cmpOpt->[1] for $part->[1]->@*;
            }
            mes "---------",             $db, [0], $cmpOpt->[1];
        } #}}}
        #}}}

        ## DELETE LO BASED ON DEPTH PRIORITY I EACH LIB #{{{
        $SECTIONS0 = $catalog->{SECTIONS};
        $SECTIONS1 = $masterbin->{SECTIONS};
        $COs   = [$SECTIONS0->[0]{$CO}, $SECTIONS1->[0]{$CO}];
        $Data::Dumper::Maxdepth=3;
        my $cnt = 0;
        for my $toDel_ (@toDels) {
            for my $part (@$toDel_) {
                my $LO_ = dclone $part->[1];
                my $CO_ = $COs->[$cnt];
                my $co_  =
                    (grep {
                        (grep {
                            my $lo_ = $_;
                            (grep {
                                $lo_->{$lo} eq $_->{$lo}
                            } @$LO_)[0]
                        } $_->{$LO}->@*)[0]
                    } @$CO_)[0];
                my @LOs_ =
                    grep {
                        my $lo_ = $_;
                        (grep {
                            $lo_->{$lo} eq $_->{$lo}
                        } @$LO_)[0];
                    } $co_->{$LO}->@*;
                push $co_->{$UO}->@*, {$uo => $part->[0]{$uo}, $LO => \@$LO_};
                $co_->{$LO}->@* =
                    grep {
                        my $lo_ = $_;
                        !(grep {
                            $lo_->{$lo} eq $_->{$lo}
                        } @$LO_)[0];
                    } $co_->{$LO}->@*;
            }
            $cnt++;
        } #}}}

        ## MAKE SURE THINGS ARE EQUAL #{{{
        for my $uo0 ($UOs[0]->@*) {
            my $uo1 = (grep {$_->{$uo} eq $uo0->{$uo}} $UOs[1]->@*)[0] || die;
            for my $lo0 ($uo0->{$LO}->@*) {
                my $lo1 = (grep {$_->{$lo} eq $lo0->{$lo}} $uo0->{$LO}->@*)[0] || die} }#}}}

        #}}}
    }#}}}

    ## --- Combine {{{
    #my $catalog = $db->{hash}[0];
        my $catalog_contents          = dclone($catalog);
        $catalog                      = {};
        $catalog->{contents}          = $catalog_contents;
        $catalog->{contents}{libName} = 'hmofa_lib';
        $catalog->{contents}{SECTIONS}[0]{section} = 'masterbin';

    #my $masterbin = $db->{hash}[1];
        my $masterbin_contents            = dclone($masterbin);
        $masterbin                        = {};
        $masterbin->{contents}            = $masterbin_contents;
        $masterbin->{contents}->{libName} = 'hmofa_lib';
        $masterbin->{contents}{SECTIONS}[0]{section} = 'masterbin';

    my $sub = genFilter({
        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
        dspt    => $db->{external}{gitIO},
    });

    ## Walkers {{{
    my $walker = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            deleteKey( $_, 'LN',                $index, $container);
            deleteKey( $_, 'raw',               $index, $container);
            #removeKey( $_, 'SERIES', 'STORIES', $index, $container);
            #deleteKey( $_, 'preserve',          $index, $container);
            filter   ( $_, 'url',               $index, $container, $sub);
        }
    };

    my $walker2 = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            deleteKey( $_, 'LN',                $index, $container);
            deleteKey( $_, 'raw',               $index, $container);
            #removeKey( $_, 'SERIES', 'STORIES', $index, $container);
            deleteKey( $_, 'url_attribute',     $index, $container);
            #deleteKey( $_, 'preserve',          $index, $container);
            filter   ( $_, 'url',               $index, $container, $sub);
        }
    };
    # }}}

    walkdepth { wanted => $walker} ,  $masterbin->{contents};
    walkdepth { wanted => $walker2}, $catalog->{contents};
    sortHash($db,$catalog);
    sortHash($db,$masterbin);

    #my $new_hash = combine( $db, $masterbin, $catalog );
    $db->{result} = combine( $db, $catalog, $masterbin );
    ##}}}

    ## --- Validate {{{
    my @oo = (
        dclone $catalog->{contents},
        dclone $masterbin->{contents},
        dclone $db->{result}{contents},
    );
    #}}}

    ## --- output #{{{
    print $_ for $db->{debug}->@*;
    {
        my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
        $json_obj = $json_obj->allow_blessed(['true']);
        if ($db->{opts}{sort}) {
            $json_obj->sort_by( sub { cmpKeys( $db, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
        }
        my $json  = $json_obj->encode($db->{result}{contents});

        open my $fh, '>', $db->{fileNames}{output} or die;
            print $fh $json;
            truncate $fh, tell( $fh ) or die;
        close $fh
    } #}}}

    return $db;
}


#===| init2() {{{2
sub init2 {
    my $db = shift @_;
    unless (exists $db->{debug})        {$db->{debug} = []}
        else {warn "WARNING!: 'debug' is already defined by user!"}
    unless (exists $db->{meta})         {$db->{meta} = {}}
        else {warn "WARNING!: 'meta' is already defined by user!"}
    unless ($db->{fileNames}->{dspt}) {die "User did not provide filename for 'dspt'!"}
        genReservedKeys($db);
        genDspt($db);
        validate_Dspt($db);
        #$db->{dspt} = getJson($db->{fileNames}->{dspt});
    $db->{hash} = [ map { getJson($_) } $db->{fileNames}{fname}->@* ];
    $db->{external} = {
        map {
          $_ =~ m/(\w+)\.json$/;
          $1 => getJson($_);
        } $db->{fileNames}{external}->@*
    };
    return $db;
}


#===| combine() {{{2
sub combine {

    my ($db, $hash_0, $hash_1) = @_;
    unless (exists $db->{pointer}) { $db->{pointer} = [0] };
    $db->{reff_0}  = [ $hash_0->{contents} ]; my $reff_0 = $db->{reff_0};
    $db->{reff_1}  = [ $hash_1->{contents} ]; my $reff_1 = $db->{reff_1};


    # ===|| preprocess->() {{{3
    my $preprocess = sub {

        my @children = @_;
        my $pointer  = $db->{pointer};
        my $cmbOpts  = $db->{opts}{combine};
        my $lvl      = $Data::Walk::depth - 2;
        my $type     = $Data::Walk::type;

        ## Pre HASH {{{4
        if ($type eq 'HASH') {

            ## config pointer
            $pointer->[$lvl] = (exists $pointer->[$lvl] and $lvl != -1) ?++$pointer->[$lvl] :0;
            my $prior_lvl    = (scalar @$pointer) - 1;
            if ($prior_lvl > $lvl and $lvl > -1) {
                pop @$pointer for ( 1 .. ($prior_lvl - $lvl) );
            }

            my $pli       = $pointer->[$lvl];
            my $pointStr  = join('.', @$pointer);
            my $lvlReff_0 = $reff_0->[$lvl];
            my $lvlReff_1 = $reff_1->[$lvl];
            die if $lvlReff_0 eq $lvlReff_1;

            my $lvlHash_0 = ($lvl != -1) ?$lvlReff_0->[$pli] :$lvlReff_0;
            my $lvlHash_1 = ($lvl != -1) ?$lvlReff_1->[$pli] :$lvlReff_1;
            die if $lvlHash_0 eq $lvlHash_1;
            my $obj = getLvlObj($db, $lvlHash_0) || die;

            ## Verbose {{{
            mes("----------------------------------------", $db, [-1], $cmbOpts->[2]);
            mes("[$pointStr] PRE $type",                    $db, [-1], $cmbOpts->[2]);
            # }}}

            ## COMBINE Keys {{{

            ## sort by keys
            my @keys_0 = sort {lc $a cmp lc $b} keys %$lvlHash_0;
            my @keys_1 = sort {lc $a cmp lc $b} keys %$lvlHash_1;

            while (scalar @keys_0 or scalar @keys_1) {

                ## BOOL
                my $key_0 = $keys_0[0];
                my $key_1 = $keys_1[0];
                my $bool;
                if    (!$key_0 and !$key_1) { die }
                elsif (!$key_0)             { $bool = 1 }
                elsif (!$key_1)             { $bool = -1 }
                else                        { $bool = lc $key_0 cmp lc $key_1 }

                ## DIVY
                if ($bool and $bool != -1) {
                    unshift @keys_0, $key_1;
                    my $ref = ref $lvlHash_1->{$key_1};
                    $lvlHash_0->{$key_1} = $ref ?dclone($lvlHash_1->{$key_1})
                                                :$lvlHash_1->{$key_1};
                    ## Verbose {{{
                    mes "0-------", $db, [0], $cmbOpts->[2] >= 3;
                    mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                    mes "$key_1",   $db, [0], $cmbOpts->[2] >= 3;
                    # }}}
                } elsif ($bool == -1) {
                    unshift @keys_1, $key_0;
                    my $ref = ref $lvlHash_0->{$key_0};
                    $lvlHash_1->{$key_0} = $ref ?dclone($lvlHash_0->{$key_0})
                                                :$lvlHash_0->{$key_0};
                    ## Verbose {{{
                    mes "1-------", $db, [0], $cmbOpts->[2] >= 3;
                    mes "$key_0",   $db, [0], $cmbOpts->[2] >= 3;
                    mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                    # }}}
                } else {
                    shift @keys_0;
                    shift @keys_1;
                    ## Verbose {{{
                    mes "1-------", $db, [0], $cmbOpts->[2] >= 2;
                    mes "{$key_0}", $db, [0], $cmbOpts->[2] >= 2;
                    mes "{$key_1}", $db, [0], $cmbOpts->[2] >= 2;
                    # }}}
                }
                ## Verbose {{{
                mes "    ------------",                         $db, [2], $cmbOpts->[1] == 2;
                mes "    key_0: $key_0 - $lvlHash_0->{$key_0}", $db, [2], $cmbOpts->[1] == 2 if $key_0;
                mes "    key_1: $key_1 - $lvlHash_1->{$key_1}", $db, [2], $cmbOpts->[1] == 2 if $key_1;
                # }}}
            }
            # }}}

            # convert hash back into array
            undef @children;
            for my $key (sort keys %$lvlHash_0) {
                push @children, ($key, $lvlHash_0->{$key});
            }
            return @children;
        #}}}

        ## Pre ARRAY {{{4
        } elsif ($type eq 'ARRAY') {

            my $pli       = $pointer->[$lvl];
            my $pointStr  = join('.', @$pointer);
            my $lvlReff_0 = $reff_0->[$lvl];
            my $lvlReff_1 = $reff_1->[$lvl];
            die if $lvlReff_0 eq $lvlReff_1;

            my $lvlArray_0 = $lvlReff_0->{$pli};
            my $lvlArray_1 = $lvlReff_1->{$pli};
            die if $lvlArray_0 eq $lvlArray_1;
            my $obj = getLvlObj($db, $lvlArray_0->[0]);

            ## Verbose {{{
            mes("[$pointStr] PRE $type", $db, [-1], $cmbOpts->[1]);
            # }}}

            ## COMBINE Obj_Arrays {{{5
            if ($obj) {

                ## sort by $lvlObjs
                my @array_0 =  sort {$a->{$obj} cmp $b->{$obj}} @$lvlArray_0;                  ## OBJ
                my @array_1 =  sort {$a->{$obj} cmp $b->{$obj}} @$lvlArray_1;                  ## OBJ
                @$lvlArray_0 = ();
                @$lvlArray_1 = ();

                while (scalar @array_0 or scalar @array_1) {


                    ## BOOL
                    my $objHash_0 = $array_0[0];                                               ## OBJ
                    my $objHash_1 = $array_1[0];                                               ## OBJ
                    my $item_0    = $objHash_0 ?$objHash_0->{$obj} : undef;                    ## OBJ
                    my $item_1    = $objHash_1 ?$objHash_1->{$obj} : undef;                    ## OBJ
                    my $bool;
                    if    (!$item_0 and !$item_1) { die }
                    elsif (!$item_0)              { $bool = 1 }
                    elsif (!$item_1)              { $bool = -1 }
                    else                          { $bool = $item_0 cmp $item_1 }

                    ## Don't compare array refs
                    if ($array_0[0] and ref $array_0[0]{$obj} eq 'ARRAY') {$bool = 0}          ## OBJ

                    ## DIVY
                    if ($bool and $bool != -1) {
                        unshift @array_0, dclone $objHash_1;                                   ## OBJ
                        ## Verbose {{{
                        mes "0-------", $db, [0], $cmbOpts->[2] >= 3;
                        mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                        mes "$item_1",  $db, [0], $cmbOpts->[2] >= 3;
                        # }}}
                    } elsif ($bool == -1) {
                        unshift @array_1, dclone $objHash_0;                                   ## OBJ
                        ## Verbose {{{
                        mes "1-------", $db, [0], $cmbOpts->[2] >= 3;
                        mes "$item_0",  $db, [0], $cmbOpts->[2] >= 3;
                        mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                        # }}}
                    } else {
                        push @$lvlArray_0, (shift @array_0);
                        push @$lvlArray_1, (shift @array_1);
                        ## Verbose {{{
                        mes "---------", $db, [0], $cmbOpts->[2] >= 2;
                        mes "{$item_0}", $db, [0], $cmbOpts->[2] >= 2;
                        mes "{$item_1}", $db, [0], $cmbOpts->[2] >= 2;
                        # }}}
                        if ($lvlArray_0->[0] and ref $lvlArray_0->[0]{$obj} eq 'ARRAY') {last} ## OBJ
                    }
                }
                die if $lvlArray_0 eq $lvlArray_1;                                             ## OBJ
            # }}}

            ## COMBINE Arrays {{{5
            } else {

                #sort by parts
                my @array_0 = sort {lc $a cmp lc $b} @$lvlArray_0;                      ## PART
                my @array_1 = sort {lc $a cmp lc $b} @$lvlArray_1;                      ## PART
                @$lvlArray_0 = ();
                @$lvlArray_1 = ();

                while (scalar @array_0 or scalar @array_1) {

                    ## BOOL
                    my $item_0 = $array_0[0];                                           ## PART
                    my $item_1 = $array_1[0];                                           ## PART
                    my $bool;
                    if    (!$item_0 and !$item_1) { die }
                    elsif (!$item_0)              { $bool = 1 }
                    elsif (!$item_1)              { $bool = -1 }
                    else                          { $bool = $item_0 cmp $item_1 }

                    ## DIVY
                    if ($bool and $bool != -1) {
                        unshift @array_0, $item_1;                                      ## PART
                        ## Verbose {{{
                        mes "0-------", $db, [0], $cmbOpts->[2] >= 3;
                        mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                        mes "$item_1",  $db, [0], $cmbOpts->[2] >= 3;
                        # }}}
                    } elsif ($bool == -1) {
                        unshift @array_1, $item_0;                                      ## PART
                        ## Verbose {{{
                        mes "1-------", $db, [0], $cmbOpts->[2] >= 3;
                        mes "$item_0",  $db, [0], $cmbOpts->[2] >= 3;
                        mes "-",        $db, [0], $cmbOpts->[2] >= 3;
                        # }}}
                    } else {
                        push @$lvlArray_0, (shift @array_0);
                        push @$lvlArray_1, (shift @array_1);
                        ## Verbose {{{
                        mes "1-------",  $db, [0], $cmbOpts->[2] >= 2;
                        mes "{$item_0}", $db, [0], $cmbOpts->[2] >= 2;
                        mes "{$item_1}", $db, [0], $cmbOpts->[2] >= 2;
                        # }}}
                    }
                }
            }
            # }}}

            ## Verbose {{{
            mes("-----------------------------------------------------", $db,[-1], $cmbOpts->[1]) unless $obj;
            # }}}

            $reff_0->[$lvl+1]->@* = @$lvlArray_0;
            @children = @$lvlArray_0;
            return @children;
        # }}}

        } else { return @_ }
    };

    # ===|| wanted->() {{{3
    my $wanted = sub {

        my $item    = $_;
        my $pointer = $db->{pointer};
        my $cmbOpts = $db->{opts}{combine};
        my $lvl     = $Data::Walk::depth-2;
        my $type    = $Data::Walk::type;
        my $index   = $Data::Walk::index;

        unless ($lvl == -1) {
          ## configure pointer
            my $prior_lvl = (scalar @$pointer) - 1;
            if ($prior_lvl > $lvl) {
                pop @$pointer for ( 0 .. ($prior_lvl - $lvl) );
            }

            my $lvlReff_0 = $reff_0->[$lvl];
            my $lvlReff_1 = $reff_1->[$lvl];
            die if $lvlReff_0 eq $lvlReff_1;

            ## Want Array/Scalar in HASH {{{4
            if ($type eq 'HASH') {
                unless ($index & 1) {

                    my $obj_0        = $item;
                    my $item_0       = $lvlReff_0->{$obj_0};
                    my $item_1       = $lvlReff_1->{$obj_0};

                    my $pli          = $obj_0;
                    $pointer->[$lvl] = $pli;

                    my $pointStr     = join('.', @$pointer);

                    ## Verbose {{{
                    mes("-----------------------------------------------------", $db,[-1], $cmbOpts->[1]);
                    mes("[$pointStr] WANT in $type", $db, [-1], $cmbOpts->[2]);
                    mes("      obj: $obj_0",         $db, [0],  $cmbOpts->[3]);
                    mes("   item_0: $item_0",        $db, [0],  $cmbOpts->[3]);
                    mes("   item_1: $item_1",        $db, [0],  $cmbOpts->[3]);
                    # }}}

                    ## CHECKS
                    if (ref $item_0 ne 'ARRAY'
                    and ref $item_0 ne 'HASH'
                    and ref $item_1 ne 'ARRAY'
                    and ref $item_1 ne 'HASH'
                    and $item_0     ne $item_1 )
                    {
                        mes($item_0." ne ".$item_1,$db,[0],$cmbOpts->[1]);
                        die $!;
                    }

                    ## lvlReffs are now Array/Scalar
                    $reff_1->[$lvl+1] = $lvlReff_1->{$item};
                    $reff_0->[$lvl+1] = $lvlReff_0->{$item};
                }
            # }}}

            ## Want Hash/Scalar in ARRAY {{{4
            } elsif ($type eq 'ARRAY') {

                my $pli          = $index;
                $pointer->[$lvl] = $pli;
                my $hash         = $item;
                my $lvlObj_0     = getLvlObj($db, $hash);
                my $lvlObj_1     = getLvlObj($db, $lvlReff_1->[$pli]);
                my $lvlItem_0    = $lvlObj_0 ?$lvlReff_0->[$pli]->{$lvlObj_0} : undef;
                my $lvlItem_1    = $lvlObj_1 ?$lvlReff_1->[$pli]->{$lvlObj_1} : undef;
                my $groupName    = getGroupName($db, $lvlObj_0);
                my $pointStr     = join('.', @$pointer);

                ## verbose {{{
                mes("[$pointStr] WANT in $type",          $db, [-1], $cmbOpts->[2]);
                mes("      Obj: $lvlObj_0",               $db, [0],  $cmbOpts->[3]);
                mes("   item_0: ".($lvlItem_0 // "NONE"), $db, [0],  $cmbOpts->[3]);
                mes("   item_1: ".($lvlItem_1 // "NONE"), $db, [0],  $cmbOpts->[3]);
                # }}}

                ## CHECKS
                if ($lvlItem_0 and $lvlItem_1 and $lvlItem_0 ne $lvlItem_1 and (ref $lvlItem_0 ne 'ARRAY') and (ref $lvlItem_1 ne 'ARRAY')) {
                  die("Fuckie Wuckie! In ${0} at line: ".__LINE__)
                }

                ## CONFIGURE REFFS
                $reff_1->[$lvl+1] = $lvlReff_1->[$pli];
                $reff_0->[$lvl+1] = $lvlReff_0->[$pli];
            # }}}

            } else { die("Hash contains a reff_1 that is neither hash or array! In ${0} at line: ".__LINE__) }
        }
    };
    #}}}

    walk { wanted => $wanted, preprocess => $preprocess}, $hash_0->{contents};

    return $hash_0;
}

# UTILITIES {{{1
#------------------------------------------------------

#===| cmpKeys() {{{2
sub cmpKeys {
    my ($db, $key_a, $key_b, $hash, $opts) = @_;

    # save point if already defined
    my @save = exists $db->{point} ?$db->{point}->@* :();

    my $pointStr_a = getPointStr_FromUniqeKey($db, $key_a) ? getPointStr_FromUniqeKey($db, $key_a)
                                                             : genPointStr_ForRedundantKey($db, $key_a, $hash);
    my $pointStr_b = getPointStr_FromUniqeKey($db, $key_b) ? getPointStr_FromUniqeKey($db, $key_b)
                                                             : genPointStr_ForRedundantKey($db, $key_b, $hash);
    my @point_a = split /\./, $pointStr_a;
    my @point_b = split /\./, $pointStr_b;

    ## NEGITIVE ORDERS
    if ($point_a[-1] < $point_a[-1]*-1) {
        $pointStr_a = genPointStr_ForRedundantKey($db, $key_a, $hash,1);
        @point_a = split /\./, $pointStr_a;
    }
    if ($point_b[-1] < $point_b[-1]*-1) {
        $pointStr_b = genPointStr_ForRedundantKey($db, $key_b, $hash,1);
        @point_b = split /\./, $pointStr_b;
    }

    my $len_a   =  scalar @point_a;
    my $len_b   =  scalar @point_b;
    my $lvlObj  = getLvlObj($db,$hash);
    my $bool = $len_a <=> $len_b || $point_a[-1] <=> $point_b[-1];

    ## verbose {{{
    #my $n = 16 - length($key_a);
    #my $m = 10 - length($pointStr_a);
    #my $o = 16 - length($key_b);
    #my $p = 10 - length($pointStr_b);
    #print $key_a." " x $n." (";
    #print $pointStr_a." "x$m." cmp ";
    #print $pointStr_b,") "." "x$p;
    #print "$key_b "." "x$o."[$bool]\n"; #}}}

    # reinstate saved point or delete it if it wasn't defied
    if (scalar @save) {
        $db->{point}->@* = @save;
    } else {
        delete $db->{point};
    }

    return $bool;

    #===|| getPointStr_FromUniqeKey() {{{3
    sub getPointStr_FromUniqeKey {
        my ($db, $key)  = @_;

        if    (exists $db->{dspt}{$key})          { return $db->{dspt}{$key}{order} }
        elsif (getObj_FromGroupName($db, $key))   { return $db->{dspt}{getObj_FromGroupName($db, $key)}{order} }
        else                                        { return 0 }

        #===| getObj_FromGroupName() {{{4
        sub getObj_FromGroupName {

            my $db      = shift @_;
            my $dspt      = $db->{dspt};
            my $groupName = shift @_;

            my @keys  = grep { exists $dspt->{$_}{groupName} } keys $dspt->%*;
            if (scalar @keys) {
                my @match = grep { $dspt->{$_}{groupName} eq $groupName } @keys;
                if ($match[0]) { return $match[0] }
                else { return 0 }
            } else { return 0 }
        }
    }
    #===|| genPointStr_ForRedundantKey() {{{3
    sub genPointStr_ForRedundantKey {

        my ($db, $key, $hash, $F)  = @_;

        my $lvlObj     =  getLvlObj($db, $hash);
        $db->{point} = [ split /\./, $db->{dspt}{$lvlObj}{order} ];
        my $pointStr   = getPointStr($db);
        my $dspt_obj   = $db->{dspt}{getObj($db)};

        ## --- ATTRIBUTES
        if ((exists $dspt_obj->{attributes}) and (exists $dspt_obj->{attributes}{$key})) {
            my $dspt_attr = $dspt_obj->{attributes}{$key};
            my $cnt;
            $cnt = exists $dspt_attr->[1] ? $dspt_attr->[1]
                                              : 1;
            for (my $i = 1; $i <= $cnt; $i++) { $pointStr = changePointStrInd($pointStr, 1) }
            if ($pointStr) { return $pointStr }
            else           { die "pointStr $pointStr doesn't exist or is equal to '0'!" }

        ## --- RESERVED KEYS and NEGITIVE ORDERS
        } elsif (isReservedKey($db, $key) or $F) {
            my $first = join '.', $db->{point}->@[0 .. ($db->{point}->$#* - 1)];
            my $pointEnd = $db->{point}[-1];

            # order
            my $order;
            if ($F) {
                my $obj = getObj_FromGroupName($db,$key) ?getObj_FromGroupName($db,$key)
                                                           :$key;
                my @point = split /\./, $db->{dspt}{$obj}{order};
                my $resvMax = 0;
                for (keys $db->{reservedKeys}->%*) {
                    my $resvOrder = $db->{reservedKeys}{$_}[1];
                    $resvMax = $resvOrder if $resvMax < $resvOrder;
                }
                $order = $point[-1]*-1 + $resvMax;
            } else { $order = $db->{reservedKeys}{$key}[1] }

            # genPoinstr
            my $dspt_attr = exists $dspt_obj->{attributes} ?$dspt_obj->{attributes} :0;
            if ($dspt_attr) {
                my @orders = map {
                    my $order = $dspt_attr->{$_}[1];
                    $order // 1;
                } keys $dspt_attr->%*;
                my $attr = ( sort { $b cmp $a } @orders)[0];
                my $end = $order + $attr + $pointEnd;
                $pointStr = ($first) ?$first.'.'.$end :$end;
            } else {
                my $end = $order +  $pointEnd;
                $pointStr = ($first) ?$first.'.'.$end :$end;
            } return $pointStr;

        ## --- lvl 0
        } elsif (exists $db->{dspt}{$key} and $db->{dspt}{$key}{order} == 0 ) {
            return 0;

        ## --- INVALID KEY
        } else { die "Invalid Key: $key." }
    }
}


#===| changePointLvl() {{{2
sub changePointLvl {

    my $point = shift @_;
    my $op    = shift @_;

    if ($op) { push $point->@*, 1 }
    else     { pop $point->@*, 1 }

    return $point;

}


#===| changePointStrInd() {{{2
sub changePointStrInd {

    my $pointStr = ($_[0] ne '') ?$_[0]
                                 :{ die("pointStr cannot be an empty str! In ${0} at line: ".__LINE__) };
    my @point    = split /\./, $pointStr;
    my $op       = $_[1];

    if ($op) { $point[-1]++ }
    else     { $point[-1]-- }

    $pointStr = join '.', @point;
    return $pointStr;
}


#===| filter(){{{2
sub filter {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    my $sub0   = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         $hash->{$arg} = $sub0->($hash->{$arg});
    }
}


#===| genOpts() {{{2
sub genOpts {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        delegate => [1,0,0,0,0,0,0,0],
        leveler  => [1,0,0,0,0,0,0,0],
        divy     => [1,0,0,0,0,0,0,0],
        attribs  => [1,0,0,0,0,0,0,0],
        delims   => [1,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => 0,

        ## MISC
        sort     => 0,
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| genOpts2() {{{2
sub genOpts2 {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        delegate => [1,0,0,0,0,0,0,0],
        combine  => [1,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0],
        cmp      => [1,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => 0,

        ## MISC
        sort     => 0,
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| getAttrDspt(){{{2
sub getAttrDspt {
    my ($db, $obj) = @_;
    my $objDspt = $db->{dspt}{$obj};
    my $attrDspt = (exists $objDspt->{attributes}) ? $objDspt->{attributes}
                                                   : 0;
    return $attrDspt;
}


#===| getGroupName() {{{2
sub getGroupName {
    # return GROUP_NAME at current point.
    # return 'getObj()' if GROUP_NAME doesn't exist!

    my $db = shift @_;
    my $obj  = shift @_;
    my $dspt = $db->{dspt};
    if ($obj) {
        my $groupName = exists ($dspt->{$obj}{groupName}) ? $dspt->{$obj}{groupName}
                                                          : $obj;
        unless ($groupName) { die("groupName was returned empty or '0'! In ${0} at line: ".__LINE__) }
        return $groupName;
    }
    else { return 0 }

}


#===| getJson() {{{2
sub getJson {
    my $fname = shift @_;
    my $hash = do {
        open my $fh, '<', $fname;
        local $/;
        decode_json(<$fh>);
    };
    return $hash
}


#===| getLvlObj {{{2
sub getLvlObj {
    my $db = shift @_;
    my $hash = shift @_;
    if (ref $hash eq 'HASH') {
        for (keys $hash->%*) {
             if ( exists $db->{dspt}{$_} ) {return $_}
        }
    }
}


#===| getObj() {{{2
# return OBJECT at current point
# return '0' if OBJECT doesn't exist for CURRENT_POINT!
# die if POINT_STR generated from CURRENT_POINT is an empty string!
sub getObj {

    my $db       = shift @_;
    my $dspt     = $db->{dspt};
    my $pointStr = join( '.', $db->{point}->@* );

    die "pointStr cannot be an empty string!" if $pointStr eq '';

    my $match =
        (grep {
            ($dspt->{$_}{order} // "") =~ /^$pointStr$/
        } keys $dspt->%*)[0];

    return ($match // 0 );

}


#===| getPointStr() {{{2
sub getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $db = shift @_;
    my $pointStr = join('.', $db->{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| isAttr(){{{2
sub isAttr {
    my ($db, $lvlObj, $key) = @_;
    my $attrDspt = getAttrDspt($db,$lvlObj);
    if ($attrDspt) {
        my $attr = (grep {$_ eq $key} keys %$attrDspt)[0];
        return ($attr) ? $attrDspt->{$attr}
                       : 0;
    }
    else {
        return 0;
    }
}


#===| isReservedKey() {{{2
sub isReservedKey {
    my ($db, $key)  = @_;
    my $resvKeys      = $db->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
}


#===| longest() {{{2
sub longest {
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



# OTHER {{{1
#------------------------------------------------------

#===| genfilter() {{{2
sub genFilter {
    my $ARGS    = shift @_;
    my $dspt    = $ARGS->{dspt};
    my $obj     = $ARGS->{obj};
    my $pattern = $ARGS->{pattern};

    return sub {
        my $raw = shift @_;
        if ($raw =~ $pattern) {
            return ($dspt->{$1}) ? $dspt->{$1} : $raw;
        }
        else { return $raw }
    };
}


#===| sortHash(){{{2
sub sortHash {
    my ($db, $hash) = @_;


    #===| sortSub->(){{3
    my $sortSub = sub {
        my $key = shift @_;
        my $index = shift @_;
        my $container  = shift @_;
        if ( ($index % 2) == 0 and ref $container->{$key} eq 'ARRAY') {
            my $checkobj = getLvlObj($db, $container->{$key}[0]);
            if ($checkobj) {
                $container->{$key} = [ sort {
                    my $obj_a = getLvlObj($db, $a);
                    my $obj_b = getLvlObj($db, $b);
                    if ($obj_a ne $obj_b) {
                        lc $db->{dspt}{$obj_a}{order} cmp lc $db->{dspt}{$obj_b}{order}
                    } else {
                        lc $a->{$obj_a} cmp lc $b->{$obj_b}
                    }
                } $container->{$key}->@* ];
            }
        }
    };

    my $sub = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            $sortSub->($_, $index, $container);
        }
    };

    walk { wanted => $sub}, $hash->{contents};
}


#===| removeKey(){{{2
sub removeKey {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $key2  = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         my $hash = $Data::Walk::container;
         my @stories;
         for my $part ($hash->{$key}->@*) {
             push @stories, $part->{$key2}->@*;
         }
         unless (exists $hash->{$key2}) {$hash->{$key2} = []}
         push $hash->{$key2}->@*, @stories;
         delete $hash->{$key};
    }
}


#===| deleteKey(){{{2
sub deleteKey {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         delete $hash->{$arg};
    }
}


#===| waltzer() {{{2
sub waltzer {
    my $type      = $Data::Walk::type;
    my $index     = $Data::Walk::index;
    my $container = $Data::Walk::container;
    if ($type eq 'HASH') {
        #deleteKey( $_, 'LN',     $index, $Data::Walk::container);
        #deleteKey( $_, 'raw',    $index, $Data::Walk::container);
        #deleteKey( $_, 'test33', $index, $Data::Walk::container);
        #deleteKey( $_, 'test3',  $index, $Data::Walk::container);
        #deleteKey( $_, 'test',   $index, $Data::Walk::container);
        #filter   ( $_, 'url',    $index, $Data::Walk::container, $sub);
    }
}
