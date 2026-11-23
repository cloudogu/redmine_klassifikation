class KlassifikationController < ApplicationController
  FIELD_NAME = 'Klassifikation'.freeze

  accept_api_auth :issue, :project

  # An issue's own value wins. If it is empty (or the issue has no such field),
  # the value is inherited from its project, then the parent project, and so on.
  def issue
    issue = Issue.find_by(id: params[:id])
    return head(:not_found) unless issue&.visible?

    own = own_value(issue)
    # Never fall back when the issue's own value is hidden from this user:
    # that could show a lower classification than the issue really has.
    return head(:not_found) if own == :hidden
    return render_value(own, nil) if own.present?

    inherited, source = project_value(issue.project)
    return head(:not_found) if inherited == :hidden || (own.nil? && inherited.nil?)

    render_value(inherited.to_s, source)
  end

  def project
    project = Project.find_by(identifier: params[:id]) || Project.find_by(id: params[:id])
    return head(:not_found) unless project&.visible?

    value, source = project_value(project)
    return head(:not_found) if value.nil? || value == :hidden

    render_value(value, source == project ? nil : source)
  end

  private

  # nil     -> the object has no such field
  # :hidden -> the field exists but is not visible to the current user
  # String  -> the value ('' when not set)
  def own_value(customizable)
    cfv = customizable.custom_field_values.detect { |v| v.custom_field.name == FIELD_NAME }
    return nil unless cfv
    return :hidden unless customizable.visible_custom_field_values(User.current).include?(cfv)

    Array(cfv.value).reject(&:blank?).join(', ')
  end

  # Walks from the project up to the root project and returns
  # [value, project_the_value_came_from].
  def project_value(project)
    field_seen = false
    project.self_and_ancestors.reorder(lft: :desc).each do |p|
      value = own_value(p)
      return [:hidden, p] if value == :hidden
      next if value.nil?

      field_seen = true
      return [value, p] if value.present?
    end
    [field_seen ? '' : nil, nil]
  end

  # Decide by URL extension only: with "Accept: */*" respond_to would pick JSON.
  def render_value(value, inherited_from)
    if params[:format] == 'json'
      render json: { klassifikation: value.presence, inherited_from: inherited_from&.identifier }
    else
      render plain: value
    end
  end
end
