#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use JSON qw(decode_json);
use LWP::UserAgent;

my $VERSION = '0.01';

my %base_urls = (
    api     => 'http://api.metacpan.org/v0/release/',
    release => 'https://metacpan.org/release',
);

sub fetch_cpan
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^!cpan\b/;

    my @args = split /\s+/, $data;
    shift @args;

    my $query_name = sub { local $_ = shift; s/::/-/g; $_ };

    if ($data =~ /^!cpan\s*$/) {
        $server->command("msg $target !cpan distname");
    }
    elsif (@args) {
        my $dist_name = shift @args;
        my $dist = $query_name->($dist_name);

        my $url = $base_urls{api} . $dist;

        my $ua = LWP::UserAgent->new(agent => "cpan.pl Irssi Plugin/$VERSION");
        my $response = $ua->get($url);

        if ($response->is_success) {
            my $meta = decode_json($response->content);
            my $link = join '/', ($base_urls{release}, @$meta{qw(author name)});
            $server->command("msg $target $link");
        }
        else {
            $server->command("msg $target Dist '$dist_name' not found");
        }
        Irssi::print("cpan query for $target");
    }
}

Irssi::signal_add('message public', 'fetch_cpan');
