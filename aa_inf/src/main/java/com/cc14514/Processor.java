package com.cc14514;

import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.BlockingQueue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.cc14514.inf.AaRequest;

public class Processor {
	
	
	private static Logger logger = LoggerFactory.getLogger(Processor.class);
	
	public static BlockingQueue<AaRequest> queue = new ArrayBlockingQueue<AaRequest>(100000, true);
	
	private static Thread pro = null;

	public static void put(AaRequest request){
		try {
			queue.put(request);
			logger.info("queue_size="+queue.size()+" ; "+request.toString());
		} catch (InterruptedException e) {
			e.printStackTrace();
			logger.error("queue_put_error", e);
		}
	}
	
}
