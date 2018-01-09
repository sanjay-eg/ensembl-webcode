=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::cactus_hal;

### Draws compara pairwise alignments - see EnsEMBL::Web::ImageConfig
### and E::W::ImageConfig::MultiBottom for usage

use strict;

use List::Util qw(max min);

use EnsEMBL::Draw::Style::Feature::Alignment;

use base qw(EnsEMBL::Draw::GlyphSet);

# Useful for debugging. Should all be 0 in checked-in code.
my $debug_force_compact = 0; # render_normal -> render_compact

sub init {
  my $self = shift;

  ## Fetch and cache features
  my $data = $self->get_data;
  my $features = $data->[0]{'features'} || [];
 
  ## No features show "empty track line" if option set
  if ($features eq 'too_many') {
    $self->too_many_features;
    return [];
  }
  elsif (!scalar(@$features)) {
    $self->no_features;
    return [];
  }

  ## Set track depth (i.e. number of rows of features)  
  my $depth = $self->depth;
  $depth    = 1e3 unless defined $depth;
  $self->{'my_config'}->set('depth', $depth);

  ## Set track height
  $self->{'my_config'}->set('height', '10');
  
  ## OK, done!
  return $features;
}


sub render_normal {
  my $self = shift;

  return $self->render_compact if $debug_force_compact;

  $self->{'my_config'}->set('bumped', 1);
  $self->{'my_config'}->set('no_join', 1);

  my $data = $self->get_data;
  if (scalar @{$data->[0]{'features'}||[]}) {
    #use Data::Dumper; $Data::Dumper::Sortkeys = 1;
    #warn Dumper($data);
    my $config = $self->track_style_config;
    my $style  = EnsEMBL::Draw::Style::Feature::Alignment->new($config, $data);
    $self->push($style->create_glyphs);
    $self->add_connections($style);
  }
  else {
    $self->no_features;
  }

}

sub render_compact {
  my $self = shift;

  $self->{'my_config'}->set('no_join', 1);
}

sub get_data {
  my $self = shift;
  $self->{'my_config'}->set('DEBUG_RAINBOW', 1); 

  ## Check the cache first
  my $cache_key = $self->my_label;
  if ($self->feature_cache($cache_key)) {
    return $self->feature_cache($cache_key);
  }

  my $ref_sp    = $self->{'config'}->hub->species;
  my $nonref_sp = $self->{'config'}->hub->param('s1');

  my $slice   = $self->{'container'};
  my $compara = $self->dbadaptor('multi',$self->my_config('db'));
  my $mlss_a  = $compara->get_MethodLinkSpeciesSetAdaptor;
  my $mlss_id = $self->my_config('method_link_species_set_id');
  my $mlss    = $mlss_a->fetch_by_dbID($mlss_id);
  my $gab_a   = $compara->get_GenomicAlignBlockAdaptor;

  #Get restricted blocks
  my $gabs = $gab_a->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, undef, undef, 'restrict');

  my @slices      = split(' ',$self->my_config('slice_summary')||'');
  my $strand_flag = $self->my_config('strand');
  my $length      = $slice->length;
  my $strand      = $self->strand;
  my $colour      = $self->my_colour('default');
  $self->{'config'}{'hub'}->param('r1') =~ /:(\d+)\-/;
  my $other_start = $1; 

  my %zmenu = (
                type    => 'Location',
                action  => 'PairwiseAlignment',
                method  => $self->my_config('type'),
              );

  my $features = [];
  my $feature_key = lc $self->my_config('type');
  my $connection_colour = $self->my_colour($feature_key, 'join') || 'gold'; 
  use Data::Dumper;

  foreach my $gab (@{$gabs||[]}) {
    warn "\n\n### NEXT";
    my $start     = $gab->reference_slice_start;
    my $end       = $gab->reference_slice_end;
    next if $end < 1 || $start > $length;

    my $nonref    = $gab->get_all_non_reference_genomic_aligns->[0];
    my $nr_start  = $nonref->dnafrag_start;
    my $nr_end    = $nonref->dnafrag_end;
    my $hseqname  = $nonref->dnafrag->name;
  
    ## Create zmenu link 
    my $chr       = $self->{'container'}->seq_region_name;
    my $slice_start = $self->{'container'}->start;
    my $ref_url   = $self->_url({
                                's1' => $ref_sp,
                                'r1'  => sprintf('%s:%s-%s', $chr, $start + $slice_start, $end + $slice_start),
                                %zmenu
                              });
    my $nonref_url = $self->_url({
                                's1' => $nonref_sp,
                                'r1'  => sprintf('%s:%s-%s', $hseqname, $nr_start, $nr_end),
                                %zmenu
                              });

    ## Create information needed for cross-species join
    my $block_id = sprintf('%s_%s-%s-%s:%s_%s-%s-%s', 
                              $ref_sp, $chr, $start + $slice_start, $end + $slice_start,
                              $nonref_sp, $hseqname, $nr_start, $nr_end);

    # Should we draw an 'x' rather than a quadrilateral?
    my $ref_ori     = $gab->reference_slice_strand;
    my $nonref_ori  = $nonref->dnafrag_strand;
    my $other_ori   = $self->my_config('ori');

    # flipdata -- alignment is interstrand
    # flipview -- views are in opposite orientations
    my $flipdata = ($ref_ori != $nonref_ori);
    my $flipview = (($ref_ori == -1) xor ($other_ori == -1));
    my $cross = ($flipdata xor $flipview) ? 1 : 0;

    ## Convert into something the drawing code can understand
    ## Note that we link to the _other_ species in the alignment
    my $drawable = {
                    $ref_sp     => {
                                    'start'     => $start, 
                                    'end'       => $end, 
                                    'colour'    => $colour,
                                    'href'      => $nonref_url, 
                                    'index'     => 0,
                                    },
                    $nonref_sp  => {'start'     => $nr_start - $other_start, 
                                    'end'       => $nr_end - $other_start,
                                    'colour'    => $colour,
                                    'href'      => $ref_url, 
                                    'index'     => 1,
                                    },
                    'connections' => [{
                                        'key'     => $block_id,
                                        'colour'  => $connection_colour,
                                        'cross'   => $cross,
                                      }],
                  };
    #warn Dumper($drawable);

    push @$features, $drawable;
  }

  ## Set cache
  my $data = [{'features' => $features}];
  $self->feature_cache($cache_key, $data);
  return $data;
}

1;
