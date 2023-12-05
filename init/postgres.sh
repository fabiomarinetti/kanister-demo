#!/bin/bash

cat <<EOT | PGPASSWORD=$POSTGRES_PASSWORD psql -U pgadmin -d postgres -f -
CREATE DATABASE testdb;

-- CONNECT TO testdb;
\c testdb;

CREATE SEQUENCE test_id_seq;

CREATE TABLE test(
  "id" INTEGER PRIMARY KEY DEFAULT nextval('test_id_seq'),
  "fullname" VARCHAR(255),
  "email" VARCHAR(255)
);

INSERT INTO test (fullname, email) VALUES ('Gigetto Fantoni', 'gfantoni@expert.ai');
INSERT INTO test (fullname, email) VALUES ('Marco Pisellonio', 'mpisellonio@expert.ai');
EOT

exit 0
