use inc::Module::Install;

name 'botaniko';
all_from 'lib/botaniko.pm';

#core
requires( 'Digest::SHA1' );
requires( 'AnyEvent' );
requires( 'ElasticSearch' );
requires( 'YAML::XS' );
requires( 'AnyEvent::IRC::Client' );
requires( 'Class::Unload' );
requires( 'LWP::UserAgent' );
requires( 'Getopt::Long' );

#plugins
requires( 'Net::Twitter' );
requires( 'HTTP::Request' );
requires( 'HTML::Entities' );
requires( 'URI::Escape' );
requires( 'JSON::XS' );
requires( 'DateTime::Format::Strptime' );

#tests 't/*.t';
#author_tests 'xt';

install_script 'bin/botaniko';

#build_requires 'Test::More';
build_requires 'Module::Install';

use_test_base;
auto_include;
WriteAll;
