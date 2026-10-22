#!/bin/bash
# Network Guard — virtual network setup
# Creates 3 isolated namespaces: gateway, trusted device, IoT device

ip netns del ns_gateway 2>/dev/null
ip netns del ns_trusted 2>/dev/null
ip netns del ns_iot 2>/dev/null

ip netns add ns_gateway
ip netns add ns_trusted
ip netns add ns_iot

ip link add veth_gw_trusted type veth peer name veth_trusted_gw
ip link add veth_gw_iot type veth peer name veth_iot_gw

ip link set veth_gw_trusted netns ns_gateway
ip link set veth_trusted_gw netns ns_trusted
ip link set veth_gw_iot netns ns_gateway
ip link set veth_iot_gw netns ns_iot

ip netns exec ns_gateway ip addr add 10.0.1.1/24 dev veth_gw_trusted
ip netns exec ns_gateway ip addr add 10.0.2.1/24 dev veth_gw_iot
ip netns exec ns_trusted ip addr add 10.0.1.2/24 dev veth_trusted_gw
ip netns exec ns_iot     ip addr add 10.0.2.2/24 dev veth_iot_gw

ip netns exec ns_gateway ip link set veth_gw_trusted up
ip netns exec ns_gateway ip link set veth_gw_iot up
ip netns exec ns_trusted ip link set veth_trusted_gw up
ip netns exec ns_iot     ip link set veth_iot_gw up
ip netns exec ns_gateway ip link set lo up
ip netns exec ns_trusted ip link set lo up
ip netns exec ns_iot     ip link set lo up

ip netns exec ns_iot     ip route add default via 10.0.2.1
ip netns exec ns_trusted ip route add default via 10.0.1.1
ip netns exec ns_gateway sysctl -w net.ipv4.ip_forward=1

echo "[+] Network ready!"
echo "    Gateway:  10.0.1.1 / 10.0.2.1"
echo "    Trusted:  10.0.1.2"
echo "    IoT:      10.0.2.2"
