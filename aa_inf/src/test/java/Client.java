
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import org.apache.thrift.TException;

import com.cc14514.inf.AaRequest;

public class Client {

	
	
	public static void main(String[] args) throws TException {  
		long start=System.currentTimeMillis();

        
        Map<String,String> params = new HashMap<String,String>();
        params.put("userId", "731");
        AaRequest request = new AaRequest();
        request.sn = UUID.randomUUID().toString();
//        for(int i=0;i<1;i++){
//        	TTransport transport = new TSocket("127.0.0.1", 8877);
//        	TProtocol protocol = new TBinaryProtocol(transport);  
//        	ProcessServices.Client client=new ProcessServices.Client(protocol);  
//        	transport.open();
//        	RemoteSuccess success = client.process(request);
//        	System.out.println(success.toString());
//        	transport.close();
//        }

        
        System.out.println((System.currentTimeMillis()-start));
        System.out.println("client sucess!");
    }
}