package botaniko::plugin::say;

use strict;
use warnings;
use 5.010;

use botaniko::command;
use botaniko::irc;

command
	say => {
		help => "say something",
		root => 1,
		bin => sub {
			my $chan = shift;
			my $msg = join(' ', @_);
			send_channel $chan => $msg;
			[];
		}
	};

1
