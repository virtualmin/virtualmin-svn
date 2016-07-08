use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_anon.cgi' );
strict_ok( 'edit_anon.cgi' );
warnings_ok( 'edit_anon.cgi' );
