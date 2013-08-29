package botaniko::plugin::scraper;

use strict;
use warnings;
use 5.010;

use JSON qw( decode_json );
use POSIX qw( strftime );

use botaniko::config;
use botaniko::logger;
use botaniko::command;
use botaniko::tools;

#global config
cfg_default 'plugins.gilbert' => {
    version => 1,
    host => 'http://your-host.com:your-port',
    api => {
        users => '/users',
        games => '/games?{"$sort":%20{"date":%20-1}}',
        submit=> '/games',
    },
    limit => 5,
};

my $last_game_id = '';

my $usage = [
    'Usage: bab [filter] [limit=5] [format=classic]',
    '<filter>: a regex: <p1>&<p2>/<p3>&<p4>, <p{1..4}> '
        . 'matches the player {1..4}, e.g. match_all: .*&.*/.*&.*',
    '  shortcuts: <p> search for all games with player <p>',
    '             <p1>&<p2> search for all games with <p1> and '
        . '<p2> in the same team',
    '             <p1>/<p2> search for all games with <p1> and '
        . '<p2> in different teams',
    '  examples: niko      # all games with niko',
    '            niko/hugo # all games with niko against hugo',
    '<format>: output format. Available ones: classic,short.',
];

sub fmt_date {
    my $t = shift();
    
    if ($t > 2000000000) {
        # JS timestamp
        $t /= 1000;
    }
    strftime("%d/%m/%Y", localtime($t));
}

sub basic_fmt {
    my $s = shift;
    my $d = shift;
    my $date = fmt_date($d->{date});

    $s =~ s/\{date\}/$date/gi;
    $s =~ s/\{p1\}/$d->{p1}/gi;
    $s =~ s/\{p2\}/$d->{p2}/gi;
    $s =~ s/\{p3\}/$d->{p3}/gi;
    $s =~ s/\{p4\}/$d->{p4}/gi;
    $s =~ s/\{s1\}/$d->{s1}/gi;
    $s =~ s/\{s2\}/$d->{s2}/gi;

    # shortcuts
    $s =~ s/\{ps\}/$d->{p1}, $d->{p2}, $d->{p3} and $d->{p4}/gi;
    
    $s;
}

my $formats = {
    classic => sub {
        basic_fmt(
            '{date}: {p1} and {p2} vs {p3} and {p4}, final score: {s1} - {s2}.', @_);
    },
    short   => sub {
        my $d = shift;
        for (1..4) { # keep only last name
            my @t = split(' ', $d->{"p$_"});
            $d->{"p$_"} = $t[-1];
        }
        basic_fmt('{date}: {p1}+{p2} [{s1} - {s2}] {p3}+{p4}', $d);
    },

};

sub get_players {
	my $cfg = cfg 'plugins.gilbert';
    my $url = "$cfg->{host}$cfg->{api}{users}";
	my $json = useragent->get( $url );
	unless( $json->is_success ) {
		trace(ERROR=>'error loading '.$url.' : '.$json->status_line),
	}
    my $r = decode_json( $json->decoded_content );
    my $players = {};
    for (@$r) {
        $players->{$_->{id}} = $_->{username};
    }
    cfg 'plugins.gilbert.players', $players;
}

sub mk_filter {
    my $f = shift;
    my @patts = split(/\s*[\/&]\s*/, $f, 4);

    sub {
        my ($p1, $p2, $p3, $p4) = @_;

        my @teams = (
            join('##', ($p1, $p2)),
            join('##', ($p3, $p4))
        );

        for (0, 1) {

            my $c1 = $_;
            my $c2 = ($_+1)%2;

            return 1 if ((($teams[$c1] =~ /$patts[0]/i) && ($teams[$c1] =~ /$patts[1]/i))
                      && (($teams[$c2] =~ /$patts[2]/i) && ($teams[$c2] =~ /$patts[3]/i)));
        }

        0;
    }
}

sub fmt_game {
    my ($p1, $p2, $p3, $p4, $s1, $s2, $fmt) = @_; 
    my $date = $_->{date};
    if (!(defined $fmt) || !$fmt || !exists($formats->{$fmt})) {
        $fmt = 'classic';
    }
    &{$formats->{$fmt}}({
        p1 => $p1, p2 => $p2, p3 => $p3, p4 => $p4,
        s1 => $s1, s2 => $s2, date => $date
    });
}

sub get_games {
    my $limit = shift() || 5;
    my $filter = shift() || '.*&.*/.*&.*';
    my $format = shift() || 'classic';
    my $cfg = cfg 'plugins.gilbert';
    $filter = mk_filter($filter);
    trace(DEBUG=>"limit:".$limit);
    my $url = "$cfg->{host}$cfg->{api}{games}";
	my $json = useragent->get( $url );
	unless( $json->is_success ) {
		trace(ERROR=>'error loading '.$url.' : '.$json->status_line),
		return ['error loading games list : '.$json->status_line];
	}
    my $r = decode_json( $json->decoded_content );
    my $players = cfg('plugins.gilbert.users') || get_players;
    my $games = [];

    for (@$r) {
        my $p1 = $players->{$_->{player1}};
        my $p2 = $players->{$_->{player2}};
        my $p3 = $players->{$_->{player3}};
        my $p4 = $players->{$_->{player4}};

        unless ($p1 && $p2 && $p3 && $p4) {
            trace(ERROR=> 'Undefined player');
            return ['error with the players list. Check the logs.'];
        }

        next unless &$filter($p1, $p2, $p3, $p4);
        last if $limit-- <= 0;

        my $s = fmt_game($p1, $p2, $p3, $p4, $_->{score1}, $_->{score2}, $format);
        push @$games, $s;
    }

    if (@$games < 1) {
        return ['No games found.'];
    }

    trunc($games, 10);
}

command
    bab => {
		help => 'bab [filter] [limit=5] # print the last games (max limit = 10)',
		root => 0,
		bin  => sub {
			my( $qry, $limit, $format ) = getoptions( \@_,
				limit  => cfg('plugins.gilbert.limit'),
                format => 'classic',
			);

            my $filter = join(' ', @$qry) || '.*&.*/.*&.*';

            if ($filter =~ /help/i) {
                return $usage;
            }

            # filter on one player only
            if ($filter =~ /^[^&\/]+$/) {
                $filter .= '&.*/.*&.*';
            }

            # filter on one team only
            elsif ($filter =~ /^[^&\/]+&[^&\/]+$/) {
                $filter .= '/.*&.*';
            }
            
            # filter on two players of different teams
            elsif ($filter =~ /^[^&\/]+\/[^&\/]+$/) {
                $filter = ".*&$filter&.*";
            }

            return ['unrecognized filter.'] unless $filter =~ /^[^&]+&[^\/]+\/[^&]+&.*$/;

            return $limit <= 0
                ? ['No games found.']
                : get_games($limit, $filter, $format);
        }
    };

1
