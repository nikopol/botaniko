package botaniko::plugin::moc;

use strict;
use warnings;
use 5.010;

use botaniko::config;
use botaniko::command;
use botaniko::tools;

cfg_default 'plugins.moc' => {
	server => 'localhost',
};

sub mocmd {
	my $cmd = shift;
	my $cfg = cfg 'plugins.moc.server';
	$cmd = ($cfg && $cfg ne 'localhost')
		? "ssh $cfg 'mocp --".$cmd."'"
		: 'mocp --'.$cmd;
	( `$cmd` )
}

sub mocinfo { map { chomp; $_ } grep { /Artist|SongTitle/ } mocmd('info') }

command 
	moc => {
		help => "next|prev|stop|info music control",
		bin  => sub {
			my( $what, $server ) = getoptions(\@_,server=>undef);
			cfg( 'plugins.moc.server' => $server ) if $server;
			my @out;
			while( @$what ) {
				my $cmd = shift @$what;
				given ( $cmd ) {
					when( /stop/ ) { mocmd('stop'); push @out, 'music stopped' }
					when( /next/ ) { mocmd('next'); push @out, mocinfo }
					when( /prev/ ) { mocmd('previous'); push @out, mocinfo }
					when( /info/ ) { push @out, mocinfo }
					default        { push @out, $_.'? try info,stop,next or prev' }
				}
			}
			\@out
		},
	};

1
