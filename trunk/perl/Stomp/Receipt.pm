#!/usr/local/bin/perl
use strict;

package Stomp::Receipt;
use base qw( Stomp::Message );

sub new { 
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  bless $self, $class;
  $self->_init(@_);

  return $self;
}

sub id 
{
    my $self=shift;
    return $self->header("receipt-id");
}
1;
