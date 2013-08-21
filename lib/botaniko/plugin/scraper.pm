package botaniko::plugin::scraper;

use strict;
use warnings;
use 5.010;

use botaniko::config;
use botaniko::logger;
use botaniko::command;
use botaniko::tools;

cfg_default 'plugins.scraper' => {
	scraps   => {},
	prefix   => '=> ',
};

sub scrap {
	my $s = shift;
	my $cfg = cfg 'plugins.scraper.scraps.'.$s;
	return ['scrap '.$s.' not defined'] unless $cfg;
	my $r = useragent->get( $cfg->{url} );
	unless( $r->is_success ) {
		trace(ERROR=>'error loading '.$cfg->{url}.' : '.$r->status_line),
		return ['error loading '.$cfg->{url}.' : '.$r->status_line];
	}
	my $prefix = cfg('plugins.scraper.prefix') || '';
	my $page = $r->decoded_content;
	my $rule = $cfg->{rule};
	my @scraps;
	push @scraps, "$prefix$1" while $page =~ /$rule/mg;
	@scraps ? \@scraps : ['no match'];
}

command
	scrap => {
		help => 'scrap [[-]name [url rule]]',
		root => 0,
		bin  => sub {
			if( @_ == 0 ) {
				my @scraps = keys %{cfg('plugins.scraper.scraps')||{}};
				my @out;
				push( @out, join(',', splice(@scraps,0,4>@scraps?scalar @scraps:4)) ) while @scraps;
				return @out ? trunc( \@out ) : ['no scraps available'];
			} else {
				my $what = shift;
				my( $rm, $scrap ) = $what=~/^(-?)(.+)$/;
				my $key  = 'plugins.scraper.scraps.'.$scrap;
				if( @_ > 1 ) {
					my $url  = shift @_;
					my $rule = join(' ',@_);
					my $upd  = cfg $key;
					cfg $key => {
						url  => $url,
						rule => $rule,
					};
					return [ $upd
						? 'scrap '.$scrap.' updated'
						: 'scrap '.$scrap.' added'
					]
				} elsif( $rm ) {
					if( cfg $key ) {
						cfg $key => undef;
						return [ 'scrap '.$scrap.' deleted' ];
					} else {
						return [ 'scrap '.$scrap.' not found' ];
					}
				} else {
					return scrap( $scrap )
				}
			}
		}
	};

1
