#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
yarn install
yarn build:css
bundle exec rails assets:precompile
bundle exec rails db:create db:migrate db:seed