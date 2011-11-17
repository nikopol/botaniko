package botaniko::logger;

use strict;
use warnings;
use 5.010;
use POSIX 'strftime';
use Encode;
use YAML::XS;

use botaniko::config;

use base 'Exporter';
our @EXPORT = qw(trace);

sub trace {
	my( $level, $msg ) = @_;
	state $LEVELS = {
		ERROR   => 0,
		WARN    => 1,
		WARNING => 1,
		NOTICE  => 2,
		INFO    => 3,
		TWEET   => 4,
		DEBUG   => 5,
	};
	state $COLORS = {
		RESET   => "\e[0m",
		ERROR   => "\e[31m",
		DEBUG   => "\e[90m",
		TWEET   => "\e[34m",
		NOTICE  => "\e[93m",
		INFO    => "\e[37m",
		WARN    => "\e[95m",
		WARNING => "\e[95m",
	};
	printf( "%s|%s%-6s%s|%s%s%s\n",
		strftime("%H%M%S",localtime(time)),
		$COLORS->{$level}, $level, $COLORS->{RESET},
		$COLORS->{$level}, ref($msg) ? Dump $msg : encode_utf8($msg)||'', $COLORS->{RESET}
	) if $LEVELS->{$level} <= $LEVELS->{cfg 'loglevel'};
	0
}

1
