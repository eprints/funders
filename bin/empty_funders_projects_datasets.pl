#!/usr/bin/perl -w -I/opt/eprints3/perl_lib

use EPrints;
use strict;

my $repo = EPrints->new->repository( $ARGV[0] );
die "Usage: $0 [repoid]\n" if !defined $repo;

foreach( 'funder', 'project' )
{
print "Comment-out code to use that script (danger zone)\n";
#
#        $repo->dataset( $_ )->search()->map( sub { $_[2]->remove } );
}

