#!/usr/bin/perl -w -I/opt/eprints3/perl_lib

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../perl_lib";
use EPrints;

######################################################################
#
#
######################################################################

=pod

=head1 NAME

B<projects_for_eprints_report.pl> - Report EPrints that issues with associated projects.

=head1 SYNOPSIS

B<projects_for_eprints_report.pl> - I<repository_id> I<username> [B<options>]

=head1 DESCRIPTION

Report EPrints in the live archive or review buffer that have no project set but do not explicitly state they have no associated projects.

This script will:

  - search the live archive or review buffer for EPrints that have no project set but do not explicitly state they have no associated project.
  - send an email to all admins/editors that are setup to receive email alerts with this list of EPrints.

Note that this considers the date to be the local date, not the UTC date.

=head1 ARGUMENTS

=over 8

=item B<repository_id> 

The ID of the EPrint repository to search.

=item B<username> 

Optionally, the username who should have the report sent to their email address.

=back

=head1 OPTIONS

=over 8

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print the full manual page and then exit.

=item B<--quiet>

This option does not do anything.

=item B<--verbose>

Explain in detail what is going on. May be repeated for greater effect.

=item B<--version>

Output version information and exit.

=back   


=cut

use EPrints;
use Getopt::Long;
use Pod::Usage;
use strict;

my $version = 0;
my $verbose = 0;
my $quiet = 0;
my $help = 0;
my $man = 0;

Getopt::Long::Configure("permute");

GetOptions( 
	'help|?' => \$help,
	'man' => \$man,
	'version' => \$version,
	'verbose+' => \$verbose,
	'silent' => \$quiet,
	'quiet' => \$quiet
) || pod2usage( 2 );
EPrints::Utils::cmd_version( "projects_for_eprints_report" ) if $version;
pod2usage( 1 ) if $help;
pod2usage( -exitstatus => 0, -verbose => 2 ) if $man;
pod2usage( 2 ) if( scalar @ARGV > 2 || scalar @ARGV < 1 ); 

our $noise = 1;
$noise = 0 if( $quiet );
$noise = 1+$verbose if( $verbose );

# Set STDOUT to auto flush (without needing a \n)
$|=1;

my $repoid = $ARGV[0];
my $session = new EPrints::Session( 1 , $repoid , $noise );
if( !defined $session )
{
	print STDERR "Failed to load repository: $repoid\n";
	exit 1;
}
my $repository = $session->get_repository;
my $user;
if ( defined $ARGV[1] ) 
{
	my $username = $ARGV[1];
	$user = $repository->user_by_username( $username );
	if( !defined $user )
	{
        	print STDERR "Failed to find user with username: $username\n";
        	exit 1;
	}
	elsif ( !defined $user->get_value( 'email' ) )
	{
		print STDERR "Failed to find email address for user with username: $username\n";
                exit 1;
	}
}
 
my $ds = $session->dataset( "eprint" );

# Search for EPrints 
my $searchexp = new EPrints::Search( 
		session=>$session, 
		dataset=>$ds );

my $date = sprintf("-%04d-%02d-%02d", EPrints::Time::utc_datetime() );
$searchexp->add_field(
        fields => [ 
		$ds->field('eprint_status'),
	],
        value => "archive buffer", 
        match => "IN",
);


my $list = $searchexp->perform_search;

my $unknown_projects_counter = 0;
my $no_funded_projects_counter = 0;
my $unknown_projects_text = $session->make_doc_fragment;
$list->map( sub {
	my( $session, $dataset, $eprint ) = @_;
	if ( EPrints::Utils::is_set( $eprint->get_value( 'unknown_project' ) ) )
	{
		my $p = $session->make_element( "p" );
                $p->appendChild( $eprint->render_citation_link_staff );
		my $reason = $session->make_element( "em" );
		$p->appendChild($session->make_element( "br" ));
		my $reasonlabel = $session->make_element( "b" );
                $reasonlabel->appendText("Reason: ");
		$reason->appendChild($reasonlabel);
		$reason->appendText($eprint->get_value( 'unknown_project' ));
		$p->appendChild( $reason );
 		$unknown_projects_text->appendChild( $p );
		$unknown_projects_counter++;
	}
	elsif ( ( !EPrints::Utils::is_set($eprint->get_value( 'nofunding' )) || $eprint->get_value( 'nofunding' ) eq "FALSE" ) && !EPrints::Utils::is_set($eprint->get_value( 'projects' ) ) )
	{
		$no_funded_projects_counter++;
	}
} );

my $unknown_projects_counter_text = $session->make_element( "em" ); 
$unknown_projects_counter_text->appendText($unknown_projects_counter);
my $no_funded_projects_counter_text = $session->make_element( "em" ); 
$no_funded_projects_counter_text->appendText($no_funded_projects_counter);

my $mail = $session->html_phrase(
	"bin/projects_for_eprints_report:mail_body",
       	unknown_projects_counter => $unknown_projects_counter_text,
	no_funded_projects_counter => $no_funded_projects_counter_text,
	unknown_projects_text => $unknown_projects_text,
);

if ( defined $user ) 
{
	$user->mail(
		"bin/projects_for_eprints_report:mail_subject",
         	$mail 
	);

	EPrints::XML::dispose( $mail );
}
else
{
	my $email = $repository->config( "adminemail" );
	my $langid = $repository->config( "defaultlanguage" );
	my $lang = $repository->get_language( $langid ); 
	EPrints::Email::send_mail(
                session  => $session,
                langid   => $langid,
                to_name  => $email,
                to_email => $email,
                subject  => EPrints::Utils::tree_to_utf8( $lang->phrase( "bin/projects_for_eprints_report:mail_subject", {}, $session ) ),
                message  => $mail,
                sig      => $lang->phrase( "mail_sig", {}, $session ),
        );	
	
}


$session->terminate();


=head1 COPYRIGHT

=for COPYRIGHT BEGIN

Copyright 2000-2015 University of Southampton.

=for COPYRIGHT END

=for LICENSE BEGIN

This file is part of EPrints L<http://www.eprints.org/>.

EPrints is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EPrints is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

You should have received a copy of the GNU General Public License
along with EPrints.  If not, see L<http://www.gnu.org/licenses/>.

=for LICENSE END

