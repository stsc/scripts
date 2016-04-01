#!/usr/bin/perl

use strict;
use warnings;

use Irssi;
use JSON qw(decode_json);
use LWP::UserAgent;

my $VERSION = '0.02';

my %base_urls = (
    api_release => 'http://api.metacpan.org/v0/release/_search',
    api_file    => 'http://api.metacpan.org/v0/file/_search',
    release     => 'https://metacpan.org/release',
);

sub do_post
{
    my ($url, $json) = @_;

    my $request = HTTP::Request->new(POST => $url);
    $request->content_type('application/json');
    $request->content($json);

    my $ua = LWP::UserAgent->new(agent => "cpan.pl Irssi Plugin/$VERSION");
    my $response = $ua->request($request);

    if ($response->is_success) {
        return decode_json($response->content);
    }
    else {
        die $response->status_line, "\n";
    }
}

sub prepare_json
{
    (my $arg = $_[1]) =~ s/"/\\"/g;

    my %json = (
        api_release => <<"JSON",
{
    "query": { "term": { "release.distribution": "$arg" } },
    "filter": { "term": { "release.status": "latest" } },
    "sort": { "version": { "order": "desc" } },
    "fields": [ "author", "name" ]
}
JSON
        api_file => <<"JSON",
{
     "query": { "filtered": {
         "query": { "match_all": {} },
             "filter": { "and": [
                 { "term": { "file.module.name": "$arg" } },
                 { "term": { "file.status": "latest" } }
             ]}
         }
     },
     "sort": { "version": { "order": "desc" } },
     "fields": [ "author", "release" ]
}
JSON
    );

    return $json{$_[0]};
}

sub fetch_cpan
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^!cpan\b/;

    my @args = split /\s+/, $data;
    shift @args;

    my $dist_name   = sub { local $_ = shift; s/::/-/g; $_ };
    my $module_name = sub { local $_ = shift; s/-/::/g; $_ };

    if ($data =~ /^!cpan\s*$/) {
        $server->command("msg $target !cpan distname");
    }
    elsif (@args) {
        my $arg = shift @args;
        my $dist = $dist_name->($arg);

        my $dist_not_found = "Dist '$arg' not found";

        my $meta = do_post($base_urls{api_release}, prepare_json('api_release', $dist));
        my $hits = $meta->{hits}{hits};

        if (@$hits) {
            my $link = join '/', ($base_urls{release}, @{$hits->[0]{fields}}{qw(author name)});
            $server->command("msg $target $link");
        }
        else {
            my $module = $module_name->($arg);

            my $meta = do_post($base_urls{api_file}, prepare_json('api_file', $module));
            my $hits = $meta->{hits}{hits};

            if (@$hits) {
                my $link = join '/', ($base_urls{release}, @{$hits->[0]{fields}}{qw(author release)});
                $server->command("msg $target $link");
            }
            else {
                $server->command("msg $target $dist_not_found");
            }
        }
        Irssi::print("cpan query for $target");
    }
}

Irssi::signal_add('message public', 'fetch_cpan');
