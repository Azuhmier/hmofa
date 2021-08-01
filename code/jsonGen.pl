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
use XML::Simple;
use YAML;
use Data::Dumper;
use List::Util;
use Data::Nested;
use Array::Utils;
use Data::Compare;
use Deep::Hash::Utils qw(reach slurp nest deepvalue);
use Data::Structure::Util qw(
  has_utf8 utf8_off utf8_on unbless get_blessed get_refs
  has_circular_ref circular_off signature
);
use List::Util qw( uniq );
my $erreno;
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');
use Data::Walk;
sub mes;


# MAIN {{{1
#------------------------------------------------------
{
    # OPTS {{{
    # ;opts
        my $opts = genOpts({
            ## Processes
            all      => [1,0],
            leveler  => [1,1,0,0,0],
            divy     => [1,1,0,0,0,0,0,0,0],
            #1 general
            #2 matches
            #3 Preserves
            #4 shorthand
            #5
            #6
            #7
            #8 shorthand
            attribs  => [1,0,0,0,0],
            delims   => [1,0,0,0,0],
            encode   => [1,0,0,0,0],
            write    => [1,1,1,0,0],
            #1
            #2
            #3
            #4
            delegate => [1,1,0,0,0],

            ## STDOUT
            verbose  => 1,
            display  => 0,
            lineNums => 0,

            ## MISC
            sort    => 1,
        });
    my $opts2 = genOpts2({
        ## Processes
        #combine  => [1,1,3,1,0],
        combine  => [1,0,0,0,0],
        # 1
        # 2
        # 3
        # 4 refs
        encode   => [1,0,0,0,0],
        write    => [1,0,0,0,0],
        delegate => [1,0,0,0,0],
        cmp      => [1,0,0,0,0],

        ## STDOUT
        verbose  => 1,

        ## MISC
        sort    => 1,
    });
    #}}}

    # DELEGATES {{{
    # masterbin
        delegate({
            opts => $opts,
            name => 'masterbin',
            preserve => {
                libName => [
                    ['',[0]],
                ],
                section => [
                    ['FOREWORD',[1]],
                ],
            },
            fileNames => {
                fname  => '../masterbin.txt',
                output => './json/masterbin.json',
                dspt   => './json/deimos.json',
            },
        });

        ## tagCatalog
        delegate({
            opts => $opts,
            name => 'catalog',
            preserve => {
                libName => [
                    ['',[0]],
                ],
                section => [
                    ['Introduction/Key',[1,1,1]],
                ],
            },
            fileNames => {
                fname  => '../tagCatalog.txt',
                output => './json/catalog.json',
                dspt   => './json/deimos.json',
            },
        });

     delegate2({
         opts => $opts2,
         name => 'hmofa_llib',
         fileNames => {
             fname    => ['./data/catalog/catalog.json', './data/masterbin/masterbin.json',],
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

    my $data = shift @_;
    my $delegate_opts = $data->{opts}{delegate};
    if ($delegate_opts->[0]) {

        ## verbose 1 #{{{
        mes "$data->{name} {{"."{",                $data, [-1], $delegate_opts->[1];
        mes "Generating   $data->{name} {{"."{", $data, [0], $delegate_opts->[1]; #}}}

        ## sigtrap
        $SIG{__DIE__} = sub {
            if ($data and exists $data->{debug}) {
                print $_ for $data->{debug}->@*;
                print $erreno if $erreno;
            }
        };

        ## checks
        init($data);

        ## matches
        getMatches($data);
        validate_Matches($data);
        $data->{matches4}->%* =
            map { map { $_->{LN} => $_
                      } $data->{matches_clone}{$_}->@*
                } keys $data->{matches_clone}->%*;
        ## convert
        leveler($data,\&checkMatches);

        ## encode
        encodeResult($data);

        ## verbose 1 {{{
        mes "}"."}}", $data, [0], $delegate_opts->[1]; #}}}

        ## write
        my $writeArray = genWriteArray($data);
        open my $fh, '>', './result/'.$data->{result}{libName}.'.txt' or die $!;
        for (@$writeArray) {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
        close $fh;

        ## verbose 1 {{{
        mes "}"."}}", $data, [-1], $delegate_opts->[1]; #}}}

        ## output {{{

        if ($delegate_opts->[1]) {
            ## Matches Meta
            my $matches_Meta = $data->{meta}{matches};
            my $max = length longest(keys $matches_Meta->%*);

            ## Verbose
            #print "\nSummary: $data->{name}\n";
            #for my $obj (sort keys $matches_Meta->%*) {
            #    printf "%${max}s: %s\n", ($obj, $matches_Meta->{$obj}{count});
            #}

            ## Subs
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
        }
        print $_ for $data->{debug}->@*;
        #}}}

        ## WRITE {{{
        my $headDir = './data';
        my $dirname = $headDir.'/'.$data->{result}{libName};
        mkdir $headDir if (!-d './data');
        mkdir $dirname if (!-d $dirname);

        ## META
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{meta});
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
            my $json     = $json_obj->encode($data->{result});
            my $fname    = $dirname.'/'.$data->{result}->{libName}.'.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches});
            my $fname    = $dirname.'/matches.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES4
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches4});
            my $fname    = $dirname.'/matches4.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES_CLONE
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{matches_clone});
            my $fname    = $dirname.'/matches_clone.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## MATCHES_CLONE
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($data->{dspt});
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

        return $data;
    }
}


