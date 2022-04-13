
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

    # RESUME
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

    # SMASK - SUBMASKS
    my $paths_SMASK = delete $args->{smask} // [];
    __checkChgArgs( $paths_SMASK, 'ARRAY' , 'ARRAY REF' );
    if ( $paths_SMASK )
    {
        $paths->{smask} = [ map { abs_path $_; $_ } @$paths_SMASK ]
    }


    # generate path config
    $self->{paths} = $self->gen_config( 'paths', $paths );


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
    $self->{params} = $self->gen_config( 'params', $params  );


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

