package botaniko::irc;

use strict;
use warnings;
use 5.010;
use AnyEvent::IRC::Client;
use Encode;

use botaniko::logger;
use botaniko::config;

use base 'Exporter';
our @EXPORT = qw(irc channels send_channel send_user notify join_channel leave_channel channel_list);

sub tempo {
	state $last;
	sleep 1 if $last && $last == time;
	$last = time;
}

sub irc {
	state $irc;
	$irc = new AnyEvent::IRC::Client() unless $irc;
	$irc
}

sub channels {
	my $chan = shift;
	map { /^#/ ? $_ : "#$_" }
		!$chan                ? keys %{irc->channel_list} :
		ref($chan) eq 'ARRAY' ? @$chan :
		$chan eq 'all'        ? keys %{irc->channel_list} :
		                        ( $chan )
}

sub send_channel {
	return if cfg 'mute';
	for my $chan ( channels shift ) {
		for my $msg ( @_ ) {
			tempo;
			irc->send_chan($chan, PRIVMSG=>($chan, encode_utf8 $msg));
		}
	}
}

sub send_user {
	my $user = shift;
	while( my $msg = shift @_ ) {
		tempo;
		irc->send_srv(PRIVMSG=>$user, encode_utf8 $msg);
	}
}

sub notify {
	return if cfg 'mute';
	for my $chan ( channels shift ) {
		for my $msg ( @_ ) {
			irc->send_chan($chan, NOTICE=>($chan, encode_utf8 $msg));
			tempo;
		}
	}
}

sub join_channel {
	for my $chan ( channels shift ) {
		trace INFO=>"joining $chan";
		irc->send_srv('JOIN', $chan);
	}
}

sub leave_channel {
	for my $chan ( channels shift ) {
		trace INFO=>"leaving $chan";
		irc->send_srv('PART', $chan);
	}
}

sub channel_list {
	irc->channel_list( shift )
}

1
