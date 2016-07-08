use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'dump.cgi' );
strict_ok( 'dump.cgi' );
warnings_ok( 'dump.cgi' );
