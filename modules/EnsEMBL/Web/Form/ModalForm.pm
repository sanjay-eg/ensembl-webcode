package EnsEMBL::Web::Form::ModalForm;

use strict;

use base qw(EnsEMBL::Web::Form);

use constant {
  WIZARD_CLASS_NAME => 'wizard',
  
  _PARAMS_KEY       => '__modal_form_params',
};

sub new {
  ## @overrides
  ## @params HashRef with keys
  ##  - action         Action attribute
  ##  - class          Class attribute
  ##  - method         Method attribute
  ##  - wizard         Flag on if form is a part of wizard
  ##  - label          Label for the submit button if wizard - default "Next >"
  ##  - back_button    Flag if 0, back button is not displayed
  ##  - no_button      No buttons displayed automatically if flag is on
  ##  - buttons_on_top If flag on, dupicate buttons are added at the top of the form
  ##  - buttons_align  where to align the buttons - centre, left, right, default
  my ($class, $params) = @_;
  my $self = $class->SUPER::new({
    'id' => $params->{'name'},
    'action' => $params->{'action'} || '#',
    'method' => $params->{'method'},
  });
  
  $self->set_attribute('class', $params->{'class'}) if $params->{'class'};

  $self->{$self->_PARAMS_KEY} = {};
  for (qw(wizard label back_button no_button backtrack current next buttons_on_top buttons_align)) {
    $self->{$self->_PARAMS_KEY}{$_} = $params->{$_} if exists $params->{$_};
  }
  return $self;
}

sub render {
  ## Adds buttons and hidden inputs inside the form before rendering it
  ## @overrides
  my $self = shift;
  my $params = $self->{$self->_PARAMS_KEY};
  
  my $label = $params->{'label'} || 'Next >';
  my @buttons;
  my @hiddens;

  if ($params->{'wizard'}) {
    $self->set_attribute('class', $self->WIZARD_CLASS_NAME);
    
    push @buttons, {'type' => 'button', 'name' => 'wizard_back', 'value' => '< Back', 'class' => 'back submit'} unless defined $params->{'back_button'} && $params->{'back_button'} == 0;
    
    # Include current and former nodes in _backtrack
    if ($params->{'backtrack'}) {
      for (@{$params->{'backtrack'}}) {
        push @hiddens, {'name' => '_backtrack', 'value' => $_} if $_;
      }
    }
    
    push @buttons, {'type'  => 'Submit', 'name' => 'wizard_submit', 'value' => $label};
    push @hiddens, {'name' => '_backtrack', 'value' => $params->{'current'}}, {'name' => 'wizard_next', 'value' => $params->{'next'}};

  } elsif (!$params->{'no_button'}) {
    push @buttons, {'type' => 'Submit', 'name' => 'submit', 'value' => $label};
  }
  
  $self->add_hidden(\@hiddens);
  my $buttons_field = $self->add_button({'buttons' => \@buttons, 'align' => $params->{'buttons_align'} || 'default'});
  
  if ($params->{'buttons_on_top'}) {
    $buttons_field = $buttons_field->clone_node(1);
    $buttons_field->is_button_field(1);
    my $fieldset = $self->fieldsets->[0] || $self->add_fieldset;
    $fieldset->prepend_child($buttons_field);
  }

  return $self->SUPER::render;
}

1;