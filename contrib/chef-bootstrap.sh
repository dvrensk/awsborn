#!/bin/bash

echo '------------------'
echo 'Bootstrapping Chef'
echo

aptitude -y update
aptitude -y install gcc g++ curl build-essential \
  libxml-ruby libxml2-dev \
  ruby irb ri rdoc ruby1.8-dev libzlib-ruby libyaml-ruby libreadline-ruby \
  libruby libruby-extras libopenssl-ruby \
  libdbm-ruby libdbi-ruby libdbd-sqlite3-ruby \
  sqlite3 libsqlite3-dev libsqlite3-ruby

curl -L 'http://rubyforge.org/frs/download.php/69365/rubygems-1.3.6.tgz' | tar zxf -
cd rubygems* && ruby setup.rb --no-ri --no-rdoc

ln -sfv /usr/bin/gem1.8 /usr/bin/gem

gem install chef ohai --no-ri --no-rdoc

echo
echo 'Bootstrapping Chef - done'
echo '-------------------------'
