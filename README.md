# RangePinger
RangePinger is a bash script designed for checking the reachability of a range of IP addresses. 
# Usage
**checking ranges from the pipeline**

echo "XX.XX.XX.XX/18" | ./rp.sh -t 1000 

**This script can be combined with other tools like  asnmap and httpx**

asnmap -d example.com | ./rp.sh -t 2000 | httpx -silent -probe
