package Catalyst::Plugin::ExternalURI;

use Moose::Role;
use namespace::autoclean;

our $VERSION = '0.01';

use Regexp::Common qw /URI/;
use Regexp::Common::URI::RFC2396 qw /$host $port $path_segments/;

#has _config => ( is => 'rw' );

sub _get_changes_for_uri {
  my $c = shift;
  my $url = shift;

  if ($url =~ m/$RE{URI}{HTTP}{-scheme => '(?:https?|)'}{-keep}/){
    my ($uscheme, $uhost, $uport, $upath, $uquery) = ($2, $3, $4, $7, $8);

    # Strip trailing slash on upath (since it gets concatenated with the 
    # path from the URI (that always starts with slash, it's not needed
    $upath =~ s/\/$//s if (defined $upath);

    return { (defined $uscheme and $uscheme ne '')?(scheme => $uscheme):(),
             (defined $uhost)?(host => $uhost):(),
             (defined $uport)?(port => $uport):(),
             (defined $upath and $upath ne '')?(path => "/$upath"):(),
             (defined $uquery)?(query => $uquery):(),
    };
  } elsif ($url =~ m/^(https?):\/\//) {
    return { scheme => $1 };
  } elsif ($url =~ m/^($host)(?::($port))?/) {
    my ($uhost, $uport) = ($1, $2);
    return { (defined $uhost)?(host => $uhost):(),
             (defined $uport)?(port => $uport):(),
    };
  } elsif ($url =~ m/^\/($path_segments)/){
      my $upath = $1;
      return { 
          path => "/$upath"
      }
  } else {
       die "Can't recognize translation for $url";
  }
}

around uri_for => sub {
  my ( $orig, $c, $path, @args ) = @_;

  my $config = $c->config->{externaluri};

  my $uri = $c->$orig($path, @args);

  foreach my $rule (@$config){
    my ($match, $rewrite, $continue) = (undef, undef, 0);

    $match = (exists $rule->{ match }) ? $rule->{ match } : (keys %$rule)[0] ;
    $rewrite = (exists $rule->{ rewrite }) ? $rule->{ rewrite } : (values %$rule)[0] ;
    $continue = $rule->{ continue } if (exists $rule->{ continue });

    if ($path =~ m/$match/){
      my $changes = $c->_get_changes_for_uri($rewrite);
      $uri->scheme($changes->{ scheme }) if (defined $changes->{ scheme });
      $uri->host($changes->{ host }) if (defined $changes->{ host });
      $uri->port($changes->{ port }) if (defined $changes->{ port });
      $uri->path($changes->{ path } . $uri->path) if (defined $changes->{ path });
    
      last if (not $continue);
    }
  }

  return $uri;
};

=head1 NAME

Catalyst::Plugin::ExternalURI - Rewrite URLs generated with uri_for

=head1 VERSION

Version 0.001

=head1 SYNOPSIS

Include ExternalURI in your Catalyst Plugin list to activate it

In MyApp.pm

    use Catalyst qw/ ... ExternalURI ... /;

In MyApps configuration:

    __PACKAGE__->config(
        externaluri => [
            # Converts urls with the form of /static/css to start with another domain name 
            { '^/static' => 'http://static.mydomain.com' },
            ...
            { 'MATCH' => 'REWRITE' }
            or
            { match => '^/static', rewrite => 'http://static.mydomain.com' },
        ]
    );

=head1 DESCRIPTION

This plugin helps you rewrite the URLs generated by C<< uri_for >> (and C<< uri_for_action >>) 
so they can point to different domains (not necesarily hosted by your application).

=head1 USE CASES

=head2 Enable static content to be hosted in external services

If you upload your resources to services like Amazon S3, CloudFiles, or CDNs
you can easily change the appropiate urls in your application to point to the resources
on that provider.

  { '^/static/' => 'http://yours3bucket.s3.amazonaws.com/' }

  # $c->uri_for('/static/css/main.css') gets converted into
  # http://yours3bucket.s3.amazonaws.com/static/css/main.css

=head2 Enable parallel download of resources

Since your pages now point to various domains, your browser will open parallel connections
to those domains (enabling faster pages loads). Try splitting images, js and css to load from 
different domains.

  { '^/static/css/' => 'http://css.myapp.com/' },
  { '^/static/js/'  => 'http://js.myapp.com/' },

  # $c->uri_for('/static/css/main.css') gets converted into
  # http://css.myapp.com/static/css/main.css
  # $c->uri_for('/static/js/framework.js') gets converted into
  # http://js.myapp.com/static/js/framework.js

=head2 Avoid cache problems

You can prefix a version number to all your static URLs. That way, when you deploy, you can
point all your static contents to fresh, new, uncached versions of your files.

  { '^/static' => 'http://js.mydomain.com/v1' }

  # $c->uri_for('/static/js/framework.js') gets converted into
  # http://js.myapp.com/v1/static/js/framework.js

=head1 Configuration

The C<externaluri> key of the configuration has to contain an ARRAY of RULES. Each call to 
uri_for will evaluate the RULES in the configuration of the plugin. 

Each rule is a hashref that has the form of:

  { 'REGEX' => 'REWRITE' }

or

  { match => 'REGEX', rewrite => 'REWRITE' [, continue => 1 ] }

Each rules match is evaluated against the uri that is passed to C<uri_for>. When a key matches 
the uri, the REWRITE gets applied, and evaluation of rules is interrupted, unless stated in the rule
with a C<continue> key with a value of 1.

REWRITE rules force specific portions of a url to their specification:

C<https://> Forces the scheme part of the URL to be https. All other elements are unchanged

C<http://mydomain.com> Will force the scheme to http, and the host part of the URL to mydomain.com

C</v3> Will force a prefix in the path of the URL

C<http://mybucket.s3.amazonaws.com/v1> Will force scheme to http, change the host, and prefix the
URI part with /v1

=head1 CAVEAT

=head2 Be specific with your matches

C<'/static'> will match uris like C<'/im/not/static'>. This is supported, but it may not be
what you meant to do. You probably meant C<'^/static'>

=head1 AUTHOR

Jose Luis Martinez (JLMARTIN)

Miquel Ruiz (MRUIZ)

=head1 COPYRIGHT

=cut

1;
