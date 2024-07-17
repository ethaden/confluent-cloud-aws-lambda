package io.confluent.example.aws.lambda;

public record Address(
    String street,
    String city,
    String zipCode,
    String state,
    String country,
    String extraInfo,
    boolean isPrimaryAdress
) {
        public Address(
            String street,
            String city,
            String zipCode,
            String state,
            String country,
            String extraInfo
        ) {
            this(street, city, zipCode, state, country, extraInfo, true);
    }
}
