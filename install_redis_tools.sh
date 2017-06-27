apt-get update
apt-get install ruby vim wget redis-tools host -y
cd $HOME
wget http://download.redis.io/redis-stable/src/redis-trib.rb
chmod +x redis-trib.rb
gem install redis

#aliases and functions for redis cluster
alias redis-cluster-state='for number in " " -{1..6}; do echo -n "redis$number "; redis-cli -h redis$number cluster info | grep cluster_state; done'
alias redis-cluster-reset='for number in " " -{1..6}; do echo -n "redis$number "; redis-cli -h redis$number cluster reset soft; done'
function redis-cluster-cmd() { for number in " " -{1..6}; do echo -n "redis$number "; redis-cli -h redis$number $@; done }  

#remove user input from redis_trib
sed -i 's/yes_or_die "Fix these slots by covering with a random node?"/#yes_or_die "Fix these slots by covering with a random node?"/' redis-trib.rb 

$(echo "./redis-trib.rb create --replicas 0 $(echo $(for number in " " -{1..6}; do host redis$number | awk '{print $4}'; done | sed ':a;N;$!ba;s/\n/:6379 /g' ):6379)")      

#generate test data for redis
for i in 32 {101..106}; 
do
  for j in {1..99};
  do
    redis-cli -c -h 10.0.0.$i set key$i$j value$i$j;
  done
done
