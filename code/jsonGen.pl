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
use JSON::XS;
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
    ## --- OPTS {{{
    # ;opts
        my $opts = genOpts({
            ## Processes
            delegate => [1,1,0,0,0,0,0,0],
            leveler  => [1,0,0,0,0,0,0,0],
            divy     => [1,0,0,0,0,0,0,0],
            swpr     => [1,0,0,0,0.0,0,0],
            write    => [1,0,0,0,0.0,0,0],
            attribs  => [1,0,0,0,0,0,0,0],
            delims   => [1,0,0,0,0,0,0,0],
            encode   => [1,0,0,0,0,0,0,0],
            prsv     => [1,0,0,0,0,0,0,0],

            ## STDOUT
            verbose  => 1,

            ## MISC
            sort    => 0,
        });
    my $opts2 = genOpts2({
        ## Processes
        combine  => [1,0,0,0,0,0,0,0],
        encode   => [1,0,0,0,0,0,0,0],
        swpr     => [1,0,0,0,0.0,0,0],
        write    => [1,0,0,0,0,0,0,0],
        delegate => [1,0,0,0,0,0,0,0],
        cmp      => [1,0,0,0,0,0,0,0],

        ## STDOUT
        verbose  => 1,

        ## MISC
        sort    => 0,
    });
    #}}}
    ## --- DELEGATES {{{
    ## masterbin
        hasher({
            opts  => $opts,
            name  => 'masterbin',
            drsr  => $drsr_M,
            preserve => {
                libName => [ [''], 'section'],
                section => [ ['FOREWORD'], ],
            },
            fileNames => {
                fname  => '../masterbin.txt',
                output => './json/masterbin.json',
                dspt   => './json/deimos.json',
            },
        });

    ## tagCatalog
        hasher({
            opts  => $opts,
            name  => 'catalog',
            drsr  => $drsr_C,
            preserve => {
                libName => [ [''], 'section'],
                section => [ ['Introduction/Key'] ],
            },
            fileNames => {
                fname  => '../tagCatalog.txt',
                output => './json/catalog.json',
                dspt   => './json/deimos.json',
            },
        });

    ## hmofa_lib
        masher({
            opts => $opts2,
            name => 'hmofa_lib',
            drsr  => $drsr_H,
            fileNames => {
                fname    => ['./db/catalog/catalog.json', './db/masterbin/masterbin.json',],
                output   => './json/hmofa_lib.json',
                dspt     => './json/deimos.json',
                external => ['./json/gitIO.json'],
            },
        });
    ## hmofa_lib
        masher({
            opts => $opts2,
            name => 'libby',
            drsr  => $drsr_C,
            fileNames => {
                fname    => ['./db/catalog/catalog.json', './db/masterbin/masterbin.json',],
                output   => './json/libby.json',
                dspt     => './json/deimos.json',
                external => ['./json/gitIO.json'],
            },
        });
    print `./diff.sh`;
}
# SUBROUTINES {{{1
#------------------------------------------------------

#===| hasher() {{{2
# Args
    # dspt
    # dsr
    # name
    # opts
    # output json
    # prsv
    # txt file
# decode
    # from json
# encode
    # matches
    # convert
    # encode
# write
     # txt file from json
