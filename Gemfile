source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.0"

gem "rails", "~> 7.1.0"
gem "pg", "~> 1.1"
gem "puma", "~> 6.0"
gem "bootsnap", ">= 1.4.4", require: false
gem "rack-cors"
gem "bcrypt", "~> 3.1.7"
gem "jwt"
gem "redis", "~> 4.0"
gem "dotenv-rails"
gem "wicked_pdf"
gem "wkhtmltopdf-binary"
gem "htmltoword"
gem "pdf-reader"
gem "ruby-openai"
gem "httparty"
gem "kaminari"
gem "razorpay"

group :development, :test do
  gem "byebug", platforms: [:mri, :windows]
  gem "rspec-rails"
  gem "factory_bot_rails"
end

group :development do
  gem "listen", "~> 3.3"
  gem "spring"
end