package com.cc14514;

import java.io.IOException;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import com.cc14514.inf.AaRequest;
import com.ericsson.otp.erlang.OtpErlangAtom;
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

	@Autowired
	public JNode(String nodeCookie, String nodePing, String nodeName,String nodeBox) throws Exception {
		super();
		this.nodeCookie = nodeCookie;
		this.nodePing = nodePing;
		this.nodeName = nodeName;
		this.nodeBox = nodeBox;
	}

	@PostConstruct
	private void start_link() throws Exception {
		new Thread(new Runnable() {
			@Override
			public void run() {
					try {
						OtpNode node = new OtpNode(nodeName, nodeCookie);
						if(node.ping(nodePing, 1000)){
							logger.debug("true_ping="+nodeName);
						}else{
							logger.debug("false_ping="+nodeName);
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
								OtpErlangString type = new OtpErlangString(aa.getType());
								OtpErlangString content = new OtpErlangString(aa.getContent());
								OtpErlangTuple packet = new OtpErlangTuple(new OtpErlangObject[]{fun,sn,type,content});
								box.send("aa_inf_server_run", nodePing, packet);
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