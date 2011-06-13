#!/bin/bash

IFACE="pppoe-wan"

#bandwidth
UPRATE="99000kbit"
PRIORATE0="4kbit"
PRIORATE1="512kbit"
PRIORATE2="512kbit"
PRIORATE3="512kbit"
PRIORATE4="512kbit"
PRIOICMP="20kbit"

# bursts
BURST="7k"
CBURST0="1k"
CBURST1="3k"
CBURST2="2k"
CBURST3="1k"
CBURST4="0k"

#iptables rules

iptables -F -t mangle
iptables -X -t mangle
tc qdisc del dev $IFACE root

MARKPRIO0="9"
MARKPRIO1="10"
MARKPRIO2="11"
MARKPRIO3="12"
MARKPRIO4="13"

insmod cls_fw
insmod sch_esfq
insmod sch_htb
insmod sch_sfq
insmod cls_u32
insmod sch_prio
insmod ipt_CONNMARK
insmod sch_dsmark

iptables -N MPOST_1 -t mangle
iptables -N MOUT_1 -t mangle

iptables -t mangle -A POSTROUTING -o $IFACE -j MPOST_1
iptables -t mangle -A OUTPUT -o $IFACE -j MOUT_1

iptables -A MPOST_1 -t mangle -p icmp -j MARK --set-mark $MARKPRIO0
iptables -A MPOST_1 -t mangle -p icmp -j ACCEPT

iptables -A MOUT_1 -t mangle -p icmp -j MARK --set-mark $MARKPRIO0
iptables -A MOUT_1 -t mangle -p icmp -j ACCEPT

iptables -A MPOST_1 -t mangle -p tcp --tcp-flags ACK ACK -j MARK --set-mark $MARKPRIO1
iptables -A MOUT_1 -t mangle -p tcp --tcp-flags ACK ACK -j MARK --set-mark $MARKPRIO1

iptables -A MPOST_1 -t mangle  -p tcp --dport 22 -j MARK --set-mark $MARKPRIO2
iptables -A MOUT_1 -t mangle  -p tcp --dport 22 -j MARK --set-mark $MARKPRIO2

iptables -N NON_TCP -t mangle

iptables -A MPOST_1 -t mangle -j NON_TCP
iptables -A MOUT_1 -t mangle -j NON_TCP

iptables -A NON_TCP -t mangle -p tcp -j RETURN
iptables -A NON_TCP -t mangle -m mark --mark 0 -j MARK --set-mark $MARKPRIO1

iptables -A MPOST_1 -t mangle -p tcp -m tos --tos Minimize-Delay -m mark --mark 0 -j MARK --set-mark $MARKPRIO1
iptables -A MPOST_1 -t mangle -p tcp -m tos --tos Maximize-Throughput -m mark --mark 0 -j MARK --set-mark $MARKPRIO2
iptables -A MPOST_1 -t mangle -p tcp -m tos --tos Minimize-Cost -m mark --mark 0 -j MARK --set-mark $MARKPRIO4

iptables -A MOUT_1 -t mangle -p tcp -m tos --tos Minimize-Delay -m mark --mark 0 -j MARK --set-mark $MARKPRIO1
iptables -A MOUT_1 -t mangle -p tcp -m tos --tos Maximize-Throughput -m mark --mark 0 -j MARK --set-mark $MARKPRIO2
iptables -A MOUT_1 -t mangle -p tcp -m tos --tos Minimize-Cost -m mark --mark 0 -j MARK --set-mark $MARKPRIO4

iptables -A MPOST_1 -t mangle -j RETURN
iptables -A MOUT_1 -t mangle -j RETURN

# tc
tc qdisc add dev $IFACE root handle 1:0 htb default 203 r2q 50

tc class add dev $IFACE parent 1:0 classid 1:1 htb rate $UPRATE burst $BURST cburst $CBURST1 overhead 20

# classes
tc class add dev $IFACE parent 1:1 classid 1:200 htb rate $PRIORATE0 ceil $PRIOICMP cburst $CBURST0 prio 0 mtu 1492
tc class add dev $IFACE parent 1:1 classid 1:201 htb rate $PRIORATE1 ceil $UPRATE cburst $CBURST1 prio 1 mtu 1492
tc class add dev $IFACE parent 1:1 classid 1:202 htb rate $PRIORATE2 ceil $UPRATE cburst $CBURST2 prio 2 mtu 1492
tc class add dev $IFACE parent 1:1 classid 1:203 htb rate $PRIORATE3 ceil $UPRATE cburst $CBURST3 prio 3 mtu 1492
tc class add dev $IFACE parent 1:1 classid 1:204 htb rate $PRIORATE4 ceil $UPRATE cburst $CBURST4 prio 4 mtu 1492

# filters
tc filter add dev $IFACE parent 1:0 protocol ip prio 0 handle $MARKPRIO0 fw classid 1:200
tc filter add dev $IFACE parent 1:0 protocol ip prio 1 handle $MARKPRIO1 fw classid 1:201
tc filter add dev $IFACE parent 1:0 protocol ip prio 2 handle $MARKPRIO2 fw classid 1:202
tc filter add dev $IFACE parent 1:0 protocol ip prio 3 handle $MARKPRIO3 fw classid 1:203
tc filter add dev $IFACE parent 1:0 protocol ip prio 4 handle $MARKPRIO4 fw classid 1:204

# qdiscs
tc qdisc add dev $IFACE parent 1:200 esfq perturb 10
tc qdisc add dev $IFACE parent 1:201 esfq perturb 10
tc qdisc add dev $IFACE parent 1:202 esfq perturb 10
tc qdisc add dev $IFACE parent 1:203 esfq perturb 10
tc qdisc add dev $IFACE parent 1:204 esfq perturb 10
