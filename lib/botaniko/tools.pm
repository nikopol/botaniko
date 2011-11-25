package botaniko::tools;

use strict;
use warnings;
use 5.010;

use LWP::UserAgent;
use botaniko::logger;
use botaniko::config;

use base 'Exporter';
our @EXPORT = qw(admin error delay useragent record pickone trunc getoptions);

sub error {
	$@ = shift;
	trace ERROR => $@;
	undef
}

sub delay {
	my $z = shift;
	my $d = int( $z / (24*60*60) ); $z -= $d*24*60*60; 
	my $h = int( $z / (60*60) );    $z -= $h*60*60; 
	my $m = int( $z / 60 );         $z -= $m*60;
	$d ? sprintf('%d days %dh %dm %ds', $d, $h, $m, $z) :
	$h ? sprintf('%dh %dm %ds', $h, $m, $z) :
	$m ? sprintf('%dm %ds', $m, $z) :
	sprintf('%ds', $z)
}

sub record {
	my( $k, $v, $n ) = @_;
	my $key = 'records.'.$k;
	if( my $r = cfg($key) ) {
		if( $r->{score} < $v ) {
			my $p = 'new record! (was '.$r->{name}.' with '.delay($r->{score}).')';
			cfg $key=>{ name=>$n, score=>$v };
			return $p;
		}
	} else {
		cfg $key=>{ name=>$n, score=>$v };
	}
	''
}

sub useragent {
	state $ua;
	unless( $ua ) {
		my $opt = cfg('lwp') || {
			agent   => 'Bot4Niko/'.$botaniko::VERSION,
			timeout => 10,
		};
		$ua = LWP::UserAgent->new( %$opt );
	}
	$ua
}

sub admin {
	my( $who, $flag ) = @_;
	state $admins = {};
	$admins->{$who} = $flag if defined $flag;
	$admins->{$who}
}

sub pickone { $_[ int(rand(scalar @_)) ] }

sub trunc {
	my( $out, $max ) = @_;
	$max = 5 if !$max || $max<1 || $max>10;
	my $count = scalar @$out;
	$out = [
		splice( @$out, 0, $max ),
		"...truncated from $count lines"
	] if $count > $max;
	$out
}

sub getoptions {
	my $prm = shift;
	$prm = [ grep { length $_ } map { s/(^\s+|\s+$)//g; $_ } @$prm ];
	my @opt;
	while( @_ ) {
		my($o,$v) = (shift,shift);
		if( my @found = grep { /^$o=/ } @$prm ) {
			$prm = [ grep { $_ !~ /^$o=/ } @$prm ];
			@found = map { s/^$o=//; $_ } @found;
			push @opt, $found[0];
		} else {
			push @opt, $v;
		}
	}
	( $prm, @opt )
}

1
