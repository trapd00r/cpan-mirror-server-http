package CPAN::Mirror::Server::HTTP;
BEGIN {
  $CPAN::Mirror::Server::HTTP::VERSION = '0.02';
}

#ABSTRACT: Simple HTTP server for serving a CPAN mirror

use strict;
use warnings;
use Cwd ();
use Pod::Usage;
use HTTP::Daemon;
use HTTP::Status;
use HTTP::Response;
use HTML::Tiny;
use File::Spec;
use MIME::Base64 qw[decode_base64];
use Number::Bytes::Human qw[format_bytes];
use POSIX qw[strftime :sys_wait_h];
use Getopt::Long;

my %icons_encoded = (
back =>
  'R0lGODlhFAAWAMIAAP///8z//5mZmWZmZjMzMwAAAAAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRo
  ZSBwdWJsaWMgZG9tYWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIg
  MTk5NQAh+QQBAAABACwAAAAAFAAWAAADSxi63P4jEPJqEDNTu6LO3PVpnDdOFnaCkHQGBTcqRRxu
  WG0v+5LrNUZQ8QPqeMakkaZsFihOpyDajMCoOoJAGNVWkt7QVfzokc+LBAA7',

blank =>
  'R0lGODlhFAAWAKEAAP///8z//wAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRoZSBwdWJsaWMgZG9t
  YWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIgMTk5NQAh+QQBAAAB
  ACwAAAAAFAAWAAACE4yPqcvtD6OctNqLs968+w+GSQEAOw==',

compressed =>
  'R0lGODlhFAAWAOcAAP//////zP//mf//Zv//M///AP/M///MzP/Mmf/MZv/MM//MAP+Z//+ZzP+Z
  mf+ZZv+ZM/+ZAP9m//9mzP9mmf9mZv9mM/9mAP8z//8zzP8zmf8zZv8zM/8zAP8A//8AzP8Amf8A
  Zv8AM/8AAMz//8z/zMz/mcz/Zsz/M8z/AMzM/8zMzMzMmczMZszMM8zMAMyZ/8yZzMyZmcyZZsyZ
  M8yZAMxm/8xmzMxmmcxmZsxmM8xmAMwz/8wzzMwzmcwzZswzM8wzAMwA/8wAzMwAmcwAZswAM8wA
  AJn//5n/zJn/mZn/Zpn/M5n/AJnM/5nMzJnMmZnMZpnMM5nMAJmZ/5mZzJmZmZmZZpmZM5mZAJlm
  /5lmzJlmmZlmZplmM5lmAJkz/5kzzJkzmZkzZpkzM5kzAJkA/5kAzJkAmZkAZpkAM5kAAGb//2b/
  zGb/mWb/Zmb/M2b/AGbM/2bMzGbMmWbMZmbMM2bMAGaZ/2aZzGaZmWaZZmaZM2aZAGZm/2ZmzGZm
  mWZmZmZmM2ZmAGYz/2YzzGYzmWYzZmYzM2YzAGYA/2YAzGYAmWYAZmYAM2YAADP//zP/zDP/mTP/
  ZjP/MzP/ADPM/zPMzDPMmTPMZjPMMzPMADOZ/zOZzDOZmTOZZjOZMzOZADNm/zNmzDNmmTNmZjNm
  MzNmADMz/zMzzDMzmTMzZjMzMzMzADMA/zMAzDMAmTMAZjMAMzMAAAD//wD/zAD/mQD/ZgD/MwD/
  AADM/wDMzADMmQDMZgDMMwDMAACZ/wCZzACZmQCZZgCZMwCZAABm/wBmzABmmQBmZgBmMwBmAAAz
  /wAzzAAzmQAzZgAzMwAzAAAA/wAAzAAAmQAAZgAAM+4AAN0AALsAAKoAAIgAAHcAAFUAAEQAACIA
  ABEAAADuAADdAAC7AACqAACIAAB3AABVAABEAAAiAAARAAAA7gAA3QAAuwAAqgAAiAAAdwAAVQAA
  RAAAIgAAEe7u7t3d3bu7u6qqqoiIiHd3d1VVVURERCIiIhEREQAAACH+TlRoaXMgYXJ0IGlzIGlu
  IHRoZSBwdWJsaWMgZG9tYWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1i
  ZXIgMTk5NQAh+QQBAAAkACwAAAAAFAAWAAAImQBJCCTBqmDBgQgTDmQFAABDVgojEmzI0KHEhBUr
  WrwoMGNDihwnAvjHiqRJjhX/qVz5D+VHAFZiWmmZ8BGHji9hxqTJ4ZFAmzc1vpxJgkPPn0Y5CP04
  M6lPEkCN5mxoJelRqFY5TM36NGrPqV67Op0KM6rYnkup/gMq1mdamC1tdn36lijUpwjr0pSoFyUr
  mTJLhiTBkqXCgAA7',

folder =>
  'R0lGODlhFAAWAMIAAP/////Mmcz//5lmMzMzMwAAAAAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRo
  ZSBwdWJsaWMgZG9tYWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIg
  MTk5NQAh+QQBAAACACwAAAAAFAAWAAADVCi63P4wyklZufjOErrvRcR9ZKYpxUB6aokGQyzHKxyO
  9RoTV54PPJyPBewNSUXhcWc8soJOIjTaSVJhVphWxd3CeILUbDwmgMPmtHrNIyxM8Iw7AQA7',

text =>
  'R0lGODlhFAAWAMIAAP///8z//5mZmTMzMwAAAAAAAAAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRo
  ZSBwdWJsaWMgZG9tYWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIg
  MTk5NQAh+QQBAAABACwAAAAAFAAWAAADWDi6vPEwDECrnSO+aTvPEddVIriN1wVxROtSxBDPJwq7
  bo23luALhJqt8gtKbrsXBSgcEo2spBLAPDp7UKT02bxWRdrp94rtbpdZMrrr/A5+8LhPFpHajQkA
  Ow==',

mkv =>
  'R0lGODlhEAAQAOf/AAAAAIAAAACAAICAAAAAgIAAgACAgMDAwMDcwKbK8AAAMzMAADMAMwAzMxYW
  FhwcHCIiIikpKVVVVU1NTUJCQjk5Of98gP9QUNYAk8zs/+/Wxufn1q2pkDP/AGYAAJkAAMwAAAAz
  ADMzAGYzAJkzAMwzAP8zAABmADNmAGZmAJlmAMxmAP9mAACZADOZAGaZAJmZAMyZAP+ZAADMADPM
  AGbMAJnMAMzMAP/MAGb/AJn/AMz/AAD/MzMA/2YAM5kAM8wAM/8AMwAz/zMzM2YzM5kzM8wzM/8z
  MwBmMzNmM2ZmM5lmM8xmM/9mMwCZMzOZM2aZM5mZM8yZM/+ZMwDMMzPMM2bMM5nMM8zMM//MMzP/
  M2b/M5n/M8z/M///MwAAZjMAZmYAZpkAZswAZv8AZgAzZjMzZmYzZpkzZswzZv8zZgBmZjNmZmZm
  ZplmZsxmZgCZZjOZZmaZZpmZZsyZZv+ZZgDMZjPMZpnMZszMZv/MZgD/ZjP/Zpn/Zsz/Zv8AzMwA
  /wCZmZkzmZkAmcwAmQAAmTMzmWYAmcwzmf8AmQBmmTNmmWYzmZlmmcxmmf8zmTOZmWaZmZmZmcyZ
  mf+ZmQDMmTPMmWbMZpnMmczMmf/MmQD/mTP/mWbMmZn/mcz/mf//mQAAzDMAmWYAzJkAzMwAzAAz
  mTMzzGYzzJkzzMwzzP8zzABmzDNmzGZmmZlmzMxmzP9mmQCZzDOZzGaZzJmZzMyZzP+ZzADMzDPM
  zGbMzJnMzMzMzP/MzAD/zDP/zGb/mZn/zMz/zP//zDMAzGYA/5kA/wAzzDMz/2Yz/5kz/8wz//8z
  /wBm/zNm/2ZmzJlm/8xm//9mzACZ/zOZ/2aZ/5mZ/8yZ//+Z/wDM/zPM/2bM/5nM/8zM///M/zP/
  /2b/zJn//8z///9mZmb/Zv//ZmZm//9m/2b//6UAIV9fX3d3d4aGhpaWlsvLy7KystfX193d3ePj
  4+rq6vHx8fj4+P/78KCgpICAgP8AAAD/AP//AAAA//8A/wD//////yH5BAEKAP8ALAAAAAAQABAA
  AAiyAP8JHEiwoMF/7+6xw3fv3UGBkg7E43XgnSR8B9/FE/hO3b15B9gVvAdvoDpX6ubNe7eOYLt7
  Hv/BvCcQXjtJAtt1RPlPpUyP93D+Y8drJj1JbeKdVBdS4Dpe8ugJxGdG3swDLe+tewfvnSuNKlVO
  FImPjc6lVj3Cgyfyn6tFbSTNlOcKJcWW/9iYMbPuXgJ48TreO+BKIBtITNq0Y3iAFy93iwfqNYMR
  YTt27F4+3DwwIAA7',

flv =>
  'R0lGODlhEAAQAMZuAEADEEIEEUQFEUYFEUkGEUsGEk0HEk8IElEIE1cHElcIElQJE1gIElkIE1YJ
  E1kJE2UGE1sJE1gKE1wJE1oKE2YHFF0KE14KE1wLEl8LE2kIFGoIE2ALE2wJFHAJFHEJFG4KFHML
  FHQLFHcLFHYMFXgNFXkNFXsNFX0OFXURGYMOFoQPFoMQFoIRFoQRFocRF48QGJAQGHMYIogTFo0U
  F5ITGJAVF40WGpUVGJIWF5oVGpcXGKAWG6IWG6YaG68cHqseH68dHq4eH7IgIrYjJrsjJb4nLLso
  LpoyNcEoLL0rM74sNcQsMsMtNsczP88yOsw0PpVFS805R5lITalGR9E7Sp1LT7xFRtM/UaFUWLdc
  XclcXbxgY7djZKRobs1gZbBydb1vcdRpcdpseM9zd9VyecF5e9d4fruAg8KIir6Qk9GLjsCQk9yO
  lv///////////////////////////////////////////////////////////////////////yH5
  BAEKAH8ALAAAAAAQABAAAAeVgH+Cg4SFhoeHS1JYVVBMRT88MIZKTmNtYl9bQz0xhkdNZ2VPSVdh
  NSsjhEJERmRrXFpdaC8nHoQ+QUBmVDs5N2woIhuEOjg2aUg0My1qKR0VgyosLS5gWVZTUV4yFRUQ
  gh8hJCUmJSQhIBre34Ic7xwZFxYTEQ8NDAoJghgUEg4LEBwwUIDAAAEBACBayLChw4eCAgEAOw==',

unknown =>
  'R0lGODlhFAAWAMIAAP///8z//5mZmTMzMwAAAAAAAAAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRo
  ZSBwdWJsaWMgZG9tYWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIg
  MTk5NQAh+QQBAAABACwAAAAAFAAWAAADaDi6vPEwDECrnSO+aTvPEQcIAmGaIrhR5XmKgMq1LkoM
  N7ECrjDWp52r0iPpJJ0KjUAq7SxLE+sI+9V8vycFiM0iLb2O80s8JcfVJJTaGYrZYPNby5Ov6Wol
  PD+XDJqAgSQ4EUCGQQEJADs=',
);

