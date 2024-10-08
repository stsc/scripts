#!/usr/bin/perl
#
# navhost - List/view remote files in browser
#
# Copyright (c) 2009-2013, 2016, 2018-2019, 2024 Steven Schubiger
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use constant true  => 1;
use constant false => 0;

use CGI ();
#use CGI::Carp 'fatalsToBrowser';
use Fcntl ':mode';
use File::Spec::Functions ':ALL';
use IO::File ();
use POSIX qw(ceil strftime);
use URI::Escape qw(uri_escape);

my $VERSION = '0.26';

my (%config,
    @entry_color,
    $header_color,
    %html,
    %icons,
    $icons_path,
    %params,
    $prot,
    $query);

#-----------------------
# Start of configuration
#-----------------------

$prot = 'http'; # 'http' or 'https'
$icons_path = '/~sts/images';
%icons = (
    file   => 'file.png',
    folder => 'folder.png',
);
$header_color = '#e3e3e3';
@entry_color = ('#e8e8e8', '#ffffff');

#---------------------
# End of configuration
#---------------------

{
    $query = CGI->new;

    $params{path} = do { local $_ = $query->param('path'); defined $_ ? $_ : rootdir() };
    $params{all}  = do { local $_ = $query->param('all');  defined $_ ? $_ : false     };
    $params{asc}  = do { local $_ = $query->param('asc');  defined $_ ? $_ : true      };

    $config{script_url} = join '', ("$prot://", $ENV{SERVER_NAME}, ":$ENV{SERVER_PORT}", $ENV{SCRIPT_NAME});
    $config{icons}      = { map { $_ => join '/', ($icons_path, $icons{$_}) } keys %icons };

    parse_templates();
    read_dir_listing();
}

sub get_script_url
{
    my %fields = @_;

    foreach my $field (grep !exists $fields{$_}, keys %params) {
        $fields{$field} = $params{$field};
    }

    return "$config{script_url}?" . join ';', map { "$_=" . uri_escape($fields{$_}) } qw(path all asc);
}

sub parse_templates
{
    my ($listing, $status) = split /\n###\n/, do { local $/; <DATA> };

    my ($header, $body, $footer) = map {
        s/^\n+//; $_
    } ($listing =~ /
        <!--BEGIN\ \w+-->
        (.+?)
        <!--END\ \w+-->/gsx
    );

    %html = (
        header => $header,
        body   => $body,
        footer => $footer,
        status => $status,
    );
}

sub read_dir_listing
{
    opendir(my $dh, $params{path}) or read_file();

    my $script_url_mode = get_script_url(all  => $params{all} ? false : true);
    my $script_url_root = get_script_url(path => '/');
    my $script_url_home = get_script_url(path => (getpwuid((stat($0))[4]))[7]);
    my $script_url_curr = get_script_url(path => $params{path});
    my $script_url_sort = get_script_url(asc  => $params{asc} ? false : true);

    my $mode  = $params{all} ? 'default' : 'all';
    my $order = $params{asc} ? 'desc'    : 'asc';

    my $html_header = $html{header};

    my %subst = (
        path         => qq($params{path}),
        option_all   => qq(<a href="$script_url_mode">toggle <b>$mode</b></a>),
        name_sort    => qq(<a href="$script_url_sort">sort <b>$order</b></a>),
        folder_image => qq(<img src="$config{icons}->{folder}" alt="folder">),
        folder_root  => qq(<a href="$script_url_root">/ (root)</a>),
        folder_home  => qq(<a href="$script_url_home">~ (home)</a>),
        folder_curr  => qq(<a href="$script_url_curr">. (current)</a>),
        header_color => qq($header_color),
        version      => qq($VERSION),
    );
    foreach my $place_holder (keys %subst) {
        html_populate(\$html_header, $place_holder, $subst{$place_holder});
    }

    print $query->header('text/html');
    print $html_header;

    my $sort = sub
    {
        my @upper = grep  /^\.\.$/, @_;
               @_ = grep !/^\.\.$/, @_;

        return @upper, sort {
          $params{asc}
            ? $a cmp $b
            : $b cmp $a
          } grep !/^\.[^.]/,
          @_ unless $params{all};

        return @upper, map $_->[0],
          sort { $params{asc}
            ? $a->[1] cmp $b->[1]
            : $b->[1] cmp $a->[1]
          } map [ $_, substr($_, /^\.[^.]/ ? 1 : 0, length) ],
          @_;
    };

    my $counter = 1;

    foreach my $entry ($sort->(readdir($dh))) {
        my %skipable = (
            curdir => $entry eq curdir(),
            updir  => $entry eq updir() && $params{path} eq rootdir(),
        );
        next if $skipable{curdir} || $skipable{updir};

        my %attrs;
        my $html_body = $html{body};

        my $image = sub {
            return { img => $config{icons}->{folder}, alt => 'folder' } if -d catfile($_[0], $entry);
            return { img => $config{icons}->{file},   alt => 'file'   };
        }->($params{path});

        if ($entry eq updir()) {
            subst_up_dir($entry, \$html_body, $config{icons}->{folder});
            print $html_body;
            next;
        }
        subst_entry_image(\$html_body, $image);
        subst_entry_name($entry, \$html_body);
        gather_attrs($entry, \%attrs);
        subst_entry_attrs(\$html_body, \%attrs);
        subst_entry_color(\$html_body, $counter++);

        print $html_body;
    }

    closedir($dh);

    my $html_footer = $html{footer};
    html_populate(\$html_footer, 'last_generated', strftime('%Y-%m-%d %H:%M:%S %Z', localtime));

    print $html_footer;
    exit;
}

