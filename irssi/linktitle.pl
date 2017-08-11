#!/usr/bin/perl
# Requires LWP::Protocol::https implicitly to be installed

use strict;
use warnings;
use constant max_size => 1024 ** 2 * 10;
use constant timeout  => 3;

use Encode;
use Irssi;
use HTML::Entities;
use IO::Socket::SSL;
use LWP::UserAgent;

my @ignores = (
    qr{^GitHub\d+$},
    qr{^uribot$},
);
my @exclusions = (
    qr{^http://(?:www\.)?perlpunks\.de},
    qr{^http://(?:board|wiki|www)\.perl-community\.de},
);

sub fetch_url_title
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ m{\bhttps?://\S+};

    foreach my $ignore (@ignores) {
        return if $nick =~ $ignore;
    }

    my $scrub_whitespace = sub
    {
        my ($data) = @_;
        $$data =~ s/^\s*//;
        $$data =~ s/\s*$//;
    };
    $scrub_whitespace->(\$data);

    my @urls = grep m{^https?://\S+}, split /\s+/, $data;

    foreach my $exclude (@exclusions) {
        for (my $i = 0; $i < @urls; $i++) {
            if ($urls[$i] =~ $exclude) {
                splice(@urls, $i--, 1);
            }
        }
    }

    foreach my $url (@urls) {
        my $ua = LWP::UserAgent->new;
        $ua->ssl_opts(SSL_verify_mode => SSL_VERIFY_NONE);
        $ua->max_size(max_size);
        $ua->timeout(timeout);
        my $response;
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm timeout;
            $response = $ua->get($url);
            alarm 0;
        };
        if ($@) {
            warn $@ unless $@ eq "alarm\n";
            next;
        }
        if ($response->header('Client-Aborted')) {
            next;
        }
        if ($response->is_success && $response->headers->content_is_text) {
            if ($response->content =~ m{<title(?:\s+.*?)?>(.*?)</title>}is) {
                my $title = $1;
                if ($title =~ /\S/) {
                    $title = Encode::decode('UTF-8', $title);
                    $title =~ s/[\r\n]/ /g;
                    $scrub_whitespace->(\$title);
                    $title =~ s/\s{2,}/ /g;
                    decode_entities($title);
                    $server->command("msg $target [ $title ]");
                    Irssi::print("url title for $target");
                }
                else {
                    $server->command("msg $target [ Untitled document ]");
                    Irssi::print("empty url title for $target");
                }
            }
        }
        elsif ($response->is_error($response->code)) {
            my $status = $response->status_line;
            $server->command("msg $target $status [$url]");
            Irssi::print("status line for $target");
        }
    }
}

Irssi::signal_add('message public', 'fetch_url_title');
