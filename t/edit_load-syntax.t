use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_load.cgi' );
strict_ok( 'edit_load.cgi' );
warnings_ok( 'edit_load.cgi' );
