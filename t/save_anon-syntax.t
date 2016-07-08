use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_anon.cgi' );
strict_ok( 'save_anon.cgi' );
warnings_ok( 'save_anon.cgi' );
