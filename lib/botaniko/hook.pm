package botaniko::hook;

use Modern::Perl;

use botaniko::logger;

use base 'Exporter';
our @EXPORT = qw(hook fire);

my %hooks;

# CONNECT    $cnx
# DISCONNECT $cnx
# MSG        $msg,$user,$from,$chan
# JOIN       $chan
# QUIT       $chan
# USERJOIN   $user,$chan
# USERQUIT   $user,$msg
# NICKCHANGE $old,$new
# TWEET      $msg,$user
# TOTWEET    $msg

sub hook {
	my( $hook, $sub ) = @_;
	$hooks{$hook} = [] unless defined $hooks{$hook};
	my $plug = $botaniko::plugin::PLUGNAME;
	trace DEBUG=>'adding hook '.$hook.' for '.$plug;
	push @{$hooks{$hook}}, {
		plugin => $plug,
		bin    => $sub,
	}
}

sub unhook {
	my $plug = shift;
	for my $hook ( keys %hooks ) {
		$hooks{$hook} = [ grep {
			$_->{plugin} eq $plug
				? trace DEBUG=>"remove hook $hook for $plug"
				: 1
		} @{$hooks{$hook}} ];
	}
}

sub fire {
	my $hooks = shift;
	my @prm   = @_;
	$hooks = [ $hooks ] unless ref($hooks) eq 'ARRAY'; 
	my @out;
	for my $hook ( @$hooks ) {
		if( $hooks{$hook} ) {
			for( @{$hooks{$hook}} ) {
				my $sub = $_->{bin};
				push @out, &$sub( @prm );
			}
		}
	}
	@out
}

1
