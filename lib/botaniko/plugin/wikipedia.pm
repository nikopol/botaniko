package botaniko::plugin::wikipedia;

use strict;
use warnings;
use 5.010;

use HTML::Entities;
use URI::Escape;
use JSON::XS;

use botaniko::config;
use botaniko::logger;
use botaniko::command;
use botaniko::tools;

cfg_default 'plugins.wikipedia' => {
	api => "http://%s.wikipedia.org/w/api.php?action=query&list=search&srlimit=1&srsearch=%s&format=json",
	url => "http://%s.wikipedia.org/wiki/%s",
	loc => "en",
};

command wikipedia => {
	help => "wikipedia query [lang=fr]",
	bin  => sub {
		my( $qry, $loc ) = getoptions(\@_,lang=>cfg 'plugins.wikipedia.loc');
		$qry = join(' ',@$qry);
		return [ 'what are you searching for ?' ] unless $qry;
		my $url = sprintf cfg('plugins.wikipedia.api'), $loc, $qry;
		trace DEBUG=>'loading '.$url;
		my $r = useragent->get( $url );
		unless( $r->is_success ) {
			my $err = $url.' returned '.$r->status_line; 
			trace WARN=>$err;
			return [ $err ];
		}
		my $w = eval { decode_json( $r->decoded_content ) }
			or return ['error parsing answer'];
		if( $w->{query} && $w->{query}->{search} ) {
			my $l = $w->{query}->{search}->[0]->{snippet};
			$l =~ s/<[^<>]+>//g;
			$l =~ s/\s+/ /g;
			return [
				decode_entities( $l ),
				sprintf(cfg('plugins.wikipedia.url'),$loc,uri_escape($qry))
			]
		}
		[ 'nothing found' ];
	}
};

1
