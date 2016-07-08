use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'list-svn-repositories.pl' );
strict_ok( 'list-svn-repositories.pl' );
warnings_ok( 'list-svn-repositories.pl' );