#===| init() {{{2
sub init {

  my $data = shift @_;

  # ---|| properties |---{{{3
  unless (exists $data->{point})     {$data->{point}     = [1]}
      else {warn "WARNING!: 'point' is already defined by user!"}
  unless (exists $data->{result})    {$data->{result}    = {libName => $data->{name}}}
      else {warn "WARNING!: 'result' is already defined by user!"}
  unless (exists $data->{reffArray}) {$data->{reffArray} = [$data->{result}]}
      else {warn "WARNING!: 'reffArray' is already defined by user!"}
  unless (exists $data->{meta})      {$data->{meta}      = {}}
      else {warn "WARNING!: 'meta' is already defined by user!"}
  unless (exists $data->{debug})     {$data->{debug}     = []}
      else {warn "WARNING!: 'debug' is already defined by user!"}
  unless (exists $data->{pointer})     {$data->{pointer}     = []}
      else {warn "WARNING!: 'index' is already defined by user!"}
  genReservedKeys($data);

  # ---|| filenames |---{{{3
  unless ($data->{fileNames}{dspt})   {die "User did not provide filename for 'dspt'!"}
      genDspt($data);
      validate_Dspt($data);
  unless ($data->{fileNames}{fname})  {die "User did not provide filename for 'fname'!"}
  unless ($data->{fileNames}{output}) {die "User did not provide filename for 'output'!"}
  #}}}
}
#===| genReservedKeys() {{{2
sub genReservedKeys {

    my $data = shift @_;
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

    $data->{reservedKeys} = $defaults;
}

#===| gendspt {{{2
sub genDspt {

    my $data = shift @_;
    my $dspt = do {
        open my $fh, '<', $data->{fileNames}{dspt};
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
    if (exists $data->{preserve}) {
       my $preserve = $data->{preserve};
        for my $obj (keys %$preserve) {
            my $preserve_obj          = dclone($preserve->{$obj});
            $dspt->{$obj}{preserve}->@* = @$preserve_obj;
        }
        delete $data->{preserve};
    }
    $data->{dspt} = dclone($dspt);
}
#===| validate_Dspt() {{{2
sub validate_Dspt {

    my $data = shift @_;
    my $dspt = $data->{dspt};
    my %hash = ();

    ## check for duplicates: order
    my @keys  = sort map { exists $dspt->{$_}{order} and  $dspt->{$_}{order} } keys %{$dspt};
    my %DupesKeys;
    for (@keys) { die "Cannot have duplicate reserved keys!" if $DupesKeys{$_}++ }

    ## META
    $data->{meta}{dspt} = {};
    my $dspt_meta = $data->{meta}{dspt};


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

    my $data = shift @_;
    my $fname = $data->{fileNames}{fname};
    my $dspt  = $data->{dspt};
    my $output;

    open( my $fh, '<', $fname )
        or die $!;

    while (my $line = <$fh>) {

        my $flag;
        for my $objKey (keys %$dspt) {
            my $obj = $dspt->{$objKey};

            if ($obj->{re} and $line =~ /$obj->{re}/) {
                my $match = {
                    LN      => $.,
                    $objKey => $1,
                    raw     => $line,
                };
                push  $output->{$objKey}->@*, $match;
                $flag=1;
            }
        }
        unless ($flag) {
            my $match = {
                LN      => $.,
                preserve => $line,
            };
            push  $output->{preserve}->@*, $match;
        }
    }

    close( $fh );
    $data->{matches} = $output;
}



#===| validate_Matches() {{{2
sub validate_Matches {

    my $data    = shift @_;
    my $dspt    = $data->{dspt};
    my $matches = $data->{matches};
    my $meta    = $data->{meta};
    $data->{matches_clone} = dclone($matches);

    ## MATCHES META
    $meta->{matches} = {};
    my $meta_matches = $meta->{matches};

    for my $obj (keys %$dspt, 'preserve') {

        $meta_matches->{$obj}      = {};
        my $meta_matches_obj       = $meta_matches->{$obj};

        my $matches_obj            = $matches->{$obj};
        $meta_matches_obj->{count} = $matches_obj ? scalar @$matches_obj : 0;
    }
}



#===| leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub leveler {

    my $data = shift @_;
    my $sub  = shift @_;
    my $leveler_opts = $data->{opts}{leveler};

    if ($leveler_opts->[0]) {

        ## check existance of OBJ at current point
        my $objKey = getObj( $data );
        unless ($objKey) { return }


        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ($objKey) {

            ## verbose {{{
            mes(getPointStr($data)." $objKey", $data, [1], $leveler_opts->[1]); #}}}

            ## Checking existance of recursionReffArray
            unless (defined $recursionReffArray) { $recursionReffArray->@* = $data->{reffArray}->@* }

            ## checkMatches
            $sub->( $data );

            ## Check for CHILDREN
            changePointLvl($data->{point}, 1);
            leveler( $data, $sub);
            changePointLvl($data->{point});
            $data->{reffArray}->@* = $recursionReffArray->@*;

            ## Check for SYBLINGS
            if (scalar $data->{point}->@*) {
                $data->{point}[-1]++;
            } else { last }

            $objKey = getObj($data);
        }
        return $data->{result};
    }
}


#===| checkMatches() {{{2
sub checkMatches {

    my $data = shift @_;
    my $obj  = getObj($data);
    my $divier  = \&divyMatches;

    if (exists $data->{matches}{$obj}) {
        $divier->($data);
    }
}


