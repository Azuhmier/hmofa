package Ohm::Main;

use warnings;
use strict;
use utf8;
use Carp qw(croak carp confess);
use Storable qw(dclone);
use Cwd qw (getcwd abs_path);
use JSON::XS;
use Data::Dumper;

use lib ($ENV{HOME}.'/hmofa/hmofa/code/test/lib');
use Hash::Flatten qw(:all);

use constant FALSE => 1==0;
use constant TRUE  => not FALSE;
use constant BASE  => '.ohmi';


#############################################################
#  PUBLIC
#############################################################

sub get #{{{1
{
    my ( $self, $tableName, $flag ) = @_;

    croak "Error: No arguments were supplied"
            if !$tableName && !$flag;
    die "Error: No tableName was supplied"
            if !$tableName;
    croak "Error: No argument for key in table '$tableName' was supplied"
            if !$flag;

    my $isValidType = !( ref $tableName ) && !( ref $flag );
    croak 'Error: Argument must be a tableName-key SCALAR pair' unless $isValidType;

    croak "Error: Table '$tableName' is undefined"
            unless exists( $self->{$tableName} );

    croak "Error: '$flag' is not a key in '$tableName'"
            unless exists( $self->{$tableName}{ $flag } );

    return $self->{$tableName}{$flag}
}




sub set_flags #{{{1
{
    my ( $self, @args ) = @_;

    $self->{'flags'} = $self->__gen_config('flags')
            unless exists $self->{'flags'};

    $self->__set('flags',@args);

    return $self;
}




sub new #{{{1
{
    my ($class, $args, $old_args) = @_;

    my $self = { cwd => getcwd };
    bless $self, $class;

    my $bp = $self->__gen_config('self');

    $self->{$_} = $bp->{$_} for keys %$bp;

    $self->{args} = $old_args if $old_args;

    $self->__init($args);

    return $self;
}#}}}




#############################################################
# PRIVATE
#############################################################

sub __set #{{{1
{
    my ( $self, $tableName, @args ) = @_;
    $self->__private(caller);

    croak 'Error: No argument was supplied'
            if !$tableName && !@args;
    die 'Error: No tableName was supplied'
            if !$tableName;
    croak "Error: Key-Value pair not supplied for table '$tableName'"
            if !@args;

    my @typeConditons =
    (
            UNIVERSAL::isa($args[0], 'HASH'),
            !(ref $args[0]) && !(ref $args[1]),
            !(ref $tableName),
    );

    my $isValidArgumentsType = 0;
    $isValidArgumentsType |= $_ for @typeConditons[0,1];
    croak 'Error: Argument must be a HASH or key-value SCALAR pair'
            unless $isValidArgumentsType;

    my $isValidTableType = $typeConditons[2];
    die 'Error: First argument must be a SCALAR'
            unless $isValidTableType;

    croak "Error: Table '$tableName' is undefined"
            unless exists( $self->{$tableName} );


    if ( UNIVERSAL::isa($args[0], 'HASH') )
    {
        my $hash = $args[0];

        for my $key ( keys %$hash )
        {
            croak "Error: '$key' is not a key in '$tableName'"
                    if !exists( $self->{$tableName}{$key} );

            $self->{$tableName}{$key} = $hash->{$key};
        }
    }

    else
    {
        my ( $key, $value ) = @args;

        croak 'Error: Key-Value pair was not supplied'
                if !$key && !$value;
        croak "Error: key was not supplied"
                unless $key;
        croak "Error: Value for '$key' was not supplied"
               unless $key;
        croak "Error: '$key' is not a key in '$tableName'"
                if !exists( $self->{$tableName}{ $key } );

        $self->{$tableName}{$key} = $value;
    }


    return $self;

}




sub __set_status #{{{1
{
    my ( $self, @args ) = @_;
    $self->__private(caller);

    $self->{'status'} = $self->__gen_config('status')
            unless exists $self->{'status'};

    $self->__set('status', @args);

    return $self;

}




sub __set_args #{{{1
{

    my ( $self, $args, $clearArgs ) = @_;
    $self->__private(caller);


    my $old_args = $self->{args};

    if ($old_args && !$clearArgs)
    {
        $self->__checkArgs( {args => $args} );
        $args = __merge($args, $old_args);
    }

    else
    {
        $self->__checkArgs( {args => $args}, $clearArgs);
    }


    $self->{args} = $args;
}




