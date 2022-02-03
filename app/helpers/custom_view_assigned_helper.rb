module CustomViewAssignedHelper
  def assignable_users(issue)
    current_project = Project.find(issue.project_id)

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
    target_roles = MemberRole.select { |role| workflow_rules.include?(role.role_id) }.map(&:member_id).sort
    target_members = Member.select { |member| target_roles.include?(member.id) &&
        member.project_id == current_project.id }.map(&:user_id).sort

    types = ['User']
    types << 'Group' if Setting.issue_group_assignment?

    scope = current_project.memberships.active
    users = scope.select { |m| types.include?(m.principal.type) &&
        m.roles.detect(&:assignable) && target_members.include?(m.principal.id) }.map(&:principal).sort

    author = User.find(issue.author_id)
    assigned_to = Principal.find_by_id(issue.assigned_to_id) if issue.assigned_to_id

    # don't add the author regardless
    # users << author if author
    users << assigned_to if assigned_to

    users.uniq.sort
  end
end
