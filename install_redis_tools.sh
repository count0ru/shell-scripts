apt-get update
apt-get install ruby vim wget redis-tools -y
wget http://download.redis.io/redis-stable/src/redis-trib.rb
chmod +x redis-trib.rb
gem install redis
