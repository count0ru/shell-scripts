apt-get update
apt-get install ruby vim wget redis-tools host -y
wget http://download.redis.io/redis-stable/src/redis-trib.rb
chmod +x redis-trib.rb
gem install redis

#show current cluster state 
alias redis-cluster-state='for number in " " -{1..6}; do echo -n "redis$number "; redis-cli -h redis$number cluster info | grep cluster_state; done'

for number in " " -{1..6}; do redis-cli -h redis$number cluster reset soft; done
$(echo "./redis-trib.rb create --replicas 0 $(echo $(for number in " " -{1..6}; do host redis$number | awk '{print $4}'; done | sed ':a;N;$!ba;s/\n/:6379 /g' ):6379)")      
