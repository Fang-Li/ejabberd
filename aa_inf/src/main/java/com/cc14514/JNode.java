package com.cc14514;

import java.io.IOException;
import java.util.Date;
import java.util.Set;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.cc14514.inf.AaRequest;
import com.cc14514.zoo.ConfigWatcher;
import com.ericsson.otp.erlang.OtpErlangAtom;
import com.ericsson.otp.erlang.OtpErlangBinary;
import com.ericsson.otp.erlang.OtpErlangObject;
import com.ericsson.otp.erlang.OtpErlangString;
import com.ericsson.otp.erlang.OtpErlangTuple;
import com.ericsson.otp.erlang.OtpMbox;
import com.ericsson.otp.erlang.OtpNode;

@Component
public class JNode {

	private static Logger logger = LoggerFactory.getLogger(JNode.class);
	private String nodeCookie = null;
	private String nodePing = null;
	private String nodeName = null;
	private String nodeBox = null;

	private static String nodeMapBasePath = "/ejabberd-node";
	public ConfigWatcher nodeMap = null;
	@Autowired
	public JNode(String nodeCookie, String nodePing, String nodeName,String nodeBox,String zooServer) throws Exception {
		super();
		this.nodeCookie = nodeCookie;
		this.nodePing = nodePing;
		this.nodeName = nodeName;
		this.nodeBox = nodeBox;
		this.nodeMap = new ConfigWatcher(zooServer,nodeMapBasePath);
	}
	
	public String getNode(){
		Set<String> keyset = nodeMap.publicConfig.keySet();
		Object[] arr = keyset.toArray();
		int len = arr.length;
		long t = new Date().getTime();
		return arr[(int)(t%len)].toString();
	}
	
	@PostConstruct
	private void start_link() throws Exception {
		new Thread(new Runnable() {
			@Override
			public void run() {
					try {
						OtpNode node = new OtpNode(nodeName, nodeCookie);
						Set<String> keyset = nodeMap.publicConfig.keySet();
						for(String n : keyset){
							boolean rtn = node.ping(n, 1000);
							logger.debug("ping="+n+" ; rtn="+rtn);
						}
						OtpMbox box = node.createMbox(nodeBox);
						logger.debug("start_link...nodeName=" + nodeName);
						logger.debug("start_link...nodeCookie=" + nodeCookie);
						logger.debug("start_link...nodePing=" + nodePing);
						logger.debug("start_link...nodeBox=" + nodeBox);
						while (true) {
							try {
								AaRequest aa = Processor.queue.take();
								OtpErlangAtom fun = new OtpErlangAtom("retome_push");
								OtpErlangString sn = new OtpErlangString(aa.getSn());
								OtpErlangBinary type = new OtpErlangBinary(aa.getType().getBytes());
								OtpErlangBinary content = new OtpErlangBinary(aa.getContent().getBytes());
								OtpErlangTuple packet = new OtpErlangTuple(new OtpErlangObject[]{fun,sn,type,content});
								String targetNode = getNode();
								logger.info("sn="+sn+" ; targetNode="+targetNode);
								box.send("aa_inf_server_run", targetNode , packet);
							} catch (Exception e) {
								logger.error("error", e);
							}
						}
					} catch (IOException e1) {
						e1.printStackTrace();
					}
			}
		}).start();
	}

}