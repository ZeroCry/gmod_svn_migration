#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Storable;
use File::stat;

use Cache::File;
use LWP::Simple ();
use Path::Class;

use YAML;

my $authors_file = file('authors.txt');

my $authors = get_current_author_list( $authors_file );

# look through the svn repo to find all author SF usernames
add_svn_authors( $authors );

# look for their info in sourceforge
add_sourceforge_author_info( $authors );

# look for their info on github.  github user info takes precedence
# over sourceforge user info if the author names match (whitespace and
# case insensitively)
add_github_author_info( $authors );

my $authors_out = $authors_file->openw;
for my $a ( map $authors->{$_}, sort keys %$authors) {
    my $name  = $a->{name} || $a->{sourceforge_login};
    my $email = $a->{email} && " <$a->{email}>" || '';
    $authors_out->print( "$a->{sourceforge_login} = $name$email\n" );
}


##############

sub get_current_author_list {
    my $authors_file = shift;

    my $authors = {};

    return $authors unless -e $authors_file;

    my $fh = $authors_file->openr;
    while ( <$fh> ) {
        chomp;
        my ( $login, $name ) = split /\s*=\s*/, $_, 2;

        my $email;
        if( $name =~ / ([^<]+) < ([^>]+) > /x ) {
            $name  = $1;
            $email = $2;
        }

        $_ && s/^\s+|\s+$//g for $name, $email;

        $name  = undef if $name eq $login;
        $email = undef if $email && $email =~ /no email/;

        $authors->{$login} = {
            sourceforge_login => $login,
            name  => $name,
            email => $email,
        };
    }

    return $authors;
}

sub add_svn_authors {
    my $authors = shift;

    my $svn_mirror = dir( 'svn_mirror' )->absolute;
    my $author_list = $svn_mirror->file('authors_list.txt');
    my $svn_mirror_modtime = $svn_mirror->file('update_stamp')->stat->mtime;

    print "fetching SVN authors from local mirror ...\n";

    unless( -e $author_list && $svn_mirror_modtime <= $author_list->stat->mtime ) {
        $author_list->openw->print(
            `svn log -q file://$svn_mirror | grep -e '^r' | awk 'BEGIN { FS = "|" } ; { print \$2 }' | sort | uniq > $author_list`
        );
    }

    my $al = $author_list->openr;
    while( <$al> ) {
        s/^\s+|\s+$//g;
        $authors->{$_} ||= { sourceforge_login => $_ };
    }

    print "done.\n";
}


sub add_sourceforge_author_info {
    my $authors = shift;

    print "looking up SourceForge account info ...\n";

    for my $author ( values %$authors ) {
        next if $author->{name} && $author->{email};

        my $login = $author->{sourceforge_login};

        print "    looking up $login\n";

        my $user_page = cached_get("http://sourceforge.net/users/$login");

        my ($name) = $user_page =~ m|Public Name:</label>([^<]+)<|
            or next;
        $name =~ s/^\s+|\s+$//g;

        $author->{name}  ||= $name;
        $author->{email} ||= $login.'@users.sourceforge.net';

    }

    print "done.\n";
}

my $github_cache = Cache::File->new(
    cache_root      => '.remote_author_info_cache/github',
    default_expires => '1 day',
   );

sub add_github_author_info {
    my $authors = shift;
    print "adding author info from GitHub...\n";
    for my $author (values %$authors) {
        my $login = $author->{sourceforge_login};

        print "    looking up $login\n";

        my $github_info = cached_get( "http://github.com/api/v2/yaml/user/show/$login" )
            or next;

        $github_info = Load( $github_info )
            or next;
        $github_info = $github_info->{user}
            or next;

        if( !$author->{name} || $github_info->{name} && cmp_name( $author->{name}, $github_info->{name} ) == 0 ) {
            $author->{name}  = $github_info->{name};
            $author->{email} = $github_info->{email} || $author->{email};
        }
    }
    print "done.\n";
}

# compare names without sensitivity to whitespace or case
sub cmp_name {
    my @n = @_;
    for (@n) {
        s/\s//g;
        $_ = lc $_;
    }
    return $n[0] cmp $n[1];
}

{ my $cache;
  sub cached_get {
      $cache ||= Cache::File->new(
          cache_root      => '.remote_author_info_cache',
          default_expires => '1 day',
          load_callback   => sub { sleep 1; LWP::Simple::get( shift->key ) || '' },
         );

      $cache->get( shift );
  }
}
