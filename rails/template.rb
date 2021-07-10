# frozen_string_literal: true

gem 'amazing_print'
gem 'oj'
gem 'pundit' if (install_pundit = yes?('Install Pundit? (y/n)'))
gem 'seedbank'

if yes?('Install ViewComponent? (y/n)')
  gem 'view_component'

  create_file 'app/components/application_component.rb', <<~RUBY
    # frozen_string_literal: true

    class ApplicationComponent < ViewComponent::Base
      include ApplicationHelper
    end
  RUBY
end

gem_group :development, :test do
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
end

gem_group :development do
  gem 'annotate'
  gem 'solargraph', require: false
end

gem_group :test do
  gem 'rspec-rails'
end

run 'bundle install -j $(nproc)'
run 'bundle binstub rspec-core'
run 'spring stop'

generate 'annotate:install'
generate 'pundit:install' if install_pundit
generate 'rspec:install'

# Rename `user` to `current_user` in ApplicationPolicy.
gsub_file 'app/policies/application_policy.rb', /user/, 'current_user' if install_pundit

# Disable classified-sort on annotate_models.
gsub_file 'lib/tasks/auto_annotate_models.rake',
          "'classified_sort'             => 'true'",
          "'classified_sort'             => 'false'"

# Install FactoryBot and Time helpers for RSpec.
inject_into_file 'spec/rails_helper.rb', after: "RSpec.configure do |config|\n" do <<~RUBY
  config.include ActiveSupport::Testing::TimeHelpers
  config.include FactoryBot::Syntax::Methods

RUBY
end

# Remove ActiveRecord fixtures.
gsub_file 'spec/rails_helper.rb',
          "  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures\n" \
          "  config.fixture_path = \"\#{::Rails.root}/spec/fixtures\"\n\n",
          ''

if install_pundit
  # Add Pundit DSL helper for RSpec.
  inject_into_file 'spec/rails_helper.rb', after: "require 'rspec/rails'\n" do <<~RUBY
    require 'pundit/rspec'
  RUBY
  end
end

# Add RSpec hooks to run seeds and clean up file uploads.
inject_into_file 'spec/rails_helper.rb', after: "# config.filter_gems_from_backtrace(\"gem name\")\n" do <<~RUBY

  # Seed database with initial data before tests.
  config.before(:suite) do
    require 'rake'

    Rails.application.class.load_tasks
    Seedback.load_tasks

    Rake::Task['db:seed'].invoke
  end

  # Remove any uploaded files created during tests.
  config.after(:suite) do
    FileUtils.rm_rf(Rails.root.join('tmp', 'storage'))
  end
RUBY
end

# Configure generators, i18n storage paths, ActiveStorage URLs, and schema format.
inject_into_file 'config/application.rb', after: "# config.eager_load_paths << Rails.root.join(\"extras\")\n" do <<~RUBY

  # Dump structure file in PostgreSQL native format.
  config.active_record.schema_format = :sql

  # Mount ActiveStorage routes at /files/...
  config.active_storage.routes_prefix = '/files'

  # Load translations from subdirectories of `config/locales` as well.
  config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]

  config.generators do |g|
    g.orm                 :active_record
    g.fixture_replacement :factory_bot
    g.test_framework      :rspec, request_specs: false, helper_specs: false
    g.helper              false
    g.assets              false
  end
RUBY
end

%w[development.rb test.rb].each do |filename|
  gsub_file "config/environments/#{filename}",
            '# config.i18n.raise_on_missing_translations = true',
            'config.i18n.raise_on_missing_translations = true'

  gsub_file "config/environments/#{filename}",
            '# config.action_view.annotate_rendered_view_with_filenames = true',
            'config.action_view.annotate_rendered_view_with_filenames = true'
end

inject_into_file 'config/environments/test.rb', before: "end\n" do <<-RUBY

  # Tell Active Job not to process enqueued jobs.
  # The :test queue adapter accumulates jobs in the
  # ActiveJob::Base.queue_adapter.enqueued_jobs array.
  config.active_job.queue_adapter = :test
RUBY
end

# Remove unused requires from file.
gsub_file 'config/application.rb',
          /# require [^\n]+\n/,
          ''

# Add a base class for Service objects.
create_file 'app/services/application_service.rb', <<~RUBY
  # frozen_string_literal: true

  class ApplicationService
  end
RUBY

if yes?('Configure Rubocop? (y/n)')
  create_file '.rubocop.yml', File.read("#{ENV['HOME']}/.dotfiles/rails/.rubocop.yml")

  run 'bundle binstub rubocop'
  run 'bin/rubocop -A'
end
