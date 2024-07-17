/*
 * This source file was generated by the Gradle 'init' task
 */
package io.confluent.example.aws.lambda;

import java.util.Base64;
import java.util.Base64.Decoder;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.KafkaEvent;
import com.google.gson.Gson;

public class App implements RequestHandler<KafkaEvent, Void> {

    @Override
    public Void handleRequest(KafkaEvent event, Context context) {
        Decoder base64Decoder = Base64.getDecoder();
        if (context != null) {
            LambdaLogger logger = context.getLogger();
            //logger.log("EVENT TYPE: " + event.getClass());
            logger.log("EVENT: " + event.toString());
            event.getRecords().forEach((k, v) -> {
                v.forEach((record) -> {
                    //logger.log(k+" IS "+v.getValue().toString());
                    logger.log(record.getValue());
                    Gson gson = new Gson();
                    Customer customer = gson.fromJson(new String(base64Decoder.decode(record.getValue())), Customer.class);
                    logger.log("Customer: "+customer.toString());
                });
            });
            logger.log(event.toString());
            // event.forEach((k, v) -> {
            //     logger.log("key TYPE: " + k.getClass() + ". Value TYPE: "+v.getClass());
            //     logger.log("key="+k.toString()+". value="+v.toString());
            // });
            // Gson gson = new Gson();
            // event.forEach((k, v) -> {
            //     //AWSLambdaKafkaRecordBatch recordBatch = gson.fromJson((String)v, AWSLambdaKafkaRecordBatch.class);
            //     //logger.log(recordBatch.toString());
            //     logger.log(v.toString());
            // });
        } else {
            event.getRecords().forEach((k, v) -> {
                v.forEach((record) -> {
                    //logger.log(k+" IS "+v.getValue().toString());
                    System.out.println(record.getValue());
                    Gson gson = new Gson();
                    Customer customer = gson.fromJson(record.getValue(), Customer.class);
                    System.out.println("Customer: "+customer.toString());
                });
            });
        }
        return null;
    }

    public static void main(String[] args) {
        //new App().handleRequest(Map.of("Lambda!", null), null);
    }
}
