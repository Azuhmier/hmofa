#!/usr/bin/perl;
use warnings;
use strict;
use LWP::Simple;
use LWP::UserAgent;
use HTML::SimpleLinkExtor;
use List::MoreUtils 'uniq';
use File::Find;
use File::Path;
use File::Basename;
use File::Spec;
use File::Glob;
use File::Copy;
use Cwd;
use utf8;
no warnings 'utf8';

my $head = glob('~/hmofa/hmofa');
my $cwd = getcwd;
my $archive = $head."/archive_7";
my $RecentScrapes = $head."/Recent_Scrapes";
my @pastes=GetPasteKeys($archive);
my @scrapes=GetPasteKeys($RecentScrapes."/archive");
#my ($filename, $dirs, $suffix) = finfo_display($cwd."/ll.iuo");
#for my $file (@scrapes) {
#  ReturnValidPastes($RecentScrapes."/archive/".$file);
#}
ReturnInvalidPastes($RecentScrapes."/archive",\@scrapes);
  print "\n";
ReturnInvalidPastes($archive,\@pastes);

sub finfo_display {
  my $cwd = shift @_;
  my ($filename, $dirs, $suffix) = fileparse($cwd);
  print "fname: $filename\n";
  print "dir: $dirs\n";
  print "suffix: $suffix\n";
  return [$filename, $dirs, $suffix];
}

sub GetPasteKeys {
  my $dirname = shift @_;
  my @PasteKeys;
  opendir (my $dh, $dirname) || die "Error in opening dir $dirname\n";
  {
    #while( ($filename = readdir($dh))) {
    #  print("$filename\n");
    #}
    @PasteKeys = grep { /^[^.]+/ } readdir($dh);
    #print join "\n", @PasteKeys;
  }
  closedir $dh;
  return @PasteKeys;
}

sub ReturnInvalidPastes {
  my $dir = shift;
  my $PasteKeys = shift;
  my @PasteKeys =@$PasteKeys;
  my @FilePaths = map {$dir."/".$_ } @PasteKeys;
  for my $file (@FilePaths) {
    my $pastekey = shift @PasteKeys;
    open my $fh, '<', $file or die "$0: $file: No such file\n";
      while (my $line = <$fh>) {
          if ($line =~ /<h1>.*\(#40[34]\)<\/h1>/) { 
          }
      }
   }
}

