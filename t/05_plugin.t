use Test::More tests=>3;

BEGIN { use_ok('botaniko::plugin'); }
use botaniko::plugin;

is(plugins(), undef);
ok(!plugged('foo'));
