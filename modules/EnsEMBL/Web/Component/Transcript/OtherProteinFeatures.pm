package EnsEMBL::Web::Component::Transcript::OtherProteinFeatures;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);
use EnsEMBL::Web::Form;

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object   = $self->object;
  my @other = map { @{$object->translation_object->get_all_ProteinFeatures($_)} } qw( tmhmm SignalP ncoils Seg );
  return unless @other ;
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
  $table->add_columns(
    { 'key' => 'type',  'title' => 'Domain type',      'width' => '60%', 'align' => 'center' },
    { 'key' => 'start', 'title' => 'Start',            'width' => '30%', 'align' => 'center' , 'hidden_key' => '_loc' },
    { 'key' => 'end',   'title' => 'End',              'width' => '30%', 'align' => 'center' },
  );
  foreach my $domain ( 
    sort { $a->[0] cmp $b->[0] || $a->[1]->start <=> $b->[1]->start || $a->[1]->end <=> $b->[1]->end }
    map { [ $_->analysis->db || $_->analysis->logic_name || 'unknown', $_ ] }
    @other ) {
    ( my $domain_type = $domain->[0] ) =~ s/_/ /g;
    $table->add_row( {
      'type'  => ucfirst($domain_type),
      'start' => $domain->[1]->start,
      'end'   => $domain->[1]->end,
      '_loc'  => join '::', $domain->[1]->start,$domain->[1]->end,
    } );
  }
  return $table->render;
}

1;

