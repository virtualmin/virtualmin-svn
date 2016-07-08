use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_dump.cgi' );
strict_ok( 'edit_dump.cgi' );
warnings_ok( 'edit_dump.cgi' );