sub hasher {

    my $db = shift @_;
    my $delegate_opts = $db->{opts}{delegate};
    $SIG{__DIE__} = sub {
        if ($db and exists $db->{debug}) {
            print $_ for $db->{debug}->@*;
            print $erreno if $erreno;
        }
    };
    if ($delegate_opts->[0]) {
        _init($db);

        ## verbose 1 #{{{
        mes "\n...Generating $db->{name}", $db, [-1], $delegate_opts->[1];

        ## --- matches {{{3
        getMatches($db);

        ## --- convert #{{{3
        _leveler($db,\&_checkMatches);

        ## --- encode  #{{{3
        encodeResult($db);

        ## --- write array {{{3
        my $writeArray = _sweeper($db) || die;
        open my $fh, '>', './result/'.$db->{result}{libName}.'.txt' or die $!;
        {
            #binmode($fh, "encoding(UTF-8)");
            for (@$writeArray) {
                print $fh $_,"\n";
            }
            truncate $fh, tell($fh) or die;
            seek $fh,0,0 or die;
        }
        close $fh;

        ## --- output {{{3

        if ($delegate_opts->[1]) {
            ## Matches Meta
            my $matches_Meta = $db->{meta}{matches};
            my $max = length _longest(keys $matches_Meta->%*);

            ## Subs
        }

        ## --- WRITE {{{3
        my $headDir = './db';
        my $dirname = $headDir.'/'.$db->{result}{libName};
        mkdir $headDir if (!-d './db');
        mkdir $dirname if (!-d $dirname);

        ## META
        {
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
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
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
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
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
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
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{matchesByLine});
            my $fname    = $dirname.'/matchesByLine.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## StaticMatches
        {
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
            $json_obj    = $json_obj->allow_blessed(['true']);
            my $json     = $json_obj->encode($db->{static}{matches});
            my $fname    = $dirname.'/static_matches.json';
            open my $fh, '>', $fname or die "Error in opening file $fname\n";
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close $fh;
        }
        ## DSPT
        {
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
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

        ## verbose 1 #{{{3
        my $max = 22;
        mes "...summarizing $db->{name}",   $db, [-1], $delegate_opts->[2];
        mes "KEY ".(' 'x($max-3))." VALUE", $db, [0], $delegate_opts->[2];
        mes "- ".(' 'x($max-1))." -",       $db, [0], $delegate_opts->[2];
        for my $key (sort {$a cmp $b} keys $db->%*) {
            my $S0 = " " x ($max - length $key);
            mes "$key ${S0} $db->{$key}", $db, [0], $delegate_opts->[2];
        }
        print $_ for $db->{debug}->@*; #}}}

        return $db;
    }
}


#===| getMatches() {{{2
sub getMatches {

    my $db = shift @_;
    my $dspt = $db->{dspt};

    ## --- open tgt file for regex parsing
    open my $fh, '<', $db->{fileNames}{fname}
        or die $!;
    {
        my $FR_prsv = {F=>0, obj=>'libName'};
        while (my $line = <$fh>) {

            ## --- Regex LOOP
            my $match;
            for my $obj (keys %$dspt) {
                if (exists $dspt->{$obj}{re} and $line =~ $dspt->{$obj}{re}) {
                    next if _isPrsv($db,$obj,$1,$FR_prsv);
                    $match = {
                        LN   => $.,
                        $obj => $1,
                        raw  => $line,
                    }; push $db->{matches}{$obj}->@*, $match;
                }
            }

            ## --- Put MISSES in PRESERVES
            if (!$match and _isPrsv($db,'NULL','',$FR_prsv)) {
                $match = {
                    LN       => $.,
                    preserve => $line,
                }; push $db->{matches}{preserve}->@*, $match;
            }
        }
    } close $fh ;

    ## -- utilize regex matches
    $db->{static}{matches} = dclone($db->{matches});
    for my $obj (keys %$dspt, 'preserve') {
        $db->{meta}{matches}{$obj}{count} =
            ($db->{matches}{$obj}) ? scalar $db->{matches}{$obj}->@*
                                   : 0;
    }

    $db->{matchesByLine}->%* =
        map {
            map {
                $_->{LN} => $_
            } $db->{matches}{$_}->@*
        } keys $db->{matches}->%*;

}


#===| divyMatches() {{{2
sub divyMatches {

    my $db = shift @_;
    my $opts_divy = $db->{opts}{divy};
    if ($opts_divy->[0]) {

        my $obj  = _getObj($db);
        my $dspt = $db->{dspt};
        my @objMatches = $db->{matches}{$obj}->@*;

        ## --- REFARRAY LOOP
        my $refArray = $db->{reffArray};
        my $ind      = (scalar @$refArray) - 1;
        for my $ref (reverse @$refArray) {
            my $lvlObj  = _getLvlObj($db, $ref);
            my $ref_LN  = $ref->{LN} ?$ref->{LN} :0;

            ## verbose 1 {{{
            my $S0 = ' 'x(9-length $lvlObj);
            mes "[$lvlObj] ${S0} $ref->{$lvlObj}", $db, [1], $opts_divy->[1]; #}}}

            ## --- MATCHES LOOP {{{3
            my $childObjs;
            for my $match (reverse @objMatches) {
                next unless $match;

                # CHECKS
                unless (exists $match->{$obj}) {
                    $erreno = "ERROR!: undef match->{obj} at $0 line ".__LINE__;
                    die }
                unless ($match->{LN}) {
                    $erreno = "$lvlObj,$obj ERROR!: undef match->{LN} at $0 line ".__LINE__;
                    die }

                ## --- MATCH FOUND {{{
                if ($match->{LN} > $ref_LN) {
                    my $match     = pop @objMatches;
                    genAttributes( $db, $match);
                    push @$childObjs, $match;

                    ## verbose 2 {{{
                    my $S0 = ' 'x(9-length $lvlObj);
                    mes "<$obj> ${S0} $match->{$obj}", $db, [2], $opts_divy->[2]; #}}}

                } else { last } #}}}
            }

            ## --- MATCHES TO REFARRAY {{{3
            if ($childObjs) {
                @$childObjs = reverse @$childObjs;
                my $groupName = _getGroupName($db, $obj);
                $refArray->[$ind]{$groupName} = $childObjs;
                splice( @$refArray, $ind, 1, ($refArray->[$ind], @$childObjs) );

            } #}}}

            $ind--;
        }
    }
}

#===| genAttributes() {{{2
sub genAttributes {

    my $db  = shift @_;
    my $match = shift @_;
    my $attrOPTS = $db->{opts}{attribs};

    if ($attrOPTS->[0]) {

        my $obj       = _getObj($db);
        my $objDSPT   = $db->{dspt}{$obj};
        $match->{raw} = $match->{$obj};

        if (exists $objDSPT->{attributes}) {
            my $attrDSPT       = $objDSPT->{attributes};
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
}


#===| encodeResult() {{{2
sub encodeResult {

    my $db  = shift @_;

    #proof of concept {{{3
    $db->{result}{'.'}  = \$db->{result};
    $db->{result}{'..'} = \$db;

    $db->{result}{TAGS} = [
        \$db->{result}{TAGS},
        \$db->{result},
        1,
    ];

    my $circ_ref = $db->{circ_array};
    push @$circ_ref, \$db->{result};
    push @$circ_ref, \$db->{result}{TAGS};
    for my $ref (@$circ_ref) {
        my $rt = ref $$ref;
        if ($rt eq 'HASH') {
            my $href = $$ref;
            delete $href->{'.'};
            delete $href->{'..'};
        } elsif ($rt eq 'ARRAY'){
            my $aref = $$ref;
            my $sz = scalar @$aref;
            if ($sz > 2) {
                @$aref = $aref->@[2 .. $aref->$#*];
            } else {
                @$aref = ();
            }
        }
    }
    delete $db->{result}->{TAGS};#}}}


    if  ($db->{opts}{encode}[0]) {
        my $fname = $db->{fileNames}{output};
        {
            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
            $json_obj = $json_obj->allow_blessed(['true']);
            my $json  = $json_obj->encode($db->{result});
            open( my $fh, '>' ,$fname ) or die $!;
                print $fh $json;
                truncate $fh, tell( $fh ) or die;
            close( $fh );
        }
    }
}


#===| masher() {{{2
# ARGS
    # direcorty
    # directory
    # hash list
# cmp
# cmb
sub masher {

    my $ov = shift @_;
    $SIG{__DIE__} = sub {
        if ($ov and exists $ov->{debug}) {
            print $_ for $ov->{debug}->@*;
            print $erreno if $erreno;
        }
    };
    _init2($ov);

    my $catalog   = dclone $ov->{hash}[0];
    my $masterbin = dclone $ov->{hash}[1];

    ## --- cmp {{{3
    # takes hash list; clones them; removes prsvs (remember parent) and
    # equalizes them with
    # verbose; interactive
    {
        #top prsv removed
        delete $masterbin->{PRESERVE};
        delete $catalog->{PRESERVE};

        my $SECTIONS0 = $catalog->{SECTIONS};
        my $SECTIONS1 = $masterbin->{SECTIONS};

        # section prsv removed
        @$SECTIONS0 = map { $SECTIONS0->[$_] } (1 .. $SECTIONS0->$#*);
        @$SECTIONS1 = map { $SECTIONS1->[$_] } (1 .. $SECTIONS1->$#*);

        ## --- UO - LO {{{4
        ## SETUP {{{5
        my $lo    = 'title';  my $LO = _getGroupName($ov,$lo);
        my $uo    = 'series'; my $UO = _getGroupName($ov,$uo);
        my $co    = 'author'; my $CO = _getGroupName($ov,$co);
        my $uo_uw = 'other';
        my $COs   = [$SECTIONS0->[0]{$CO}, $SECTIONS1->[0]{$CO}];
        my @UOs;
        my @LOs;
        my @COs;

        ## TAKE A LOOK {{{5
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

        ## verbose 1 {{{6
        mes "\n==================",        $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% TAKE A LOOK %%",           $ov, [-1], $ov->{opts}{cmp}->[1];
        for my $LO_ (@LOs) {
            mes( $_->{$uo} || "    $_->{$lo}", $ov, [0],  $ov->{opts}{cmp}->[1]) for @$LO_;
            mes "---------",                   $ov, [0],  $ov->{opts}{cmp}->[1];
        }

        ## REMOVE UNWANTED UOs {{{5
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
        }

        ## LOOK FOR dupes FOR LO {{{5
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
        ## verbose {{{6
        mes "\n==================",       $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% LOOK FOR INTER dupes %%", $ov, [-1], $ov->{opts}{cmp}->[1];
        my @dupes = grep {$seen{$_} > 1} keys %seen;
        mes "$_",                         $ov, [0], $ov->{opts}{cmp}->[1] for @dupes;

        ## GET SERIES LO FOR dupes #{{{5
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
        ## verbose {{{6
        mes "\n==================",         $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% GET UO TITLE FOR dupes %%", $ov, [-1], $ov->{opts}{cmp}->[1];
        for my $UO_ (@UOs) {
            mes $_->{$uo},  $ov, [0], $ov->{opts}{cmp}->[1] for @$UO_;
            mes "---------", $ov, [0], $ov->{opts}{cmp}->[1];
        }

        ## SEE IF dupes ARE THE ONLY MEMBERS OF THEIR UO {{{5
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
        ## verbose {{{6
        mes "\n==================",                                $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% SEE IF dupes ARE THE OLNY MEMBERS OF THEIR UO %%", $ov, [-1], $ov->{opts}{cmp}->[1];
        for my $UO_ (@UOs) {
            mes $_->{$uo},  $ov, [0], $ov->{opts}{cmp}->[1] for @$UO_;
            mes "---------", $ov, [0], $ov->{opts}{cmp}->[1];
        }

        ## CHECK IF UO ARE THE SAME #{{{5
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
        ## verbose {{{6
        mes "\n==================",           $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% CHECK IF UO ARE THE SAME %%", $ov, [-1], $ov->{opts}{cmp}->[1];
        mes  $_,                              $ov, [0],  $ov->{opts}{cmp}->[1] for @CONFLICTS;

        ## CREATE UO PAIR CONFLICTS #{{{5
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
        ## verbose {{{6
        mes "\n==================",       $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "|CREATE UO PAIR CONFLICTS|", $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "$_->[0]{$uo}, $_->[1]{$uo}", $ov, [0], $ov->{opts}{cmp}->[1] for @TODO;

        ## IF NOT DELELTE SECTION BY LIB PRIORITY #{{{5
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
        ## verbose {{{6
        mes "\n==================",                              $ov, [-1], $ov->{opts}{cmp}->[1];
        mes "%% GET lo THAT NEED TO BE REMOVED IN EACH HASH %%", $ov, [-1], $ov->{opts}{cmp}->[1];
        for my $toDel_ (@toDels) {
            for my $part (@$toDel_) {
                mes "[$part->[0]{$uo}]", $ov, [0], $ov->{opts}{cmp}->[1];
                mes "    ($_->{$lo})",   $ov, [0], $ov->{opts}{cmp}->[1] for $part->[1]->@*;
            }
            mes "---------",             $ov, [0], $ov->{opts}{cmp}->[1];
        }

        ## DELETE LO BASED ON DEPTH PRIORITY I EACH LIB #{{{5
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
        }

        ## MAKE SURE THINGS ARE EQUAL #{{{5
        for my $uo0 ($UOs[0]->@*) {
            my $uo1 = (grep {$_->{$uo} eq $uo0->{$uo}} $UOs[1]->@*)[0] || die;
            for my $lo0 ($uo0->{$LO}->@*) {
                my $lo1 = (grep {$_->{$lo} eq $lo0->{$lo}} $uo0->{$LO}->@*)[0] || die} }

    }

    ## --- refurbish hashes {{{3
    #creates 'contents' key for non-writable structures;
    $catalog = { result => $catalog };
    $catalog->{result}{libName} = $ov->{name};
    $catalog->{result}{SECTIONS}[0]{section} = 'masterbin';

    $masterbin = { result => $masterbin };
    $masterbin->{result}->{libName} = $ov->{name};
    $masterbin->{result}{SECTIONS}[0]{section} = 'masterbin';

    my $sub = _genFilter({
        pattern => qr?\Qhttps://raw.githubusercontent.com/Azuhmier/hmofa/master/archive_7/\E(\w{8})?,
        dspt    => $ov->{external}{gitIO},
    });

    ## --- Combine {{{3
    ## --- Walkers {{{4
    my $walker = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            _deleteKey( $_, 'LN',                $index, $container);
            _deleteKey( $_, 'raw',               $index, $container);
            filter   ( $_, 'url',               $index, $container, $sub);
        }
    };

    my $walker2 = sub {
        my $type      = $Data::Walk::type;
        my $index     = $Data::Walk::index;
        my $container = $Data::Walk::container;
        if ($type eq 'HASH') {
            _deleteKey( $_, 'LN',                $index, $container);
            _deleteKey( $_, 'raw',               $index, $container);
            _deleteKey( $_, 'url_attribute',     $index, $container);
            filter   ( $_, 'url',               $index, $container, $sub);
        }
    };#}}}

    walkdepth { wanted => $walker} ,  $masterbin->{result};
    walkdepth { wanted => $walker2}, $catalog->{result};
    _sortHash($ov,$catalog);
    _sortHash($ov,$masterbin);

    $ov->{static}{hash}[0]{result} = dclone $catalog->{result};
    $ov->{static}{hash}[1]{result} = dclone $masterbin->{result};
    $ov->{static}{hash}[0]{dspt} = dclone $ov->{dspt};
    $ov->{static}{hash}[1]{dspt} = dclone $ov->{dspt};
    $ov->{static}{hash}[0]{opts} = dclone $ov->{opts};
    $ov->{static}{hash}[1]{opts} = dclone $ov->{opts};
    $ov->{static}{hash}[0]{name} = 'catalog';
    $ov->{static}{hash}[1]{name} = 'masterbin';
    $ov->{result} = combine( $ov, $catalog, $masterbin );
    $ov->{result} = dclone $ov->{result}{result};

    $ov->{dspt} = getJson('/Users/azuhmier/hmofa/hmofa/code/db/catalog/dspt.json');

    ## --- output #{{{3
    _validate($ov);

    print $_ for $ov->{debug}->@*;
    {
        my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
        $json_obj = $json_obj->allow_blessed(['true']);
        my $json  = $json_obj->encode($ov->{result});

        open my $fh, '>', $ov->{fileNames}{output} or die;
            print $fh $json;
            truncate $fh, tell( $fh ) or die;
        close $fh
    }#}}}
    ## --- write array {{{3
    $ov->{result} = dclone $ov->{result};
    _sortHash($ov,$ov);
    $ov->{result} = dclone $ov->{result};
    #delete $ov->{contents};
    my $writeArray = _sweeper($ov) || die;
    open my $fh, '>', './result/'.$ov->{result}{libName}.'.txt' or die $!;
    {
        #binmode($fh, "encoding(UTF-8)");
        for (@$writeArray) {
            print $fh $_,"\n";
        }
        truncate $fh, tell($fh) or die;
        seek $fh,0,0 or die;
    }
    close $fh;#}}}
    ## --- WRITE {{{
    my $CONFIG_DIR = glob '~/.ohm/.config';
    my $PWD = 0;
    {
        open my $fh, '<', $CONFIG_DIR
            or die 'something happened';
        while (my $line = <$fh>)  {
            if ($line =~ m/^PWD=(.*)/) {
                $PWD = $1;
                last;
            }
        }
    }

    #my $result = `{ printf "[TOC]\n"; cat ./result/hmofa_lib.txt;} | rentry edit -p ${PWD} -u hmofa`;
    #}}}

    return $ov;
}


#===| combine() {{{2
## args
#  - hash
#      - contents
#  - ov
#      - reff_0
#      - reff_1
#      - pointer
#          - lvl
sub combine {

    my ($ov, $hash_0, $hash_1) = @_;
    unless (exists $ov->{pointer}) { $ov->{pointer} = [0] };
    $ov->{reff_0}  = [ $hash_0->{result} ]; my $reff_0 = $ov->{reff_0};
    $ov->{reff_1}  = [ $hash_1->{result} ]; my $reff_1 = $ov->{reff_1};


    # ===|| preprocess->() {{{3
    my $preprocess = sub {

        my @children = @_;
        my $pointer  = $ov->{pointer};
        my $cmbOpts  = $ov->{opts}{combine};
        my $lvl      = $Data::Walk::depth - 2;
        my $type     = $Data::Walk::type;

        ## Pre HASH {{{4
        if ($type eq 'HASH') {

            ## config pointer{{{
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
            my $obj = _getLvlObj($ov, $lvlHash_0) || die;#}}}

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
                } elsif ($bool == -1) {
                    unshift @keys_1, $key_0;
                    my $ref = ref $lvlHash_0->{$key_0};
                    $lvlHash_1->{$key_0} = $ref ?dclone($lvlHash_0->{$key_0})
                                                :$lvlHash_0->{$key_0};
                } else {
                    shift @keys_0;
                    shift @keys_1;
                }
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
            my $obj = _getLvlObj($ov, $lvlArray_0->[0]);

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
                    } elsif ($bool == -1) {
                        unshift @array_1, dclone $objHash_0;                                   ## OBJ
                    } else {
                        push @$lvlArray_0, (shift @array_0);
                        push @$lvlArray_1, (shift @array_1);
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
                    } elsif ($bool == -1) {
                        unshift @array_1, $item_0;                                      ## PART
                    } else {
                        push @$lvlArray_0, (shift @array_0);
                        push @$lvlArray_1, (shift @array_1);
                    }
                }
            }
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
        my $pointer = $ov->{pointer};
        my $cmbOpts = $ov->{opts}{combine};
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

                    ## CHECKS
                    if (ref $item_0 ne 'ARRAY'
                    and ref $item_0 ne 'HASH'
                    and ref $item_1 ne 'ARRAY'
                    and ref $item_1 ne 'HASH'
                    and $item_0     ne $item_1 )
                    {
                        mes($item_0." ne ".$item_1,$ov,[0],$cmbOpts->[1]);
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
                my $lvlObj_0     = _getLvlObj($ov, $hash);
                my $lvlObj_1     = _getLvlObj($ov, $lvlReff_1->[$pli]);
                my $lvlItem_0    = $lvlObj_0 ?$lvlReff_0->[$pli]->{$lvlObj_0} : undef;
                my $lvlItem_1    = $lvlObj_1 ?$lvlReff_1->[$pli]->{$lvlObj_1} : undef;
                my $groupName    = _getGroupName($ov, $lvlObj_0);
                my $pointStr     = join('.', @$pointer);

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

    walk { wanted => $wanted, preprocess => $preprocess}, $hash_0->{result};

    return $hash_0;
}

#===| _init() {{{2
sub _init {

  my $db = shift @_;

  ## --- properties {{{3
  unless (exists $db->{point}    ) {$db->{point}     = [1]}
      else {warn "WARNING!: 'point' is already defined by user!"}
  unless (exists $db->{result}   ) {$db->{result}    = { libName => $db->{name}} }
      else {warn "WARNING!: 'result' is already defined by user!"}
  unless (exists $db->{reffArray}) {$db->{reffArray} = [$db->{result}]}
      else {warn "WARNING!: 'reffArray' is already defined by user!"}
  unless (exists $db->{meta}     ) {$db->{meta}      = {}}
      else {warn "WARNING!: 'meta' is already defined by user!"}
  unless (exists $db->{debug}    ) {$db->{debug}     = []}
      else {warn "WARNING!: 'debug' is already defined by user!"}
  unless (exists $db->{pointer}  ) {$db->{pointer}   = []}
      else {warn "WARNING!: 'index' is already defined by user!"}
  _genReservedKeys($db);

  ## --- fnames {{{3
  unless ($db->{fileNames}{dspt}  ) {die "User did not provide filename for 'dspt'!"  }
      _genDspt($db);
  unless ($db->{fileNames}{fname} ) {die "User did not provide filename for 'fname'!" }
  unless ($db->{fileNames}{output}) {die "User did not provide filename for 'output'!"} #}}}
}
#===| _genReservedKeys() {{{2
sub _genReservedKeys {

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

#===| _genDspt {{{2
sub _genDspt {

    my $db = shift @_;
    my $dspt = do {
        open my $fh, '<', $db->{fileNames}{dspt};
        local $/;
        decode_json(<$fh>);
    };

    $dspt->{libName}  = { order =>'0', groupName =>'LIBS'};
    $dspt->{preserve} = { order =>'-1', groupName =>'PRESERVE'};

    ## --- Generate Regex's #{{{3
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

    ## --- preserve #{{{3
    if (exists $db->{preserve}) {
        for my $obj (keys $db->{preserve}->%*) {
            $dspt->{$obj}{preserve}->@* = $db->{preserve}{$obj}->@*;
        }
    } delete $db->{preserve};

    ## --- VALIDATE {{{3
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

    ## --- META {{{3
    my @orders = grep { defined } map {$dspt->{$_}{order}} keys %$dspt;
    $db->{meta}{dspt}{max} = (
        sort {
            length $b <=> length $a
                ||
            substr($b, -1) <=> substr($a, -1);
        } @orders
    )[0];
    ## --- META {{{3
    $dspt->{NULL}{groupNames} = {
        map  { $dspt->{$_}{groupName} => $_  }
        grep { exists $dspt->{$_}{groupName} }
        keys %$dspt
    };

    #}}}

    $db->{dspt} = $dspt;
}


#===| _leveler() {{{2
# iterates in 2 dimensions the order of the dspt
sub _leveler {

    my ($db,$sub) = @_;
    my $opts_leveler = $db->{opts}{leveler};

    if ($opts_leveler->[0]) {

        ## check existance of OBJ at current point
        my $obj = _getObj( $db );
        unless ($obj) { return }

        ## Reverence Arrary for the current recursion
        my $recursionReffArray;
        while ($obj) {

            ## verbose 1 {{{
            mes _getPointStr($db)." $obj", $db, [0], $opts_leveler->[1]; #}}}

            ## Checking existance of recursionReffArray
            unless (defined $recursionReffArray) { $recursionReffArray->@* = $db->{reffArray}->@* }

            ## checkMatches
            $sub->( $db );

            ## Check for CHILDREN
            _changePointLvl($db->{point}, 1);
            _leveler( $db, $sub);
            _changePointLvl($db->{point});
            $db->{reffArray}->@* = $recursionReffArray->@*;

            ## Check for SYBLINGS
            if (scalar $db->{point}->@*) {
                $db->{point}[-1]++;
            } else { last }

            $obj = _getObj($db);
        }
        ## --- Preserves
        if (_getPointStr($db) eq '1.1.1.1.4') {
            $db->{point}->@* = (-1);

            ## verbose 1 {{{
            $obj = _getObj( $db );
            mes _getPointStr($db)." $obj", $db, [0], $opts_leveler->[1]; #}}}

            divyMatches($db);
        }

        return $db->{result};
    }
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


#===| _isPrsv() {{{2
sub _isPrsv {
    my ($db, $obj, $match, $FR_prsv) = @_;
    my $opts_prsv  = $db->{opts}{prsv};

    if ($opts_prsv->[0]) {
        my $dspt = $db->{dspt};

        if (
            $FR_prsv->{obj} eq 'libName'
                and
            exists $dspt->{libName}{preserve}
                and
            exists $dspt->{libName}{preserve}->[1]
                and
            $dspt->{libName}{preserve}->[1] ne $obj
        ) {
            $obj  = 'libName';
        }

        my $S0 = ' 'x(12-length $obj);

        #disable prsv
        $FR_prsv->{F} = 0 if $obj eq $FR_prsv->{obj};

        # --- preserve
        my $prsv = $dspt->{$obj}{preserve} // 0;
        if ($prsv and !$FR_prsv->{F}) {

            if (
                #all items
                join '', $prsv->[0][0] eq ''
                    or
                #specfic Item
                (grep { $_ eq $match} $prsv->[0]->@*)[0]
            ) {
                $FR_prsv->%* = (F=>1, obj=> ($prsv->[1] // $obj) );
                my $rv = ($obj eq 'libName') ?1 :0;
                #print "<$obj> ${S0} $rv-$match\n";
                return $rv;
            }

        } else {
            #print "<$obj> ${S0} $FR_prsv->{F}-$match\n"
            #    if $FR_prsv->{F};
        }
    }
    return $FR_prsv->{F};
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


#===| _sweeper(){{{2
sub _sweeper {
#iterates through a data hash structure

    my ($db, $dry, $addReffs) = @_;
    my $dspt = $db->{dspt};
        die unless scalar %$dspt;
    my $result = dclone $db->{result};
        die unless scalar %$result;

    #return values
    my $writeArray = []; #psuedo-boolean
    my $refMap     = [];
    my $ATTRS      = [];

    if ($db->{opts}{swpr}[0]) {
        $db->{pointer}  = [ 0]; my $pointer  = $db->{pointer};
        $db->{pointer2} = [ 0]; my $pointer2 = $db->{pointer2};
        $db->{pointer3} = [ 0]; my $pointer3 = $db->{pointer3};
        $db->{point}    = [-1]; my $point    = $db->{point};
        $db->{objChain} = [  ]; my $objChain = $db->{objChain};
        $db->{childs}   = {};   my $childs   = $db->{childs};

        $dspt->{$_}{drsr} = $db->{drsr}{$_} for keys %$dspt;


        ## verbose 1{{{3
        mes "...Writing $db->{name}", $db, [-1], $db->{opts}{swpr}[1];

        # ===| $preprocess_sorted {{{3
        my $preprocess_sorted = sub {

            my @children = @_;

            if ($Data::Walk::type eq 'HASH') {

                ## Tranform array to hash
                my $hash = {};
                my $cnt = 0; for (@children) {
                    $hash->{$children[$cnt - 1]} = $_ if ($cnt & 1);
                    $cnt++;
                }

                ## Tranform hash to array whilst sorting keys
                @children = ();
                for (sort {
                            if    ($a eq 'PRESERVE' and $b ne 'libName' and $b ne 'section') {-1}
                            elsif ($a eq 'PRESERVE' and $b eq 'libName' or  $b eq 'section') { 1}
                            elsif ($b eq 'PRESERVE' and $a ne 'libName' and $a ne 'section') { 1}
                            elsif ($b eq 'PRESERVE' and $a eq 'libName' or  $a eq 'section') {-1}

                            elsif ($a eq 'SERIES' and $b eq 'STORIES') { 1}
                            elsif ($b eq 'SERIES' and $a eq 'STORIES') {-1}

                            else { _cmpKeys( $db, $a, $b, $hash, [1]) }

                          } keys %{$hash}) { push @children, ($_, $hash->{$_}) }

            }
            return @children;
        };


        # ===| $wanted {{{3

        my $wanted = sub {
            my $container = $Data::Walk::container;
            my $lvl       = ($Data::Walk::depth - 2)/2;
            my $key       = $_;

            if ($Data::Walk::type eq 'HASH' and $lvl >= 0) {
                my $obj = _getLvlObj($db,$container);
                if ($key eq $obj) {
                    my $drsr  = $dspt->{$obj}{drsr};
                    _crctPnter($db,$lvl); # pop pointer if ascending levels

                    ## --- POINTERS #{{{4
                    $pointer->[$lvl]  = $obj;
                    $pointer2->[$lvl] = $container;
                        my $objItem  = $container->{$obj};
                        my $objRef   = ref $container->{$obj};
                        my $fmtdItem = ($objRef eq 'ARRAY') ?"[".(join ', ', sort @$objItem)."]"
                                                            :$objItem;
                    $pointer3->[$lvl] = "<$obj>$fmtdItem";

                    ## ATTRS {{{4
                    for my $key (keys %$container) {
                        if (_isAttr($db,$obj,$key)) {
                            my $attrItem = $container->{$key};
                            my $attrRef  = ref $container->{$key};
                            my $fmtdAttr = ($attrRef eq 'ARRAY') ?"[".(join ', ', sort @$attrItem)."]"
                                                                 :$attrItem;
                            push @$ATTRS,"<$obj>$fmtdItem<$key>$fmtdAttr";
                        }
                    }

                    ## REFMAP {{{4
                    push @$refMap, [[@$pointer],[@$pointer2],[@$pointer3]];

                    ## verbose 2 {{{4
                    # the lvl can not increase while the objlvl decreases
                    # the lvl can not decrease while the objlvl increases
                    $childs->{$obj}++;
                    my $objOrder = $dspt->{$obj}{order};

                    my $F1 = 0; if (_getPointStr($db) ne $objOrder) {
                        $db->{point}->@* = split /\./, $objOrder;
                        $F1 = 1;
                    } my $pointStr = join '.', @$pointer;

                    my $S0 = " " x (47 - length $pointStr);
                    my $S1 = " " x (9 - length $objOrder);
                    my $item = (ref $container->{$obj} eq 'ARRAY') ? '['.(join ', ', $container->{$obj}->@*).']'
                                                                   : $container->{$obj};
                    my $pointStr2 = join '.', @$pointer2;
                    my $pointStr3 = join '.', @$pointer3;
                    mes "-"x36, $db, [0], $db->{opts}{swpr}[2];
                    mes "[$F1, $lvl] $objOrder ${S1} $pointStr ${S0} $item",
                        $db, [0], $db->{opts}{swpr}[2];
                    mes "[$F1, $lvl] $objOrder ${S1} $pointStr ${S0} $pointStr2",
                        $db, [0], $db->{opts}{swpr}[3];
                    mes "[$F1, $lvl] $objOrder ${S1} $pointStr ${S0} $pointStr3",
                        $db, [0], $db->{opts}{swpr}[4];

                    ## --- Write Array {{{4
                    _write2array($db, $container, $writeArray, $lvl, $result) unless $dry;

                    ## --- CHECKS {{{4
                    if ($db->{$obj}{scalar} and $objChain->[-2][1] eq $obj) {
                        $erreno = "ERROR: Scalar obj '$obj' was repeated!";
                        die;
                    } #}}}
                }
            }
        }; #}}}

        walkdepth (
            {
                preprocess => $preprocess_sorted,
                wanted => $wanted
            },
            $result
        );

        ## verbose 1 #{{{
        my $max = 11;
        mes "OBJ ".(' 'x($max-3))." CNT", $db, [0], $db->{opts}{swpr}[1];
        mes "- ".(' 'x($max-1))." -",     $db, [0], $db->{opts}{swpr}[1];
        for my $obj (sort {$childs->{$a} <=> $childs->{$b}} keys $childs->%*) {
            my $S0 = " " x ($max - length $obj);
            mes "$obj ${S0} $childs->{$obj}", $db, [0], $db->{opts}{swpr}[1];
        }#}}}
   }
   #db-{dspt}
   #db->{opts}
   #db->{static}
   #db->{result}
   delete $db->{point};
   delete $db->{pointer};
   delete $db->{pointer2};
   delete $db->{pointer3};
   delete $db->{childs};
   delete $db->{objChain};
   #_getLvlObj
   #_crctpointer
   #_isAttr
   #_getPointSr
   #_write2array
   #cmpKeys
   #$dry
   #$addReffs

   if ($dry) { return dclone [$refMap, $ATTRS] }
   else      { return $writeArray // 0 }
}


#===| _write2array() {{{2
sub _write2array {
    my ($db, $container, $writeArray, $lvl, $result) = @_;
    my $write_opts = $db->{opts}{write};

    if ($write_opts->[0]) {
        my $pointer   = $db->{pointer};
        my $point     = $db->{point};
        my $objChain  = $db->{objChain};
        my $childs    = $db->{childs};
        my $obj       = _getLvlObj($db, $container);
        my $dspt      = $db->{dspt};
        my $drsr      = $dspt->{$obj}{drsr};

        ## verbose 2 {{{3
        my $S0 = ' ' x (13 - length $obj);
        mes "<$obj> $S0 $container->{$obj}", $db, [0], $write_opts->[2];

        ## --- String: d0, d1 #{{{3
        my $str = '';
        my $ref = ref $container->{$obj};
        if ($ref ne 'ARRAY') {
            $str .= $drsr->{$obj}[0]
                 . $container->{$obj}
                 . $drsr->{$obj}[1];
        }

        ## verbose 3 {{{4
        mes "<$obj> $S0 $str", $db, [0], $write_opts->[3];

        ## --- Attributes String: d0, d1, d2, d3, d4{{{3
        my $attrStr = '';
        my $attrDspt = _getAttrDspt($db, $obj);
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
                            $part = $drsr->{$attr}[2]
                                  . $part
                                  . $drsr->{$attr}[3];
                            push @itemPartArray, $part;
                        }
                        $attrItem = join $drsr->{$attr}[4], @itemPartArray;
                    }

                    $attrStr .= $drsr->{$attr}[0]
                             . $attrItem
                             . $drsr->{$attr}[1];

                }
            }
        }

        ## --- Line Striping: d5,d6 #{{{3
        my $F_empty;
        push @$objChain, [ $lvl, $obj ];
        if (exists $objChain->[-2] and exists $drsr->{$obj}[5]) {

            my $prevObj = $objChain->[-2][1];
            my $prevLvl = $objChain->[-2][0];

            my $ref = ref $drsr->{$obj}[5];
            my $tgtObjs = ($ref eq 'HASH') ?$drsr->{$obj}[5]
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
                my $cnt = $drsr->{$obj}[5];
                $str =~ s/.*\n// for (1 .. $cnt);
            }

        }

        ## --- String Concatenation {{{3
        $str = ($str) ?$str . $attrStr
                      :$attrStr;
        chomp $str if $obj eq 'preserve';

        ## verbose 4 {{{4
        mes "<$obj> $S0 $str", $db, [0], $write_opts->[4];#}}}
        #}}}

        unless ($F_empty) { push @$writeArray, $str if $obj ne 'libName'}
    }
}

#===| _init2() {{{2
sub _init2 {

    my $ov = shift @_;

    unless (exists $ov->{debug}) {$ov->{debug} = []}
        else {warn "WARNING!: 'debug' is already defined by user!"}
    unless (exists $ov->{meta}) {$ov->{meta} = {}}
        else {warn "WARNING!: 'meta' is already defined by user!"}

    ## check 'dspt', if no 'dspt' then use dspt of args, if args conflice or at
    #least one doesn't contain a dspt throw error unless 'fall to default'
    #option is on
    unless ($ov->{fileNames}->{dspt}) {
        die "User did not provide filename for 'dspt'!"}

    _genReservedKeys($ov); # hasher method
    _genDspt($ov);         # hasher method

    ## send filenames to hasher object
    $ov->{hash} = [
        map { getJson($_) }
        $ov->{fileNames}{fname}->@*
    ];

    $ov->{external} = {
        map {
            $_ =~ m/(\w+)\.json$/;
            $1 => getJson($_);
        } $ov->{fileNames}{external}->@*
    };

    return $ov;
}


#===| _validate() {{{2
# checks if 'ov' object has children and a target hash; if true, checks if attr
# and obj strs are conserved b/w the result hash and the child hashes
sub _validate {

    my $ov = shift @_;
    my @hashes = (
        $ov->{static}{hash}[0]  // die, #catalog
        $ov->{static}{hash}[1]  // die, #masterbin
        $ov // die, #hmofaLib
    );

    ## hash audit #{{{
    my @aSTRS  = ();
    my @aATTRS = ();

    for my $db (@hashes) {
        my $stuff  = _sweeper($db,1);
        my $refMap = $stuff->[0];
        my $attrs  = $stuff->[1];

        #obj strings
        my @obj_strs =
            sort map { join '.', $_->@* }
            map { $_->[2] }
            @$refMap;

        #check for dupes
        my %seen = (); for (@obj_strs) { mes $_, $ov if $seen{$_}++ }

        #all STRS
        push @aSTRS, [@obj_strs];
        push @aATTRS, $attrs;

        #verbose #{{{
        mes "-"x10, $ov, [-1];
        mes scalar $aSTRS[-1]->@*, $ov;
        mes scalar $aATTRS[-1]->@*, $ov;#}}}
    } #}}}

    isConserved($ov,\@aSTRS,'obj');
    isConserved($ov,\@aATTRS,'attr');

    sub isConserved { #{{{
        my ($ov, $arg, $type)   = @_;
        my @old  = uniq ($arg->[0]->@*,  $arg->[1]->@*);
        my @new  = $arg->[2]->@*;

        my @bin  = sort (@old, @new);
        my %seen = (); $seen{$_}++ for @bin;
        my @miss = sort grep { $seen{$_} == 1 } keys %seen;

        #verbose #{{{
        if (scalar @miss) {
            mes "$_", $ov for @miss;
            die if scalar @miss;
        } else {
            mes "...no unique $type of parent or childs hash", $ov, [-1];
        }#}}}
    }#}}}

}


# UTILITIES {{{1
#------------------------------------------------------

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
        swpr     => [1,0,0,0,0,0,0,0],
        write    => [1,0,0,0,0,0,0,0],
        prsv     => [1,0,0,0,0,0,0,0],

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



#===| _cmpKeys() {{{2
sub _cmpKeys {
    my ($db, $key_a, $key_b, $hash, $opts) = @_;

    # save point if already defined
    my @save = exists $db->{point} ?$db->{point}->@* :();

    my $pointStr_a = _getPointStr_FromUniqeKey($db, $key_a) ? _getPointStr_FromUniqeKey($db, $key_a)
                                                           : _genPointStr_ForRedundantKey($db, $key_a, $hash);
    my $pointStr_b = _getPointStr_FromUniqeKey($db, $key_b) ? _getPointStr_FromUniqeKey($db, $key_b)
                                                           : _genPointStr_ForRedundantKey($db, $key_b, $hash);
    my @point_a = split /\./, $pointStr_a;
    my @point_b = split /\./, $pointStr_b;

    ## NEGITIVE ORDERS
    if ($point_a[-1] < $point_a[-1]*-1) {
        $pointStr_a = _genPointStr_ForRedundantKey($db, $key_a, $hash,1);
        @point_a = split /\./, $pointStr_a;
    }
    if ($point_b[-1] < $point_b[-1]*-1) {
        $pointStr_b = _genPointStr_ForRedundantKey($db, $key_b, $hash,1);
        @point_b = split /\./, $pointStr_b;
    }

    my $len_a   =  scalar @point_a;
    my $len_b   =  scalar @point_b;
    my $lvlObj  = _getLvlObj($db,$hash);
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

    #===|| _getPointStr_FromUniqeKey() {{{3
    sub _getPointStr_FromUniqeKey {
        my ($db, $key)  = @_;

        if    (exists $db->{dspt}{$key})          { return $db->{dspt}{$key}{order} }
        elsif (_getObj_FromGroupName($db, $key))   { return $db->{dspt}{_getObj_FromGroupName($db, $key)}{order} }
        else                                        { return 0 }

        #===| _getObj_FromGroupName() {{{4
        sub _getObj_FromGroupName {
            my ($db, $groupName) = @_;
            my $dspt = $db->{dspt};
            return $dspt->{NULL}{groupNames}{$groupName} // 0;
        }
    }
    #===|| _genPointStr_ForRedundantKey() {{{3
    sub _genPointStr_ForRedundantKey {

        my ($db, $key, $hash, $F)  = @_;

        my $lvlObj     =  _getLvlObj($db, $hash);
        $db->{point} = [ split /\./, $db->{dspt}{$lvlObj}{order} ];
        my $pointStr   = _getPointStr($db);
        my $dspt_obj   = $db->{dspt}{_getObj($db)};

        ## --- ATTRIBUTES
        if ((exists $dspt_obj->{attributes}) and (exists $dspt_obj->{attributes}{$key})) {
            my $dspt_attr = $dspt_obj->{attributes}{$key};
            my $cnt;
            $cnt = exists $dspt_attr->[1] ? $dspt_attr->[1]
                                              : 1;
            for (my $i = 1; $i <= $cnt; $i++) { $pointStr = _changePointStrInd($pointStr, 1) }
            if ($pointStr) { return $pointStr }
            else           { die "pointStr $pointStr doesn't exist or is equal to '0'!" }

        ## --- RESERVED KEYS and NEGITIVE ORDERS
        } elsif (_isReservedKey($db, $key) or $F) {
            my $first = join '.', $db->{point}->@[0 .. ($db->{point}->$#* - 1)];
            my $pointEnd = $db->{point}[-1];

            # order
            my $order;
            if ($F) {
                my $obj = _getObj_FromGroupName($db,$key) ?_getObj_FromGroupName($db,$key)
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


#===| _getAttrDspt(){{{2
sub _getAttrDspt {
    my ($db, $obj) = @_;
    my $objDSPT = $db->{dspt}{$obj};
    my $attrDspt = (exists $objDSPT->{attributes}) ? $objDSPT->{attributes}
                                                   : 0;
    return $attrDspt;
}


#===| _getGroupName() {{{2
sub _getGroupName {
    # return GROUP_NAME at current point.
    # return '_getObj()' if GROUP_NAME doesn't exist!

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


#===| _getLvlObj {{{2
sub _getLvlObj {
    my $db = shift @_;
    my $hash = shift @_;
    if (ref $hash eq 'HASH') {
        for (keys $hash->%*) {
             if ( exists $db->{dspt}{$_} ) {return $_}
        }
    }
}


#===| _getObj() {{{2
# return OBJECT at current point
# return '0' if OBJECT doesn't exist for CURRENT_POINT!
# die if POINT_STR generated from CURRENT_POINT is an empty string!
sub _getObj {

    my $db       = shift @_;
    my $dspt     = $db->{dspt};
    my $pointStr = join( '.', $db->{point}->@* );

    die "pointStr cannot be an empty string!" if $pointStr eq '';

    my $match =
        (grep {
            ($dspt->{$_}{order} // "") eq $pointStr
        } keys $dspt->%*)[0];

    return ($match // 0 );

}


#===| _getPointStr() {{{2
sub _getPointStr {
    # return CURRENT POINT
    # return '0' if poinStr is an empty string!

    my $db = shift @_;
    my $pointStr = join('.', $db->{point}->@*);
    return ($pointStr ne '') ? $pointStr
                             : 0;
}


#===| _isAttr(){{{2
sub _isAttr {
    my ($db, $lvlObj, $key) = @_;
    my $attrDspt = _getAttrDspt($db,$lvlObj);
    if ($attrDspt) {
        my $attr = (grep {$_ eq $key} keys %$attrDspt)[0];
        return ($attr) ? $attrDspt->{$attr}
                       : 0;
    }
    else {
        return 0;
    }
}


#===| _isReservedKey() {{{2
sub _isReservedKey {
    my ($db, $key)  = @_;
    my $resvKeys      = $db->{reservedKeys};

    my @matches  = grep { $key eq $resvKeys->{$_}[0] } keys %{$resvKeys};

    return $matches[0] ? 1 : 0;
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
#===| _crctPnter() {{{2
# pop pointer if ascending levels
sub _crctPnter {

    my ($db,$lvl) = @_;

    if (exists $db->{pointer}) {
        my $pointer   = $db->{pointer};
        my $len       = scalar @$pointer;
        my $prior_lvl = $len - 1;
        if ($lvl < $prior_lvl and $len != 1) {
            my $cnt        = $prior_lvl - $lvl;
            my @pntersKeys = grep {$_ =~ /^pointer/} keys %$db;
            for my $key (@pntersKeys) {
                pop $db->{$key}->@*  for (0 .. $cnt);
            }
        }

    } else {
        die 'key "pointer" does not exists in variable "db"' unless exists $db->{pointer};
    }

}


# OTHER {{{1
#------------------------------------------------------

#===| _genfilter() {{{2
sub _genFilter {
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


#===| _sortHash(){{{2
sub _sortHash {
    my ($db, $hash) = @_;


    #===| sortSub->(){{3
    my $sortSub = sub {
        my $key = shift @_;
        my $index = shift @_;
        my $container  = shift @_;
        if ( ($index % 2) == 0 and ref $container->{$key} eq 'ARRAY') {
            my $checkobj = _getLvlObj($db, $container->{$key}[0]);
            if ($checkobj) {
                $container->{$key} = [ sort {
                    my $obj_a = _getLvlObj($db, $a);
                    my $obj_b = _getLvlObj($db, $b);
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

    walk { wanted => $sub}, $hash->{result};
}


#===| _removeKey(){{{2
sub _removeKey {
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


#===| _deleteKey(){{{2
sub _deleteKey {
    my $arg   = shift @_;
    my $key   = shift @_;
    my $index = shift @_;
    my $hash  = shift @_;
    if ( ($index % 2 == 0) and $arg eq $key) {
         delete $hash->{$arg};
    }
}