my @extension_icons = grep{!/(?:unknown|text|folder|compressed|blank|back)/}
  keys %icons_encoded;

my %icons = map { ( $_ => decode_base64( $icons_encoded{$_} ) ) }
              keys %icons_encoded;

my $index = 'index.html';

my $VERBOSE = $ENV{DEBUG};
sub run {
  my $root = Cwd::getcwd();
  my $port = '8080';

  GetOptions(
    'root:s'  => \$root,
    'port:i'  => \$port,
    'verbose' => \$VERBOSE,
  ) or pod2usage(2);

  local $SIG{CHLD};

  sub _REAPER {
    my $child;
    while (($child = waitpid(-1,WNOHANG)) > 0) {}
    $SIG{CHLD} = \&_REAPER; # still loathe SysV
  };

  $SIG{CHLD} = \&_REAPER;

  my $httpd = HTTP::Daemon->new( LocalPort => $port )
                or die "$!\n";

  while ( 1 ) {
    my $conn = $httpd->accept;
    next unless $conn;
    my $child = fork();
    unless ( defined $child ) {
      die "Cannot fork child: $!\n";
    }
    if ( $child == 0 ) {
      _handle_request( $conn, $root );
      exit(0);
    }
    $conn->close();
  }

}

sub _handle_request {
  my $conn = shift;
  my $root = shift;
  REQ: while (my $req = $conn->get_request) {
    if ($req->method eq 'GET' ) {
      # Special case /icons
      #TODO use the @extension_icons array here
      if ( my ($icon) = $req->uri->path =~ m{
          ^/icons/(back|blank|compressed|folder|unknown|mkv|flv)\.gif$
        }x ) {

        my $resp = _gen_icon( $icon );
        $conn->send_response( $resp );
        next REQ;
      }

      my @path = $req->uri->path_segments;
      my $path = File::Spec->catfile( $root, @path );


      if ( -d $path and $req->uri->path !~ m#/$# ) {
        my $resp = _gen_301( $req->uri );
        $conn->send_response( $resp );

        next REQ;
      }
      if ( -d $path and -e File::Spec->catfile( $path, $index ) ) {
        $path = File::Spec->catfile( $path, $index );
      }
      if ( -d $path ) {
        my $resp = _gen_dir( $req->uri, $path );
        $conn->send_response( $resp );
        next REQ;
      }
      unless ( -e $path ) {
        $conn->send_error(RC_NOT_FOUND);
        print "Not found: '$path'\n" if $VERBOSE;
        next REQ;
      }
      unless($path =~ m/favicon\.ico/) {
        print "\e[38;5;22m\e[1m      GET\e[0m: '$path'\n" if $VERBOSE;
      }
      $conn->send_file_response( $path );
    }
    else {
      $conn->send_error(RC_FORBIDDEN)
    }
  }
}

