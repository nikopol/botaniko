package botaniko::config;

use strict;
use warnings;
use 5.010;

use botaniko::file;

use base 'Exporter';
our @EXPORT = qw(cfg chancfg loadcfg cfg_default chancfg_default set_chan_default flatcfg);

my $cfgfile = 'botaniko.yml';
my $cfg = {
	server     => { host => 'irc.freenode.net', port => 6667 },
	nick       => 'bot4nik',
	loglevel   => 'INFO',
	mute       => 0,
	passphrase => '9b77f2db9bfb3ddbbd9267f9cc3ea2c28a5b9234',
	lwp        => { timeout => 20, agent => 'B0T4NiK/0.4' },
	autoload   => [],
	autojoin   => [],
	db         => {
		servers      => '127.0.0.1:9200',
		transport    => 'http',
		max_requests => 10_000,
		trace_calls  => 0,
		no_refresh   => 0,
	},
};
my %chandft;

sub cfg {
	return $cfg unless @_;
	my @tree = split /\./, $_[0];
	my $key = pop @tree;
	my $b = $cfg;
	for( @tree ) {
		if( !exists $b->{$_} ) {
			return undef unless @_ > 1;
			$b->{$_} = {};
		}
		$b = $b->{$_};
	}
	if( @_ > 1 ) {
		$b->{$key} = $_[1];
		file($cfgfile => $cfg) unless $_[2];
	}
	$b->{$key}
}

sub chancfg {
	my( $chan, $key ) = ( shift, shift );
	$chan =~ s/^#//;
	cfg( "channels.$chan.$key", @_ )
}

sub loadcfg {
	my %prm = @_;
	if( my $file = delete $prm{config} ) {
		$cfgfile = $file;
	}
	$cfg = file( $cfgfile ) if -r $cfgfile;
	for( keys %prm ) {
		cfg($_=>$prm{$_},1) if defined $prm{$_}
	}
	file $cfgfile => $cfg
}

sub cfg_default {
	my( $key, $val ) = @_;
	cfg( $key=>$val ) unless defined cfg $key;
}

sub set_chan_default {
	my $chans = shift;
	$chans = [ $chans ] unless ref($chans) eq 'ARRAY';
	for my $c ( @$chans ) {
		$c =~ s/^#//;
		for my $d ( keys %chandft ) {
			my $k = "channels.$c.$d";
			cfg( $k => { %{$chandft{$d}} } ) unless defined cfg $k;
		}
	}
}

sub chancfg_default {
	my( $key, $val ) = @_;
	$chandft{$key} = $val;
	set_chan_default [ botaniko::irc::channels() ]
}

sub flatcfg {
	my($tree,$pfx,$flat) = @_;
	unless( defined $tree ) {
		$tree = $cfg;
		$pfx  = '';
		$flat = {};
	}
	for( keys %$tree ) {
		if( ref($tree->{$_}) eq 'ARRAY' )   { $flat->{"$pfx$_"} = join(',',@{$tree->{$_}}) }
		elsif( ref($tree->{$_}) eq 'HASH' ) { $flat = flatcfg( $tree->{$_}, "$pfx$_.", $flat ) }
		else                                { $flat->{"$pfx$_"} = defined $tree->{$_} ? "$tree->{$_}" : 'undefined' }
	}
	$flat
}

1
