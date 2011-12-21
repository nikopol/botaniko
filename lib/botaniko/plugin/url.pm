package botaniko::plugin::url;

use strict;
use warnings;
use 5.010;
use HTML::Entities;
use Image::Info qw(image_info dim);
use POSIX 'strftime';
use DateTime::Format::Strptime;

use botaniko::config;
use botaniko::logger;
use botaniko::tools;
use botaniko::db;
use botaniko::hook;
use botaniko::command;
use botaniko::irc;

my $DBTYPE = 'url';

chancfg_default 'plugins.url' => {
	echo       => 0,
	test_tweet => 0,
	test_url   => 1,
	tweet_url  => 1,
};

sub process_url {
	my( $chan, $nick, $from, $url, $text ) = @_;

	state $parsedt = new DateTime::Format::Strptime( pattern => '%F %T' );

	$url =~ s/^\(|\)$//g;
	my $fromurl = $url;
	trace DEBUG=>'loading '.$url;
	my $r = useragent->get( $url );
	my $html  = '';
	my $title = '';
	my $type  = '';
	my $err   = '';
	my $tagol = $text =~ /\#oldlink/i;
	$url = $r->request->uri->canonical->as_string if $r && $r->request;
	if( $r->is_success ) {
		trace DEBUG=>'resolved as '.$url.' ('.$r->headers->content_type.')';
		$type = $r->headers->content_type;
		if( $type =~ /html/i ) {
			$html = $r->decoded_content;
			$html =~ s/[\r\n]//g;
			$html =~ s/<!--.+?-->//g;
			$title = ( $html =~ /<title>([^<]+)/i || $html =~ /<h1>([^<]+)/i ) 
				? decode_entities( $1 )
				: '';
			$title =~ s/^\s+|\s+$//g;
			trace DEBUG=>($title?'title found '.$title:'title not found');
		} elsif( $type =~ /image/i ) {
			my $inf = image_info( \$r->decoded_content() );
			if( $inf ) {
				my( $width, $height ) = dim( $inf );
				$title = "Image $width x $height";
				$title .= ' : '.$inf->{Comment} if $inf->{Comment};
			}
		}
	} else {
		$err = $url.' returned '.$r->status_line;
		trace WARN=>$err;
	}
	my $s = dbsearchterm $DBTYPE,'url',$url;
	if( $s && $s->{hits}->{total} && chancfg($chan,'plugins.url.test_url') && ($chan ne 'twitter' || chancfg($chan,'plugins.url.test_tweet')) ) {
		unless( $tagol ) {
			my $e = $parsedt->parse_datetime($s->{hits}->{hits}->[0]->{_source}->{date})->epoch;
			my $z = $parsedt->parse_datetime(strftime("%Y-%m-%d %H:%M:%S",localtime(time)))->epoch - $e;
			send_channel( $chan=>$nick.': old link !p since '.delay($z).' '.record(oldlink=>$z,$nick) );
			send_channel( $chan=>$_->{_source}->{date}.' @'.$_->{_source}->{name}.': '.$_->{_source}->{text} )
				for @{$s->{hits}->{hits}};
		}
	} else {
		if( $chan ne 'twitter' ) {
			if( chancfg($chan,'plugins.url.echo') ) {
				my $out;
				$out = $url.' => type: '.$type if $type;
				$out = $url.' => "'.$title.'"' if $title;
				$out = $err if $err;
				send_channel( $chan=>$out ) if $out;
			}
			if( $tagol ) {
				send_channel $chan=>$nick.': this is not an old link for me';
			}
		}
		trace INFO=>"add $url ($title)";
		eval { dbindex $DBTYPE=>{
			chan => $chan,
			name => $nick,
			from => $from,
			url  => $url,
			text => $text,
			title=> $title,
			meta => $url,
		} };
		if( $chan ne 'twitter' && chancfg($chan,'plugins.url.tweet_url') && $text !~ /notweet/i ) {
			$text =~ s/^[^\s\:]+\:\s+//;
			fire TOTWEET=>$text,$nick,$chan;
		}
	}
}

hook MSG => sub {
	my($msg,$user,$from,$chan) = @_;
	if( my @urls = ($msg =~ m{(https?://[\S]+)}gi) ) {
		process_url( $chan, $user, $from, $_, $msg ) for @urls
	}
};

hook TWEET => sub {
	my($msg,$user) = @_;
	if( my @urls = ($msg =~ m{(https?://[\S]+)}gi) ) {
		process_url( 'twitter', $user, '', $_, $msg ) for @urls
	}
};

1
