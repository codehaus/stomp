#!/usr/local/bin/perl
use strict;
use IO::Socket::INET;
use Stomp::Message;
use Stomp::Receipt;
use Stomp::Error;

package Stomp::Connection;
sub new { 
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {};

  bless $self, $class;
  $self->_init(@_);

  return $self;
}
sub _init($%) {
	my $self = shift;
    my(%parameters) = @_;
    foreach (keys %parameters ) {
        $self->{$_} = $parameters{$_};
    }
    $self->_connect();
    $self->{"pending"}="";
    $self->Connect( $self->{"login"}, $self->{"passcode"});
    
} 
 
#
# Socket Connection
# 
sub _connect 
{
	my $self = shift;
    my(%parameters) = @_;
    foreach (keys %parameters ) {
        $self->{$_} = $parameters{$_};
    }
    $self->{"host"} ||= "localhost";
    $self->{"port"} ||= 61613;
    my $socket = IO::Socket::INET->new( PeerAddr=> $self->{"host"}, PeerPort=> $self->{"port"}, Proto=>"tcp", Blocking =>1 );

    die "connection error " unless (defined($socket));
    binmode($socket);
    $self->{"socket"} = $socket;

}

#
# Send a message
# 
sub _transmit 
{
	my $self = shift;
    my $command = shift;
    my $parameters = shift;
    my $body  = shift;
    my $socket = $self->{"socket"};
    my $string;

    $string = $command."\n";
    foreach (keys %$parameters ) {
        next unless (defined($parameters->{$_}));

        my $line = $_.":".$parameters->{$_}."\n";
        $string .= $line;
    }

    $string .= "\n";
    if ($body) {
        $string .= $body."\n";
    }

    $string .="\0";
    print STDERR "Stomp::Connection _transmit:$string\n" if ($self->{"debug"});
    $socket->syswrite ($string, length($string));

    return;

}

#
# Get something back
#
sub _recv
{
	my $self = shift;
    my $socket = $self->{"socket"};
    my $string = "";

    my $line;
    my $len;
    $string = $self->{"pending"} if ( $self->{"pending"} );

    $len = $socket->sysread($line, 50);

    while ( not($line =~ /\0/s )) {
        $string .= $line;
        $len = $socket->sysread($line,50);
    }

    if ( $line =~ /(.*?)\0(.*)/s ) {
        $string .= $1;
        my $x = $2;
        $x =~ s/^\n//;
        $self->{"pending"} = $x;
    }
    else {
        $string .= $line;
    }
    return $string;
}

# Stomp - Connect message
#
sub Connect($$$) {
	my $self = shift;
    my $login = shift;
    my $pass = shift;
    
    $self->_transmit( "CONNECT", { login=> $login, passcode=> $pass });

    my $result = $self->_recv();
    if ($result =~ /CONNECTED/ ) {
        if ($result =~ /session:(.*)/ ) {
            $self->{'session'} = $1;
            return "OK";
        }
        else {
            $self->{"error"}=$result;
            return undef;
        }
    }
    $self->{"error"}=$result;
    return undef;

}
# Stomp - Disconnect Message
#
sub Disconnect($$$)
{
    my $self=shift;
    my $socket = $self->{"socket"};
    $self->_transmit( "Disconnect", { session=> $self->{"session"} });
    $socket->shutdown( 1 );
    $self->{"socket"}=undef;
}


# Stomp - Begin Message
#
sub Begin($)
{
    my $self=shift;
    my $rcpt = shift;

    $self->_transmit( "BEGIN", { session=> $self->{"session"} , receipt=> $rcpt});
}

# Stomp - Commit Message
#
sub Commit($)
{
    my $self=shift;
    my $rcpt = shift;

    $self->_transmit( "COMMIT", { session=> $self->{"session"}, receipt=> $rcpt });
}

# Stomp - Abort Message
#
sub Abort($$$)
{
    my $self=shift;
    my $rcpt = shift;

    $self->_transmit( "ABORT", { session=> $self->{"session"}, receipt=>$rcpt });
}



# Stomp - Send Message
#
sub Send($$$)
{
    my $self=shift;
    my $queue = shift;
    my $body = shift;
    my $rcpt = shift;

    $self->_transmit( "SEND", { session=> $self->{"session"}, destination=> $queue, receipt=>$rcpt }, $body);
}
# Stomp - Subscribe Message
#
sub Subscribe($$)
{
    my $self=shift;
    my $queue = shift;
    my $rcpt = shift;

    $self->_transmit( "SUBSCRIBE", { session=> $self->{"session"}, destination=> $queue, receipt=> $rcpt });
}
# Stomp - Unsubscribe Message
#
sub Unsubscribe($$)
{
    my $self=shift;
    my $queue = shift;
    my $rcpt = shift;

    $self->_transmit( "UNSUBSCRIBE", { session=> $self->{"session"}, destination=> $queue, receipt=> $rcpt });
}

#
##
# Reciept
#

sub Read($)
{
    my $self=shift;
    my $string;

    print "about to read\n";
    $string =  $self->_recv();
    my @parts = split /\n/, $string;
    my $type = shift @parts;
    print "TYPE:$type\n" if ($self->{"debug"});
    print "MSG:$string\n" if ($self->{"debug"});
    if ($type eq "MESSAGE" ) {
        return Stomp::Message->new(\@parts);
    }
    elsif ($type  eq "RECEIPT" ) {
        return Stomp::Receipt->new(\@parts);
    }
    return Stomp::Error->new(\@parts);
    
}


1;
