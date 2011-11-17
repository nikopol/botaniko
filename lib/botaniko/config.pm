package botaniko::config;

use strict;
use warnings;
use 5.010;

use botaniko::file;

use base 'Exporter';
our @EXPORT = qw(cfg loadcfg cfg_default flatcfg);

my $cfgfile = 'botaniko.yml';
my $cfg = {
	server     => { host => 'irc.freenode.net', port => 6667 },
	nick       => 'bot4nik',
	channels   => [ 'botaniko' ],
	loglevel   => 'INFO',
	mute       => 0,
	passphrase => '9b77f2db9bfb3ddbbd9267f9cc3ea2c28a5b9234',
	lwp        => { timeout => 20, agent => 'B0T4NiK/0.1' },
	autoload   => [],
	db         => {
		servers      => '127.0.0.1:9200',
		transport    => 'http',
		max_requests => 10_000,
		trace_calls  => 0,
		no_refresh   => 0,
	},
};

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
		else                                { $flat->{"$pfx$_"} = "$tree->{$_}" }
	}
	$flat
}

1
