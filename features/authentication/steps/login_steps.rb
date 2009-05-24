
Given /^I am not authenticated$/ do
  # yay!
end


Given /^I have one user "([^\"]*)" with password "([^\"]*)"$/ do |login, password|
    User.gen!(:login => login,
             :password => password,
             :password_confirmation => password)
end

Given /^I have one admin user "([^\"]*)" with password "([^\"]*)"$/ do |login, password|
    User.gen!(:admin, :login => login,
             :password => password,
             :password_confirmation => password)
end

Then /^the login request should success$/ do
  @response.status.should == 200
end