package es.vicfuen02.auto_ec2_deploy;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/")
public class EC2RestController {


    @RequestMapping
    public String echo() {
        return "Hi this is a sb app";
    }

}