sub subst_up_dir
{
    my ($entry, $html, $image) = @_;

    my $path_updir = do {
        my @dirs = splitdir((splitpath($params{path}))[1]);
        pop @dirs;
        catdir(@dirs)
    };

    my $script_url = get_script_url(path => $path_updir);

    html_populate($html, 'entry_image', qq(<img src="$image" alt="folder">));
    html_populate($html, 'entry_name',  qq(<a href="$script_url">$entry</a>));

    $$html =~ s/\$\w+//g;
}

sub subst_entry_image
{
    my ($html, $image) = @_;

    html_populate($html, 'entry_image', qq(<img src="$image->{img}" alt="$image->{alt}">));
}

sub subst_entry_name
{
    my ($entry, $html) = @_;

    if (!-d catfile($params{path}, $entry) and -p _ || -S _ || -b _ || -c _ || -B _) {
        html_populate($html, 'entry_name', $entry);
    }
    else {
        my $path = catfile($params{path}, $entry);

        my $script_url = get_script_url(path => $path);

        html_populate($html, 'entry_name', qq(<a href="$script_url">$entry</a>));
    }
}

sub gather_attrs
{
    my ($entry, $attrs) = @_;

    my $file = catfile($params{path}, $entry);

    %$attrs = (
        perms => sub
        {
            my $mode = (lstat($file))[2];
            return join '',
              (S_ISREG($mode)) ? '-' : sub
                { my @types = (
                    [ S_ISDIR($mode),  'd' ],
                    [ S_ISLNK($mode),  'l' ],
                    [ S_ISBLK($mode),  'b' ],
                    [ S_ISCHR($mode),  'c' ],
                    [ S_ISFIFO($mode), 'p' ],
                    [ S_ISSOCK($mode), 'S' ],
                  );
                  foreach my $type (@types) {
                      return $type->[1] if $type->[0];
                  };
                  return '-';
                }->(),
              ($mode & S_IRUSR) ? 'r' : '-',
              ($mode & S_IWUSR) ? 'w' : '-',
              ($mode & S_IXUSR) ? 'x' : '-',
              ($mode & S_IRGRP) ? 'r' : '-',
              ($mode & S_IWGRP) ? 'w' : '-',
              ($mode & S_IXGRP) ? 'x' : '-',
              ($mode & S_IROTH) ? 'r' : '-',
              ($mode & S_IWOTH) ? 'w' : '-',
              ($mode & S_IXOTH) ? 'x' : '-';
        }->(),
        links => (lstat(_))[3],
        owner => (getpwuid((lstat(_))[4]))[0],
        group => (getgrgid((lstat(_))[5]))[0],
        size  => sub
        {
            my $unit;
            my @units = qw(K M G T P E);
            # bytes
            my $size = (lstat(_))[7];
            while (@units && $size > 1024) {
                $size /= 1024;
                $unit = shift @units;
            }
            if (defined $unit && $size < 10) {
                $size = sprintf '%.1f', $size;
            }
            else {
                $size = ceil($size);
            }
            return defined $unit ? "${size}${unit}" : $size;
        }->(),
        mtime => strftime '%Y-%m-%d %H:%M:%S', localtime((lstat(_))[9]),
    );
}

