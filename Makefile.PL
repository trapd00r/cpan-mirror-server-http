
use strict;
use warnings;

BEGIN { require v5.8.8; }

use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Simple HTTP server for serving a CPAN mirror',
  'AUTHOR' => 'Chris Williams <chris@bingosnet.co.uk>',
  'BUILD_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.42',
    'Test::More' => '0.47'
  },
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.42'
  },
  'DISTNAME' => 'CPAN-Mirror-Server-HTTP',
  'EXE_FILES' => [
    'bin/cpanmirrorhttpd'
  ],
  'LICENSE' => 'perl',
  'NAME' => 'CPAN::Mirror::Server::HTTP',
  'PREREQ_PM' => {
    'File::LsColor' => '0',
    'File::Spec' => '3.12',
    'Getopt::Long' => '2.35',
    'HTML::Tiny' => '1.05',
    'HTTP::Daemon' => '5.827',
    'HTTP::Response' => '0',
    'HTTP::Status' => '0',
    'MIME::Base64' => '3.07',
    'Number::Bytes::Human' => '0.07',
    'Pod::Usage' => '1.33'
  },
  'VERSION' => '0.02',
  'test' => {
    'TESTS' => 't/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



