package botaniko::plugin::linkmag;

use strict;
use warnings;
use 5.010;
use HTTP::Request;
use JSON::XS;

use botaniko::logger;
use botaniko::command;
use botaniko::tools;
use botaniko::config;

cfg_default	'plugins.linkmag' => {
	theme       => 'your_theme_url',
	mustread    => 'your_mustread_url',
	mustreaddoc => 'your_mustreaddoc_url',
};

command 
	mustread => {
		help => 'mustread [theme [count]]',
		bin  => sub {
			my $theme = shift || 'fr/actualites';
			my $count = shift || 3;
			my $urlmustread    = cfg('plugins.linkmag.mustread');
			my $urlmustreaddoc = cfg('plugins.linkmag.mustreaddoc');
			$count = 3 if $count < 0 || $count > 5;
			trace DEBUG=>'loading '.$urlmustread;
			my $req = HTTP::Request->new(POST => $urlmustread);
			$req->header( 'Content-Type' => 'application/json' );
			$req->content( encode_json({
				themes => [{ path=>$theme }],
				count  => $count,
			}) );
			my $r = useragent->request( $req );
			return [ 'youmag api returned '.$r->status_line ] unless $r->is_success;
			my $out = [];
			my $lst = decode_json $r->decoded_content;
			for( @$lst ) {
				my $docid = $_->{content_id};
				trace DEBUG=>'loading '.$urlmustreaddoc.$docid;
				$r = useragent->get( $urlmustreaddoc.$docid );
				if( $r->is_success ) {
					my $doc = decode_json $r->decoded_content;
					push @$out, "- $doc->{title}";
					push @$out, "  $doc->{original_url}"
				} else {
					push @$out, "- doc $docid returned $r->status_line"
				}
			}
			$out or ['nothing']
		}
	},
	theme => {
		help => 'theme [regex] [reload]',
		bin  => sub {
			my $arg   = shift;
			my $regex = $arg ? qr/$arg/i : qr/./;
			state $themes;
			if( !$themes || shift ) {
				my $url = cfg('plugins.linkmag.theme');
				trace DEBUG=>"loading ".$url;
				my $r = useragent->get( $url );
				return [ 'youmag api returned '.$r->status_line ] unless $r->is_success;
				$themes = decode_json( $r->decoded_content );
			}
			my $out	  = [ grep { $_ =~ $regex } @$themes ];
			my $count = scalar @$out;
			if( $count > 5 ) {
				$out = [ 
					splice( @$out, 0, 5 ),
					"...truncated from $count matching results"
				]
			}
			$out or ['not found']
		}
	};

1