sub _gen_dir {
  my $uri  = shift;
  my $path = shift;
  my $resp = HTTP::Response->new( 200 );
  my %dir;

  {
    opendir my $DIR, $path or die "$!\n";

    $dir{ $_ } = [ ( stat( File::Spec->catfile( $path, $_ ) ) )[7,9],
                   ( -d File::Spec->catfile( $path, $_ ) ? 1 : 0 ),
                 ] for grep { !/^\./ } readdir $DIR;
  }

  my $h = HTML::Tiny->new;

  my @data;
  foreach my $item ( sort keys %dir ) {
    my $data = $dir{$item};
    push @data, [
      $h->td( { valign => 'top' },
        [ $h->img({ src => '/icons/' . _guess_type( $data->[2], $item ),
            alt => ( $data->[2] ? '[DIR]' : '[   ]' ) }) ],
        [ $h->a( { href => ( $data->[2] ? "$item/" : $item ) }, $item ) ],
        { align => 'right' },
        strftime("%d-%b-%Y %H:%M",localtime($data->[1])),
        { align => 'right' },
        format_bytes( $data->[0] ),
      ),
    ];
  }

  my $parent;

  {
    my @segs = split m#/#, $uri->path;
    if ( scalar @segs ) {
      pop @segs;
      if ( grep { $_ } @segs ) {
        $parent = join('/', @segs);
      }
      $parent .= '/';
    }
  }

  unshift @data,
    [ $h->td( { valign => 'top' },
      [ $h->img({ src => '/icons/back.gif', alt => '[DIR]' }) ],
      [ $h->a( { href => $parent }, 'Parent Directory' ) ],
      ' ',
      '  - ', )
    ]
    if $parent;

  my $html = $h->html(
    [
      $h->head( $h->title( 'Index of ' . $uri->path ) ),
      $h->body(
        [
          $h->h1( 'Index of ' . $uri->path ),
          $h->table(
            [
              $h->tr(
                [ $h->th( [ $h->img({ src => '/icons/blank.gif', alt => '[ICO]' }) ],
                                'Name', 'Last modified', 'Size' ) ],
                [ $h->th( { colspan => 4 }, [ $h->hr() ] ) ],
                @data,
                [ $h->th( { colspan => 4 }, [ $h->hr() ] ) ],
              ),
            ],
          ),
        ],
      ),
    ],
  );

  $resp->header( 'Content-Type', 'text/html' );
  $resp->content( $html );
  {
    use bytes;
    $resp->header( 'Content-Length', length $resp->content );
  }
  return $resp;
}

