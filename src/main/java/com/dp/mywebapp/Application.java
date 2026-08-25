package com.dp.mywebapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class Application {

    public static String getMessage() {
        return "DP DevSecOps Platform";
    }

    @GetMapping("/")
    public String home() {
        return getMessage();
    }

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
