#!/usr/bin/perl
# Requires LWP::Protocol::https implicitly to be installed

use strict;
use warnings;

use Encode;
use Irssi;
use HTML::Entities;
use HTTP::Size;
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
        my %options;
        my $size = HTTP::Size::get_size($url);
        if (defined $size) {
            if (int($size / 1024) > 1024) {
                next;
            }
            %options = ();
        }
        else {
            %options = (max_size => 1024 * 1024);
        }
        my $ua = LWP::UserAgent->new(%options);
        $ua->ssl_opts(SSL_verify_mode => SSL_VERIFY_NONE);
        my $response = $ua->get($url);
        if (exists $options{max_size} && $response->header('Client-Aborted')) {
            next;
        }
        if ($response->is_success && $response->headers->content_is_text) {
            my $content = $response->content;
            my ($title) = $content =~ m{<title(?:\s+.*?)?>(.+?)</title>}is;
            if (defined $title && $title =~ /\S/) {
                $title = Encode::decode('UTF-8', $title);
                $title =~ s/[\r\n]/ /g;
                $scrub_whitespace->(\$title);
                $title =~ s/\s{2,}/ /g;
                decode_entities($title);
                $server->command("msg $target [ $title ]");
                Irssi::print("url title for $target");
            }
            elsif ($content =~ m{<title(?:\s+.*?)?>\s*</title>}is) {
                $server->command("msg $target [ Untitled document ]");
                Irssi::print("empty url title for $target");
            }
        }
    }
}

Irssi::signal_add('message public', 'fetch_url_title');
