#!/usr/bin/env perl

use strict;
use warnings;

# ATS Via header transaction code decoder
# Format: [u<client-info> c<cache-lookup> s<server-info> f<cache-fill> p<proxy-info> e<error-codes>:t<tunnel-info>c<cache-type><cache-lookup-result> p<parent-proxy> s<server-conn-info>]
# https://docs.trafficserver.apache.org/en/latest/appendices/faq.en.html#how-do-i-interpret-the-via-header

my %client_info = (
    'C' => 'client:cookie',
    'E' => 'client:error-in-request',
    'I' => 'client:IMS',
    'N' => 'client:no-cache',
    'S' => 'client:simple-request',
    ' ' => 'client:(none)',
);

my %cache_lookup = (
    'A' => 'cache:not-acceptable',
    'H' => 'cache:hit-fresh',
    'M' => 'cache:miss',
    'R' => 'cache:hit-RAM',
    'S' => 'cache:stale',
    ' ' => 'cache:(no-lookup)',
);

my %server_info = (
    'E' => 'server:error',
    'N' => 'server:not-modified',
    'S' => 'server:served',
    ' ' => 'server:(no-connection)',
);

my %cache_fill = (
    'D' => 'fill:deleted',
    'U' => 'fill:updated',
    'W' => 'fill:written',
    ' ' => 'fill:(no-write)',
);

my %proxy_info = (
    'N' => 'proxy:not-modified',
    'R' => 'proxy:revalidated',
    'S' => 'proxy:served',
    ' ' => 'proxy:(none)',
);

my %error_codes = (
    'A' => 'error:auth-failure',
    'C' => 'error:connection-failed',
    'D' => 'error:dns-failure',
    'F' => 'error:forbidden',
    'H' => 'error:bad-header',
    'L' => 'error:loop-detected',
    'M' => 'error:moved-temporarily',
    'N' => 'error:none',
    'R' => 'error:cache-read-error',
    'S' => 'error:server-error',
    'T' => 'error:timed-out',
    ' ' => 'error:(none)',
);

my %tunnel_info = (
    'A' => 'tunnel:authorization',
    'F' => 'tunnel:header-field',
    'M' => 'tunnel:method',
    'N' => 'tunnel:no-forward',
    'O' => 'tunnel:cache-off',
    'U' => 'tunnel:dynamic-url',
    ' ' => 'tunnel:(none)',
);

my %cache_type = (
    'C' => 'cache-type:cache',
    'L' => 'cache-type:cluster',
    'P' => 'cache-type:parent',
    'S' => 'cache-type:server',
    ' ' => 'cache-type:(miss)',
);

my %cache_lookup_result = (
    'C' => 'lookup:hit-revalidate-config',
    'D' => 'lookup:hit-revalidate-method',
    'H' => 'lookup:hit',
    'I' => 'lookup:conditional-miss-412',
    'K' => 'lookup:cookie-miss',
    'M' => 'lookup:miss',
    'N' => 'lookup:conditional-hit-304',
    'S' => 'lookup:hit-expired',
    'U' => 'lookup:hit-revalidate-client',
    ' ' => 'lookup:(none)',
);

my %parent_proxy = (
    'F' => 'parent:failed',
    'S' => 'parent:success',
    ' ' => 'parent:(none)',
);

my %server_conn = (
    'F' => 'server-conn:failed',
    'S' => 'server-conn:success',
    ' ' => 'server-conn:(none)',
);

sub decode_via {
    my ($codes) = @_;

    # Format before ':': u(.)c(.)s(.)f(.)p(.)e(.)
    # Format after  ':': t(.)c(.)(.)p(.)s(.)
    unless ($codes =~ /^u(?<client>.)c(?<cache>.)s(?<server>.)f(?<fill>.)p(?<proxy>.)e(?<error>.):t(?<tunnel>.)c(?<ctype>.)(?<clookup>.)p(?<parent>.)s(?<sconn>.)$/) {
        return $codes;  # unrecognized format, leave as-is
    }

    my @parts;
    push @parts, $client_info{$+{client}}          // "client:$+{client}";
    push @parts, $cache_lookup{$+{cache}}          // "cache:$+{cache}";
    push @parts, $server_info{$+{server}}          // "server:$+{server}";
    push @parts, $cache_fill{$+{fill}}             // "fill:$+{fill}";
    push @parts, $proxy_info{$+{proxy}}            // "proxy:$+{proxy}";
    push @parts, $error_codes{$+{error}}           // "error:$+{error}";
    push @parts, $tunnel_info{$+{tunnel}}          // "tunnel:$+{tunnel}";
    push @parts, $cache_type{$+{ctype}}            // "cache-type:$+{ctype}";
    push @parts, $cache_lookup_result{$+{clookup}} // "lookup:$+{clookup}";
    push @parts, $parent_proxy{$+{parent}}         // "parent:$+{parent}";
    push @parts, $server_conn{$+{sconn}}           // "server-conn:$+{sconn}";

    # drop "(none)" entries to reduce noise
    @parts = grep { $_ !~ /:\(none\)$/ } @parts;

    return join(', ', @parts);
}

while (<STDIN>) {
    if (/^(?<pre>Via:[^\(]+\([^\[]+\[)(?<codes>[^\]]+)(?<post>\].*)$/) {
        print "$+{pre}" . decode_via($+{codes}) . "$+{post}\n";
    } else {
        print;
    }
}