#===| divyMatches() {{{2
sub divyMatches {
    my $data = shift @_;
    my $opts_divy = $data->{opts}{divy};

    if ($opts_divy->[0]) {
        my $obj  = getObj($data);
        my $dspt = $data->{dspt};
        my $matches_obj = [ grep {exists $_->{LN}} $data->{matches_clone}{$obj}->@* ];
        my $matches_ALL = [
            grep {exists $_->{LN}}
            map  {$data->{matches4}->{$_}}
            sort {$a<=>$b}
            keys $data->{matches4}->%*
        ];
        ## verbose: prev_obj 0 {{{
        my $prev_lvlObj = '';
        my $prev_obj = ''; #}}}

        ## --- REFARRAY LOOP
        my $refArray = $data->{reffArray};
        my $ind = (scalar @$refArray) - 1;
        for my $ref (reverse @$refArray) {
            my $lvlObj  = getLvlObj($data, $ref);
            my $ref_LN  = $ref->{LN} ?$ref->{LN} :0;
            my @MATCHES = ([ @$matches_obj ]);
            ## --- PRESERVE{{{
            my $lvlPreserve = $dspt->{$lvlObj}{preserve} // undef;
            my $F_inclusive = 0;

            if ($lvlPreserve) {
                my $correction;
                my $F;

                ## INCLUSIVE/EXCLUSIVE
                if ( (grep { $_->[0] eq $ref->{$lvlObj} } @$lvlPreserve)[0] ) {
                    $F_inclusive = 1; $correction = 0;
                } elsif ($lvlPreserve->[0][0] eq '' && scalar @$lvlPreserve == 1) {
                    $correction = ($lvlObj eq 'libName') ?0 :1;
                } else { $F = 1 }

                unless ($F) {

                    ## ELEIGBLE_OBJ
                    my @elegible_obj = grep {
                        exists $dspt->{$_}{order}
                            and
                        $_ ne 'preserve'
                            and
                        $dspt->{$_}{order}
                            and
                        scalar (split /\./, $dspt->{$_}{order})
                            ==
                        ((scalar (split /\./, $dspt->{$lvlObj}{order})) + $correction)
                    } keys %$dspt;

                    ## LN
                    my $LN = $ref_LN;
                    ## verbose 3,3{{{
                    mes "IDX-$ind preserve -> $lvlObj", $data,[1], $opts_divy->[3];
                    mes "($LN)",                        $data,[4], $opts_divy->[3]; #}}}
                    for my $obj (@elegible_obj) {
                        for my $item ($data->{matches}{$obj}->@*) {
                            if ($item->{LN} > $LN) {
                                ## verbose 3,3{{{
                                mes "[$item->{LN}] ",       $data,[4,1], $opts_divy->[3];
                                mes "<$obj> $item->{$obj}", $data,[-1], $opts_divy->[3] == 2; #}}}
                                $LN = $item->{LN}; last;
                            }
                            ## verbose 3,3{{{
                            else {
                                mes " $item->{LN}  ",       $data,[4,1], $opts_divy->[3];
                                mes "<$obj> $item->{$obj}", $data,[-1], $opts_divy->[3] == 2;
                            } #}}}
                        }
                    }

                    ## PRES ARRAY
                    my $pres_ARRAY = [
                        grep {
                            exists $_->{LN}
                                &&
                            $_->{LN} < $LN
                                &&
                            ($F_inclusive ?1 :$_->{LN} > $ref_LN)
                        } @$matches_ALL
                    ];

                    ## PRES ARRAY CLEANUP
                    for my $hash (@$pres_ARRAY) {
                        next if exists $hash->{preserve};
                        my $obj = getLvlObj($data,$hash);
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

                    ## MATCHES
                    if ($F_inclusive) { $MATCHES[0] = $pres_ARRAY}
                    else                { push @MATCHES, $pres_ARRAY}
                }
            } #}}}
            ## verbose 2,3 {{{
            #my $prev_obj = '' if $opts_divy->[4] == 2;
            mes "IDX-$ind $obj -> $lvlObj",          $data, [1] if $opts_divy->[2] == 3;
            mes "[$ref_LN] <".$lvlObj."> ".$ref->{$lvlObj}, $data, [4] if $opts_divy->[2] == 3; #}}}

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
                    $obj = exists $match->{preserve} ?'preserve' :getLvlObj($data, $match);

                    ## CHECKS
                    unless ($match->{LN}) {
                        $erreno = "$lvlObj ERROR!: undef match->{LN} at $0 line ".__LINE__;
                        die }
                    unless (exists $match->{$obj}) {
                        $erreno = "ERROR!: undef match->{obj} at $0 line ".__LINE__;
                        die }

                    ## --- MATCH FOUND {{{
                    if ($match->{LN} > $ref_LN) {
                        my $match = pop @{ $F_inclusive || $F_partial ?$array :$matches_obj };
                        my $attrDebug = genAttributes( $data, $match, [$F_partial, $F_inclusive]);
                        push @$childObjs, $match;
                        ## verbose 2,2{{{
                        unless ($F++) {
                            mes( "[LN$ref_LN, $ind] $obj -> $lvlObj: $ref->{$lvlObj}", $data, [1], $opts_divy->[2] == 2);
                        }
                        my $LL = $match->{LN};
                        mes "(".$LL.") <$obj> ".($match->{$obj} // 'undef'), $data, [4], $opts_divy->[2] == 3
                            if $data->{dspt}->{$obj}{partion};
                        mes "(".$LL.") <$obj> ".($match->{$obj} // 'undef'), $data, [4], $opts_divy->[2] == 3
                            unless $data->{dspt}{$obj}{partion};

                        if (scalar $attrDebug->@* and $data->{opts}{attribs}[1]) {
                            mes "$_", $data, [-1, 1] for $attrDebug->@*;
                        } #}}}
                    } else { last } #}}}
                    ## verbose 1,1 {{{
                    if ($obj ne $prev_obj) {
                        push @$mes, mes "$obj -> $lvlObj", $data, [2,0,1], $opts_divy->[1] == 1;
                        push @$mes, mes "[$ref_LN, $ind]", $data, [2,0,1], $opts_divy->[6] == 1;
                    } $prev_obj = $obj; #}}}
                } #}}}
                ## --- MATCHES TO REFARRAY {{{
                if ($childObjs) {
                    my $childObjsClone = [ reverse @{ dclone($childObjs) } ];

                    if ($F_inclusive) {
                        unless (exists $refArray->[$ind]{PRESERVE}) {
                            $refArray->[$ind]{PRESERVE} = []
                        }
                        @$childObjsClone = map {$data->{matches4}{$_->{LN}} } @$childObjsClone;
                        my $ref = dclone($childObjsClone);
                        push $refArray->[$ind]{PRESERVE}->@*, @$ref;

                    } else {
                        my $groupName =  $F_partial ?'PRESERVE' :getGroupName($data, $obj);
                        $refArray->[$ind]{$groupName} = $childObjsClone;
                        splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjsClone) );

                    }

                    for my $hashRef (@$childObjs) { %$hashRef = () }

                    # verbose 1,1{{{
                    if ($mes and scalar @$mes) {
                        mes "$_", $data, [0,1,0], $opts_divy->[1] == 1 for @$mes;
                    } #}}}

                } #}}}

            } $ind--;
        }
    }
}

