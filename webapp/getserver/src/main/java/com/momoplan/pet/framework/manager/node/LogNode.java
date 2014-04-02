package com.momoplan.pet.framework.manager.node;

import java.io.IOException;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.ericsson.otp.erlang.OtpErlangAtom;
import com.ericsson.otp.erlang.OtpErlangBinary;
import com.ericsson.otp.erlang.OtpErlangInt;
import com.ericsson.otp.erlang.OtpErlangObject;
import com.ericsson.otp.erlang.OtpErlangString;
import com.ericsson.otp.erlang.OtpErlangTuple;
import com.ericsson.otp.erlang.OtpMbox;
import com.ericsson.otp.erlang.OtpNode;
import com.momoplan.pet.framework.manager.node.counter.CounterLog;

@Component
public class LogNode {
	
	private static Logger msg_logger = LoggerFactory.getLogger(LogNode.class);
	private static Logger counter_logger = LoggerFactory.getLogger(CounterLog.class);
	
	private String nodeCookie = null;
	private String nodePing = null;
	private String nodeName = null;
	private String nodeBox = null;
	
	@Autowired
	public LogNode(String nodeCookie, String nodePing, String nodeName,String nodeBox) {
		super();
		this.nodeCookie = nodeCookie;
		this.nodePing = nodePing;
		this.nodeName = nodeName;
		this.nodeBox = nodeBox;
	}

	@PostConstruct
	private void start_link() throws Exception{
		new Thread(new Runnable(){
			
			private void msg_log(OtpErlangObject obj){
				try{
					//tuple ::> {id,from,to,msgtype,body}
					OtpErlangTuple tuple = (OtpErlangTuple)obj;
					OtpErlangString id = (OtpErlangString)tuple.elementAt(0);
					OtpErlangString from = (OtpErlangString)tuple.elementAt(1);
					OtpErlangString to = (OtpErlangString)tuple.elementAt(2);
					OtpErlangString msgtype = (OtpErlangString)tuple.elementAt(3);
					OtpErlangBinary bin = (OtpErlangBinary)tuple.elementAt(4);
					String body = new String(bin.binaryValue());
					StringBuffer log = new StringBuffer("\02");
					log.append(id.stringValue()).append("\01");
					log.append(from.stringValue()).append("\01");
					log.append(to.stringValue()).append("\01");
					log.append(msgtype.stringValue()).append("\01");
					log.append(body);
					msg_logger.info(log.toString());
					//TODO write in cassandra
				}catch(Exception e){
					msg_logger.error("error", e);
				}
			}

			private void counter_log(OtpErlangObject obj){
				try{
					//tuple ::> {counter:atom,domain:string,total:int}
					OtpErlangTuple tuple = (OtpErlangTuple)obj;
					OtpErlangAtom counter = (OtpErlangAtom)tuple.elementAt(0);
					if("counter".equalsIgnoreCase(counter.atomValue())){
						OtpErlangString domain = (OtpErlangString)tuple.elementAt(1);
						OtpErlangInt total = (OtpErlangInt)tuple.elementAt(2);
						StringBuffer log = new StringBuffer("\02");
						log.append(domain.stringValue()).append("\01");
						log.append(total.intValue());
						counter_logger.info(log.toString());
						//TODO write in cassandra
					}
				}catch(Exception e){}
			}

			@Override
			public void run() {
				try {
					OtpNode node = new OtpNode(nodeName, nodeCookie);
					node.ping(nodePing, 5000);
					OtpMbox box = node.createMbox(nodeBox);
					msg_logger.debug("start_link...nodeName="+nodeName);
					msg_logger.debug("start_link...nodeCookie="+nodeCookie);
					msg_logger.debug("start_link...nodePing="+nodePing);
					msg_logger.debug("start_link...nodeBox="+nodeBox);
					while(true){
						try{
							//tuple ::> {id,from,to,msgtype,body}
							OtpErlangObject obj = box.receive();
							msg_log(obj);
							counter_log(obj);
						}catch(Exception e){
							msg_logger.error("error", e);
						}
					}				
				} catch (IOException e1) {
					e1.printStackTrace();
				}
			}
		}).start();;
	}
	
}