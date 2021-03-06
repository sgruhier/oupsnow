require File.join( File.dirname(__FILE__), '..', "spec_helper" )

describe Project do

  it "should be valid" do
    pr = make_project
    pr.should be_valid
    pr.project_members.should_not be_empty
  end

  it "should invalid without name" do
    project = make_project(:name => nil)
    project.should_not be_valid
    project.errors.on(:name).should_not be_blank
  end

  it "should have name uniq" do
    project_1 = make_project
    project_2 = make_project(:name => project_1.name)
    project_2.should_not be_valid
    project_2.errors.length.should == 1
    project_2.errors.on(:name).should_not be_blank
  end

  it "should not valid project without member" do
    make_project(:project_members => []).should_not be_valid
  end

  it "should not valid project without admin member" do
    project_member = ProjectMember.make(:user => nil,
                                        :function => (Function.not_admin || Function.make))
    make_project(:project_members => [project_member]).should_not be_valid
  end

  it 'should create an event about creation when a project is create' do
    lambda do
      make_project
    end.should change(Event, :count).by(1)
  end

  it 'should add an event about change if project is update' do
    project = make_project
    lambda do
      project.name = 'new_title'
      project.user_update = project.project_members.first.user
      project.save
    end.should change(Event, :count).by(1)
  end

  describe 'destroy project' do
    before :each do
      @project = make_project
      Ticket.make(:project => @project)
      @project.milestones << Milestone.make
    end

    it 'should destroy himself' do
      lambda do
        @project.destroy
      end.should change(Project, :count).by(-1)
    end

    it 'should destroy all Ticket related to this project' do
      @project.tickets.should_not be_empty
      lambda do
        @project.destroy
      end.should change(Ticket, :count).by(-1)
      Ticket.first(:conditions => {:project_id => @project.id}).should be_nil
    end

    it 'should destroy all Event related to this project' do
      @project.events.should_not be_empty
      lambda do
        @project.destroy
      end.should change(Event, :count)
      Event.first(:conditions => {:project_id => @project.id}).should be_nil
    end

    it 'should destroy all Milestone related to this project' do
      @project.milestones.should_not be_empty
      lambda do
        @project.destroy
      end.should change(Milestone, :count)
      Milestone.first(:conditions => {:project_id => @project.id}).should be_nil
    end
  end

  describe '#has_member?' do
    before do
      @user = User.make
      @project = make_project
      @function = Function.first || Function.make
      @project.add_member(@user, Function.first)
    end

    it 'should return true if has member' do
      @project.has_member?(@user).should be_true
    end

    it 'should return false if has not this member' do
      user = User.make
      @project.has_member?(user).should_not be_true
    end
  end

  describe 'Project#new_with_admin_member' do
    before :each do
      Function.destroy_all
      @function = Function.make(:admin)
      @admin_user = User.make(:admin)
      @user = User.make
    end

    it 'should create a project with user like admin function' do
      pr = Project.new_with_admin_member({'name' => 'first project',
                                    'description' => 'so cool'},
                                    @user)
      pr.should be_new
      pr.project_members.should have(1).items
      pr.project_members.first.function_id.should == Function.admin._id
      pr.project_members.first.user_id.should == @user._id
    end
  end

  describe "change_functions" do

    before do
      @project = make_project # there are 1 user by default
      @function = Function.make
      @admin_member = @project.project_members.first
      @user_member =  ProjectMember.make(:function => @function)
      @project.project_members << @user_member
      @project.save
      @project.reload
    end

    it 'should made nothing if no change' do
      @project.change_functions({@admin_member.id => Function.admin.id,
                                @user_member.id => @function.id}).should be_true
      @project.project_members.first.function_id.should == Function.admin._id
      @project.project_members.second.function_id.should == @function._id
    end

    it 'should change if change needed' do
      @project.change_functions({@admin_member.id => Function.admin.id,
                                @user_member.id => Function.admin.id}).should be_true
      @project.project_members.first.function_id.should == Function.admin._id
      @project.project_members.second.function_id.should == Function.admin._id
    end

    it 'should made nothing if no admin define' do
      @project.change_functions({@admin_member.id => @function.id,
                                @user_member.id => Function.make.id}).should be_false
      @project.project_members.first.function_id.should == Function.admin._id
      @project.project_members.second.function_id.should == @function._id
    end
  end

  describe '#project_membership(user)' do
    before do
      @project = make_project
      @user = User.make
    end
    it 'should return project_member with this user if user member of this project' do
      @member = @project.project_members.build(:user => @user, :function => Function.make)
      @project.save! && @user.reload
      @project.project_membership(@user).should == @member
    end

    it 'should return nil if user no member of this project' do
      @project.project_membership(@user).should be_nil
    end
  end

  describe '#update_tag_counts' do
    before do
      @project = make_project
      @project.tickets.should be_empty
      @project.update_tag_counts
      @project.tag_counts.should be_empty
    end
    it 'should update tag_counts to empty if no tag in tickets' do
      make_ticket(:project => @project, :tag_list => '')
      @project.update_tag_counts
      @project.tag_counts.should be_empty
    end

    it 'should update tag_counts if ticket contains tags' do
      make_ticket(:project => @project, :tag_list => 'foo')
      @project = Project.find(@project._id)
      @project.update_tag_counts
      @project.tag_counts.should == {'foo' => 1}

      make_ticket(:project => @project, :tag_list => 'foo,bar')
      @project = Project.find(@project._id)
      @project.update_tag_counts
      @project.tag_counts.should == {'foo' => 2, 'bar' => 1}

      make_ticket(:project => @project, :tag_list => 'bar')
      @project = Project.find(@project._id)
      @project.update_tag_counts
      @project.tag_counts.should == {'foo' => 2, 'bar' => 2}

      make_ticket(:project => @project, :tag_list => 'foo,bar,baz')
      @project = Project.find(@project._id)
      @project.update_tag_counts
      @project.tag_counts.should == {'foo' => 3, 'bar' => 3, 'baz' => 1}
    end
  end

  describe '#new_num_ticket' do
    before do
      @project = make_project
    end
    it 'should be nil if no ticket' do
      @project.num_ticket.should be_nil
    end

    it 'should be 2 if one new_num ask' do
      @project.new_num_ticket.should == 1
      @project.num_ticket.should == 2
    end

    it 'should be 3 if two ticket' do
      @project.new_num_ticket.should == 1
      @project.new_num_ticket.should == 2
      @project.num_ticket.should == 3
    end
  end

end
