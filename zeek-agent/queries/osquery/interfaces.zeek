##! Query interfaces activity.

@load zeek-agent

module AgentInterfaces;

export {

	redef enum Log::ID += { LOG };

	type Info: record {
		ts:        time   &log;
		host:      string &log;
                hostname:  string &log;
		interface: string &log;
		mac:       string &log &optional;
		ip:        addr   &log;
		mask:      addr   &log &optional;
	};
}


event AgentInterfaces::new_interface(result: ZeekAgent::Result, interface: string, mac: string, ip: string, mask: string)
	{
	# Remove interface name from IP and turn the string into an ip address
	local clean_ip = to_addr(split_string(ip, /\%/)[0]);

	local info = Info($ts = network_time(),
	                  $host = result$host,
			  $hostname = ZeekAgent::getHostInfo(result$host)$hostname,
	                  $interface = interface,
	                  $ip = clean_ip);

	if ( mac != "00:00:00:00:00:00" )
		info$mac = mac;

	if ( mask != "" )
		info$mask = to_addr(mask);

	Log::write(LOG, info);
	}


event zeek_init() &priority=10
	{
	Log::create_stream(LOG, [$columns=Info, $path="agent-interfaces"]);

	local query = ZeekAgent::Query($ev=AgentInterfaces::new_interface,
	                                $query="SELECT d.interface, d.mac, a.address, a.mask FROM interface_addresses AS a INNER JOIN interface_details AS d ON a.interface=d.interface",
	                                $utype=ZeekAgent::ADD);
	ZeekAgent::subscribe(query);
	}
