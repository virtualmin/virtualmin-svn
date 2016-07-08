use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'delete-svn-repository.pl' );
strict_ok( 'delete-svn-repository.pl' );
warnings_ok( 'delete-svn-repository.pl' );
