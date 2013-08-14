use Test::More tests => 26;
use 5.010;

BEGIN { use_ok('botaniko::tools'); }
use botaniko::tools;
use botaniko::config;

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

# record
cfg 'records.foo' => {score => 42, name => 'Foo'};
ok(record('foo', 43, 'Foo') =~ /^new record/i);
is(record('foo', 43, 'Foo'), '');

# useragent
cfg('lwp.agent' => 'Test');
is(useragent()->agent, 'Test');

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

# trunc
my $lines = [1, 2, 3, 4, 5];
is(scalar @{trunc($lines, 2)}, 3);
is(trunc($lines, 2)->[-1], '...truncated from 3 lines');
my $longlines = [ 'a' x 140 ];
ok(trunc($longlines, 2)->[0] =~ /^a+\.\.\.$/);

# getoptions
my ($qry) = getoptions(['foo'], {});
is_deeply($qry, ['foo']);
my ($qry, $bar) = getoptions(['foo'],
    bar => 42
);
is_deeply($qry, ['foo']);
is($bar, 42);
($qry, $bar) = getoptions(['foo', 'bar=21'],
    bar => 42
);
is_deeply($qry, ['foo']);
is($bar, 21);
($qry, $bar) = getoptions(['foo', 'bar=21', 'qux'],
    bar => 42
);
is_deeply($qry, ['foo', 'qux']);
