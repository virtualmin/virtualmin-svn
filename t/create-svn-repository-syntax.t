use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'create-svn-repository.pl' );
strict_ok( 'create-svn-repository.pl' );
warnings_ok( 'create-svn-repository.pl' );
