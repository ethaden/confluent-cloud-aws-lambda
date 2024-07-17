package io.confluent.example.aws.lambda;

import java.util.List;
import java.util.UUID;

public record Customer(
    UUID id,
    String lastName,
    String givenName,
    List<Address> addresses
) {
    public Customer(
        String lastName,
        String givenName,
        List<Address> addresses) {
            this(UUID.randomUUID(), lastName, givenName, addresses);
        }
}
