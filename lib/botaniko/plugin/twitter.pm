package botaniko::plugin::twitter;

use strict;
use warnings;
use 5.010;

no if $] >= 5.018, 'warnings', "experimental::smartmatch";

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
my $MAXTWEETIDS = 100;
my @tweetids;

cfg_default 'plugins.twitter' => {
	name                => 'your_bot_twitter_account_name',
	consumer_key        => 'your_consumer_key',
	consumer_secret     => 'your_consumer_secret',
	access_token        => 'your_access_token',
	access_token_secret => 'your_access_token_secret',
	interval            => 120,
	timeline            => 1,
	timeline_lastid     => 0,
	mentions            => 1,
	mentions_lastid     => 0,
	dm                  => 1,
	dm_lastid           => 0,
};

chancfg_default 'plugins.twitter' => {
	echo                => 1,
};

my $twitter = Net::Twitter->new( 
	traits         => ['API::RESTv1_1'],
	useragent_args => cfg('lwp') || { agent => 'Bot4Niko/'.$botaniko::VERSION, timeout => 10 },
	decode_html_entities => 1,
	%{cfg('plugins.twitter')}
);
$twitter->access_token(cfg 'plugins.twitter.access_token');
$twitter->access_token_secret(cfg 'plugins.twitter.access_token_secret');
unless( cfg 'plugins.twitter.timeline_lastid' ) {
	my $timeline = eval { $twitter->friends_timeline({ count=>1 }) };
	if( my $err = $@ ) {
		trace ERROR=>'twitter '.$err->error;
		$twitter = undef;
	}
	cfg 'plugins.twitter.timeline_lastid' => $$timeline[0] ? $$timeline[0]->{id} : 1;
}
trace DEBUG=>"last tweet id set to ".cfg 'plugins.twitter.timeline_lastid';

sub twitter_fetch {
	return unless $twitter;
	my( $what, $fetch ) = @_;
	my $lastidkey = 'plugins.twitter.'.$what.'_lastid';
	trace DEBUG=>'get twitter '.$what.' from '.cfg($lastidkey);
	my %opt = ( count=>10 );
	$opt{since_id} = cfg($lastidkey) if cfg($lastidkey);
	my $timeline = eval { &$fetch(\%opt) };
	if( my $err = $@ ) {
		trace ERROR=>'twitter '.$err->error;
	} elsif( $$timeline[0] ) {
		cfg $lastidkey => $$timeline[0]->{id};
		my $me = cfg 'plugins.twitter.name';
		while( my $tweet = pop @$timeline ) {
			next if $tweet->{id} ~~ @tweetids;
			my $name = $tweet->{user}{screen_name} || $tweet->{sender}{screen_name} || '?';
			if( $name ne $me ) {
				my $text = $tweet->{text};
				dbindex $DBTYPE=>{
					name    => $name,
					text    => $text,
					created => $tweet->{created_at}
				};
				trace TWEET=>"$name: $text";
				for my $chan ( channels ) {
					next unless chancfg($chan,'plugins.twitter.echo');
					my @lines = split /\s*[\r\n]+\s*/, $text;
					my $max = 5;
					while( scalar @lines && $max ) {
						notify( $chan => ($max == 5 ? ' ' x (1+length($name)) : '@'.$name).': '.(shift @lines) );
						$max--;
					}
				}
				fire TWEET=>$text,$name;
			}
			push @tweetids, $tweet->{id};
			shift @tweetids while scalar @tweetids > $MAXTWEETIDS;
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
	cb       => sub{ twitter_fetch( timeline => sub { $twitter->home_timeline(@_) } ) },
	after    => 20,
	interval => cfg('plugins.twitter.interval') || 120,
);

async(
	id       => 'mentions',
	cb       => sub{ twitter_fetch( mentions => sub { $twitter->mentions_timeline(@_) } ) },
	after    => 30,
	interval => cfg('plugins.twitter.interval') || 120,
);

async(
	id       => 'dm',
	cb       => sub{ twitter_fetch( dm => sub { $twitter->direct_messages(@_) } ) },
	after    => 40,
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
				map  { $_->{screen_name}.($_->{name}?' ('.$_->{name}.')':'') }
				@{$r->{users}} 
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
				map  { $_->{screen_name}.($_->{name}?' ('.$_->{name}.')':'') } 
				@{$r->{users}} 
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
	},
	dm => {
		help => 'dm tweetos msg',
		root => 1,
		bin  => sub {
			return unless @_;
			my $who = shift() || return ['to who ?'];
			my $msg = join(' ',@_) || return ['message ?'];;
			my $r = eval { $twitter->new_direct_message( {screen_name=>$who,text=>$msg} ) };
			if( my $err = $@ ) {

				return ['twitter '.$err->error];
			}
			[ 'dm sent to @'.$r->{recipient}{screen_name} ];
		}
	};

1
