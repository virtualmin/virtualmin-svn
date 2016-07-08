use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'commit-email.pl' );
strict_ok( 'commit-email.pl' );
warnings_ok( 'commit-email.pl' );
