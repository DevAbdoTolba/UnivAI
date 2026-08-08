-- A learner may not have given a phone number.
--
-- It was NOT NULL because registration always collected one. Google sign-in
-- carries no phone number, so that stopped being true the moment an account
-- could be created any other way — and a required field on one route only
-- describes how the account happened to be created, not the learner.
--
-- NULL means "not given". Existing rows that were written as '' meant the same
-- thing and become NULL, so one absent value has one representation and
-- `phone IS NULL` is the whole question.

ALTER TABLE "user" ALTER COLUMN "phone" DROP NOT NULL;

UPDATE "user" SET "phone" = NULL WHERE btrim("phone") = '';
