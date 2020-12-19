#!/usr/bin/perl
#============================================================
#
#         FILE: tags.pl
#
#        USAGE: ./tags.pl
#
#  DESCRIPTION: Helps with story tagging and organization, 
#               maybe more.
#
#       AUTHOR: Azuhmier (aka taganon), azuhmier@gmail.com
# ORGANIZATION: HMOFA
#      VERSION: 1.0
#      CREATED: September 2019
#============================================================

use strict;
use warnings;
use autodie;
use Storable qw(dclone);
use Data::Dumper;
use List::MoreUtils 'uniq';
use lib ($ENV{HOME}.'/hmofa/hmofa/code/lib');
use hmofa_dspt ':all';
#use XML::Hash::XS qw();
no warnings 'utf8';

# GLOBAL
# DIRECTORIES #{{{

my $MASTER      = glob('~/hmofa/');
my $output_dir  = glob('~/hmofa/hmofa/code/goto_files/');

#}}}
# FILE PATHS #{{{
my $Catalog        = glob('~/hmofa/hmofa/Library.txt'); # Library
my $Kosher_Catalog = glob('~/hmofa/hmofa/Lib_Kosher.txt');

# goto_files/
my $tag_file        = 'tag_bin.txt';
my $name_file       = 'tag_names.txt';
my $ops_file        = 'ops.txt';
my $ops_names_file  = 'op_names.txt';
my $ops_group_file  = 'op_groups.txt';

#}}}
# GLOBAL VARS #{{{
my $fh; # FileHandle of tag catalog
my @fixed;

#}}}
# FORWARD DECLARATIONS #{{{
sub Lib_analy;
sub get_tags;

#}}}

{
  #-----| Catalog Modification |------{{{
    # Analysis of Catalog 
    open my $fh_Catalog, '<', $Catalog
      or die "Cannot open '$Catalog' in read-write mode: $!";
      ( my $dspt_Catalog, my $original ) =  Lib_analy($fh_Catalog, $output_dir);
    close $fh_Catalog
      or die "Cannot close $Catalog: $!";
    # Get Tags
    $dspt_Catalog = get_tags($dspt_Catalog, $tag_file, $name_file, 1, $output_dir);
    # Formating the Catalog
    lib_fmt($original);
  #}}}
  #-----| STDOUT |-----{{{
  #  my $hreff = $dspt_Catalog;
  #my $conv   = XML::Hash::XS->new(utf8 => 0, encoding => 'utf-8');
  #my $xmlstr = $conv->hash2xml($hreff, utf8 => 1);
  #open my $fh_xml, '>' , 'test.xml';
  #  print $fh_xml $xmlstr;
  #close $fh_xml;

  # find length of longest key
  my $ub = 0;
    for my $key (keys %$dspt_Catalog) {
      if (length $key > $ub) {
        $ub = length $key
      }
    }

  # print element number of each key
  for my $key (sort keys %$dspt_Catalog) {
    my $bin =  scalar @{$dspt_Catalog->{$key}{LN}};
    printf "$key"." " x ( 2 + ($ub - length $key))."%s\n", '| '.$bin
  }
  #}}}
}

#-----|| Lib_analy() ||-------{{{
# Lib_analy:  

