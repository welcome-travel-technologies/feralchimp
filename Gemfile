source "https://rubygems.org"
gemspec

gem "rake"
group :development do
  gem "rubocop", :github => "bbatsov/rubocop", :require => false
  gem "pry", {
    :require => false
  }
end

group :test do
  gem "webmock", :require => false
  gem "codeclimate-test-reporter", :require => false
  gem "luna-rspec-formatters", :require => false
  gem "rspec", :require => false
end
