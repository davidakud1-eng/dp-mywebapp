package com.dp.mywebapp;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ApplicationTest {

    @Test
    void shouldReturnApplicationMessage() {
        assertEquals("DP DevSecOps Platform", Application.getMessage());
    }
}
