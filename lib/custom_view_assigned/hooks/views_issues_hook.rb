class ViewsIssueHook < Redmine::Hook::Listener
  def view_issues_form_details_bottom(context)
    users = RedmineCustomViewAssigned.filtering_users == 'true' ?
        helpers.assignable_users(context[:issue]) :
        context[:issue].assignable_users

    case RedmineCustomViewAssigned.grouping_mode
      when 'groups' then
        context[:controller].send(
            :render_to_string, {
                                 :partial => 'issues/assigned_grouping',
                                 :layout => false,
                                 :locals => {:groups => grouping_by_group(users)}
                             })
      when 'roles' then
        context[:controller].send(
            :render_to_string, {
                                 :partial => 'issues/assigned_grouping',
                                 :layout => false,
                                 :locals => {:groups => grouping_by_role(users,context[:issue])}
                             })
      else
        context[:controller].send(
            :render_to_string, {
                                 :partial => 'issues/assigned_not_grouping',
                                 :layout => false,
                                 :locals => {:users => users}
                             })
    end
  end

  private
  def add_entry_to_group(groups, group_name, entry_id, entry_name)
    unless groups.has_key? group_name
      groups[group_name] = []
    end

    groups[group_name] << {id: entry_id, name: entry_name}
  end

  def grouping_by_group(users)
    groups = {}

    label_no_group = l(:label_custom_view_assigned_no_group)
    # Don't display <<me>> entry as the user could be not assignable directly
    # add_entry_to_group(groups, label_no_group, User.current.id, "<< #{l(:label_me)} >>")

    users.each do |user|
      if user.instance_of? Group
        # add_entry_to_group(groups, h(l(:label_group_plural)), user.id, user.name)
        add_entry_to_group(groups, l(:label_group_plural), user.id, user.name)
      else
        if user.groups.empty?
          add_entry_to_group(groups, label_no_group, user.id, user.name)
        end

        user.groups.each do |user_group|
          add_entry_to_group(groups, user_group.name, user.id, user.name)
        end
      end
    end

    groups
  end

  # Thanks to ithwsw (https://github.com/ithwsw/) for the quick fix below
  # Quick fix for the error message: "builtin not found" while running the method "def <=>(role)" in app/modles/roles.rb
  # Remark following line to remove "Current user" in groups in order to prevent error occured. 
  # add_entry_to_group(groups, l(:label_custom_view_assigned_current_user), User.current.id, "<< #{l(:label_me)} >>")
  def grouping_by_role(users,issue)
    groups = {}
    current_project = Project.find(issue.project_id)
    
    # add_entry_to_group(groups, l(:label_custom_view_assigned_current_user), User.current.id, "<< #{l(:label_me)} >>")

    # Two calculation modes:
	# explicative example:
	# Project X has these roles: "Client", "Manager", "Programmer"
	#   "Client" creates issues with NEW status
	#   Workflows:
	#     "Manager" can change status from NEW to ASSIGNED
	#     "Programmer" can change from ASSIGNED to RESOLVED
	#     "Client" can change status from RESOLVED to CLOSED
	#   -OLD MODE- When "Manager" changes status to ASSIGNED, in the "assignee" dropdown list only members with "Programmer"
	#    role are available, because in the workflows only programmers can change from ASSIGNED to other statuses.
	#   -NEW MODE- When "Manager" changes status to ASSIGNED, in the "assignee" dropdown list only members with "Manager"
	#    role are available, because in the workflows only managers can change from other statuses to ASSIGNED
    workflow_rules = case RedmineCustomViewAssigned.calculation_mode
      when 'old' then
        WorkflowRule.where('old_status_id = ? AND tracker_id = ? AND type = ?', issue.status_id, issue.tracker_id, WorkflowTransition).group(:role_id).pluck(:role_id)
      else
        WorkflowRule.where('new_status_id = ?', issue.status_id).group(:role_id).pluck(:role_id)
    end
    target_roles = MemberRole.select { |role| workflow_rules.include?(role.role_id) }.map(&:role_id)

    Role.order(:position).each do |role|
      if ((target_roles.include? role.id) || !(RedmineCustomViewAssigned.filtering_users))
        users.each do |user|
          if (!(user.instance_of? Group) && (user.roles_for_project(current_project).include? role))
            add_entry_to_group(groups, role, user.id, user.name)
          # end
          elsif ((user.instance_of? Group) && (user.members.any? { |member| member.roles.include? role}))
            if RedmineCustomViewAssigned.differentiate_groups
              add_entry_to_group(groups, role, user.id, "[#{l:label_custom_view_assigned_group_prefix}] " << user.name)
            else
              add_entry_to_group(groups, role, user.id, user.name)
            end
          end
        end
      end
    end

    groups
  end
end

class InitHelpers
  include Singleton
  include CustomViewAssignedHelper
end

def helpers
  InitHelpers.instance
end
