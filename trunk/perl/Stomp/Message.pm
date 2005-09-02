#!/usr/local/bin/perl
#
# Copyright 2005 Zilbo.com
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# $Revision:$
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
