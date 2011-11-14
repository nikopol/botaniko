package botaniko::plugin::twitter;

use Modern::Perl;
use Net::Twitter;

use botaniko 'async';
use botaniko::config;
use botaniko::logger;
use botaniko::hook;
use botaniko::command;
use botaniko::db;
use botaniko::irc;

cfg_default 'plugins.twitter' => {
	name                => 'your_twitter_account_name',
	consumer_key        => 'your_consumer_key',
	consumer_secret     => 'your_consumer_secret',
	access_token        => 'your_access_token',
	access_token_secret => 'your_access_token_secret',
	echo                => 1,
	interval            => 120,
	lastid              => 0,
};

my $twitter = Net::Twitter->new( traits=>['API::REST', 'OAuth'], %{cfg('plugins.twitter')} );
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
	my $timeline = eval { $twitter->friends_timeline({ count=>10, since_id=>cfg('plugins.twitter.lastid') }) };
	if( my $err = $@ ) {
		trace ERROR=>'twitter '.$err->error;
	} elsif( $$timeline[0] ) {
		cfg 'plugins.twitter.lastid'=>$$timeline[0]->{id};
		my $me = cfg 'plugins.twitter.name';
		while( my $tweet = pop @$timeline ) {
			my $name = $tweet->{user}->{screen_name};
			if( $name ne $me ) {
				my $text = $tweet->{text};
				dbindex tweet=>{
					name    => $name,
					text    => $text,
					created => $tweet->{created_at}
				};
				trace TWEET=>"$name: $text";
				notify( all=>'@'.$name.': '.$text )
					if cfg('plugins.twitter.echo');
				fire TWEET=>$text,$name;
			}
		}
	}
}

sub tweet {
	my $txt = shift;
	trace INFO=>"TWEET $txt";
	eval { $twitter->update( $txt ) };
	if( my $err = $@ ) {
		trace ERROR=>$err->error;
		return 0
	}
	1
}

async( 
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
		help => 'follower [regex]',
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
			$out = [ splice(@$out,0,10), "...truncated from $count followers" ]
				if @$out > 10;
			@$out ? $out : [ '...nobody' ]
		}
	},
	following => {
		help => 'following [regex]',
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
			$out = [ splice(@$out,0,10), "...truncated from $count followings" ]
				if @$out > 10;
			@$out ? $out : [ '...nobody' ]
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
