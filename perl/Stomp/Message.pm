#!/usr/local/bin/perl
use strict;
package Stomp::Message;
sub new { 
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  bless $self, $class;
  $self->_init(@_);

  return $self;
}
sub _init($@) {
	my $self = shift;
    my $lines = shift;
    my @lines = @$lines;

    # put the headers in their own fields
    #
    my $line = shift @lines;
    while (defined($line) and $line ne "" ) {
#        print STDERR      join("\n",@lines),"\n";
        if ($line =~ /(.*?):(.*)/ ) {
            $self->{$1} = $2;
#            print "$1 -> $2\n";
        }
        else {
            print STDERR "MISMATCH $line\n";
        }
        $line = shift @lines;
#            print STDERR "X$line\n";
    }
    if (@lines >0 ) {
        # ok .. if we are here we are the line above the body.
        my $body = join("\n", @lines );
        $self->{"body"}=$body;
    }

    return $self;
} 

sub body($) 
{
    my $self = shift;
    return $self->{"body"};
}
sub header($$) 
{
    my $self = shift;
    my $name = shift;
    return $self->{$name};
}


1;