sub Lib_analy {
  # FUN ARGS {{{
  my $fh = shift; # filehandle
  my $output_dir_in = shift;

  #}}}
  # FUN VARS #{{{
  my @ORIGINAL;
  my $dspt = gen_dspt();

  #}}}
  my $num_of_keys  = scalar keys %$dspt; # number of keys
  #-----| BLOCK: get lines |-----{{{
  {
    # //WHILE// line at file handle pointer
    while (my $line = <$fh>) {

      my $count; # number regexp match fails
      $line =~ s///g; #removes carriage returns

      # //FOR// every first level key in the dispatch table
      for my $key (keys %$dspt) {

        my $path = \$dspt->{$key}{file_path};
        my $key_reff = $dspt->{$key};
        $$path = $output_dir_in.'/'.$key.'.txt';

        # [IF]
        if ($key_reff->{re} && $line =~ /$key_reff->{re}/) {

          push  @{$key_reff->{LN}}, $.;
          push  @{$key_reff->{match}}, $line;

            # [IF's]
            if ($key_reff->{group1}) {push @{$key_reff->{group1}} , $1;}
            if ($key_reff->{group2}) {push @{$key_reff->{group2}} , $2;}
            if ($key_reff->{group3}) {push @{$key_reff->{group3}} , $3;}
            if ($key_reff->{group4}) {push @{$key_reff->{group4}} , $4;}
            if ($key_reff->{group5}) {push @{$key_reff->{group5}} , $5;}
            if ($key_reff->{group6}) {push @{$key_reff->{group6}} , $6;}
        }

        # //ELSE// no matches if count = the number of keys 
        else {  
          ++$count;
        }
      }

      # [IF]
      if ($flag && $num_of_keys == $count) {
        push  @{$dspt->{unkown}{LN}}, $.;
        push  @{$dspt->{unkown}{match}}, $line;
        $flag = 0;
      }
      push @ORIGINAL, $line;
    }
  }

  #}}}
  return $dspt, \@ORIGINAL;
}

