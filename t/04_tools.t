use Test::More tests=>15;
use 5.010;

BEGIN { use_ok('botaniko::tools'); }
use botaniko::tools;

# error
is(error('something'), undef);

# delay
is(delay(0), '0s');
is(delay(60), '1m 0s');
is(delay(61), '1m 1s');
is(delay(3600), '1h 0m 0s');
is(delay(3601), '1h 0m 1s');
is(delay(3660), '1h 1m 0s');
is(delay(3702), '1h 1m 42s');
is(delay(86400), '1 days 0h 0m 0s');
is(delay(86463), '1 days 0h 1m 3s');

# useragent
ok(useragent());

#admin
my $who  = 'me';
my $what = 'foo';
is(admin($who=>$what), $what);
is(admin($who), $what);

# pickone
srand(42);
my $arr = [1, 2, 3, 4, 5, 6];
my $el  = pickone($arr);
srand(42);
is(pickone($arr), $el);
