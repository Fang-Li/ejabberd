package com.cc14514;

import java.net.InetSocketAddress;
import java.util.List;

import org.apache.thrift.TException;
import org.apache.thrift.protocol.TBinaryProtocol;
import org.apache.thrift.server.TServer;
import org.apache.thrift.server.TThreadPoolServer;
import org.apache.thrift.server.TThreadPoolServer.Args;
import org.apache.thrift.transport.TServerSocket;
import org.apache.thrift.transport.TServerTransport;
import org.apache.thrift.transport.TTransportFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationContext;
import org.springframework.context.support.ClassPathXmlApplicationContext;

import com.cc14514.inf.AaRequest;

public class Main {

	private static Logger logger = LoggerFactory.getLogger(Main.class);
	
	private static String paths[] = { "spring/applicationContext.xml" };
	public static ApplicationContext ctx = null;
	
	private static int DEFAULT_PORT = 6281;
	
	static class aa_inf_impl implements com.cc14514.inf.aa_inf.Iface {

		@Override
		public String process(AaRequest request) throws TException {
			Processor.put(request);
			return "ok";
		}

		@Override
		public String process_batch(List<AaRequest> request) throws TException {
			for(AaRequest aa : request){
				Processor.put(aa);
			}
			return "ok";
		}
	}

	public static void main(String[] args) {
		int port = DEFAULT_PORT;
		if(args!=null&&args.length>0){
			String p = args[0];
			port = Integer.parseInt(p);
		}
		logger.info("启动端口："+port);
		ctx = new ClassPathXmlApplicationContext(paths);
		com.cc14514.inf.aa_inf.Processor<aa_inf_impl> processor = new com.cc14514.inf.aa_inf.Processor<aa_inf_impl>(new aa_inf_impl());
		TServer server = null;
		try {
			TServerTransport serverTransport = new TServerSocket(new InetSocketAddress("0.0.0.0", port));
			Args trArgs = new Args(serverTransport);
			trArgs.processor(processor);
			trArgs.protocolFactory(new TBinaryProtocol.Factory(true, true));
			trArgs.transportFactory(new TTransportFactory());
			server = new TThreadPoolServer(trArgs);
			logger.info("server begin >>>>>>");
			server.serve();
		} catch (Exception e) {
			if (server != null && server.isServing())
				server.stop();
			logger.info("server error <<<<<<");
			logger.error("server error", e);
			throw new RuntimeException("index thrift server start failed!!"+ "/n" + e.getMessage());
		}
	}

}