#}}}
#-----|| get_tags() ||-------{{{
# get_tags:
sub get_tags {

  # FUN ARGS #{{{
  my $dspt = shift;
  my $tag_file = shift;
  my $name_file = shift;
  my $output = shift;
  my $output_dir_in = shift;

  #}}}
  # FUN VARS #{{{
  my $tags_raw       = ${$dspt->{tags}{analy}{raw}}[0];
  my $tags           = ${$dspt->{tags}{analy}{tag_bin}}[0];
  my $tag_lnums      = ${$dspt->{tags}{analy}{tag_bin}}[1];
  my $tag_names      = ${$dspt->{tags}{analy}{tag_names}}[0];
  my $tag_name_lnums = ${$dspt->{tags}{analy}{tag_names}}[1];

  my $ops_raw              = ${$dspt->{tags}{analy}{raw_ops}}[0];
  my $ops_raw_lnums        = ${$dspt->{tags}{analy}{raw_ops}}[1];
  my $ops                  = ${$dspt->{tags}{analy}{ops_bin}}[0];
  my $ops_lnums            = ${$dspt->{tags}{analy}{ops_bin}}[1];
  my $ops_names            = ${$dspt->{tags}{analy}{ops_names}}[0];
  my $ops_name_lnums       = ${$dspt->{tags}{analy}{ops_names}}[1];

  #}}}
  #-----| GET RAW TAGS FROM TAGLINES |-----{{{

  # //FOR// tagline line numbers
  for my $tagln_LN ( @{$dspt->{tags}{LN}} ) {

    # //FOR// non-operater tag groups
    for my $key ( grep {m/group/} keys %{$dspt->{tags}} ) {

      # [IF]
      if ($key =~ /group[^356]/) {
        # get tag group even if UNDEF
        my $tag_group = shift @{$dspt->{tags}{$key}};

        # [IF]
        if ($tag_group) {

          # /WHILE/ current tag group contains characters are not the
          # delemiter: $d
          while ( $tag_group =~ /([^$d]+)/g ) {

            push( @$tags_raw, $1 ); # captured group --> tags_raw
            # current tagline LN --> tags_raw_ln 
            push( @$tag_lnums, $tagln_LN );
          }
        }
      }

      else {
        # get tag group even if UNDEF
        my $op_group = shift @{$dspt->{tags}{$key}};

        # [IF]
        if ($op_group) {

          # //WHILE// current tag group contains characters that are not the
          #delemiter: $d
          while ( $op_group =~ /(.+)/g ) {

            my $var = $op_group;
            push( @$ops_raw, $1 ); # captured group --> ops_raw
            # current tagline LN --> ops_raw_LN
            push( @$ops_raw_lnums, $tagln_LN );
            # //WHILE//
            while ( $var =~ /([^\s])\1*/g ) {

              push( @$ops, $& ); # last match --> ops
              push( @$ops_lnums, $tagln_LN ); # current tagline LN --> ops_LN
            }
          }
        }
      }
    }
  } 

  #}}}
  #-----| GETTING OP NAMES |-----{{{
  my @idx = sort {uc($$ops_raw[$a]) cmp uc($$ops_raw[$b])} 0 .. $#$ops_raw;
  @$ops_raw      = @$ops_raw[@idx];
  @$ops_raw_lnums = @$ops_raw_lnums[@idx];

  @idx = sort {uc($$ops[$a]) cmp uc($$ops[$b])} 0 .. $#$ops;
  @$ops      = @$ops[@idx];
  @$ops_lnums = @$ops_lnums[@idx];

  #}}}
  #-----| GETTING OP NAMES |-----{{{
  @$ops_names = uniq(@$ops);

  #}}}
  #-----| GET TAG NAME LINE NUMBERS IN THE TAG_BIN ARRAY |-----{{{
  my @ops_names_copy = @$ops_names; # make copy of tagnames
  my $count = 0; # set count that will act as the line numbers

  # //FOR// every tag in the tag bin
  for my $op ( @$ops ) {
    ++$count;

    # [IF] current tag matches the current tag name              
    if ( $ops_names_copy[0] && $op =~ /\Q$ops_names_copy[0]\E/ ) {

      push( @$ops_name_lnums, $count ); # push current count to tag_name line
                                        # numbers
      shift @ops_names_copy;            # get next tag name
    }
  }
  #}}}
  #-----| CLEANING TAGS |-----{{{

  # //FOR// raw tags
  for my $line ( @$tags_raw ) {

    $line =~ s/^\s*([^\s])/$1/g; # removes spaces before tag
    $line =~ s/([^\s])\s*$/$1/g; # removes spaces after tag
    $line =~ s/\?//g;            # removes "?" from tag
    push @$tags, $line;          # push cleaned tag to tag_bin array
  }

  #}}}
  #-----| SORTING TAGS: CASE INSENSITIVE |-----{{{
    @idx = sort {uc($$tags[$a]) cmp uc($$tags[$b])} 0 .. $#$tags;
    @$tags      = @$tags[@idx];
    @$tag_lnums = @$tag_lnums[@idx];

    #}}}
  #-----| GET TAG NAMES |-----{{{
    @$tag_names = uniq( sort {uc($a) cmp uc($b)} @$tags ); # get tag names and
    # their linenumbers

    #}}}
  #-----| GET TAG NAME LINE NUMBERS IN THE TAG_BIN ARRAY |-----{{{
  my @tag_names_copy = @$tag_names; # make copy of tagnames
  $count = 0; # set count that will act as the line numbers

  # //FOR// every tag in the tag bin
  for my $tag ( @$tags ) {
    ++$count;

    # [IF] current tag matches the current tag name
    if ( $tag_names_copy[0] && $tag =~ /\Q$tag_names_copy[0]\E/ ) {

      push( @$tag_name_lnums, $count ); # push current count to tag_name line
                                        # numbers
      shift @tag_names_copy;            # get next tag name

    }
  }

  #}}}
  #-----| OUTPUT FILES |-----{{{
  # [IF] output argument was provided and it's true
  if ( $output ) {

    # output fmtd_tgln
    open $fh, '>', $output_dir_in.'/'.$name_file;
      print $fh shift @$tag_name_lnums, " $_\n" for @$tag_names;
    close $fh;

    open $fh, '>', $output_dir_in.'/'.'tags_only.txt';
      print $fh "$_\n" for @$tag_names;
    close $fh;

    # output tags
    open $fh, '>', $output_dir_in.'/'.$tag_file;
      print $fh shift @$tag_lnums ," $_\n" for @$tags;
    close $fh;

    open $fh, '>', $output_dir_in.'/'.$ops_names_file;
      print $fh shift @$ops_name_lnums, " $_\n" for @$ops_names;
    close $fh;

    open $fh, '>', $output_dir_in.'/'.$ops_file;
      print $fh shift @$ops_lnums," $_\n" for @$ops;
    close $fh;

    open $fh, '>', $output_dir_in.'/'.$ops_group_file;
      print $fh shift @$ops_raw_lnums ," $_\n" for @$ops_raw;
    close $fh;

    open $fh, '>', $output_dir_in.'/url_only.txt';
      my @line = @{$dspt->{url}{match}};
      print $fh grep { /^https:\/\/pastebin.com\/\w[^\/]/ } @line;
    close $fh;

    # //FOR// every key of dispatch table
    for my $key ( keys %$dspt ) {

      # </OPEN/> 
      my $file_path =  $dspt->{$key}{file_path};
      open $fh, '>', $file_path;
      {
        my @line = @{$dspt->{$key}{LN}};
        print $fh shift @line," $_" for @{$dspt->{$key}{match}};
      }
      # </CLOSE/> 
      close $fh;
    }
  }
  # //ELSE//
  else { }
  #}}}
  return $dspt;
}
#}}}
#-----|| libfix() ||-------{{{
sub libfix {
  # FUN ARGS #{{{
  my $fh            = shift;  # FileHandle brah
  my $Copy_Catalog  = shift;  # Path to Library Copy
  my $dspt          = shift;  # Dispatch Table
  my $fname_in      = shift;  # Path to Library

  #}}}
  # FUN VARS #{{{
  my @COPY;  # Array to Store Copy of Library
  my @FIXED; # Array to Store the Modified Copy of the Library

  #}}}
  #-----| MAKE ARRAY COPY OF LIBRARY |-----{{{

  # </OPEN/>
  open($fh, '<', $fname_in); # Open Library for Reading
  {

    # //WHILE// Line Exist at the FileHandle Pointer
    while (my $line = <$fh>) {
      push @COPY, $line; # current line --> @COPY
    }

  }
  close $fh;

  #}}}
  #-----| LIBRARY COPY FILE OPENING/CREATION |-----{{{

  # </OPEN/>
  open($fh, '>', $Copy_Catalog); # Open or Create File for Library Copy
  close $fh;

  #}}}
  #-----| WRITE TO LIB_COPY FILE AND MODIFY IT |-----{{{

  # </OPEN/>
  open($fh, '+<', $Copy_Catalog); # Open Library Copy for Read/Write
  {
    print $fh @COPY; # Write @COPY to Library Copy File
    truncate $fh, tell($fh); # Truncate File at Current Postion of the
                             # FileHandle Pointer
    #-----| READ FILE AND MAKE FIXES TO LINES |-----{{{
    seek $fh,0,0; # Put FileHandle Pointer at BOF

    # //WHILE// a Line Exist at the FileHandle Pointer
    while (my $line = <$fh>) {

      # [IF] Current Line is Under a Title
      if ($flag) {

        # [IF] Current Line is a TagLine
        if ($line =~ /$dspt->{tags}{re}/) {
          # Also sets Regexp Capture Groups 
          # Regexp Capture  Groups:
            # [atag][btag]$3 | COMPLETE
            # [halftag]$5    | INCOMPLETE
            # $6             | INCOMPLETE

          #-----| FIX INCOMPLETE TAGS |-----{{{
          my $atag = \$1;          # Anthro Tags reff
          my $btag = \$2;          # Story Tags reff
          my $halftag = \$4;       # HalfTag reff
          my @ops = (\$3,\$5,\$6); # Operators reff

          # [IF] Current Line is HalfTag
          if ($kind eq "half") {
             $line =~ s/.*/\[\]$&/; # Insert Single Tag Bracket
          }

          # [ELSIF] Current Line only cosists of Operators
          elsif (${$ops[2]}) {
             $line =~ s/.*/\[\]\[\]$&/; # Insert Empty Tag Brackets
          }

          #}}}
          #-----| TAGLINE CLEANING |-----{{{
          $line =~ /$dspt->{tags}{re}/; # Reset Capture Groups Now That...
                                        # ... All Taglines are Complete

          $line =~ s/$d+\s*($d)/$1/g; # Remove extra Commas to the Left
          $line =~ s/($d)\s*$d+/$1/g; # Remove extra Commas to the Right
          $line =~ s/\s*(\[)\s*/$1/g; # Remove extra Spaces around Left Brace
          $line =~ s/\s*(\])[ ]*([^ ])[ ]*/$1$2/g; # Remove extra Spaces around
                                                   # Right Brace
          $line =~ s/$d*(\[)$d/$1/g;# Remove extra Commas around Left Brace
          $line =~ s/$d*(\])$d*/$1/g; # Remove extra Commas around Right Brace
          $line =~ s/($d\s)\s*/$1/g; # Remove extra Spaces Right of Comma
          $line =~ s/\s*($d)/$1/g; # Remove extra Spaces Left of Comma
          $line =~ s/($d)([^ ])/$1 $2/g; # IF no space after comma, add one
          $line =~ s/\s*(\s)\s*/$1/g; # Remove Extra Spaces

          #}}}
          #-----| DUPLICATE TAGS |-----{{{
          $line =~ /$dspt->{tags}{re}/; # reset match variables now that...
          my @past_matches = '';
          my $duplicate_found = 0;
          my @dupe;

          # //WhILE//
          while ($line =~ /[^\[\],\n]+/g) {
            my $match = $&;
            $match =~ s/^\s//;

            # //FOR//
            for my $ele (uniq(@past_matches)) {

              # [IF]
              if ($ele eq $match) {
                $duplicate_found=1;
                push @dupe, $match;
              }

              # [ELSE]
              else {
                $duplicate_found=0;
              }

            }

            push @past_matches, $match;
          }

          no warnings 'uninitialized';

          # //FOR//
          for (@dupe) {
$line =~ s/(?<!\w)\s$_\?*$d|(\[)$_\?*(\])|$d\s$_\?*(\])|(\[)$_$d\s/$1$2$3$4/;
          }

          use warnings;

          #}}}
          #-----| DUPLICATE OPS |-----{{{
          $line =~ /$dspt->{tags}{re}/; # reset match variables now that...
          @past_matches = '';
          $duplicate_found = 0;
          @dupe =();
          $line =~ /\]\[.*\]\K[^\]\[]+/;
          my $OPS = $&;

          # //WHILE//
          while ($OPS =~ /./g) {

            my $match = $&;

            # //FOR//
            for my $ele (uniq(@past_matches)) {

               # [IF]
               if ($ele eq $match) {
                 $duplicate_found=1;
                 push @dupe, $match;
               }

               # //ELSE//
               else {
                 $duplicate_found=0;
               }

             }

             push @past_matches, $match;
           }

           # //FOR//
           for (@dupe) {
            $OPS =~ s/\Q$_\E//;
            $line =~ s/\][^\]\[]+/\]$OPS/;
           }

           #}}}
          #-----| SUBSTITUTING OPERATORS |-----{{{
          $line =~ /$dspt->{tags}{re}/; # reset match variables now that...
                                        # ...tagline in complete
          my %special =  %{$dspt->{tags}{special}};
          my %tag_subs = %{$special{tag_subs}};
          my %OPS = %{$special{ops}};
            
          # //FOR//
          for my $key (keys %OPS) {
            my $ARRAY = $OPS{$key};
            my $NEW = @$ARRAY[1];
            my $op = @$ARRAY[0];
            my $old_list = @$ARRAY[2];

            # [IF]
            if ($line =~ /\].*\Q$op\E/) {
              $line =~ s/\Q$op\E//g; # REMOVE $
              #-----| CREATE OLD |-----{{{
 
              # //FOR//
              for my $OLD (@$old_list) {

                my $EXPR = '';
                my $COUNT = 0;
                my $LEN =  scalar @{$tag_subs{full_sub}};
                #-----| CREATE REGEXP |-----#

                # //FOR//
                for my $string (@{$tag_subs{full_sub}}) {
                  $COUNT++;
                  $EXPR .= $string;

                  # [IF]
                  if ($COUNT > $LEN) {
                    next;
                  }

                  $EXPR .=$OLD;
                }

                my $regexp = qr/$EXPR/;
$line =~ s/(?<!\w)\s$OLD\?*$d|(\[)$OLD\?*(\])|$d\s$OLD\?*(\])|(\[)$OLD$d\s/$1$2$3$4/ig;
              }

              #}}}
              #-----| INSERT NEW |-----{{{
              $line =~ /$dspt->{tags}{re}/;

              # [IF]
              if (!$$btag) {
                $line =~ s/$regexp{tag_sub}/$&$NEW/;
              }

              # [ELSE]
              else {
                $line =~ s/$regexp{tag_sub}/$&$NEW$d /;
              }
              #}}}
            }

          }

        #}}}
        }
        #-----| MISSING TAGLINES |-----{{{

        # [ELSIF] current line matches url regexp
        elsif ($line =~ /$dspt->{url}{re}/) {
          $line =~ s/$dspt->{url}{re}/\[\]\[\]\n$&/;
        }

        # [ELSE] currlent line doesn't follow any regexp put forth
        else {
          $flag=0; # set flag to zero to let program know that it is done
                   # ixing line that was under title for there is no regexp
                   # embedded code for unkown
        }

        #}}}
      }
      #-----| TITLE FINDING AND FLAGGING |-----{{{

      # [ELSIF] current line matches title regexp
      elsif ($line =~ /$dspt->{title}{re}/) {}
      #}}}
      push @FIXED, $line; # push fixed line to the fixed array
    }

    #}}}
    #-----| WRITE FIXES BACK |-----{{{

    # </SEEK/>
    seek $fh, 0, 0;

    # //FOR// every $line of the fixed array
    for my $line  (@FIXED) {
      $line =~ s///g; # remove carriage returns
      print $fh $line;
    }

    #</TRUNCATE/> 
    truncate $fh, tell($fh);

    #}}}
  }
  close $fh;

  #}}}
  return @FIXED;
};

