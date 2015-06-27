#!/usr/bin/perl

use strict;
use warnings;

use File::HomeDir;
use File::Spec;
use Irssi;
use Storable;

my $bot_name = 'AL-76';

my $file = File::Spec->catfile(File::HomeDir->my_home, '.irssi', 'scripts', 'data', 'explain.dat');

store({}, $file) unless -e $file;
my $explain = retrieve($file);

sub explain
{
    my ($server, $data, $nick, $addr, $target) = @_;

    return unless $data =~ /^\Q$bot_name\E(?:\s*[,:])?\s+/g;

    if ($data =~ /\G list \s* $/cgx) {
        my $abbrevs = join ', ', sort keys %$explain;
        $server->command("msg $target $nick: $abbrevs");
    }
    elsif ($data =~ /\G (.+?) \s+ is \s+ (.+?) \s* $/cgx) {
        my ($abbrev, $explanation) = ($1, $2);
        push @{$explain->{$abbrev}}, $explanation;
        store($explain, $file);
        $server->command("msg $target $nick: saved $abbrev");
    }
    elsif ($data =~ /\G forget \s+ (.+?) \s* $/cgx) {
        my $abbrev = $1;
        if (exists $explain->{$abbrev}) {
            delete $explain->{$abbrev};
            store($explain, $file);
            $server->command("msg $target $nick: forgot $abbrev");
        }
        else {
            $server->command("msg $target $nick: $abbrev is unknown");
        }
    }
    elsif ($data =~ /\G (.+?)\?* \s* $/cgx) {
        my $abbrev = $1;
        # there's a separate help command hence skip
        return if $abbrev =~ /^(?:\?|help)$/i;
        if (exists $explain->{$abbrev}) {
            my $list = join ' or ', @{$explain->{$abbrev}};
            $server->command("msg $target $abbrev is also known as $list");
        }
        else {
            $server->command("msg $target $nick: I don't know what $abbrev is");
        }
    }
}

Irssi::signal_add('message public', 'explain');
