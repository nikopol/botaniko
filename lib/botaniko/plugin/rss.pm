package botaniko::plugin::rss;

use strict;
use warnings;
use 5.010;

use POSIX 'strftime';
use HTTP::Headers;
use XML::FeedPP;

use botaniko 'async';
use botaniko::config;
use botaniko::logger;
use botaniko::command;
use botaniko::irc;
use botaniko::hook;
use botaniko::tools;

cfg_default 'plugins.rss' => {
	interval => 300,
	flux     => {},
};

chancfg_default 'plugins.rss' => {
	echo => 1,
};

sub read_feed {
	my $f = shift;
	trace DEBUG=>'read flux '.$f->{url};
	my $req = HTTP::Request->new( GET => $f->{url} );
	if( $f->{login} && $f->{password} ) {
		trace DEBUG=>'auth with '.$f->{login};
		$req->headers->authorization_basic( $f->{login}, $f->{password} );
	}
	my $r = useragent->request( $req );
	return trace(ERROR=>'error loading '.$f->{url}.' : '.$r->status_line)
		unless $r->is_success;
	XML::FeedPP->new( $r->decoded_content );
}

sub check_rss {
	my $flux = cfg('plugins.rss.flux') || {};
	my $nbflux = 0;
	my $nbread = 0;
	for my $name ( keys %$flux ) {
		if( my $feed = read_feed($flux->{$name}) ){
			$nbflux++;
			my $lastdate = $flux->{$name}->{lastdate} || '';
			my $maxdate;
			for my $item ( $feed->get_item() ) {
				if( !$lastdate || ($lastdate cmp $item->pubDate()) == -1 ) {
					$nbread++;
					my $who  = $item->author() || 'unknown';
					my $what = $item->title() || 'no content';
					trace NOTICE=>"$who: $what";
					for my $chan ( channels() ) {
						notify( $chan=>$name.' @'.$who.': '.$what )
							if chancfg($chan,'plugins.rss.echo');
					}
					fire RSS => $what,$who;
					$maxdate = $item->pubDate() if !$maxdate || ($maxdate cmp $item->pubDate()) == -1;
				}
			}
			$flux->{$name}{lastdate} = $maxdate if $maxdate;
		}
	}
	cfg('plugins.rss.flux'=>$flux) if $nbread;
	trace INFO=>$nbread.' new post read from '.$nbflux.' rss feeds';
}

async(
	id       => 'rss',
	cb       => sub{ check_rss },
	after    => 20,
	interval => cfg('plugins.rss.interval') || 300,
);

command
	rss => {
		help => 'rss list|read name [count=5]|add/update name url [user=u password=s]|rm name',
		root => 1,
		bin  => sub {
			my $cmd = shift or return;
			my( $opts, $count, $login, $pwd ) = getoptions(\@_,count=>5,login=>'',password=>'');
			my $flux = cfg('plugins.rss.flux') || {};
			my $name = @$opts ? shift @$opts : undef;
			if( $cmd =~ /read/i ){
				return ['which one?'] unless $name;
				return ['not found'] unless exists $flux->{$name};
				my $feed = read_feed( $flux->{$name} );
				return ['error reading feed'] unless $feed;
				$count = 10 if $count > 10;
				$count = 5 if $count < 1;
				trunc(
					[ map { $_->pubDate().' @'.$_->author().' : '.$_->title() } $feed->get_item() ],
					$count
				)
			}elsif( $cmd =~ /li?st/i ){
				return ['none'] unless @$flux;
				[ map { $_.' '.$_->{url} } keys %$flux ]
			}elsif( $cmd =~ /add|update/i ){
				return ['name?'] unless $name;
				my $url = shift @$opts;
				return ['url?'] unless $url;
				my $upd = exists $flux->{$name};
				$flux->{$name} = {
					url      => $url,
					lastdate => strftime("%Y-%m-%dT%T",localtime(time))
				};
				$flux->{$name}->{login}    = $login if $login;
				$flux->{$name}->{password} = $pwd if $pwd;
				cfg 'plugins.rss.flux' => $flux;
				[ $upd ? 'rss updated' : 'rss added' ]
			}elsif( $cmd =~ /re?m|del/i ){
				return ['name?'] unless $name;
				return ['rss not found'] unless exists $flux->{$name};
				delete $flux->{$name};
				cfg 'plugins.rss.flux' => $flux;
				[ 'rss deleted' ]
			}else{
				return ['read list add or rm?']
			}
		}
	};

1
