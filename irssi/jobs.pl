#!/usr/bin/perl

# This irssi plugin is fragile due to the web scraping it
# needs to do.  Expect it to break sooner or later.

use strict;
use warnings;
use constant many => 5;

use HTML::TreeBuilder;
use Irssi;
use LWP::UserAgent;

sub fetch_jobs
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^!jobs\b/;

    my @args = split /\s+/, $data;
    shift @args;

    my $many;
    if ($data =~ /^!jobs\s*$/) {
        $many = many;
    }
    elsif (@args) {
        my $arg = shift @args;
        if ($arg =~ /^(-?\d+)$/) {
            my $num = $1;
            if ($num <= 0) {
                $many = 0;
            }
            elsif ($num <= many) {
                $many = $num;
            }
            else {
                $many = many;
            }
        }
        else {
            $many = 0;
        }
    }

    my $ua = LWP::UserAgent->new;
    my $response = $ua->get('http://jobs.perl.org/search?offsite=1');

    die $response->status_line, "\n" unless $response->is_success;

    my $tree = HTML::TreeBuilder->new;
    $tree->parse_content($response->decoded_content);
#-----------------------#
# START of web scraping #
#-----------------------#
    my $table = ($tree->find_by_tag_name('table'))[4];
    my @rows = $table->content_list;

    my @jobs;

    while (@rows) {
        my %job;
        my @job_rows = splice @rows, 0, 2;
        if ($job_rows[0]->tag eq 'tr') {
            my $col = ($job_rows[0]->content_list)[0];
            if ($col->tag eq 'td') {
                $job{description} = $col->as_trimmed_text;
                my $extracted_link = $col->extract_links('a');
                if (@$extracted_link) {
                    ($job{link}) = @{$extracted_link->[0]};
                }
            }
        }
        if ($job_rows[1]->tag eq 'tr') {
            my $col = ($job_rows[1]->content_list)[0];
            if ($col->tag eq 'td') {
                if ($col->as_text =~ /\((\d{4}-\d{2}-\d{2})\)/) {
                    $job{date} = $1;
                }
            }
        }
        push @jobs, { %job };
    }
#---------------------#
# END of web scraping #
#---------------------#
    @jobs = splice @jobs, 0, $many;

    foreach my $job (@jobs) {
        $server->command("msg $target $job->{date}: $job->{description} ($job->{link})");
    }
}

Irssi::signal_add('message public', 'fetch_jobs');
