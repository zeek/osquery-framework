#! Logs process open sockets activity

@load zeek-agent

module zeek_agent;

export {
	## Event to indicate that a new socket connection was created on a host
	##
	## <params missing>
	global process_open_socket_added: event(t: time, host_id: string, pid: int, fd: int, family: int, protocol: int, local_address: string, remote_address: string, local_port: int, remote_port: int);
	
	## Event to indicate that an existing socket connection terminated on a host
	##
	## <params missing>
	global process_open_socket_removed: event(t: time, host_id: string, pid: int, fd: int, family: int, protocol: int, local_address: string, remote_address: string, local_port: int, remote_port: int);
}

event zeek_agent::table_process_open_sockets(resultInfo: zeek_agent::ResultInfo,
pid: int, fd: int, family: int, protocol: int, local_address: string, remote_address: string, local_port: int, remote_port: int) {
	if (resultInfo$utype == zeek_agent::ADD && pid != -1) {
		event zeek_agent::process_open_socket_added(network_time(), resultInfo$host, pid, fd, family, protocol, local_address, remote_address, local_port, remote_port);
	}
	if (resultInfo$utype == zeek_agent::REMOVE) {
		event zeek_agent::process_open_socket_removed(network_time(), resultInfo$host, pid, fd, family, protocol, local_address, remote_address, local_port, remote_port);
	}
}

event zeek_init() {
	local query = [$ev=zeek_agent::table_process_open_sockets,$query="SELECT pid, fd, family, protocol, local_address, remote_address, local_port, remote_port FROM process_open_sockets WHERE family=2", $utype=zeek_agent::BOTH, $inter=zeek_agent::QUERY_INTERVAL];
	zeek_agent::subscribe(query);
}