sub _gen_icon {
  my $icon = shift;
  my $resp = HTTP::Response->new( 200 );
  $resp->header( 'Content-Type', 'image/gif' );
  $resp->content( $icons{ $icon } );
  {
    use bytes;
    $resp->header( 'Content-Length', length $resp->content );
  }
  return $resp;
}

sub _guess_type {
  my $flag = shift;
  return 'folder.gif' if $flag;
  my $item = shift;
  return 'compressed.gif' if $item =~ m!(\.tar\.gz|\.tar\.bz2|\.tgz|\.zip)$!i;

  if( ($item =~ m|.+\.(.+)$|) and ($1 ~~ @extension_icons) ) {
    return "$1.gif";
  }
  return 'unknown.gif';
}

sub _gen_301 {
  my $uri = shift;
  my $resp = HTTP::Response->new( 301 );
  my $path = $uri->path . '/';
  my $h = HTML::Tiny->new();
  $resp->header( 'Location' => $path );
  $resp->header( 'Content-Type', 'text/html' );
  $resp->content(
     $h->html(
        [ $h->head( $h->title( '301' ) ),
          $h->body(
            [ $h->h1('Moved Permanently'), $h->p( [ 'The document has moved ', $h->a( { href => $path }, 'here' ) ] ), ]
          ),
        ] ),
  );
  {
    use bytes;
    $resp->header( 'Content-Length', length $resp->content );
  }
  return $resp;
}


1;

__END__

=pod

=head1 NAME

CPAN::Mirror::Server::HTTP - Simple HTTP server for serving a CPAN mirror

=head1 VERSION

version 0.02

=head1 SYNPOSIS

  #!/usr/bin/perl
  use strict;
  use warnings;
  use CPAN::Mirror::Server::HTTP;
  CPAN::Mirror::Server::HTTP->run();

=head2 C<run>

This method is called by L<cpanmirrorhttpd> to do all the work.

=head1 AUTHOR

Chris Williams <chris@bingosnet.co.uk>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Chris Williams.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

