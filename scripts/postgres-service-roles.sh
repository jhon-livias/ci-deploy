#!/bin/sh
# Crea un usuario de PostgreSQL por microservicio, con permiso solo sobre su esquema.
# Las migraciones siguen ejecutándose con el usuario administrador.
set -eu

: "${PGUSER:?}"
: "${PGDATABASE:?}"

sql_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}

require_password() {
  value=$1
  name=$2
  if [ "${#value}" -lt 16 ]; then
    echo "$name debe tener al menos 16 caracteres." >&2
    exit 1
  fi
  printf "%s" "$(sql_quote "$value")"
}

apply_role() {
  role=$1
  schema=$2
  password=$3
  psql -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${role}') THEN
    CREATE ROLE ${role} LOGIN PASSWORD '${password}';
  ELSE
    ALTER ROLE ${role} WITH LOGIN PASSWORD '${password}';
  END IF;
END
\$\$;
GRANT CONNECT ON DATABASE ${PGDATABASE} TO ${role};
GRANT USAGE ON SCHEMA ${schema} TO ${role};
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA ${schema} TO ${role};
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA ${schema} TO ${role};
ALTER DEFAULT PRIVILEGES FOR ROLE ${PGUSER} IN SCHEMA ${schema}
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${role};
ALTER DEFAULT PRIVILEGES FOR ROLE ${PGUSER} IN SCHEMA ${schema}
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO ${role};
SQL
}

AUTH_PW=$(require_password "$AUTH_DB_PASSWORD" AUTH_DB_PASSWORD)
ACADEMIC_PW=$(require_password "$ACADEMIC_DB_PASSWORD" ACADEMIC_DB_PASSWORD)
STUDENTS_PW=$(require_password "$STUDENTS_DB_PASSWORD" STUDENTS_DB_PASSWORD)
ENROLLMENT_PW=$(require_password "$ENROLLMENT_DB_PASSWORD" ENROLLMENT_DB_PASSWORD)
ATTENDANCE_PW=$(require_password "$ATTENDANCE_DB_PASSWORD" ATTENDANCE_DB_PASSWORD)
PAYMENTS_PW=$(require_password "$PAYMENTS_DB_PASSWORD" PAYMENTS_DB_PASSWORD)
TICKETS_PW=$(require_password "$TICKETS_DB_PASSWORD" TICKETS_DB_PASSWORD)
STUDY_PLANS_PW=$(require_password "$STUDY_PLANS_DB_PASSWORD" STUDY_PLANS_DB_PASSWORD)

apply_role auth_user auth "$AUTH_PW"
apply_role academic_user academic "$ACADEMIC_PW"
apply_role students_user students "$STUDENTS_PW"
apply_role enrollment_user enrollment "$ENROLLMENT_PW"
apply_role attendance_user attendance "$ATTENDANCE_PW"
apply_role payments_user payments "$PAYMENTS_PW"
apply_role tickets_user tickets "$TICKETS_PW"
apply_role study_plans_user study_plans "$STUDY_PLANS_PW"
