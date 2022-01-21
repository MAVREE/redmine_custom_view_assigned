module RedmineCustomViewAssigned
  class << self
    def filtering_users
      Setting.plugin_redmine_custom_view_assigned['filtering_users']
    end

    def calculation_mode
      Setting.plugin_redmine_custom_view_assigned['calculation_mode']
    end

    def grouping_mode
      Setting.plugin_redmine_custom_view_assigned['grouping_mode']
    end

    def differentiate_groups
      Setting.plugin_redmine_custom_view_assigned['differentiate_groups']
    end

    def filtering_enabled_projects
      Setting.plugin_redmine_custom_view_assigned['filtering_enabled_projects']
    end

    def grouping_enabled_projects
      Setting.plugin_redmine_custom_view_assigned['grouping_enabled_projects']
    end
  end
end
