source "https://rubygems.org"

# Specify the meta-gem's dependencies in x.gemspec
gemspec

gem "x-core", path: "x-core"
gem "x-uploader", path: "x-uploader"
gem "x-objects", path: "x-objects"

gem "fiddle", ">= 1.1.2"
gem "irb", ">= 1.14.1"
gem "minitest", ">= 6"
gem "ostruct", ">= 0.6"
gem "rake", ">= 13.0.6"
gem "rubocop", ">= 1.21"
gem "rubocop-minitest", ">= 0.31"
gem "rubocop-performance", ">= 1.18"
gem "rubocop-rake", ">= 0.6"
gem "simplecov", ">= 1"
gem "standard", ">= 1.35.1"
gem "webmock", ">= 3.18.1"
gem "yard", ">= 0.9"
gem "yardstick", ">= 0.9"

# RBS and Steep run on CRuby alone, so they are left out of the bundle of any other engine, whose job runs the
# tests alone; the steep and docs jobs of CI all run on CRuby
platforms :mri do
  gem "rbs", ">= 4.0"
  gem "steep", ">= 2.0"
end
