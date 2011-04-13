#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';
use autodie ':all';
use Path::Class;

use Pod::Usage;

my ( $project_name, $target_dir ) = @ARGV;
$project_name or pod2usage();
$target_dir ||= "../$project_name";
$target_dir = dir( $target_dir );

-e $target_dir
    and die "dir $target_dir exists, I won't overwrite it\n";

my $authors = file('authors.txt')->absolute;
-f $authors or die "can't find authors file $authors\n";

my $mirror = dir('svn_mirror')->absolute;
-e $mirror or die "svn mirror $mirror not found\n";
-d $mirror or die "svn mirror $mirror is not a directory!\n";

mkdir $target_dir;
chdir $target_dir;

system( 'svn2git',
        '--authors' => $authors,
        "file://$mirror/$project_name",
      );

print "\n\nYour new git repo is in $target_dir . Please inspect it.\n";


=head1 USAGE

  migrate_project.pl  project_name   [ target dir ]

  Example:

     migrate_project.pl Generic-Genome-Browser

  Migrates GBrowse and puts it in the ../Generic-Genome-Browser directory.

=cut

