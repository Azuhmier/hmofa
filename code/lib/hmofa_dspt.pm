#===============================================================================
#
#         FILE: hmofa_dspt.pm
#
#        USAGE: ---
#
#  DESCRIPTION: ---
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: HMOFA
#      VERSION: 1.0
#      CREATED: 11/29/2019 10:09:39
#===============================================================================
package hmofa_dspt;
use strict;
use warnings; 
use base 'Exporter';
our @EXPORT_OK = qw($kind $d $nb $flag %regexp $dspt_base gen_dspt);
our %EXPORT_TAGS = ( all => \@EXPORT_OK );
our $VERSION = 0.01;

our $kind;
our $flag = 0;

sub gen_dspt {
  # dspt vars 
  our $d = ',';
  our $nb = qr/[^\]\[]/;
  our %regexp = (
  tag_sub         => qr/\[[^\[\]]*\]\[/,
  );
  # dspt
  our $dspt_base = {
    title => #{{{
    {
      re         => qr/(?x)^(\s*)>\s*(.*)                         (?{$flag = 1;})/,
      match      => [],
      group1     => [],
      group2     => [],
      LN         => [],
      file_path  => [],
    },#}}}
    tags => #{{{
    {
      re         => qr{(?x)
                            ^\s*\[($nb*)\]\s*\[($nb*)\]($nb*)\n$  (?{$flag &= 0; $kind = 'full';})
                           |^\s*\[($nb*)\]($nb*)\n$               (?{$flag &= 0; $kind = 'half';})
                           |^\s*([~OX\$\*]+)\s*\n$                (?{$flag &= 0;})
                      },
      match      => [],
      group1     => [],
      group2     => [],
      group3     => [],
      group4     => [],
      group5     => [],
      group6     => [],
      analy      =>
      {
        raw       => [[],[]],
        tag_bin   => [[],[]],
        tag_names => [[],[]],
        raw_ops   => [[],[]],
        ops_bin   => [[],[]],
        op_names  => [[],[]],
      },
      LN         => [],
      file_path  => [],
      special    =>
      {
        delimiter => [],
        ops  =>
        {
          star              => [
                                '*',
                                'contains comfy',
                                ['contains comfy','comfy']
                               ],
          dollar_sign       => [
                                '$',
                                'comfy',
                                ['comfy','contains comfy']
                               ],
        },
        tag_subs =>
        {
          full_sub   => [
                         '(\s*','\?*\s*$d\s*|\s*','\?*\s*|$d\s*','\?*)'],
          a_front    => [],
          a_back     => [],
          b_front    => qr/\[[^\[\]]*\]\[/,
          b_back     => [],
          duplicates => [],
        },
      },
    },#}}}
    url => #{{{
    {
      re         => qr{(?x)
                            (https:\/\/pastebin\.com\/[^ \/]+)              (?{$flag &= 0;})
                           |(https:\/\/pastebin\.com\/u\/[^\s]+)            (?{$flag &= 0;})
                           |(https:\/\/www\.furaffinity\.net\/user\/[^\s]+) (?{$flag &= 0;})
                           |(https:\/\/www\.fanfiction\.net\/u\/[^\s]+)     (?{$flag &= 0;})
                           |(https?:\/\/[^\s]+)                             (?{$flag &= 0;})
                      },
      match      => [],
      group1     => [],
      group2     => [],
      group3     => [],
      group4     => [],
      group5     => [],
      URLS       => [],
      LN         => [],
      file_path  => [],
    },#}}}
    author => #{{{
    {
      re         => qr{(?x)
                            ^\s*By\s+(.*)         (?{$flag &= 0;})
                      },
      match      => [],
      group1     => [],
      LN         => [],
      file_path  => [],
    },#}}}
    mistakes => #{{{
    {
      re         => qr{(?x)
                            (^\s*[^~OX\$\(\)\s]$)  (?{$flag &= 0;})
                      },
      match      => [],
      group1     => [],
      LN         => [],
      file_path  => [],
    },#}}}
    unkown => #{{{
    {
      re         => undef,
      match      => [],
      group1     => [],
      LN         => [],
      file_path  => [],
    }, #}}}
  }; 
  return $dspt_base;
}
1;
