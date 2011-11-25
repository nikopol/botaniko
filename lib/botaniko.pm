package botaniko;

###      #####    #   # # #  #
#  #  ##   #  ##  ##  #   # #
###  #  #  # #  # # # # # ##
#  # #  #  # #### #  ## # # #
###   ##   # #  # #   # # #  #

use strict;
use warnings;
use 5.010;
use Encode;
use AnyEvent;
use Digest::SHA1 'sha1_hex';

use botaniko::config;
use botaniko::logger;
use botaniko::hook;
use botaniko::irc;
use botaniko::db;
use botaniko::plugin;
use botaniko::command;
use botaniko::tools;

use base 'Exporter';
our @EXPORT = qw(plant async unasync);

our $VERSION = '0.5';

our $w;
my %watch;
my $exiting = 0;

sub async {
	my %prm  = @_;
	my $plug = $botaniko::plugin::PLUGNAME;
	trace DEBUG=>"adding async call for $plug";
	my $k = 'plugin-'.$plug;
	if( my $id = delete $prm{id} ) { $k .= '-'.$id }
	$watch{$k} = AnyEvent->timer( %prm );
}

sub unasync {
	my $plug = shift;
	for( keys %watch ) {
		if( /^plugin-$plug/ ) {
			trace DEBUG=>'remove async call '.$_;
			delete $watch{$_};
		}
	}
}

sub plant {
	loadcfg @_;
	trace NOTICE=>"starting botaniko v$VERSION";
	dbinit or return;

	$w = AnyEvent->condvar;	
	
	irc->reg_cb(
		connect => sub {
			my($cnx, $err) = @_;
			if(defined $err) {
				trace ERROR=>"connect error: $err";
				return;
			}
			trace NOTICE=>"connected to $cnx->{host}:$cnx->{port}";
		},
		registered => sub {
			my($cnx) = @_;
			trace NOTICE=>"registred on $cnx->{host}";
			fire CONNECT=>$cnx;
			#autoload plugins
			if( my $plugs = cfg 'autoload' ) {
				$plugs = [ $plugs ] unless ref( $plugs ) eq 'ARRAY';
				plugin($_) for @$plugs;
			}
			#join channels
			if( my $chans = cfg 'autojoin' ) {
				$chans = [ $chans ] unless ref($chans) eq 'ARRAY';
				join_channel($_) for @$chans;
			}
		},
		disconnect => sub {
			my($cnx) = @_;
			trace NOTICE=>"disconnected from $cnx->{host}";
			unless( $exiting ) {
				trace INFO=>"reconnecting...";
				sleep 5;
				irc->connect(cfg('server.host'), cfg('server.port'), { nick => cfg('nick') });
			} else {
				fire DISCONNECT=>$cnx;
			}
		},
		error => sub {
			my( $cnx, $code, $msg, $ircmsg ) = @_;
			trace ERROR=>"$msg ($code)";
		},
		join => sub {
			my( $cnx, $nick, $chan, $myself ) = @_;
			if( $myself ) {
				trace NOTICE=>"joined $chan";
				set_chan_default $chan;
				fire JOIN=>$chan;
			} else {
				trace INFO=>"$nick joined $chan";
				fire USERJOIN=>$nick,$chan;
			}
		},
		quit => sub {
			my( $cnx, $nick, $msg ) = @_;
			$msg ||= "no msg";
			trace INFO=>"$nick quit ($msg)";
			fire USERQUIT=>$nick,$msg;
		},
		publicmsg => sub {
			my( $cnx, $chan, $msg ) = @_;
			my( $who, $from ) = $msg->{prefix} =~ m{^([^\!]*)\!(.*)$};
			return unless $who;
			my $txt  = decode_utf8 $msg->{params}->[1];
			my $me   = irc->nick;
			if( $txt =~ s/^$me\:?\s*// ) {
				send_channel $chan=>run( $who, $from, $txt );
			} else {
				fire MSG=>$txt,$who,$from,$chan;
			}
		},
		privatemsg => sub {
			my( $cnx, $nick, $msg ) = @_;
			my $what = decode_utf8 $msg->{params}->[1];
			if( $msg->{command} eq 'PRIVMSG' ) {
				my( $who, $from ) = $msg->{prefix} =~ m{^([^\!]*)\!(.*)$};
				my $ans;
				if( sha1_hex($what) eq cfg 'passphrase' ) {
					admin $from=>1;
					send_user $who=>pickone(
						'zog zog master !',
						'I kneel before you my king',
					);
					trace INFO=>"admin $from ($who) registred";
				} else {
					send_user $who=>run( $who, $from, $what );
				}
			} else {
				my $who  = $msg->{prefix} || 'server';
				if( $msg->{command} eq 'NOTICE' ) {
					trace NOTICE=>"$who : $what"
				} else {
					trace DEBUG=>"$msg->{command} from $who : $what"
				}
			}
		},
		nick_change => sub {
			my( $cnx, $old, $new, $myself ) = @_;
			trace DEBUG=>"$old becomes $new";
			fire NICKCHANGE=>$old,$new;
		},
	);
	trace INFO=>'connecting to '.cfg('server.host').':'.cfg('server.port');
	irc->connect(cfg('server.host'), cfg('server.port'), { nick => cfg('nick') });
	$watch{sigterm} = AnyEvent->signal( signal=>"TERM", cb => sub{ 
		trace DEBUG=>"SIGTERM!";
		$w->send('terminated') 
	});
	$watch{sigint}  = AnyEvent->signal( signal=>"INT",  cb => sub{
		trace DEBUG=>"SIGINT!\n";
		$w->send('interrupted')
	});
	my $r = $w->recv;
	trace INFO=>"leaving ($r)";
	$exiting = 1;
	irc->disconnect;
	$w = undef;
}

1
