
package PurpleWiki::Request;

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $context = shift;
  my $self = { @_, context => $context };  
#print STDERR "New request(",join(", ",%$self),")\n";
  bless($self, $class);
}

sub action {
  my $self = shift;
  $self->{action} = shift if (@_);
  my $action = $self->{action};
  return undef unless $action;
  my $reqHandler = $self->{context}->{request};
  $reqHandler->action($action);
}

sub id {
  my $self = shift;
  $self->{id} = shift if (@_);
  $self->{id};
}

sub session {
  my $self = shift;
  $self->{session} = shift if (@_);
  $self->{session};
}

sub text {
  my $self = shift;
  $self->{text} = shift if (@_);
  $self->{text};
}

sub summary {
  my $self = shift;
  $self->{summary} = shift if (@_);
  $self->{summary};
}

sub diffrevision {
  my $self = shift;
  $self->{diffrevision} = shift if (@_);
  $self->{diffrevision};
}

sub oldrev {
  my $self = shift;
  $self->{oldrev} = shift if (@_);
  $self->{oldrev};
}

sub oldconflict {
  my $self = shift;
  $self->{oldconflict} = shift if (@_);
  $self->{oldconflict};
}

sub context {
  my $self = shift;
  $self->{context} = shift if (@_);
  $self->{context};
}

sub user {
  my $self = shift;
  $self->{user} = shift if (@_);
  $self->{user};
}

sub revision {
  my $self = shift;
  $self->{revision} = shift if (@_);
  $self->{revision};
}

sub CGI {
  my $self = shift;
  $self->{cgi} = shift if (@_);
  $self->{cgi};
}

sub ARGV {
  my $self = shift;
  $self->{argv} = shift if (@_);
  $self->{argv};
}

sub xsid {
  my $self = shift;
  $self->{xsid} = shift if (@_);
  $self->{xsid};
}

sub iname {
  my $self = shift;
  $self->{iname} = shift if (@_);
  $self->{iname};
}

sub localid {
  my $self = shift;
  $self->{localid} = shift if (@_);
  $self->{localid};
}

sub rrsid {
  my $self = shift;
  $self->{rrsid} = shift if (@_);
  $self->{rrsid};
}

sub search {
  my $self = shift;
  $self->{search} = shift if (@_);
  $self->{search};
}

sub error {
  my $self = shift;
  $self->{error} = shift if (@_);
  $self->{error};
}

sub reBrowsePage {
  my $self = shift;
  my $id = shift;
  my $context = $self->{context};
  my $config = $context->{config};
  my $q = $self->{cgi};
  my $url = $q->url(-full=>1) if $q;
  $url = $config->BaseURL unless $url;
  print (($q) ? $q->redirect(-uri => "$url?$id") : "Location: $url?$id\n");
}

sub getHttpHeader {
    my $self = shift;
    my $q = $self->CGI();
    my $session = $self->session();
    my $config = $self->context()->{config};
    my $cookieName = ($config->CookieName) ? $config->CookieName :
        $config->SiteName;
    my $cookie = $q->cookie(-name => $cookieName,
                            -value => $session->id,
                            -path => $config->CookieDir,
                            -expires => '+7d');
    if ($config->HttpCharset ne '') {
        print $q->header(-cookie=>$cookie,
                          -type=>"text/html; charset=" . $config->HttpCharset);
    } else { print $q->header(-cookie=>$cookie); }
}

1;
