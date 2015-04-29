=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# this will only work for new user code as old user code will return undef for user->get_group

package EnsEMBL::Web::Command::ShareRecord;

use strict;

use Digest::MD5 qw(md5_hex);

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self  = shift;
  my $hub   = $self->hub;
  my $user  = $hub->user;
  my $group = $user->get_group($hub->param('webgroup_id'));
  my %url_params;

  if ($group && $user->is_admin_of($group)) {
    foreach (grep $_, $hub->param('id')) {
      my ($id, $checksum) = split '-', $_;
      my $record = $user->get_record($id);

      next unless $record;
      next unless $checksum eq md5_hex($record->data->{'code'});
      
      my $clone = $record->clone_and_reset;
      
      $clone->record_type($group->RECORD_TYPE);
      $clone->record_type_id($group->group_id);
      $clone->data->{'cloned_from'} = $record->record_id;
      $clone->save(user => $user->rose_object);
    }
    
    %url_params = (
      type     => 'UserData',
      action   => 'ManageData',
      function => ''
    );
  } else {
    %url_params = (
      type          => 'UserData',
      action        => 'ManageData',
      filter_module => 'Shareable',
      filter_code   => 'no_group',
    );
  }
 
  $self->ajax_redirect($hub->url(\%url_params));
}

1;
