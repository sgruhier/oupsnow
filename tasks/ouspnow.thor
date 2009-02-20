$: << File.join("doc")
require 'rubygems'
require 'rdoc/rdoc'
require 'fileutils'
require 'erb'

module OupsNow

  class Bootstrap < Thor

    desc 'first_value', 'create first user and admin function'
    def first_value
      require 'merb-core'
      ::Merb.start_environment(
        :environment => ENV['MERB_ENV'] || 'development')
      User.create(:login => 'admin', 
                  :email => 'admin@admin.com',
                  :password => 'oupsnow',
                  :password_confirmation => 'oupsnow',
                  :global_admin => true)
      Function.create(:name => 'Admin', :project_admin => true)
      Function.create(:name => 'Developper', :project_admin => false)
      State.create(:name => 'new')
      State.create(:name => 'open')
      State.create(:name => 'resolved', :closed => true)
      State.create(:name => 'hold', :closed => true)
      State.create(:name => 'closed', :closed => true)
      State.create(:name => 'invalid', :closed => true)
      Priority.create(:name => 'Low')
      Priority.create(:name => 'Normal')
      Priority.create(:name => 'High')
      Priority.create(:name => 'Urgent')
    end

  end

  class Populate < Thor

    desc 'generate_some_data', 'generate some data'
    def generate_some_data
      require 'merb-core'
      ::Merb.start_environment(
        :environment => ENV['MERB_ENV'] || 'development')
      require 'spec/fixtures'
      3.of{
        p = Project.gen!
        (1..3).of {
          Milestone.gen!(:project_id => p.id)
        }
        (20..40).of {
          Ticket.gen(
            :project_id => p.id,
            :member_create_id => p.members.first.user_id)
        }
        (20..40).of {
          t = p.tickets[rand(p.tickets.size)]
          t.reload
          t.generate_update({
            :title => rand(2) == 0 ? t.title : /\w+/.gen,
            :state_id => rand(2) == 0 ? t.state_id : State.all[rand(State.count)],
            :tag_list => rand(2) == 0 ? t.frozen_tag_list : (0..3).of { /\w+/.gen }.join(','),
            :member_assigned_id => rand(2) == 0 ? t.member_assigned_id : p.members[p.members.size],
            :milestone_id => rand(2) == 0 ? t.milestone_id : p.milestones[p.milestones.size],
            :description =>rand(2) == 0 ? "" : (0..3).of { /[:paragraph:]/.generate }.join("\n"),
          }, p.users[rand(p.users.size)])
        }
      }
    end
  end

  class Converter < Thor

    desc 'convert_from_redmine', 'convert from Redmine'
    def convert_from_redmine
      require 'merb-core'
      require 'merb_datamapper'
      ::Merb.start_environment(
        :environment => ENV['MERB_ENV'] || 'development')
      ::Merb::Orms::DataMapper.setup_connections
      require 'tasks/converter/redmine.rb'
      RedmineConverter.convert
    end
  end
end
