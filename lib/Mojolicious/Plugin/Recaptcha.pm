package Mojolicious::Plugin::Recaptcha;

use strict;
use Mojo::ByteStream;

use base 'Mojolicious::Plugin';
our $VERSION = '0.31';

sub register {
	my ($self,$app,$conf) = @_;
	
	$conf->{'lang'} ||= 'en';
	
	$app->renderer->add_helper(
		recaptcha_html => sub {
			my $self = shift;
			my ($error) = map { $_ ? "&error=$_" : "" } $self->stash('recaptcha_error');
			return Mojo::ByteStream->new(<<HTML);
  <script type="text/javascript">
var RecaptchaOptions = {
   lang : '$conf->{lang}',
};
</script>
  <script type="text/javascript"
     src="http://www.google.com/recaptcha/api/challenge?k=$conf->{public_key}$error">
  </script>
  <noscript>
     <iframe src="http://www.google.com/recaptcha/api/noscript?k=$conf->{public_key}"
         height="300" width="500" frameborder="0"></iframe><br>
     <textarea name="recaptcha_challenge_field" rows="3" cols="40">
     </textarea>
     <input type="hidden" name="recaptcha_response_field"
         value="manual_challenge">
  </noscript>
HTML

		},
	);
	$app->renderer->add_helper(
		recaptcha => sub {
			my ($self,$cb) = @_;
			
			my @post_data = (
				'http://www.google.com/recaptcha/api/verify',
				{ 
					privatekey => $conf->{'private_key'},
					remoteip   => 
						$self->req->headers->header('X-Real-IP')
						 ||
						$self->tx->{remote_address},
					challenge  => $self->req->param('recaptcha_challenge_field'),
					response   => $self->req->param('recaptcha_response_field')
				}
			);
			my $callback = sub {
				my $content = $_[1]->res->to_string;
				my $result = $content =~ /true/;
				
				$self->stash(recaptcha_error => $content =~ m{false\s*(.*)$}si)
					unless $result
				;
				$cb->($result) if $cb;
				return $result;
			};
			
			if ($cb) {
				$self->ua->post_form(
					@post_data,
					$callback,
				);
			} else {
				my $tx = $self->ua->post_form(@post_data);
				
				return $callback->('',$tx);
			}
		}
	);
}

1;

=head1 NAME

Mojolicious::Plugin::Recaptcha - ReCaptcha plugin for Mojolicious framework

=head1 VERSION

0.31

=head1 SYNOPSIS

   # Mojolicious::Lite
   plugin recaptcha => { 
      public_key  => '...', 
      private_key => '...',
      lang        => 'ru' 
   };
   
   # Mojolicious
   $self->plugin(recaptcha => { 
      public_key  => '...', 
      private_key => '...',
      lang        => 'ru'
   });
   
   # template 
   <form action="" method="post">
      <%= recaptcha_html %>
      <input type="submit" value="submit" name="submit" />
   </form>
   
   # checking blocking way
   $self->recaptcha;
   unless ($self->stash('recaptcha_error')) {
      # all ok
   }
   
   # checking non-blocking way
   $self->render_later;
   $self->recaptcha(sub {
      my $ok = shift;
      if ($ok) {
       
      } else {
         warn $self->stash('recaptcha_error');
      }
      # here you need call render
      $self->render;
   })

=head1 Internationalisation support

=over 4

=item * English by default (en)

=item * Dutch (nl)

=item * French (fr)

=item * German (de)

=item * Portuguese (pt)

=item * Russian (ru)

=item * Spanish (es)

=item * Turkish (tr)

=back

=head1 SUPPORT

=over 4

=item * Repository

L<http://github.com/konstantinov/Mojolicious-Plugin-Recaptcha>

=back

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Plugin>, L<Mojolicious::Lite>

=head1 THANKS

Special thanks for help in development

=over 2

Alexander Voronov

=back

=head1 COPYRIGHT & LICENSE

Copyright 2010-2011 Dmitry Konstantinov. All right reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.