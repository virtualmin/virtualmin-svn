use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'load.cgi' );
strict_ok( 'load.cgi' );
warnings_ok( 'load.cgi' );
