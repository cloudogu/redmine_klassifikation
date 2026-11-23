Redmine::Plugin.register :redmine_klassifikation do
  name        'Redmine Klassifikation'
  author      'Cloudogu'
  description 'Returns the raw value of the custom field "Klassifikation"'
  version     '1.0.0'
  requires_redmine version_or_higher: '5.0.0'
end
