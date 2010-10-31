#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use Storable;
use File::stat;

use LWP::Simple;
use Path::Class;

use YAML;

# look through the svn repo to find all author SF usernames
my @authors = get_svn_author_list();

# look for their info in sourceforge
get_sourceforge_author_info( \@authors );
# look for their info on github
get_github_author_info( \@authors );

for my $a (@authors) {
    my $name  = $a->{name} || $a->{sourceforce_login};
    my $email = $a->{email} || '(no email)';
    print "$a->{sourceforge_login} = $a->{name} <$a->{email}>\n";
}

sub get_svn_author_list {

    my $svn_mirror = dir( 'svn_mirror' )->absolute;
    my $author_list = $svn_mirror->file('authors_list.txt');
    my $svn_mirror_modtime = $svn_mirror->file('update_stamp')->stat->mtime;

    unless( -e $author_list && $svn_mirror_modtime <= $author_list->stat->mtime ) {
        $author_list->openw->print(
            `svn log -q file://$svn_mirror | grep -e '^r' | awk 'BEGIN { FS = "|" } ; { print \$2 }' | sort | uniq > $author_list`
        );
    }

    my $al = $author_list->openr;
    return map {
        s/^\s+|\s+$//g;
        +{ sourceforge_login => $_ }
    } <$al>;
}

sub get_sourceforge_author_info {
    my $authors = shift;
    for my $author (@$authors) {
        my $login = $author->{sourceforge_login};

        my $user_page = get("http://sourceforge.net/users/$login");

        my ($name) = $user_page =~ m|Public Name:</label>([^<]+)<|
            or next;
        $name =~ s/^\s+|\s+$//g;

        $author->{name}  = $name;
        $author->{email} = $login.'@users.sourceforge.net';

    } continue {
        sleep 2;
    }
}

sub get_github_author_info {
    my $authors = shift;
    for my $author (@$authors) {
        my $login = $author->{sourceforge_login};

        my $github_info = get( "http://github.com/api/v2/yaml/user/show/$login" )
            or next;

        $github_info = Load( $github_info )
            or next;
        $github_info = $github_info->{user}
            or next;

        if( !$author->{name} || cmp_name( $author->{name}, $github_info->{name} ) == 0 ) {
            $author->{name}  = $github_info->{name};
            $author->{email} = $github_info->{email};
        }
    } continue {
        sleep 2;
    }
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
