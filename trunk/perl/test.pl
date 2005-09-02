#!/usr/local/bin/perl -wT
use strict;
use lib qw(.);
my $usage = shift ; #||"W";
die "Usage: R - Read/Subscribe to /queue/foo\nW - write to /queue/foo\nQ - Send a QUIT message\n" unless ($usage);
use Stomp::Connection;
my $c = Stomp::Connection->new( login=> "jack", passcode=>"rabbit", host=>"localhost", port=>61613 );
if ($usage eq "W") {
    print "Writing 2 messages to /queue/foo\n";
    $c->Begin();
    $c->Send( "/queue/foo", "hi", "FOOBAR" );
    my $msg = $c->Read();
    print "wanted a FOOBAR receipt got -> " . $msg->id ."\n";
    $c->Send( "/queue/foo", "hi2" );
    $c->Commit();
    $c->Disconnect();
}
elsif ($usage eq "Q") {
    $c->Send( "/queue/foo", "QUIT" );
}
else {
    print "Subscribing to /queue/foo\n";
    $c->Subscribe("/queue/foo");
    while (1) {
        
        my $msg = $c->Read();
        print scalar localtime(),"\n";
#        print "REF", ref $msg,"X\n";
        print $msg->body,"\n";
        last if ($msg->body =~ /^QUIT/ );
    }
    $c->Unsubscribe("/queue/foo");
    $c->Disconnect();
}

