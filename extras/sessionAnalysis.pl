#!/usr/bin/perl

use Date::Manip;
use Getopt::Long;

if (scalar @ARGV == 0) {
    print "Usage: $0 session_log\n";
    exit;
}

my $reportSummary;
my $reportSession;
GetOptions('summary' => \$reportSummary,
	   'session=s' => \$reportSession);

my %sessions;

### build data structure

my $file = $ARGV[0];
open LOG, $file or die "Can't open log file.\n";
while (my $line = <LOG>) {
    chomp $line;
    my ($timeStamp, $sessionKey, $httpAction, $queryString, $host, $userId,
	$referrer) = split(/\t/, $line);
    my $session = {
	timeStamp => $timeStamp,
	httpAction => $httpAction,
	queryString => $queryString,
	host => $host,
	userId => $userId,
	referrer => $referrer,
    };
    if (!$sessions{$sessionKey}) {
	$sessions{$sessionKey} = {
	    startTime => $timeStamp,
	    sessionList => [$session],
	    numGets => 0,
	    numPosts => 0,
	};
    }
    else {
	push @{$sessions{$sessionKey}->{sessionList}}, $session;
    }
    ($httpAction eq 'GET') ? $sessions{$sessionKey}->{numGets}++ :
	$sessions{$sessionKey}->{numPosts}++;
    if ($userId && !$sessions{$sessionKey}->{userId}) {
	$sessions{$sessionKey}->{userId} = $userId;
	$sessions{$sessionKey}->{firstLogin} = $timeStamp;
    }
}
close LOG;

### reports

if ($reportSummary) {
    foreach my $sessionKey ( sort {$sessions{$a}->{startTime} <=>
				       $sessions{$b}->{startTime} }
			     keys %sessions ) {
	&sessionSummary($sessionKey);
    }
}

if ($reportSession) {
    &sessionSummary($reportSession);
    my $session = $sessions{$reportSession};
    # print GET trail
    my $prevTimeStamp = $session->{startTime};
    my %pageCount;
    foreach my $session (@{$sessions{$reportSession}->{sessionList}}) {
	if ($session->{httpAction} eq 'GET') {
	    print localtime($session->{timeStamp}) . "\t";
	    my $delta = $session->{timeStamp} - $prevTimeStamp;
	    my $diffHours = $delta / 3600;
	    my $diffMinutes = ($delta % 3600) / 60;
	    my $diffSeconds = $delta % 60;
	    $prevTimeStamp = $session->{timeStamp};
	    printf("%02d:%02d:%02d\t", $diffHours, $diffMinutes, $diffSeconds);
	    my $queryString = $session->{queryString};
	    $queryString =~ s/^([^=]+)=//;
	    if ($1 eq 'keywords') {
		print "$queryString\n";
		$pageCount{$queryString}++;
	    }
	    elsif ($1 eq 'action') {
		print "($queryString)\n";
	    }
	    else {
		print "HomePage\n";
	    }
	}
    }
    # page access count
    print "\n";
    foreach my $page (sort { $pageCount{$b} <=> $pageCount{$a} }
		      keys %pageCount) {
	print "$page\t" . $pageCount{$page} . "\t" . 
	    &percent($pageCount{$page}, $session->{numGets}) . "\n";
    }
}

sub sessionSummary {
    my $sessionKey = shift;

    print "$sessionKey\t" . localtime($sessions{$sessionKey}->{startTime}) .
	"\n";
    if ($sessions{$sessionKey}->{userId}) {
	print "\tUser ID = " . $sessions{$sessionKey}->{userId};
	print " logged in on " .
	    localtime($sessions{$sessionKey}->{firstLogin}) . "\n";
    }
    print "\t" . scalar @{$sessions{$sessionKey}->{sessionList}} .
	" actions (" . $sessions{$sessionKey}->{numGets} . " GETs, " .
	$sessions{$sessionKey}->{numPosts} . " POSTs)\n";
    print "\n";
}

sub percent {
    my ($num, $div) = @_;

    my $percent = $num / $div * 100;
    return sprintf("%2.1f\%", $percent);
}