#===| genAttributes() {{{2
sub genAttributes {

    my $data  = shift @_;
    my $match = shift @_;
    my $flags = shift @_;
    my $attr_opts = $data->{opts}{attribs};

    ## verbose {{{
    my $debug     = [];
    #}}}

    if ($attr_opts->[0] and !$flags->[0] and !$flags->[1]) {

        my $obj       = getObj($data);
        my $objReff   = $data->{dspt}{$obj};
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
                        push $debug->@*, mes("|${attrib}|",              $data, [6, 1, 1], $attr_opts->[1] == 1);
                        push $debug->@*, mes(" '".$match->{$attrib}."'", $data, [-1, 0, 1], $attr_opts->[1] == 1);
                    }
                    #}}}

                    if (scalar $attrReff->@* == 3) {
                        delimitAttribute($data, $attrib, $match);
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
    my $data           = shift @_;
    my $objKey         = getObj($data);
    my $attributesDSPT = $data->{dspt}{$objKey}{attributes};

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

    my $data  = shift @_;
    if  ($data->{opts}{encode}[0]) {
        my $fname = $data->{fileNames}{output};
        {
            my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            if ($data->{opts}{sort}) {
              $json_obj->sort_by( sub { cmpKeys( $data, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
            }
            my $json  = $json_obj->encode($data->{result});
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

    if ($write_opts->[0]) {
        $db->{pointer}   = [0];  my $pointer   = $db->{pointer};
        $db->{point}     = [-1]; my $point     = $db->{point};
        $db->{objChain}  = [];   my $objChain  = $db->{objChain};
        $db->{objChain2} = [];   my $objChain2 = $db->{objChain2};
        $db->{childs}    = {};   my $childs    = $db->{childs};

        ## verbose 1{{{
        mes "Writing $db->{name}", $db, [0,1], $write_opts->[1];
        mes " {{"."{",             $db, [0], $write_opts->[1];
        # }}}

        ## %dresser {{{
        my %dresser = (
            preserve => {
                preserve => [
                    '',
                    '',
                    '',
                    '',
                    '',
                    {
                        section => 1
                    },
                ],
            },
            libName => {
                libName => [
                    '',
                    '',
                ],
            },
            title => {
                title => [
                    ">",
                    '',
                    '',
                    '',
                    '',
                ],
                title_attribute => [
                    ' (',
                    ')',
                ],
            },
            author => {
              author => [
                  "--------------------------------------------------------------------------------------------------------------\nBy ",
                  '',
                  '',
                  '',
                  '',
                  3,
              ],
              author_attribute => [
                  ' (',
                  ')',
              ],
            },
            series  => {
                series => [
                    "===== "
                    , ' ====='
                ],
            },
            section => {
                section => [
                    "\n------------------------------------------------------------------------------------------------------------------------------\n-----------------------------------------------------% ",
                    " %-------------------------------------------------\n------------------------------------------------------------------------------------------------------------------------------",
                    '',
                    '',
                    '',
                    {
                        preserve => 2
                    },
                ],
            },
            tags => {
                anthro  => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                general => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                ops => [
                    '',
                    '',
                    '',
                    '',
                    '',
                ],
            },
            url => {
                url => [
                    '',
                    '',
                ],
                url_attribute => [
                    ' (',
                    ')',
                ],
            },
            description => {
                description => [
                    '#',
                    '',
                ],
            },
        ); #}}}
        ## %dresser2 {{{
        my %dresser2 = (
            preserve => {
                preserve => [
                    '',
                    '',
                    '',
                    '',
                    '',
                    {
                        section => 1
                    },
                ],
            },
            libName => {
                libName => [
                    '',
                    '',
                ],
            },
            title => {
                title => [
                    "\n>",
                    '',
                    '',
                    '',
                    '',
                    {
                        series => 1
                    },
                ],
                title_attribute => [
                    ' (',
                    ')',
                ],
            },
            author => {
              author => [
                  "\n-----------------------------------------------------------------------------------------------------------------------------\n-----------------------------------------------------------------------------------------------------------------------------\nby ",
                  '',
                  '',
                  '',
                  '',
                  3,
              ],
              author_attribute => [
                  ' (',
                  ')',
              ],
            },
            series  => {
                series => [
                    "\n=============/ ",
                    " /=============",
                ],
            },
            section => {
                section => [
                    "\n——————————————————————————————————————————————————————————————————————————————————\n%%%%% ",
                    " %%%%%\n——————————————————————————————————————————————————————————————————————————————————",
                    '',
                    '',
                    '',
                    {
                        preserve => 2
                    },
                ],
            },
            tags => {
                anthro  => [
                    '[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                general => ['[',
                    ']',
                    ';',
                    ';',
                    ' ',
                ],
                ops     => ['',
                    '',
                    '',
                    '',
                    '',
                ],
            },
            url => {
                url           => [
                    '',
                    '',
                ],
                url_attribute => [
                    ' (',
                    ')',
                ],
            },
            description => {
                description => [
                    '#',
                    ''
                ],
            },
        ); #}}}
        ## append DSPT {{{
        if ($db->{result}->{libName} eq 'catalog') {%dresser = %dresser2}
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
                    } $pointer->[$lvl] = $obj; #}}}

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
                    }

                    my $pointStr = join '.', @$pointer;
                    my $S0 = " " x (47 - length $pointStr);
                    my $S1 = " " x (9 - length $objOrder);
                    mes "[$F1, $lvl] $objOrder ${S1} $pointStr ${S0} $container->{$obj}",
                        $db, [0], $write_opts->[2]; #}}}

                    ## verbose 4{{{
                    my $debug = [];
                    #if ($write_opts->[1] == 4) {
                    #    push @$debug, mes("<$obj> $container->{$obj}", $db, [1,0,1]);
                    #    push @$debug, mes("lvl: " . $lvl,              $db, [1,0,1]);
                    #} ## }}}

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
        mes("-------------------------", $db, [0]) if $write_opts->[1];
        mes("SUMMARY", $db, [0]) if $write_opts->[1];
        for my $obj (sort {$childs->{$a} <=> $childs->{$b}} keys $childs->%*) {
            my $S0 = " " x (11 - length $obj);
            mes("  $obj ${S0} $childs->{$obj}", $db, [0]) if $write_opts->[1];
        }
        mes("}}"."}", $db, [0]) if $write_opts->[1];
   }
   return $writeArray ?$writeArray :0;
}
#===| delegate2() {{{2
sub delegate2 {

    my $db = shift @_;

    ## sigtrap
    $SIG{__DIE__} = sub {
        if ($db and exists $db->{debug}) {
            print $_ for $db->{debug}->@*;
            print $erreno if $erreno;
        }
    };

    ## checks
    init2($db);

    ## cmp {{{
    {
        my $cmpOpt = $db->{opts}{cmp};

        ## REMOVE PRESERVES
        my $catalog   = dclone $db->{hash}[0];
        my $SECTIONS0 = $catalog->{SECTIONS};
        @$SECTIONS0   = map { $SECTIONS0->[$_] } (1 .. $SECTIONS0->$#*);
        my $masterbin = dclone $db->{hash}[1];
        my $SECTIONS1 = $masterbin->{SECTIONS};
        @$SECTIONS1   = map { $SECTIONS1->[$_] } (1 .. $SECTIONS1->$#*);


        ## TAKE A LOOK
        my $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        my $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        my @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        my @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        my @STORIES0 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES0;
        my @STORIES1 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES1;
        mes "\n==================",              $db, [-1], $cmpOpt->[1];
        mes "%% TAKE A LOOK %%",                 $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}",  $db, [-1], $cmpOpt->[1]) for @STORIES1;
        mes "---------",                         $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}",  $db, [-1], $cmpOpt->[1]) for @STORIES0;


        ## REMOVE UNWANTED SECTIONS
        my @AUTHORS0 = grep { exists $_->{SERIES} and (grep {$_->{series} =~ /other/i} $_->{SERIES}->@*)[0] } @$AUTHORS0;
        my @AUTHORS1 = grep { exists $_->{SERIES} and (grep {$_->{series} =~ /other/i} $_->{SERIES}->@*)[0] } @$AUTHORS1;
        for my $author (@AUTHORS0) {
            my @OTHERS = map {$_->{STORIES}->@*} grep {$_->{series} =~ /other/i} $author->{SERIES}->@*;
            push $author->{STORIES}->@*, @OTHERS;
            $author->{SERIES}->@* = grep {$_->{series} !~ /other/i} $author->{SERIES}->@*;
        }
        for my $author (@AUTHORS1) {
            my @OTHERS = map {$_->{STORIES}->@*} grep {$_->{series} =~ /other/i} $author->{SERIES}->@*;
            push $author->{STORIES}->@*, @OTHERS;
            $author->{SERIES}->@* = grep {$_->{series} !~ /other/i} $author->{SERIES}->@*;
        }


        ## TAKE ANOTHER LOOK
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES0;
        @STORIES1 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES1;
        mes "\n==================",             $db, [-1], $cmpOpt->[1];
        mes "%% TAKE A LOOK %%",                $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES1;
        mes "---------",                        $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES0;


        ## LOOK FOR INTRA DUPLICATES
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0 = map { $_->{STORIES}->@* } @SERIES0;
        @STORIES1 = map { $_->{STORIES}->@* } @SERIES1;
        my %seen0; $seen0{$_}++ for @STORIES0;
        die if (grep {$seen0{$_} > 1} keys %seen0)[0];
        my %seen1; $seen1{$_}++ for @STORIES1;
        die if (grep {$seen1{$_} > 1} keys %seen1)[0];


        ## LOOK FOR INTER DUPLICATES
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0 = map { $_->{STORIES}->@* } @SERIES0;
        @STORIES1 = map { $_->{STORIES}->@* } @SERIES1;
        my %seen;
        my @STORIES = (@STORIES0, @STORIES1);
        $seen{$_->{title}}++ for @STORIES;
        mes "\n==================",            $db, [-1], $cmpOpt->[1];
        mes "%% LOOK FOR INTER DUPLICATES %%", $db, [-1], $cmpOpt->[1];
        my @duplicates = grep {$seen{$_} > 1} keys %seen;
        mes "$_",                              $db, [-1], $cmpOpt->[1] for @duplicates;


        ## GET SERIES TITLE FOR DUPLICATES
        @SERIES0 = grep { (grep { my $title = $_->{title}; (grep {$title eq $_} @duplicates)[0]; } $_->{STORIES}->@*)[0] } @SERIES0;
        @SERIES1 = grep { (grep { my $title = $_->{title}; (grep {$title eq $_} @duplicates)[0]; } $_->{STORIES}->@*)[0] } @SERIES1;
        mes "\n==================",                  $db, [-1], $cmpOpt->[1];
        mes "%% GET SERIES TITLE FOR DUPLICATES %%", $db, [-1], $cmpOpt->[1];
        mes  $_->{series},                           $db, [-1], $cmpOpt->[1] for @SERIES0;
        mes "---------",                             $db, [-1], $cmpOpt->[1];
        mes  $_->{series},                           $db, [-1], $cmpOpt->[1] for @SERIES1;

        ## SEE IF DUPLICATES ARE THE OLNY MEMBERS OF THEIR SERIES
        @SERIES0 = grep { %seen0 = (); $seen0{$_}++ for @duplicates; for my $aa ($_->{STORIES}->@*) {$seen0{$aa->{title}}++}; (grep {$seen0{$_->{title}} == 1 } $_->{STORIES}->@*)[0]; } @SERIES0;
        @SERIES1 = grep { %seen1 = (); $seen1{$_}++ for @duplicates; for my $aa ($_->{STORIES}->@*) {$seen1{$aa->{title}}++}; (grep {$seen1{$_->{title}} == 1 } $_->{STORIES}->@*)[0]; } @SERIES1;
        mes "\n==================",                                         $db, [-1], $cmpOpt->[1];
        mes "%% SEE IF DUPLICATES ARE THE OLNY MEMBERS OF THEIR SERIES %%", $db, [-1], $cmpOpt->[1];
        mes  $_->{series},                                                  $db, [-1], $cmpOpt->[1] for @SERIES0;
        mes "---------",                                                    $db, [-1], $cmpOpt->[1];
        mes  $_->{series},                                                  $db, [-1], $cmpOpt->[1] for @SERIES1;

        ## CHECK IF SERIES ARE THE SAME
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @SERIES0  = grep { (grep { my $title = $_->{title}; (grep {$title eq $_} @duplicates)[0]; } $_->{STORIES}->@*)[0] } @SERIES0;
        @SERIES1  = grep { (grep { my $title = $_->{title}; (grep {$title eq $_} @duplicates)[0]; } $_->{STORIES}->@*)[0] } @SERIES1;
        my @SERIES = (@SERIES0, @SERIES1);
        %seen = ();
        $seen{$_->{series}}++ for @SERIES;
        my @CONFLICTS = grep {$seen{$_} == 1} keys %seen;
        mes "\n==================",               $db, [-1], $cmpOpt->[1];
        mes "%% CHECK IF SERIES ARE THE SAME %%", $db, [-1], $cmpOpt->[1];
        mes  $_,                                  $db, [-1], $cmpOpt->[1] for @CONFLICTS;

        ## CREATE SERIES PAIR CONFLICTS
        my @TODO0 = grep { my $series = $_->{series}; ( grep{ $_ eq $series } @CONFLICTS)[0]; } @SERIES0;
        my @TODO1 = grep { my $series = $_->{series}; ( grep{ $_ eq $series } @CONFLICTS)[0]; } @SERIES1;
        my @TODO;
        for my $series0 (@TODO0) {
            my @stories0 = $series0->{STORIES}->@*;
            my $series1  = (grep { (grep { my $story1 = $_->{title}; (grep {$_->{title} eq $story1} @stories0)[0]; } $_->{STORIES}->@*)[0] } @TODO1)[0];
            push @TODO, [$series0, $series1];
        }
        mes "\n==================",              $db, [-1], $cmpOpt->[1];
        mes "|CREATE SERIES PAIR CONFLICTS|",    $db, [-1], $cmpOpt->[1];
        mes "$_->[0]{series}, $_->[1]{series}",  $db, [-1], $cmpOpt->[1] for @TODO;


        ## IF NOT DELELTE SECTION BY LIB PRIORITY
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        for my $hash (@TODO) {
            my $author  = (grep { (grep{ $_->{series} eq $hash->[0]{series} } $_->{SERIES}->@*)[0] } @$AUTHORS0)[0];
            my $series0 = (grep { $_->{series} eq $hash->[0]{series} } $author->{SERIES}->@*)[0];
            $series0->{series} = $hash->[1]{series};
        }

        ## TAKE ANOTHER LOOK
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES0;
        @STORIES1 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES1;
        mes "\n==================",             $db, [-1], $cmpOpt->[1];
        mes "%% TAKE A LOOK %%",                $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES1;
        mes "---------",                        $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES0;

        ## GET STORIES THAT NEED TO BE REMOVED IN EACH HASH
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        my @toDel1;
        my @SEC_STORIES0 = map { [$_, $_->{STORIES}] } map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @STORIES1        = map { $_->{STORIES}->@* } grep { exists $_->{STORIES} } @$AUTHORS1;
        for my $part0 (@SEC_STORIES0) {
            my $ele;
            for my $story0 ($part0->[1]->@*) {
                push @$ele, (grep {$_->{title} eq $story0->{title}} @STORIES1)[0];
            }
            push @toDel1, [$part0->[0], $ele] if scalar @$ele;
        }
        my @toDel0;
        my @SEC_STORIES1 = map { [$_, $_->{STORIES}] } map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0        = map { $_->{STORIES}->@* } grep { exists $_->{STORIES} } @$AUTHORS0;
        for my $part1 (@SEC_STORIES1) {
            my $ele;
            for my $story1 ($part1->[1]->@*) {
                push @$ele, (grep {$_->{title} eq $story1->{title}} @STORIES0)[0];
            }
            push @toDel0, [$part1->[0], $ele] if scalar @$ele;
        }
        mes "\n==================",                                   $db, [-1], $cmpOpt->[1];
        mes "%% GET STORIES THAT NEED TO BE REMOVED IN EACH HASH %%", $db, [-1], $cmpOpt->[1];
        for my $part (@toDel0) {
            mes "[$part->[0]{series}]", $db, [-1], $cmpOpt->[1];
            mes "    ($_->{title})",       $db, [-1], $cmpOpt->[1] for $part->[1]->@*;
        }
        mes "---------",                $db, [-1], $cmpOpt->[1];
        for my $part (@toDel1) {
            mes "[$part->[0]{series}]", $db, [-1], $cmpOpt->[1];
            mes  "    ($_->{title})",      $db, [-1], $cmpOpt->[1] for $part->[1]->@*;
        }

        ## DELETE STORIES BASED ON DEPTH PRIORITY I EACH LIB
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        for my $part0 (@toDel0) {
            my $stories = dclone $part0->[1];
            my $author  = (grep { (grep { my $story = $_; (grep {$story->{title} eq $_->{title}} @$stories)[0]; } $_->{STORIES}->@*)[0] } @$AUTHORS0)[0];
            push $author->{SERIES}->@*, {series => $part0->[0]{series}, STORIES => $stories};
            $author->{STORIES}->@* = grep { my $story = $_; !(grep {$story->{title} eq $_->{title}} @$stories)[0]; } $author->{STORIES}->@*;
        }

        for my $part1 (@toDel1) {
            my $stories = dclone $part1->[1];
            my $author  = (grep { (grep { my $story = $_; (grep {$story->{title} eq $_->{title}} @$stories)[0]; } $_->{STORIES}->@*)[0] } @$AUTHORS1)[0];
            push $author->{SERIES}->@*, {series => $part1->[0]{series}, STORIES => $stories};
            $author->{STORIES}->@* = grep { my $story = $_; !(grep {$story->{title} eq $_->{title}} @$stories)[0]; } $author->{STORIES}->@*;
        }

        ## TAKE ANOTHER LOOK
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1  = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        @STORIES0 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES0;
        @STORIES1 = map { {series => "[$_->{series}]"} ,$_->{STORIES}->@* } @SERIES1;
        mes "\n==================",             $db, [-1], $cmpOpt->[1];
        mes "%% TAKE A LOOK %%",                $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES1;
        mes "---------",                        $db, [-1], $cmpOpt->[1];
        mes( $_->{series} || "    $_->{title}", $db, [-1], $cmpOpt->[1]) for @STORIES0;

        ## MAKE SURE THINGS ARE EQUAL
        $AUTHORS0 = $SECTIONS0->[0]{AUTHORS};
        $AUTHORS1 = $SECTIONS1->[0]{AUTHORS};
        @SERIES0 = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS0;
        @SERIES1 = map { $_->{SERIES}->@* } grep { exists $_->{SERIES} } @$AUTHORS1;
        for my $series0 (@SERIES0) {
            my $series1 = (grep {$_->{series} eq $series0->{series}} @SERIES1)[0] || die;
            for my $story0 ($series0->{STORIES}->@*) {
                my $story1 = (grep {$_->{title} eq $story0->{title}} $series0->{STORIES}->@*)[0] || die;
            }
        }


    }
    # }}}

    my $catalog = $db->{hash}[0]{SECTIONS}[1];
        my $catalog_contents          = dclone($catalog);
        $catalog                      = {};
        $catalog->{contents}          = $catalog_contents;
        $catalog->{contents}{libName} = 'hmofa_lib';
        $catalog->{reff}              = $catalog;
        #$catalog->{contents}->{libName}  = 'catalog';
        delete $catalog->{contents}{section};

    my $masterbin = $db->{hash}[1]{SECTIONS}[1];
        my $masterbin_contents            = dclone($masterbin);
        $masterbin                        = {};
        $masterbin->{contents}            = $masterbin_contents;
        $masterbin->{contents}->{libName} = 'hmofa_lib';
        $masterbin->{reff}                = $masterbin;
        #$catalog->{contents}->{libName}  = 'masterbin';
        delete $masterbin->{contents}{section};

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
            deleteKey( $_, 'LN',     $index, $Data::Walk::container);
            deleteKey( $_, 'raw',    $index, $Data::Walk::container);
            removeKey( $_, 'SERIES', 'STORIES', $index, $container);
            deleteKey( $_, 'preserve',   $index, $Data::Walk::container);
            filter   ( $_, 'url',    $index, $Data::Walk::container, $sub);
        }
    };

    my $walker2 = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            deleteKey ( $_, 'LN',                $index, $container);
            deleteKey ( $_, 'raw',               $index, $container);
            removeKey( $_, 'SERIES', 'STORIES', $index, $container);
            deleteKey ( $_, 'url_attribute',               $index, $container);
            deleteKey( $_, 'preserve',   $index, $Data::Walk::container);
            #deleteKey ( $_, 'URLS',               $index, $container);
            #deleteKey ( $_, 'TAGS',               $index, $container);
            filter    ( $_, 'url',               $index, $container, $sub);
        }
    };
    # }}}

    walkdepth { wanted => $walker} ,  $masterbin->{contents};
    walkdepth { wanted => $walker2}, $catalog->{contents};
    sortHash($db,$catalog);
    sortHash($db,$masterbin);

    #my $new_hash = combine( $db, $masterbin, $catalog );
    my $new_hash = combine( $db, $catalog, $masterbin );

    ## output
    print $_ for $db->{debug}->@*;
    {
        my $json_obj = JSON::PP->new->ascii->pretty->allow_nonref;
        $json_obj = $json_obj->allow_blessed(['true']);
        if ($db->{opts}{sort}) {
            $json_obj->sort_by( sub { cmpKeys( $db, $JSON::PP::a, $JSON::PP::b, $_[0] ); } );
        }
        my $json  = $json_obj->encode($new_hash->{contents});

        open my $fh, '>', $db->{fileNames}{output} or die;
            print $fh $json;
            truncate $fh, tell( $fh ) or die;
        close $fh
    }

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
    my ($data, $key_a, $key_b, $hash, $opts) = @_;

    # save point if already defined
    my @save = exists $data->{point} ?$data->{point}->@* :();

    my $pointStr_a = getPointStr_FromUniqeKey($data, $key_a) ? getPointStr_FromUniqeKey($data, $key_a)
                                                             : genPointStr_ForRedundantKey($data, $key_a, $hash);
    my $pointStr_b = getPointStr_FromUniqeKey($data, $key_b) ? getPointStr_FromUniqeKey($data, $key_b)
                                                             : genPointStr_ForRedundantKey($data, $key_b, $hash);
    my @point_a = split /\./, $pointStr_a;
    my @point_b = split /\./, $pointStr_b;

    ## NEGITIVE ORDERS
    if ($point_a[-1] < $point_a[-1]*-1) {
        $pointStr_a = genPointStr_ForRedundantKey($data, $key_a, $hash,1);
        @point_a = split /\./, $pointStr_a;
    }
    if ($point_b[-1] < $point_b[-1]*-1) {
        $pointStr_b = genPointStr_ForRedundantKey($data, $key_b, $hash,1);
        @point_b = split /\./, $pointStr_b;
    }

    my $len_a   =  scalar @point_a;
    my $len_b   =  scalar @point_b;
    my $lvlObj  = getLvlObj($data,$hash);
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
        $data->{point}->@* = @save;
    } else {
        delete $data->{point};
    }

    return $bool;

    #===|| getPointStr_FromUniqeKey() {{{3
    sub getPointStr_FromUniqeKey {
        my ($data, $key)  = @_;

        if    (exists $data->{dspt}{$key})          { return $data->{dspt}{$key}{order} }
        elsif (getObj_FromGroupName($data, $key))   { return $data->{dspt}{getObj_FromGroupName($data, $key)}{order} }
        else                                        { return 0 }

        #===| getObj_FromGroupName() {{{4
        sub getObj_FromGroupName {

            my $data      = shift @_;
            my $dspt      = $data->{dspt};
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

        my ($data, $key, $hash, $F)  = @_;

        my $lvlObj     =  getLvlObj($data, $hash);
        $data->{point} = [ split /\./, $data->{dspt}{$lvlObj}{order} ];
        my $pointStr   = getPointStr($data);
        my $dspt_obj   = $data->{dspt}{getObj($data)};

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
        } elsif (isReservedKey($data, $key) or $F) {
            my $first = join '.', $data->{point}->@[0 .. ($data->{point}->$#* - 1)];
            my $pointEnd = $data->{point}[-1];

            # order
            my $order;
            if ($F) {
                my $obj = getObj_FromGroupName($data,$key) ?getObj_FromGroupName($data,$key)
                                                           :$key;
                my @point = split /\./, $data->{dspt}{$obj}{order};
                my $resvMax = 0;
                for (keys $data->{reservedKeys}->%*) {
                    my $resvOrder = $data->{reservedKeys}{$_}[1];
                    $resvMax = $resvOrder if $resvMax < $resvOrder;
                }
                $order = $point[-1]*-1 + $resvMax;
            } else { $order = $data->{reservedKeys}{$key}[1] }

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
        } elsif (exists $data->{dspt}{$key} and $data->{dspt}{$key}{order} == 0 ) {
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
        delegate => [1,0,0,0,0,0,0,0,0],
        leveler  => [1,0,0,0,0,0,0,0,0],
        divy     => [1,0,0,0,0,0,0,0,0],
        attribs  => [1,0,0,0,0,0,0,0,0],
        delims   => [1,0,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => [0,0,0,0,0,0,0,0,0],
        display  => [0,0,0,0,0,0,0,0,0],
        lineNums => [0,0,0,0,0,0,0,0,0],

        ## MISC
        sort     => [0,0,0,0,0,0,0,0,0],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| genOpts2() {{{2
sub genOpts2 {
    my $ARGS = shift @_;
    my $defaults = {

        ## Processes
        combine  => [1,0,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0,0],
        cmp      => [1,0,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => [0,0,0,0,0,0,0,0,0],
        display  => [0,0,0,0,0,0,0,0,0],
        lineNums => [0,0,0,0,0,0,0,0,0],

        ## MISC
        sort     => [0,0,0,0,0,0,0,0,0],
    };
    $defaults->{$_} = $ARGS->{$_}  for keys %{$ARGS};
    return $defaults;
}


#===| getAttrDspt(){{{2
sub getAttrDspt {
    my ($data, $obj) = @_;
    my $objDspt = $data->{dspt}{$obj};
    my $attrDspt = (exists $objDspt->{attributes}) ? $objDspt->{attributes}
                                                   : 0;
    return $attrDspt;
}


#===| getGroupName() {{{2
sub getGroupName {
    # return GROUP_NAME at current point.
    # return 'getObj()' if GROUP_NAME doesn't exist!

    my $data = shift @_;
    my $obj  = shift @_;
    my $dspt = $data->{dspt};
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
    my $data = shift @_;
    my $hash = shift @_;
    if (ref $hash eq 'HASH') {
        for (keys $hash->%*) {
             if ( exists $data->{dspt}{$_} ) {return $_}
        }
    }
}


#===| getObj() {{{2
sub getObj {
    # return OBJECT_KEY at current point
    # return '0' if CURRENT_POINT doesn't exist!
    # return '0' if OBJECT_KEY doesn't exist for CURRENT_POINT!

    my $data      = shift @_;
    my $dspt      = $data->{dspt};
    my $point     = $data->{point};
    my $pointStr  = join( '.', $point->@* );

    if ($pointStr eq '') { die("pointStr cannot be an empty string! In ${0} at line: ".__LINE__) }
    else {
        my @match = grep { ($dspt->{$_}{order} // "") =~ /^$pointStr$/ } keys $dspt->%*;

        unless ($match[0])         { return 0 }
        elsif  (scalar @match > 1) { die("more than one objects have the point: \'${pointStr}\'! In ${0} at line: ".__LINE__) }
        else                       { return $match[0] }
    }

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
    my ($data, $lvlObj, $key) = @_;
    my $attrDspt = getAttrDspt($data,$lvlObj);
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
    my ($data, $key)  = @_;
    my $resvKeys      = $data->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
}


#===| mes() {{{2
sub mes {
    my ($mes, $data, $opts, $bool) = @_;
    $bool = 1 unless scalar @_ >= 4;

    if ($data->{opts}->{verbose} and $bool) {
        my ($cnt, $NewLineDisable, $silent) = @$opts if $opts;
        my $indent = "    ";

        $mes = ( $cnt ? $indent x (1 + $cnt) : $indent )
             . $mes
             . ( !($NewLineDisable) ? "\n" : "" );

        push $data->{debug}->@*, $mes unless $silent;
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
    my ($data, $hash) = @_;


    #===| sortSub->(){{3
    my $sortSub = sub {
        my $key = shift @_;
        my $index = shift @_;
        my $container  = shift @_;
        if ( ($index % 2) == 0 and ref $container->{$key} eq 'ARRAY') {
            my $checkobj = getLvlObj($data, $container->{$key}[0]);
            if ($checkobj) {
                $container->{$key} = [ sort {
                    my $obj_a = getLvlObj($data, $a);
                    my $obj_b = getLvlObj($data, $b);
                    if ($obj_a ne $obj_b) {
                        lc $data->{dspt}{$obj_a}{order} cmp lc $data->{dspt}{$obj_b}{order}
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
