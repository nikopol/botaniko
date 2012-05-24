package botaniko::plugin::twitter;

use strict;
use warnings;
use 5.010;
use Net::Twitter;

use botaniko 'async';
use botaniko::config;
use botaniko::logger;
use botaniko::hook;
use botaniko::command;
use botaniko::db;
use botaniko::irc;
use botaniko::tools;

my $DBTYPE = 'tweet';

cfg_default 'plugins.twitter' => {
	name                => 'your_bot_twitter_account_name',
	consumer_key        => 'your_consumer_key',
	consumer_secret     => 'your_consumer_secret',
	access_token        => 'your_access_token',
	access_token_secret => 'your_access_token_secret',
	interval            => 120,
	lastid              => 0,
};

chancfg_default 'plugins.twitter' => {
	echo                => 1,
};

my $twitter = Net::Twitter->new( 
	traits         => ['API::REST', 'OAuth'],
	useragent_args => cfg('lwp') || { agent => 'Bot4Niko/'.$botaniko::VERSION, timeout => 10 },
	%{cfg('plugins.twitter')}
);
$twitter->access_token(cfg 'plugins.twitter.access_token');
$twitter->access_token_secret(cfg 'plugins.twitter.access_token_secret');
unless( cfg 'plugins.twitter.lastid' ) {
	my $timeline = eval { $twitter->friends_timeline({ count=>1 }) };
	if( my $err = $@ ) {
		trace ERROR=>'twitter '.$err->error;
		$twitter = undef;
	}
	cfg 'plugins.twitter.lastid' => $$timeline[0] ? $$timeline[0]->{id} : 1;
}
trace DEBUG=>"last tweet id set to ".cfg 'plugins.twitter.lastid';

sub get_twitter_timeline {
	return unless $twitter;
	#trace DEBUG=>'get twitter timeline from '.cfg('plugins.twitter.lastid');
	my $timeline = eval { $twitter->home_timeline({ count=>10, since_id=>cfg('plugins.twitter.lastid') }) };
	if( my $err = $@ ) {
		trace ERROR=>'twitter '.$err->error;
	} elsif( $$timeline[0] ) {
		cfg 'plugins.twitter.lastid'=>$$timeline[0]->{id};
		my $me = cfg 'plugins.twitter.name';
		while( my $tweet = pop @$timeline ) {
			my $name = $tweet->{user}->{screen_name};
			if( $name ne $me ) {
				my $text = $tweet->{text};
				dbindex $DBTYPE=>{
					name    => $name,
					text    => $text,
					created => $tweet->{created_at}
				};
				trace TWEET=>"$name: $text";
				for my $chan ( channels() ) {
					notify( $chan=>'@'.$name.': '.$text )
						if chancfg($chan,'plugins.twitter.echo');
				}
				fire TWEET=>$text,$name;
			}
		}
	}
}

hook TOTWEET=>sub {
	my $txt = shift;
	trace INFO=>"TWEET $txt";
	eval { $twitter->update( $txt ) };
	if( my $err = $@ ) {
		trace ERROR=>$err->error;
		return 0
	}
	1
};

async(
	id       => 'timeline',
	cb       => sub{ get_twitter_timeline },
	after    => 20,
	interval => cfg('plugins.twitter.interval') || 120,
);

command
	follow => {
		help => 'follow tweetos',
		root => 1,
		bin  => sub {
			return unless @_;
			my $r = eval { $twitter->follow_new( shift ) };
			if( my $err = $@ ) {
				trace ERROR=>'twitter '.$err->error;
				return ['twitter '.$err->error];
			}
			[ $r->{screen_name}.' ('.($r->{name}?$r->{name}:'no name').') followed' ];
		}
	},
	follower => {
		help => 'follower [regex] : list followers',
		bin  => sub {
			my $arg   = shift;
			my $regex = $arg ? qr/$arg/i : qr/./;
			my $r = eval { $twitter->followers };
			if( my $err = $@ ) {
				trace ERROR=>'twitter '.$err->error;
				return ['twitter '.$err->error];
			}
			$r = [
				sort
				grep { $_ =~ $regex } 
				map  { $_->{screen_name}.($_->{name}?' ('.$_->{name}.')':'') } @$r 
			];
			my $count = @$r;
			my $out = [];
			push( @$out, join(',', splice(@$r,0,4>@$r?scalar @$r:4)) ) while @$r;
			@$out ? trunc( $out ) : [ '...nobody' ]
		}
	},
	following => {
		help => 'following [regex] : list following',
		bin  => sub {
			my $arg   = shift;
			my $regex = $arg ? qr/$arg/i : qr/./;
			my $r = eval { $twitter->friends };
			if( my $err = $@ ) {
				trace ERROR=>'twitter '.$err->error;
				return ['twitter '.$err->error];
			}
			$r = [
				sort
				grep { $_ =~ $regex } 
				map  { $_->{screen_name}.($_->{name}?' ('.$_->{name}.')':'') } @$r 
			];
			my $count = @$r;
			my $out = [];
			push( @$out, join(',', splice(@$r,0,4>@$r?scalar @$r:4)) ) while @$r;
			@$out ? trunc( $out ) : [ '...nobody' ]
		}
	},
	unfollow => {
		help => 'unfollow tweetos',
		root => 1,
		bin  => sub {
			return unless @_;
			my $r = eval { $twitter->unfollow( shift ) };
			if( my $err = $@ ) {
				trace ERROR=>'twitter '.$err->error;
				return ['twitter '.$err->error];
			}
			[ $r->{screen_name}.' ('.($r->{name}?$r->{name}:'no name').') unfollowed' ];
		}
	};

1
