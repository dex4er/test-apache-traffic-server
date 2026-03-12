#!/usr/bin/env perl

use strict;
use warnings;
use JSON::PP;

# Generates a JSON Schema from the output of:
#   traffic_ctl config match '.*'
#
# Each line has the form:
#   proxy.config.some.key: value
#
# The "proxy.config." prefix is stripped, then the remaining dotted path is
# converted to a nested JSON Schema object tree.  Leaf types are inferred from
# the example value (integer, number, or string).
#
# Usage:
#   ./kubectl.sh exec -n ats statefulset/apache-traffic-server-l2 -- \
#     traffic_ctl config match '.*' | perl tools/gen-records-schema.pl > records.schema.json

# Build a nested schema node in-place.  Each intermediate segment becomes a
# "type": "object" node with "properties".  The leaf gets an inferred type.
sub insert {
    my ($node, $parts, $leaf) = @_;
    for my $part (@{$parts}[0 .. $#$parts - 1]) {
        $node->{properties}{$part} //= {
          type => 'object', additionalProperties => \0
        };
        $node = $node->{properties}{$part};
    }
    $node->{properties}{ $parts->[-1] } = $leaf;
}

sub infer_type {
    my ($key, $value) = @_;
    my $desc = "$key: $value";
    return { type => 'integer', description => $desc } if $value =~ /^-?\d+$/;
    return { type => 'number',  description => $desc } if $value =~ /^-?\d+\.\d+$/;
    return { type => 'string',  description => $desc };
}

my $records = { type => 'object', additionalProperties => \0 };

while (my $line = <STDIN>) {
    chomp $line;

    # Skip error / separator lines produced by traffic_ctl
    next unless $line =~ /^([\w.]+):\s*(.*)$/;
    my ($key, $value) = ($1, $2);

    # Strip the "proxy.config." prefix — records.yaml uses the bare path
    my @parts = split /\./, ($key =~ s/^proxy\.config\.//r);
    insert($records, \@parts, infer_type($key, $value));
}

# Wrap under the top-level "records:" key, matching the records.yaml structure.
my $root = {
    type                 => 'object',
    additionalProperties => \0,
    properties           => { records => $records },
};

my $json = JSON::PP->new->utf8->pretty->indent_length(2)->canonical;
print $json->encode($root);
