=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::NewTableSorts;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(each_array);

use Exporter qw(import);
our @EXPORT_OK = qw(newtable_sort_client_config newtable_sort_isnull
                    newtable_sort_cmp);

sub html_cleaned { $_[0] =~ s/<.*?>//g; return $_[0]; }
sub number_cleaned { $_[0] =~ s/([\d\.e\+-])\s.*$/$1/; return $_[0]; }

sub html_hidden {
  my ($x) = @_;

  return $1 if $x =~ m!<span class="hidden">(.*?)</span>!;
  return $x;
}

sub null_position {
  my ($v) = @_;

  $v =~ s/^.*://;
  my @v = split(/:-/,$v);
  foreach my $c (@v) {
    return 0 if newtable_sort_isnull('numeric',$c);
  } 
  return 1;
}

sub sort_position {
  my ($a,$b,$f) = @_;

  my @a = split(/:-/,$a);
  my @b = split(/:-/,$b);
  my $it = each_array(@a,@b);
  while(my ($aa,$bb) = $it->()) {
    my $c = newtable_sort_cmp('numeric',$aa,$bb,$f);
    return $c if $c; 
  }
  return 0;
}

my %SORTS = (
  '_default' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { return 0; },
    clean => sub { return $_[0]; },
  },
  'string' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { $_[0] !~ /\S/; },
    js => 'string'
  },
  'string_dashnull' => {
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    null => sub { $_[0] !~ /\S/ || $_[0] =~ /^\s*-\s*$/; },
    js => 'string'
  },
  'string_hidden' => {
    clean => \&html_hidden,
    null => sub { $_[0] =~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_hidden',
  },
  'numeric_hidden' => {
    clean => sub { return number_cleaned(html_hidden($_[0])); },
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'hidden_number',
  },
  'numeric' => {
    clean => \&number_cleaned, 
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'clean_number',
  },
  'html' => {
    clean => \&html_cleaned,
    null => sub { $_[0] =~ /\S/; },
    perl => sub { return (lc $_[0] cmp lc $_[1])*$_[2]; },
    js => 'string',
    js_clean => 'html_cleaned',
  },
  'html_numeric' => {
    clean => sub { return number_cleaned(html_cleaned($_[0])); },
    perl => sub { return ($_[0] <=> $_[1])*$_[2]; },
    null => sub { return !looks_like_number($_[0]); },
    js => 'numeric',
    js_clean => 'html_number'
  },
  'position' => {
    null => \&null_position,
    perl => \&sort_position,
    js => 'position',
  },
  'position_html' => {
    clean => \&html_cleaned,
    null => \&null_position,
    perl => \&sort_position,
    js => 'position',
    js_clean => 'html_cleaned',
  },
  'hidden_position' => {
    clean => \&html_hidden,
    null => \&null_position,
    perl => \&sort_position,
    js_clean => 'html_hidden',
    js => 'position',
  },
);

foreach my $k (keys %SORTS) {
  foreach my $d (keys %{$SORTS{'_default'}}) {
    $SORTS{$k}->{$d} ||= $SORTS{'_default'}->{$d};
  }
}

sub newtable_sort_client_config {
  my ($column_map) = @_;

  my $config;
  foreach my $col (keys %$column_map) {
    my $conf = $SORTS{$column_map->{$col}};
    $conf->{'options'} ||= {};
    if($conf->{'js'}) {
      $config->{$col} = {
        fn => $conf->{'js'},
        clean => $conf->{'js_clean'},
        type => $column_map->{$col},
        incr_ok => !($conf->{'options'}{'no_incr'}||0)
      };
    }
  }
  return $config;
}

sub newtable_sort_isnull {
  my ($type,$value) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  $value = $SORTS{$type}->{'clean'}->($value);
  return !!($SORTS{$type}->{'null'}->($value));
}

sub newtable_sort_cmp {
  my ($type,$a,$b,$f) = @_;

  $SORTS{$type} = $SORTS{'_default'} unless $SORTS{$type};
  my $av = $SORTS{$type}->{'clean'}->($a);
  my $bv = $SORTS{$type}->{'clean'}->($b);
  my $an = newtable_sort_isnull($type,$av);
  my $bn = newtable_sort_isnull($type,$bv);
  return $an-$bn if $an-$bn;
  $type = '_default' if $an;
  return $SORTS{$type}->{'perl'}->($av,$bv,$f);
}

1;
