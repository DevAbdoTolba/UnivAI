-- Assessment and slide counts are fixed by their generation contracts. The
-- obsolete global XS-XL selector must not influence any learner again.
DELETE FROM settings WHERE key = 'course_size';
