#!/usr/local/bin/perl -wT
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

