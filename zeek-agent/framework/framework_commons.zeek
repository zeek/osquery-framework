module ZeekAgent;

# Increase network session timeouts for better attribution
# redef tcp_SYN_timeout = 10sec;
# redef tcp_attempt_delay = 10sec;
# redef tcp_close_delay = 10sec;
# redef tcp_connection_linger = 10sec;
# redef tcp_inactivity_timeout = 10sec;
# redef tcp_reset_delay = 10sec;
# redef tcp_session_timer = 10sec;

export {
	## The local IP Broker is listening on
	const broker_ip = "0.0.0.0" &redef;
	
	## The local port Broker is listening on
	const broker_port = 9999/tcp &redef;
	
	## The local name of Zeek
	const endpoint_name = "ZeekMaster" &redef;
	
	## The remote IP Broker is connecting to
	const backend_ip = "0.0.0.0" &redef;
	
	## The remote port Broker is connecting to
	const backend_port = 9999/tcp &redef;
	
	# Topic prefix used for all topics in zeek-agent communication
	const TopicPrefix = "/zeek/zeek-agent" &redef;
	
	# Topic for individual zeeks
	const ZeekIndividualTopic = fmt("%s/zeek",TopicPrefix) &redef;
	# Topic to address all zeeks
	const ZeekBroadcastTopic = fmt("%s/zeeks",TopicPrefix) &redef;
	# Individual channel of this zeek instance
	const Zeek_ID_Topic = fmt("%s/%s",ZeekIndividualTopic,endpoint_name) &redef; 
	
	# Topic for individual hosts
	const HostIndividualTopic = fmt("%s/host",TopicPrefix) &redef;
	# Topic for groups
	const HostGroupTopic = fmt("%s/group",TopicPrefix) &redef;
	# Topic to address all hosts
	const HostBroadcastTopic = fmt("%s/hosts",TopicPrefix) &redef;
	
	# Topic to which zeeks send announce messages
	const ZeekAnnounceTopic = fmt("%s/zeek_announce",TopicPrefix) &redef;
	# Topic to which hosts send announce messages
	const HostAnnounceTopic = fmt("%s/host_announce",TopicPrefix) &redef;
	
	## The zeek-agent logging stream identifier.
	redef enum Log::ID += { LOG };
	
	## A record type containing the column fields of the zeek-agent log.
	type Info: record {
		## The network time at which a zeek-agent activity occurred.
		ts:                  time   &log;
		## The scope of the message. Can be 'local' to indicating a message relevant for
		## this node only. 'zeek' indicates interfaction with other zeek nodes and
		## 'zeek-agent' indicates interaction with zeek-agents.
		source:              string &log;
		## The peer name (if any) with which a communication event is concerned.
		peer:                string &log &optional;
		## The severity of the communication event message.
		level:               string &log &optional;
		## The main log message.
		message:             string &log;
	};
	
	## Type defining the type of zeek-agent change we are interested in.
	type UpdateType: enum {
		## Report the initial set of results. For purposes of scheduled queries,
		## this behaves the same as "BOTH". It is primarily used when recieiving
		INITIAL,
		ADD,      ##< Report new elements.
		REMOVE,   ##< Report removed element.
		BOTH,     ##< Report both new and removed elements.
		SNAPSHOT  ##< Report the current status at query time.
	};
	
	## Type defining a SQL query and schedule/execution parameters to be send to hosts.
	type Query: record {
		## The zeek-agent SQL query selecting the activity to subscribe to.
		query: string;
		## The type of update to report.
		utype: UpdateType &default=BOTH;
		## The interval of the query
		inter: interval &optional &default=ZeekAgent::default_query_interval;
		## The Broker topic THEY send the query result to
		resT: string &default=Zeek_ID_Topic;
		## The Zeek event to execute when receiving updates.
		ev: any &optional;
		## A cookie we can set to match the result event
		cookie: string &default="";
	};
	
	## Type defining the event header of responses
	type Result: record {
		host:   string;
		utype:  UpdateType;
		cookie: string &optional;
	};
	
	## Event that signals the connection of a new zeek-agent
	##
	## client_id: An id that uniquely identifies an zeek-agent
	global host_connected: event (host_id: string);
	
	## Event that signals the disconnection of an zeek-agent
	##
	## client_id: An id that uniquely identifies an zeek-agent
	global host_disconnected: event (host_id: string);
	
	## Event that signals the connection of a new bro
	##
	## client_id: An id that uniquely identifies a bro
	global bro_connected: event (zeek_id: string);
	
	## Event that signals the disconnection of a bro
	##
	## client_id: An id that uniquely identifies a bro
	global bro_disconnected: event (zeek_id: string);
	
	## Log a message of local scope for this zeek node
	##
	## level: the severity of the message
	## msg: the message content
	global log_local: function(level: string, msg: string, log: any &default=LOG);
	
	## Log a message with scope including other zeek nodes
	##
	## level: the severity of the message
	## peer: the identifier of the other zeek
	## msg: the message content
	global log_zeek: function(level: string, peer: string, msg: string, log: any &default=LOG);
	
	## Log a message with scope including zeek-agent nodes
	##
	## level: the severity of the message
	## peer: the identifier for the zeek-agent or group 
	## msg: the message content
	global ZeekAgent::log: function(level: string, peer: string, msg: string, log: any &default=LOG);
	
	## Comparison of two queries to be equal
	global same_event: function (q1: Query, q2: Query): bool;
}

function log_local(level: string, msg: string, log: any)
	{
	Log::write(log, Info($ts = network_time(),
	                     $level = level,
	                     $source = "local",
	                     $peer = endpoint_name,
	                     $message = msg));
	}

function log_zeek(level: string, peer: string, msg: string, log: any)
	{
	Log::write(log, Info($ts = network_time(),
	                     $level = level,
	                     $source = "zeek",
	                     $peer = peer,
	                     $message = msg));
	}

function ZeekAgent::log(level: string, peer: string, msg: string, log: any)
	{
	Log::write(log, Info($ts = network_time(),
	                     $level = level,
	                     $source = "host",
	                     $peer = peer,
	                     $message = msg));
	}

function same_event(q1: Query, q2: Query) : bool
	{
	if ( q1$query != q2$query  )
		return F;
	if ( q1?$ev != q2?$ev )
		return F;
	if ( q1?$ev && fmt("%s", q1$ev) != fmt("%s", q2$ev) )
		return F;
	if ( q1?$utype != q2?$utype )
		return F;
	if ( q1?$utype && q1$utype != q2$utype )
		return F;
	if ( q1?$resT != q2?$resT )
		return F;
	if ( q1?$resT && q1$resT != q2$resT )
		return F;
	if ( q1?$inter != q2?$inter )
		return F;
	if ( q1?$inter && q1$inter != q2$inter )
		return F;
	
	return T;
	}

event zeek_init() &priority=10
	{
	Log::create_stream(LOG, [$columns=Info, $path="zeek-agent"]);
	}
