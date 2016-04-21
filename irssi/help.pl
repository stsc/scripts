#!/usr/bin/perl

use strict;
use warnings;

use Irssi;

my $bot_name = 'AL-76';

sub help
{
    my ($server, $data, $nick, $addr, $target) = @_;
    return unless $data =~ /^\Q$bot_name\E(?:\s*[,:])?\s+/g;

    if ($data =~ /\G (?:\?+|help) \s* $/gix) {
        my $commands = join ', ', split /\n/, <<'EOT';
<abbrev> is <explanation>
forget <abbrev>
<abbrev>[?]
list
!cpan <distname>
!jobs [<many>]
!perldoc <item>
!quote random or <person> [/keyword/]
?quote <person> (mtime|total)
!seen <nickname>
EOT
        $server->command("msg $target Usage: $commands");
    }
}

Irssi::signal_add('message public', 'help');