sub subst_entry_attrs
{
    my ($html, $attrs) = @_;

    foreach my $attr (keys %$attrs) {
        html_populate($html, "entry_$attr", $attrs->{$attr});
    }
}

sub subst_entry_color
{
    my ($html, $counter) = @_;

    html_populate($html, 'entry_color', $entry_color[$counter % 2 == 0 ? 1 : 0]);
}

sub html_populate
{
    my ($html, $place_holder, $text) = @_;

    $$html =~ s/\$${\uc $place_holder}/$text/g;
}

sub read_file
{
    my $fh = IO::File->new("<$params{path}")
      or print_status("$!.");

    print $query->header('text/plain');
    print do { local $/; <$fh> };

    $fh->close;
    exit;
}

sub print_status
{
    my ($message) = @_;

    my $html = $html{status};

    html_populate(\$html, 'path', $params{path});
    html_populate(\$html, 'status_msg', $message);

    print $query->header('text/html');
    print $html;
    exit;
}

__DATA__
<!--BEGIN HEADER-->
<!-- navhost v$VERSION - https://github.com/stsc/scripts/tree/master/navhost -->
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
       "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
  <head>
    <title>navhost: $PATH</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <style type="text/css">
      .data { font-family: Courier, Monospace; font-size: small; padding: 2.5px }
      .text { font-family: Arial, Helvetica, sans-serif; font-size: small; padding: 2.5px }
    </style>
  </head>
  <body>
    <table border="0" align="left">
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
      <tr bgcolor="$HEADER_COLOR">
        <td colspan="2"><span class="data">name ($NAME_SORT)($OPTION_ALL)</span></td>
        <td width="145"><span class="data">type/permissions</span></td>
        <td colspan="2"><span class="data">links</span></td>
        <td width="120"><span class="data">owner</span></td>
        <td width="120"><span class="data">group</span></td>
        <td width="90"><span class="data">size</span></td>
        <td width="180"><span class="data">modification time</span></td>
      </tr>
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
      <tr>
        <td colspan="9">
          $FOLDER_IMAGE
          <span class="text">$FOLDER_ROOT</span>
          &nbsp;
          $FOLDER_IMAGE
          <span class="text">$FOLDER_HOME</span>
          &nbsp;
          $FOLDER_IMAGE
          <span class="text">$FOLDER_CURR</span>
        </td>
      </tr>
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
      <tr>
        <td colspan="9"><span class="text">current folder: <b>$PATH</b></span></td>
      </tr>
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
<!--END HEADER-->
<!--BEGIN BODY-->
      <tr bgcolor="$ENTRY_COLOR">
        <td width="18">$ENTRY_IMAGE</td>
        <td width="300"><span class="text">$ENTRY_NAME</span></td>
        <td width="145"><span class="data">$ENTRY_PERMS</span></td>
        <td width="40" align="right"><span class="data">$ENTRY_LINKS</span></td>
        <td width="10"></td>
        <td width="120"><span class="data">$ENTRY_OWNER</span></td>
        <td width="120"><span class="data">$ENTRY_GROUP</span></td>
        <td width="90"><span class="data">$ENTRY_SIZE</span></td>
        <td width="180"><span class="data">$ENTRY_MTIME</span></td>
      </tr>
<!--END BODY-->
<!--BEGIN FOOTER-->
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
      <tr>
        <td colspan="9"><span class="text">Last generated: $LAST_GENERATED</span></td>
      </tr>
      <tr>
        <td colspan="9"><hr size="1"></td>
      </tr>
    </table>
  </body>
</html>
<!--END FOOTER-->
###
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN"
       "http://www.w3.org/TR/html4/loose.dtd">
<html lang="en">
  <head>
    <title>navhost: $PATH</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <style type="text/css">
      .text { font-family: Arial, Helvetica, sans-serif; font-size: small }
    </style>
  </head>
  <body>
    <table border="0" align="left">
      <tr>
        <td><span class="text"><b>$STATUS_MSG</b></span></td>
      </tr>
      <tr>
        <td><span class="text"><a href="javascript:history.back()">return</a></span></td>
      </tr>
    </table>
  </body>
</html>
