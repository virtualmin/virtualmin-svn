use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_email.cgi' );
strict_ok( 'edit_email.cgi' );
warnings_ok( 'edit_email.cgi' );
