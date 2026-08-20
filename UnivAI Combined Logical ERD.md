# UnivAI Combined Logical ERD

This is one logical view of the project data model. It combines the active
PostgreSQL domains, the MongoDB exam domain, and the reference-contract model.

- Blue entities are PostgreSQL.
- Green entities are MongoDB.
- Yellow entities are reference-contract entities, not a separate active database.
- Solid lines represent stored foreign-key or document-reference relationships.
- Dotted lines represent application-enforced, cross-database, or conceptual relationships.
- The diagram is intentionally large; use Mermaid preview zoom or export it to SVG.

Source: [`docs/final-project/diagrams/diagrams.md`](docs/final-project/diagrams/diagrams.md).

```mermaid
erDiagram
    direction LR

    %% ================================================================
    %% PostgreSQL: identity, governance, and operations
    %% ================================================================

    PG_APP_USER["user (PostgreSQL)"] {
        uuid id PK
        string registration_number UK
        string email UK
        string name
        string role
        boolean banned
        string ui_locale
    }

    PG_SESSION["session (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        string token UK
        datetime expires_at
    }

    PG_ACCOUNT["account (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        string provider_id
        string account_id
    }

    PG_VERIFICATION["verification (PostgreSQL)"] {
        uuid id PK
        string identifier
        string value
        datetime expires_at
    }

    PG_LEGAL_ACCEPTANCE["legal_acceptances (PostgreSQL)"] {
        int id PK
        uuid user_id FK
        string document_type
        string document_version
        datetime accepted_at
    }

    PG_PRIVACY_PREFERENCE["privacy_preferences (PostgreSQL)"] {
        uuid user_id PK, FK
        boolean sale_or_sharing_opt_out
        boolean limit_sensitive_data_use
    }

    PG_PRIVACY_REQUEST["privacy_requests (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        string request_type
        string status
        datetime due_at
    }

    PG_USER_SUBSCRIPTION["user_subscriptions (PostgreSQL)"] {
        uuid user_id PK, FK
        string plan_code
        string status
        string provider
    }

    PG_COIN_WALLET["credit_wallets (PostgreSQL)"] {
        uuid user_id PK, FK
        int balance
        int weekly_allowance
    }

    PG_COIN_TRANSACTION["credit_transactions (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        int amount
        int balance_after
        string idempotency_key UK
    }

    PG_NOTIFICATION_PREFERENCE["notification_preferences (PostgreSQL)"] {
        uuid user_id PK, FK
        string category PK
        boolean email_enabled
    }

    PG_NOTIFICATION_OUTBOX["notification_email_outbox (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        string event_key UK
        string status
    }

    PG_NOTIFICATION_DELIVERY_LOG["notification_email_delivery_log (PostgreSQL)"] {
        uuid id PK
        uuid user_id FK
        string category
        string status
    }

    PG_RATE_LIMIT_POLICY["user_rate_limit_policies (PostgreSQL)"] {
        uuid user_id PK, FK
        string scope PK
        int max_requests
        int window_seconds
    }

    PG_RATE_LIMIT_USAGE["user_rate_limit_usage (PostgreSQL)"] {
        uuid user_id PK, FK
        string scope PK
        datetime bucket_start PK
        int request_count
    }

    PG_FINAL_EXAM_CASE["final_exam_cases (PostgreSQL)"] {
        string student_id PK
        string curriculum_id PK
        uuid declined_by FK
        string official_exam_id
        datetime finalized_at
    }

    PG_AI_OUTPUT_REPORT["ai_output_reports (PostgreSQL)"] {
        int id PK
        string student_id
        uuid reviewed_by FK
        string target_type
        string status
    }

    PG_AUTH_AUDIT["auth_audit (PostgreSQL)"] {
        int id PK
        string actor_id
        string target_id
        string action
        datetime created_at
    }

    %% ================================================================
    %% PostgreSQL: learning, generation, attendance, and results
    %% ================================================================

    PG_COLLECTION["collections (PostgreSQL)"] {
        int id PK
        string student_id
        string name
    }

    PG_DOCUMENT["documents (PostgreSQL)"] {
        int id PK
        int collection_id FK
        string status
        string sha256
    }

    PG_PROGRAMME["programmes (PostgreSQL)"] {
        int id PK
        int collection_id FK
        string student_id
        int version
        string status
    }

    PG_BOOK["books (PostgreSQL)"] {
        int id PK
        string student_id
        string filename
        string source_sha256
        string status
        string generation_stage
    }

    PG_GENERATION_MILESTONE["course_generation_milestones (PostgreSQL)"] {
        int id PK
        int book_id FK
        string student_id
        int week
        string stage
        string status
    }

    PG_LECTURE_ARTIFACT["lecture_artifacts (PostgreSQL)"] {
        string artifact_id PK
        int book_id FK
        int week
        json lecture_json
        json script_json
        json slides_json
        json quiz_json
    }

    PG_LECTURE["lectures (PostgreSQL)"] {
        int id PK
        int book_id FK
        string artifact_id FK
        string student_id
        int week
        datetime starts_at
    }

    PG_ATTENDANCE["attendance (PostgreSQL)"] {
        int id PK
        int lecture_id FK
        string student_id
        string arrival_status
        int last_sentence_index
        int total_sentences
        float attended_seconds
        boolean is_connected
    }

    PG_QA_LOG["qa_log (PostgreSQL)"] {
        int id PK
        int lecture_id FK
        string student_id
        string trace_id UK
        string question
        string answer
        json citations
    }

    PG_OUTPUT_VERSION["output_versions (PostgreSQL)"] {
        int id PK
        int source_qa_id FK
        int book_id FK
        string student_id
        int version
        string status
    }

    PG_OUTPUT_FEEDBACK["output_feedback (runtime PostgreSQL)"] {
        int id PK
        int output_id FK
        string student_id
        string rating
        boolean issue
    }

    PG_SECTION_PACK["section_packs (PostgreSQL)"] {
        string pack_id PK
        string tenant_id
        string programme_id
        int approved_plan_version
        int week
    }

    PG_GRADE["grades (PostgreSQL)"] {
        int id PK
        string student_id
        string exam_id UK
        string kind
        float score
        boolean flagged
        json report
    }

    PG_COURSE_TRANSCRIPT["course_transcripts (PostgreSQL)"] {
        string id PK
        string student_id
        string course_key
        string review_status
    }

    PG_CERTIFICATE_ARTIFACT["certificate_artifacts (PostgreSQL)"] {
        string id PK
        string transcript_id FK, UK
        string storage_ref
    }

    %% ================================================================
    %% MongoDB: exam domain
    %% ================================================================

    MG_STUDENT["students (MongoDB)"] {
        objectid id PK
        string sid UK
        string name
    }

    MG_BOOK["books (MongoDB)"] {
        objectid id PK
        objectid requested_by_student_id FK
        string status
    }

    MG_CURRICULUM["curricula (MongoDB)"] {
        objectid id PK
        objectid book_id FK
        objectid owner_student_id FK
        int source_book_id
        string source_sha256
        string status
    }

    MG_ENROLLMENT["enrollments (MongoDB)"] {
        objectid id PK
        objectid student_id FK
        objectid curriculum_id FK
        string status
    }

    MG_CHAPTER["chapters (MongoDB)"] {
        objectid id PK
        objectid curriculum_id FK
        string title
        int sequence
    }

    MG_ASSESSMENT_BLUEPRINT["assessment_blueprints (MongoDB)"] {
        objectid id PK
        string programme
        string semester
        string course_id
        string plan_version
        boolean approved
    }

    MG_QUESTION_PROVENANCE["question_provenance (MongoDB)"] {
        objectid id PK
        objectid blueprint_id FK
        objectid curriculum_id FK
        objectid chapter_id FK
        string source_hash
    }

    MG_QUESTION_BANK["question_bank (MongoDB)"] {
        objectid id PK
        string learner_id
        objectid chapter_id FK
        string status
    }

    MG_EXAM["exams (MongoDB)"] {
        objectid id PK
        objectid student_id FK
        objectid curriculum_id FK
        objectid blueprint_id FK
        string type
        string grading_status
        string integrity_status
        string review_status
    }

    MG_EXAM_CHAPTER["exam_chapters (MongoDB)"] {
        objectid id PK
        objectid exam_id FK
        objectid chapter_id FK
    }

    MG_EXAM_SESSION["exam_sessions (MongoDB)"] {
        objectid id PK
        objectid exam_id FK, UK
        string status
        string integrity_state
        string access_token_hash
        int answer_revision
        float suspicion_score
    }

    MG_EXAM_ATTEMPT_RECORD["exam_attempt_records (MongoDB)"] {
        objectid id PK
        objectid learner_id FK
        objectid source_exam_id FK
        string assessment_type
        string assessment_id
        int previous_attempt_number
    }

    MG_PROCTORING_EVENT["proctoring_events (MongoDB)"] {
        objectid id PK
        objectid exam_id FK
        string event_type
        float suspicion_delta
        datetime occurred_at
    }

    MG_GRADE_HISTORY["grade_history (MongoDB)"] {
        objectid id PK
        objectid exam_id FK
        float score
        string grading_status
    }

    MG_INTEGRITY_EVENT["integrity_events (MongoDB)"] {
        objectid id PK
        objectid exam_id FK
        string event_type
    }

    MG_INTEGRITY_APPEAL["integrity_appeals (MongoDB)"] {
        objectid id PK
        objectid exam_id FK
        string status
    }

    %% ================================================================
    %% Reference contracts: target/reference model, not active runtime ERD
    %% ================================================================

    REF_SOURCE_COLLECTION["source_collection (reference)"] {
        string id PK
        string tenant_id
        string status
    }

    REF_SOURCE_DOCUMENT["source_document (reference)"] {
        string id PK
        string collection_id FK
        string status
    }

    REF_INGESTION_JOB["ingestion_job (reference)"] {
        string id PK
        string collection_id FK
        string document_id FK
        string status
    }

    REF_PROGRAMME_PLAN["programme_plan (reference)"] {
        string id PK
        string source_collection_id FK
        int version
        string status
    }

    REF_GENERATION_JOB["generation_job (reference)"] {
        string id PK
        string source_collection_id FK
        string programme_plan_id FK
        int programme_plan_version
        string status
    }

    REF_LEARNING_PATH["learning_path (reference)"] {
        string path_id PK
        string tenant_id
        string status
    }

    REF_SEMESTER_WEEK_PLAN["semester_week_plan (reference)"] {
        string id PK
        string path_id FK
        int week
    }

    REF_SCHEDULE_ITEM["schedule_item (reference)"] {
        string id PK
        string week_plan_id FK
    }

    REF_SECTION_PACK["section_pack (reference)"] {
        string id PK
        string week_plan_id FK
    }

    REF_ASSESSMENT_PACKAGE["assessment_package (reference)"] {
        string id PK
        string week_plan_id FK
    }

    REF_PUBLICATION_RECEIPT["publication_receipt (reference)"] {
        string id PK
        string assessment_package_id FK
        string status
    }

    %% ================================================================
    %% PostgreSQL relationships
    %% ================================================================

    PG_APP_USER ||--o{ PG_SESSION : has
    PG_APP_USER ||--o{ PG_ACCOUNT : authenticates_with
    PG_APP_USER ||--o{ PG_LEGAL_ACCEPTANCE : accepts
    PG_APP_USER ||--o| PG_PRIVACY_PREFERENCE : configures
    PG_APP_USER ||--o{ PG_PRIVACY_REQUEST : submits
    PG_APP_USER ||--o| PG_USER_SUBSCRIPTION : holds
    PG_APP_USER ||--o| PG_COIN_WALLET : owns
    PG_APP_USER ||--o{ PG_COIN_TRANSACTION : receives
    PG_APP_USER ||--o{ PG_NOTIFICATION_PREFERENCE : configures
    PG_APP_USER ||--o{ PG_NOTIFICATION_OUTBOX : receives
    PG_APP_USER ||--o{ PG_NOTIFICATION_DELIVERY_LOG : receives
    PG_APP_USER ||--o{ PG_RATE_LIMIT_POLICY : governed_by
    PG_APP_USER ||--o{ PG_RATE_LIMIT_USAGE : consumes
    PG_APP_USER o|--o{ PG_FINAL_EXAM_CASE : may_decline
    PG_APP_USER o|--o{ PG_AI_OUTPUT_REPORT : reviews
    PG_APP_USER ||..o{ PG_FINAL_EXAM_CASE : owns_logically
    PG_APP_USER ||..o{ PG_AI_OUTPUT_REPORT : submits_logically
    PG_APP_USER ||..o{ PG_AUTH_AUDIT : actor_or_target

    PG_COLLECTION ||--o{ PG_DOCUMENT : contains
    PG_COLLECTION ||--o{ PG_PROGRAMME : proposes
    PG_BOOK ||--o{ PG_GENERATION_MILESTONE : checkpoints
    PG_BOOK ||--o{ PG_LECTURE_ARTIFACT : generates
    PG_BOOK ||--o{ PG_LECTURE : schedules
    PG_LECTURE_ARTIFACT o|--o{ PG_LECTURE : may_back
    PG_LECTURE ||--o{ PG_ATTENDANCE : records
    PG_LECTURE o|--o{ PG_QA_LOG : receives
    PG_QA_LOG ||--o{ PG_OUTPUT_VERSION : versions
    PG_BOOK ||--o{ PG_OUTPUT_VERSION : scopes
    PG_OUTPUT_VERSION ||--o{ PG_OUTPUT_FEEDBACK : receives
    PG_COURSE_TRANSCRIPT ||--o| PG_CERTIFICATE_ARTIFACT : certifies

    PG_APP_USER ||..o{ PG_COLLECTION : owns_by_registration_number
    PG_APP_USER ||..o{ PG_PROGRAMME : owns_by_registration_number
    PG_APP_USER ||..o{ PG_BOOK : owns_by_registration_number
    PG_APP_USER ||..o{ PG_LECTURE : owns_by_registration_number
    PG_APP_USER ||..o{ PG_ATTENDANCE : owns_by_registration_number
    PG_APP_USER ||..o{ PG_QA_LOG : owns_by_registration_number
    PG_APP_USER ||..o{ PG_OUTPUT_VERSION : owns_by_registration_number
    PG_APP_USER ||..o{ PG_OUTPUT_FEEDBACK : owns_by_registration_number
    PG_APP_USER ||..o{ PG_SECTION_PACK : owns_by_tenant_id
    PG_APP_USER ||..o{ PG_GRADE : owns_by_registration_number
    PG_APP_USER ||..o{ PG_COURSE_TRANSCRIPT : owns_by_registration_number
    PG_PROGRAMME ||..o{ PG_SECTION_PACK : binds_approved_version

    %% ================================================================
    %% MongoDB relationships
    %% ================================================================

    MG_STUDENT o|--o{ MG_BOOK : requests
    MG_BOOK o|--o{ MG_CURRICULUM : may_define
    MG_STUDENT o|--o{ MG_CURRICULUM : may_personalize
    MG_STUDENT ||--o{ MG_ENROLLMENT : has
    MG_CURRICULUM ||--o{ MG_ENROLLMENT : enrolls
    MG_CURRICULUM ||--o{ MG_CHAPTER : contains
    MG_CURRICULUM ||..o{ MG_ASSESSMENT_BLUEPRINT : matched_by_programme_and_plan
    MG_ASSESSMENT_BLUEPRINT ||--o{ MG_QUESTION_PROVENANCE : traces
    MG_CURRICULUM o|--o{ MG_QUESTION_PROVENANCE : scopes
    MG_CHAPTER o|--o{ MG_QUESTION_PROVENANCE : grounds
    MG_CHAPTER ||--o{ MG_QUESTION_BANK : supplies
    MG_STUDENT ||..o{ MG_QUESTION_BANK : owns_by_learner_id
    MG_STUDENT ||--o{ MG_EXAM : takes
    MG_CURRICULUM ||--o{ MG_EXAM : assesses
    MG_ASSESSMENT_BLUEPRINT o|--o{ MG_EXAM : binds
    MG_EXAM ||--o{ MG_EXAM_CHAPTER : covers
    MG_CHAPTER ||--o{ MG_EXAM_CHAPTER : included_in
    MG_EXAM ||--o| MG_EXAM_SESSION : runs_as
    MG_EXAM ||--o{ MG_EXAM_ATTEMPT_RECORD : gates
    MG_STUDENT ||--o{ MG_EXAM_ATTEMPT_RECORD : owns
    MG_EXAM ||--o{ MG_PROCTORING_EVENT : observes
    MG_EXAM ||--o{ MG_GRADE_HISTORY : versions
    MG_EXAM ||--o{ MG_INTEGRITY_EVENT : records
    MG_EXAM ||--o{ MG_INTEGRITY_APPEAL : receives

    %% ================================================================
    %% Reference-contract relationships
    %% ================================================================

    REF_SOURCE_COLLECTION ||--o{ REF_SOURCE_DOCUMENT : contains
    REF_SOURCE_COLLECTION ||--o{ REF_INGESTION_JOB : receives
    REF_SOURCE_DOCUMENT ||--o{ REF_INGESTION_JOB : ingested_by
    REF_SOURCE_COLLECTION ||--o{ REF_PROGRAMME_PLAN : plans
    REF_SOURCE_COLLECTION ||--o{ REF_GENERATION_JOB : generates
    REF_PROGRAMME_PLAN ||--o{ REF_GENERATION_JOB : pins_version
    REF_LEARNING_PATH ||--o{ REF_SEMESTER_WEEK_PLAN : schedules
    REF_SEMESTER_WEEK_PLAN ||--o{ REF_SCHEDULE_ITEM : contains
    REF_SEMESTER_WEEK_PLAN ||--o{ REF_SECTION_PACK : publishes
    REF_SEMESTER_WEEK_PLAN ||--o{ REF_ASSESSMENT_PACKAGE : assesses
    REF_ASSESSMENT_PACKAGE ||--o{ REF_PUBLICATION_RECEIPT : acknowledges

    %% ================================================================
    %% Cross-database and reference-to-runtime logical relationships
    %% ================================================================

    PG_APP_USER ||..o| MG_STUDENT : syncs_by_registration_number
    PG_BOOK ||..o{ MG_CURRICULUM : seeds_by_source_book_id
    PG_LECTURE ||..o{ MG_CHAPTER : seeds_by_week
    MG_EXAM ||..o| PG_GRADE : returns_result_by_exam_id
    MG_EXAM ||..o| PG_FINAL_EXAM_CASE : updates_final_case

    REF_SOURCE_COLLECTION ||..o| PG_COLLECTION : maps_to_active_collection
    REF_SOURCE_DOCUMENT ||..o| PG_DOCUMENT : maps_to_active_document
    REF_PROGRAMME_PLAN ||..o| PG_PROGRAMME : maps_to_active_programme
    REF_GENERATION_JOB ||..o{ PG_GENERATION_MILESTONE : maps_to_checkpoints
    REF_SECTION_PACK ||..o| PG_SECTION_PACK : maps_to_active_pack
    REF_ASSESSMENT_PACKAGE ||..o{ MG_EXAM : contracts_exam_publication

    %% ================================================================
    %% Visual datastore grouping
    %% ================================================================

    classDef postgres fill:#dbeafe,stroke:#2563eb,color:#0f172a,stroke-width:1px
    classDef mongodb fill:#dcfce7,stroke:#16a34a,color:#0f172a,stroke-width:1px
    classDef reference fill:#fef3c7,stroke:#d97706,color:#0f172a,stroke-width:1px

    class PG_APP_USER,PG_SESSION,PG_ACCOUNT,PG_VERIFICATION,PG_LEGAL_ACCEPTANCE,PG_PRIVACY_PREFERENCE,PG_PRIVACY_REQUEST,PG_USER_SUBSCRIPTION,PG_COIN_WALLET,PG_COIN_TRANSACTION postgres
    class PG_NOTIFICATION_PREFERENCE,PG_NOTIFICATION_OUTBOX,PG_NOTIFICATION_DELIVERY_LOG,PG_RATE_LIMIT_POLICY,PG_RATE_LIMIT_USAGE,PG_FINAL_EXAM_CASE,PG_AI_OUTPUT_REPORT,PG_AUTH_AUDIT postgres
    class PG_COLLECTION,PG_DOCUMENT,PG_PROGRAMME,PG_BOOK,PG_GENERATION_MILESTONE,PG_LECTURE_ARTIFACT,PG_LECTURE,PG_ATTENDANCE,PG_QA_LOG,PG_OUTPUT_VERSION,PG_OUTPUT_FEEDBACK postgres
    class PG_SECTION_PACK,PG_GRADE,PG_COURSE_TRANSCRIPT,PG_CERTIFICATE_ARTIFACT postgres

    class MG_STUDENT,MG_BOOK,MG_CURRICULUM,MG_ENROLLMENT,MG_CHAPTER,MG_ASSESSMENT_BLUEPRINT,MG_QUESTION_PROVENANCE,MG_QUESTION_BANK mongodb
    class MG_EXAM,MG_EXAM_CHAPTER,MG_EXAM_SESSION,MG_EXAM_ATTEMPT_RECORD,MG_PROCTORING_EVENT,MG_GRADE_HISTORY,MG_INTEGRITY_EVENT,MG_INTEGRITY_APPEAL mongodb

    class REF_SOURCE_COLLECTION,REF_SOURCE_DOCUMENT,REF_INGESTION_JOB,REF_PROGRAMME_PLAN,REF_GENERATION_JOB,REF_LEARNING_PATH reference
    class REF_SEMESTER_WEEK_PLAN,REF_SCHEDULE_ITEM,REF_SECTION_PACK,REF_ASSESSMENT_PACKAGE,REF_PUBLICATION_RECEIPT reference
```

## Important qualification

This is a combined **logical ERD**, not one physical database schema. PostgreSQL
and MongoDB remain separate stores. The reference-contract entities describe a
target/reference model, and dotted relationships are not guaranteed by database
foreign keys.
