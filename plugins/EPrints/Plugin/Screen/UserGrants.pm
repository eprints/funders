=head1 DESCRIPTION

Provides a link on the user's profile screen to manage their grants.

=cut

package EPrints::Plugin::Screen::UserGrants;

use base qw( EPrints::Plugin::Screen::Workflow );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new(%params);

	$self->{appears} = [
		{
			place => "user_view_actions",
			position => 200,
		}
	];
	
	return $self;
}

sub can_be_viewed
{
	my( $self ) = @_;

	my $user = $self->repository->current_user or return 0;

        my $onbehalfof = $self->{processor}{dataobj};

        if( defined $onbehalfof )
        {               
                # local look-up if person is allowed?
                # i bet every institution will have different requirements for that....
                        
                my $allow_fn = $self->param( 'allow_on_behalf_of' );
                if( !defined $allow_fn || ref( $allow_fn ) ne 'CODE' )
                {
                        return 0;
                }

                my $rc = &$allow_fn( $self, $user, $onbehalfof ) || 0;
                return $rc;
        }

	return 0;
}

sub from
{
	my ($self) = @_;

	my $url = $self->repository->current_url();
	$url->query_form(
		screen => "Grants",
		userid => $self->{processor}{dataobj}->id,
	);

	$self->{processor}{redirect} = $url;
}

1;
