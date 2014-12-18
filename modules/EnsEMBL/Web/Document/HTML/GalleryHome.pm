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

package EnsEMBL::Web::Document::HTML::GalleryHome;

### Simple form providing an entry to the new Site Gallery navigation system 

use strict;
use warnings;

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Component;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;

  ## Check session for messages
  my $error = $hub->session->get_data('type' => 'message', 'code' => 'gallery');

  if ($error) {
    $html .= sprintf(
      '<div style="width:95%" class="warning"><h3>Error</h3><div class="message-pad"><p>%s</p></div></div>', $error->{'message'});
    $hub->session->purge_data(type => 'message', code => 'gallery');
  }

  my $form      = EnsEMBL::Web::Form->new({'id' => 'gallery_home', 'action' => '/Info/CheckGallery', 'name' => 'gallery_home'});
  my $fieldset  = $form->add_fieldset({});

  my @array;
  foreach ($species_defs->valid_species) {
    push @array, {'value' => $_, 'caption' => $species_defs->get_config($_, 'SPECIES_COMMON_NAME')};
  }
  my @species     = sort {$a->{'caption'} cmp $b->{'caption'}} @array;
  my $favourites  = $hub->get_favourite_species;
  $fieldset->add_field({
                        'type'    => 'Dropdown',
                        'name'    => 'species',
                        'label'   => 'Species',
                        'values'  => \@species,
                        'value'   => $favourites->[0],
                        });

  my $data_types = [
                    {'value' => 'Gene',       'caption' => 'Genes'},
                    {'value' => 'Variation',  'caption' => 'Variants'},
                    {'value' => 'Location',   'caption' => 'Genomic locations'},
                    ];
 
  $fieldset->add_field({
                        'type'    => 'Radiolist',
                        'name'    => 'data_type',
                        'label'   => 'I am interested in',
                        'values'  => $data_types,
                        'value'   => 'Variation',
                        });
  $fieldset->add_field({
                        'type'    => 'String',
                        'name'    => 'identifier',
                        'label'   => 'Identifier (optional)',
                        });
  $fieldset->add_button({
    'name'      => 'submit',
    'value'     => 'Go',
    'class'     => 'submit'
  });

  $html .= $form->render;

  return $html; 
}

1;