sub __checkArgs #{{{1
{
    my ( $self, $args, $clearArgs ) = @_;
    $self->__private(caller);


    $args = $clearArgs
        ? $args
        : dclone $args;


    for my $key ( keys %$args )
    {

        my $isKeyAGroup = $self->__gen_bp($key);


        unless ( $isKeyAGroup )
        {
            next;
        }

        else
        {
            my $group = $key;
            my $arg   = $args->{$group};
            my $bp    = $self->__gen_config($group);

            %$arg = keys %$arg
                ? %{ $self->__gen_config($group, $arg) }
                : %$bp;

            my $InvalidKeys = $self->__getInvalidKeys($arg, $bp);

            if ( my $remaining = join ', ', @$InvalidKeys )
            {
                croak( "Unknown keys in to $group: $remaining" );
            }



            for my $key ( keys %$arg )
            {

                my $ref = ref($arg->{$key});

                my $validType = $ref eq ref($bp->{$key});


                unless ( $validType )
                {
                    croak "Error: invalid arg type '$ref' for '$key' in '$group'";
                }

                elsif ($ref eq 'HASH')
                {
                    $self->__checkArgs( { $key => $arg->{$key} }, $clearArgs );
                }

                elsif ($ref eq 'ARRAY')
                {

                    $self->__recurse( $arg->{$key}, $clearArgs );
                }

            }
        }
    }

    return $args;
}




sub __getInvalidKeys #{{{1
{
    my ($self, $arg, $bp) = @_;
    $self->__private(caller);

    my $seen = {};
    $seen->{$_}++ for ( keys %$bp, keys %$arg );
    my @InvalidKeys = grep { $seen->{$_} == 1 } keys %$seen;
    return \@InvalidKeys;
}




sub __recurse #{{{1
{
    my ($self, $array, $clearArgs) = @_;
    $self->__private(caller);

    for my $idx (0 .. $array->$#*)
    {

        my $arg = $array->[$idx];
        my $ref = ref $arg;

        if ($ref eq 'HASH')
        {
            for my $key (keys %$arg)
            {
                $self->__checkArgs( $arg->{$key}, $key, $clearArgs );

            }
        }

        elsif ($ref eq 'ARRAY')
        {
            for my $idx (0 .. $array->$#*)
            {
                $self->__recurse($arg->[$idx], $clearArgs);
            }
        }
    }
};



sub __merge #{{{1
{
    my ($self, $new, $old) = @_;
    $self->__private(caller);
    my $flat_old = flatten $old;
    $flat_old    = $self->__mask($flat_old, flatten $new);
    $new           = unflatten $flat_old;
    return $new;
}


sub __gen_config #{{{1
{
    my ( $self, $bp_name, $init_hash) = @_;
    $self->__private(caller);


    my $bp = dclone $self->__gen_bp( $bp_name ) // die;

    # populate config
    my $config = __populate
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

    sub __flatten #{{{2
    {
        my ($self, $key) = @_;
        return flatten $self->{$key};
    }

    sub __unflatten #{{{2
    {
        my ($self, $key) = @_;
        return unflatten $self->{$key};
    }

    sub __populate #{{{2
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
                $config->{$key} = __populate
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
            $config->{$key} = __populate
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
    }

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

        } #}}}

        return $flat_config;
    }


}




sub __gen_bp #{{{1
{
    my ( $self, $bp_name) = @_;
    $self->__private(caller);

    my $bps = $self->__bps();

    return 0 unless exists $bps->{lc $bp_name};
    return dclone $bps->{lc $bp_name};
}




sub __bps #{{{1
{
    my $self = shift  @_;
    $self->__private(caller);

    my %bps = (
        self => {
            fill => 0,
            member => {},
            general =>
            {
                plhd => {},
                prsv_opts => {},
            },
        }
    );
    return \%bps;
} #}}}




#############################################################
#  UTILITIES
#############################################################

sub __read #{{{1
{

    my ($self, $path) = @_;
    $self->__private(caller);

    open my $fh, '<:utf8', $path
        or die $!;
    chomp(my @lines = <$fh>);
    return \@lines;
}




sub __importJson #{{{1
{
    my ($self, $path) = @_;
    $self->__private(caller);

    my $jsonHash = do
    {
        open my $fh, '<', $path
            or croak "ERROR: Could not open $path, $!";
        local $/;
        decode_json(<$fh>);
    };

    return $jsonHash;
}




sub __private #{{{1
{
      my ($self, $caller) = @_;

      croak "Error: Private method called"
          unless (caller)[0]->UNIVERSAL::isa( ref($self) )
              || caller eq __PACKAGE__;

      croak "Error: Private method called".caller
          unless ($caller)[0]->UNIVERSAL::isa( ref($self) )
              || $caller eq __PACKAGE__;
} #}}}




1;
