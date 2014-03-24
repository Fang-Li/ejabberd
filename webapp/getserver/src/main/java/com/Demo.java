package com;

import com.ericsson.otp.erlang.OtpErlangAtom;
import com.ericsson.otp.erlang.OtpErlangObject;
import com.ericsson.otp.erlang.OtpErlangString;
import com.ericsson.otp.erlang.OtpErlangTuple;
import com.ericsson.otp.erlang.OtpMbox;
import com.ericsson.otp.erlang.OtpNode;

public class Demo {
	
	public static void main(String[] args) throws Exception {
		OtpNode node = new OtpNode("cc@s3", "CQYWMBXMSIDNHOFNVNNY");
		node.ping("ecache@s2", 5000);
		OtpMbox box = node.createMbox("jnode");
		
		OtpErlangString msg = new OtpErlangString("<message><body>hello world.</body></message>");
		OtpErlangAtom atom0 = new OtpErlangAtom("jnode");
		OtpErlangAtom atom1 = new OtpErlangAtom("cc@s3");
		OtpErlangTuple tuple = new OtpErlangTuple(new OtpErlangObject[]{atom0,atom1,msg});
		System.out.println(tuple.toString());
		box.send("loop", "test@s2", tuple);
		while(true){
			OtpErlangObject rev = box.receive();
			OtpErlangTuple result = (OtpErlangTuple)rev;
			OtpErlangString m = (OtpErlangString)result.elementAt(2);
			
			System.out.println(rev.toString());
			System.out.println("m="+m.toString()+" ; "+m.equals("close"));
			if(m.equals("close")){
				System.out.println("break");
				break;
			}
		}
		System.out.println("OVER...");
	}
}
