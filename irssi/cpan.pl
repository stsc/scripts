#!/usr/bin/perl

use strict;
use warnings;
use constant true  => 1;
use constant false => 0;

use Irssi;
use JSON qw(decode_json);
use LWP::UserAgent;

my $VERSION = '0.05';

my %base_urls = (
    api_release => 'https://fastapi.metacpan.org/v1/release/_search',
    api_file    => 'https://fastapi.metacpan.org/v1/file/_search',
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
    "query": { "term": { "distribution": "$arg" } },
    "filter": { "term": { "status": "latest" } },
    "sort": { "version": { "order": "desc" } },
    "fields": [ "author", "name" ]
}
JSON
        api_file => <<"JSON",
{
     "query": { "filtered": {
         "query": { "match_all": {} },
             "filter": { "and": [
                 { "term": { "module.name": "$arg" } },
                 { "term": { "status": "latest" } }
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

    my $implicit_re = qr/\b(\S+(?:\:\:\S+)+)\b/;

    my (@args, $explicit);
    if ($data =~ /^!cpan\b/) {
        @args = split /\s+/, $data;
        shift @args;
        $explicit = true;
    }
    elsif ($data =~ $implicit_re) {
        while ($data =~ /$implicit_re/g) {
            push @args, $1;
        }
        $explicit = false;
    }
    else {
        return;
    }

    my $dist_name   = sub { local $_ = shift; s/::/-/g; $_ };
    my $module_name = sub { local $_ = shift; s/-/::/g; $_ };

    if ($data =~ /^!cpan\s*$/) {
        $server->command("msg $target !cpan dist(s)");
    }
    elsif (@args) {
        while (my $arg = shift @args) {
            my $dist = $dist_name->($arg);

            my $dist_not_found = "Dist '$arg' not found";

            my $meta = do_post($base_urls{api_release}, prepare_json('api_release', $dist));
            my $hits = $meta->{hits}{hits};

            if (@$hits) {
                my $link = join '/', ($base_urls{release}, @{$hits->[0]{fields}}{qw(author name)});
                $link .= " [$arg]" unless $explicit;
                $server->command("msg $target $link");
            }
            else {
                my $module = $module_name->($arg);

                my $meta = do_post($base_urls{api_file}, prepare_json('api_file', $module));
                my $hits = $meta->{hits}{hits};

                if (@$hits) {
                    my $link = join '/', ($base_urls{release}, @{$hits->[0]{fields}}{qw(author release)});
                    $link .= " [$arg]" unless $explicit;
                    $server->command("msg $target $link");
                }
                elsif ($explicit) {
                    $server->command("msg $target $dist_not_found");
                }
            }
            Irssi::print("cpan query for $target");
        }
    }
}

Irssi::signal_add('message public', 'fetch_cpan');
