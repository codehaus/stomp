#!/usr/local/bin/perl
use strict;

package Stomp::Error;
use base qw( Stomp::Message );

sub new { 
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  bless $self, $class;
  $self->_init(@_);

  return $self;
}
1;
