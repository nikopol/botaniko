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
		games => '/games?{"$sort":%20{"date":%20-1},"limit":500}',
		submit=> '/games',
	},
	limit => 5
};

my $max_team_width = 0;
my $games_cache = [];

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
my $formats = {classic=>1, short=>1};

sub fmt_date {
	my $t = shift();

	if ($t > 2000000000) {
		# JS timestamp
		$t /= 1000;
	}
	strftime("%d/%m/%Y", localtime($t));
}

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
		my $game = $_;

		$game = beautify_game($game) unless exists($game->{teams});

		my ($p1, $p2, $p3, $p4) = (@{$game->{teams}[0]{players}}, @{$game->{teams}[1]{players}});

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

sub beautify_game {
	my $g = shift;
	my $game = {
		date => $g->{date},
		id   => $g->{id},
	};
	my $p = cfg('plugins.gilbert.users') || get_players;

	my $team1 = {
		score => $g->{score1},
		players => [sort ($p->{$g->{player1}}, $p->{$g->{player2}})]
	};
	my $team2 = {
		score => $g->{score2},
		players => [sort ($p->{$g->{player3}}, $p->{$g->{player4}})]
	};

	my @ts = sort { $b->{score} <=> $a->{score} } ($team1, $team2);
	$game->{teams} = \@ts;

	$game;
}

sub fmt_game {
	my $game = shift;
	my $fmt  = shift;
	my $date = $game->{date};
	if (!(defined $fmt) || !$fmt || !exists($formats->{$fmt})) {
		$fmt = 'classic';
	}

	if ($fmt eq 'short') {
		for (0..1) {
			my @ps = sort (map { my @s = split(' ', $_); $s[-1]; } @{$game->{teams}[$_]{players}});
			$game->{teams}[$_]{players} = \@ps;
		}
	}

	my $t1 = $game->{teams}[0];
	my $t2 = $game->{teams}[1];

	my $s1 = sprintf "%s & %s", @{$t1->{players}};
	my $s2 = sprintf "%s & %s", @{$t2->{players}};

	if ($max_team_width == 0) {
		my $p = cfg('plugins.gilbert.users') || get_players;
		my $max_player_width = 0;
		my $max_player_width2 = 0;
		my @names = map { length $_ } (values(%$p));
		for (@names) {
			if ($_ > $max_player_width) {
				$max_player_width2 = $max_player_width;
				$max_player_width = $_;
			}
			if ($max_player_width >= 30) { $max_player_width = 30; last; }
		}
		$max_team_width = $max_player_width + $max_player_width2 + length(" & ");
	}

	my $mx = $max_team_width;
	sprintf "%s: %-${mx}s vs %${mx}s [%02d-%02d]",
		fmt_date($game->{date}), $s1, $s2, $t1->{score}, $t2->{score};
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
		my $game = beautify_game($_);
		next unless &$filter($game);
		last if $limit-- <= 0;

		my $s = fmt_game($game, $format);
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
