#!/usr/bin/env perl
#============================================================
#
#        FILE: gitio.pl
#       USAGE: ./gitio.pl url
#  DESCRIPTION:
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
#============================================================
use warnings;
use strict;

# parse cmdline arguments and output hash
my %args = ArgParser(\@ARGV);

my $cmd = q{curl -s -i https://git.io -F "url=}.$args{'URL'}.q{" \\
  | grep Location                                                \\
  | sed -n 's/Location: \(.*\)/\1/p'                             \\
  | tr -d '\n'                                                   \\
  | tee /dev/tty                                                 \\
  | tr -d '\r\n'                                                 \\
  | pbcopy};
my $output = `$cmd`;
print `$output`, "\n";

sub ArgParser{
  my @args = @{shift @_};
  my %args;

  # - 3 arg MAX
    my $argNUM = scalar @args;

  # - url must come last
  # - 'https://git.io/' or 'https://raw.githubusercontent.com/' must match
    my $ioURL  = 'https://git.io/';
    my $rawURL = 'https://raw.githubusercontent.com/';
    if ($args[-1] =~ qr{\Q$ioURL\E|\Q$rawURL\E} ) { 
        $args{'URL'} = $args[-1];

    }


  # - [-s], slience output, or [-c], copy output to clipboard, are the only valid
  #   options and must not repeat
    my @opts = @args[0..$#args-1];
    for my $opt (@opts) {
      print $opt,"\n";
    }

  # - failure to meet the above guidlines will result in termination of the
  #   program

  return %args;
}