#}}}
#-----|| lib_fmt() ||-------{{{
# lib_fmt:
sub lib_fmt {
  my $lib_array_ref = shift;
  my @lib_array = @$lib_array_ref;
  my @fmt_lib;

  # //FOR//
  for my $line (@lib_array) {

    # [IF] Title
    if ($line =~ /^>/) {
      $line =~ s/>(.*)/"$1"/;
      $line =~ s/\s+(")/$1/;
    }

    # [ELSIf] Dscr
    elsif ($line =~ /^~/) {
      $line =~ s/~(.*)/#$1/;
    }

    # [ELSIF] Author
    elsif ($line =~ /^By/) {
      $line =~ s/By(.*)/by$1/;
    }
    if ( $line =~ /^\[/ ) {
      $line =~ s/(post.*)*virgin\?*, |(post.*)*virgin\?*|, (post.*)*virgin\?*|experienced\?*, |experienced\?*|, experienced\?*//gi;
      $line =~ s/,\s/,/g;
      $line =~ s/((?<!\])[^\]\[,]+)/;$1;/g;
      $line =~ s/,/ /g;
      $line =~ s/;$//g;
      $line =~ s/(\]\[.*\])(.*)/$1/g;
      my $ops = $2;
      $ops =~ s/;//g;
      $line =~ s/(\]$)/$1$ops/g;
    }
    push @fmt_lib, $line;
  }

  # </OPEN/>
  open (my $fh, '>', $Kosher_Catalog);
  {
    print $fh @fmt_lib;
  }
  close $fh;
}
#}}}
